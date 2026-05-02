"""tools/tts/regenerate_manifest.py — Phase 13 Workstream C step 4.

Standalone driver that emits `lib/gen/audio_manifest.g.dart` and
`lib/core/manifest/utterance_key.dart` from the current manifest.yaml
+ reviewed.yaml using the Phase 13 soft gate
(`allow_technically_reviewed=True`).

Distinct from `bake_audio.py` (which also synthesizes / normalizes via
piper / ffmpeg). This script does NO synthesis — it only does the
plan + manifest emission stages, reading durations from
`tools/tts/last-run.json` if present, otherwise probing the existing
AAC files directly with ffprobe.
"""
from __future__ import annotations

import argparse
import json
import logging
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml

# When invoked as a script, ensure the repo root is importable.
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from tools.tts.manifest_writer import (  # noqa: E402
    write_audio_manifest,
    text_hash as compute_text_hash,
)

log = logging.getLogger("regenerate_manifest")


def _probe_duration_ms(path: Path) -> int:
    """Return duration in milliseconds via ffprobe (0 on failure)."""
    argv = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(path),
    ]
    completed = subprocess.run(argv, capture_output=True, timeout=15.0, check=False)
    if completed.returncode != 0:
        return 0
    try:
        return int(round(float(completed.stdout.decode("utf-8").strip()) * 1000))
    except ValueError:
        return 0


def _resolve_used_text_voice(entry: dict, overrides: dict, manifest_voice: str) -> tuple[str, str]:
    """Mirror PiperClient._resolve_text_voice for the (text, voice) pair."""
    key = entry["key"]
    override = (overrides or {}).get(key, {}) or {}
    if "text" in override and override["text"]:
        used_text = override["text"]
    elif "phonemes" in override and override["phonemes"]:
        used_text = override["phonemes"]
    else:
        used_text = entry["text"]
    used_voice = entry.get("voice") or manifest_voice
    return used_text, used_voice


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Phase 13: regenerate audio_manifest.g.dart using the "
                    "soft gate (technically_reviewed)."
    )
    parser.add_argument("--manifest", default="manifest.yaml")
    parser.add_argument("--overrides", default="pronunciation_overrides.yaml")
    parser.add_argument("--reviewed", default="reviewed.yaml")
    parser.add_argument("--out-manifest", default="lib/gen/audio_manifest.g.dart")
    parser.add_argument("--out-enum", default="lib/core/manifest/utterance_key.dart")
    parser.add_argument(
        "--last-run", default="tools/tts/last-run.json",
        help="Read measured durations from this last-run.json if present.",
    )
    parser.add_argument(
        "--last-technical-review",
        default="tools/tts/last-technical-review.json",
        help="Read measured durations from this technical-review report "
             "as a fallback.",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(message)s")

    manifest = yaml.safe_load(Path(args.manifest).read_text()) or {}
    overrides = (
        yaml.safe_load(Path(args.overrides).read_text()) or {}
        if Path(args.overrides).is_file()
        else {"version": 1, "overrides": {}}
    )
    reviewed = (
        yaml.safe_load(Path(args.reviewed).read_text()) or {}
        if Path(args.reviewed).is_file()
        else {"version": 1, "entries": {}}
    )

    overrides_dict = (overrides or {}).get("overrides") or {}

    # Build durations map from last-run.json (preferred) or
    # last-technical-review.json (fallback) or live ffprobe.
    durations: dict = {}
    last_run_path = Path(args.last_run)
    if last_run_path.is_file():
        try:
            data = json.loads(last_run_path.read_text())
            for k, rec in (data.get("per_utterance") or {}).items():
                if "duration_ms" in rec:
                    durations[k] = int(rec["duration_ms"])
        except (json.JSONDecodeError, KeyError):
            pass

    tech_path = Path(args.last_technical_review)
    if tech_path.is_file():
        try:
            data = json.loads(tech_path.read_text())
            for k, rec in (data.get("per_entry") or {}).items():
                if k not in durations and "duration_ms" in rec:
                    durations[k] = int(rec["duration_ms"])
        except (json.JSONDecodeError, KeyError):
            pass

    # Fall back to live ffprobe for any keys still missing.
    for u in manifest["utterances"]:
        if u["key"] not in durations:
            asset = Path(u["asset"])
            if asset.is_file():
                durations[u["key"]] = _probe_duration_ms(asset)
            else:
                durations[u["key"]] = 0

    # Build used_texts map (needed for review-gate audit-trail check on
    # any reviewed:true entries; technically_reviewed entries are
    # checked against this map only when reviewed:true is also true).
    used_texts = {
        u["key"]: _resolve_used_text_voice(u, overrides_dict, manifest["voice"])
        for u in manifest["utterances"]
    }

    write_audio_manifest(
        manifest,
        reviewed,
        used_texts,
        durations,
        out_manifest_path=Path(args.out_manifest),
        out_enum_path=Path(args.out_enum),
        allow_technically_reviewed=True,
        generated_at=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    )

    # Summary.
    entries = (reviewed or {}).get("entries") or {}
    n_pending = sum(
        1 for u in manifest["utterances"]
        if (entries.get(u["key"]) or {}).get("reviewed") is not True
    )
    n_total = len(manifest["utterances"])
    print(
        f"Regenerated {args.out_manifest}: {n_total} entries "
        f"({n_pending} pending native-speaker pronunciation review)"
    )
    print(f"Regenerated {args.out_enum}: {n_total} keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
