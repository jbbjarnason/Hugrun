"""tools/tts/bake_audio.py — Plan 04 pipeline orchestrator (Piper migration).

Stages (D-02):
  1. Plan      — read manifest/overrides/reviewed; classify each utterance.
  2. Generate  — call PiperClient.synthesize for to_generate utterances.
  3. Normalize — call Normalizer.normalize_to_aac for newly generated raws.
  4. Review gate — assert every utterance is reviewed: true + text_hash matches.
  5. Manifest  — manifest_writer.write_audio_manifest if review gate passes.

Atomic per utterance (D-03): a failure in any stage for one utterance is
captured in last-run.json without aborting the run.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import logging
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

import yaml

# When invoked as a script, ensure the repo root is importable.
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from tools.tts.schema import (  # noqa: E402
    validate_manifest,
    validate_overrides,
    validate_reviewed,
)
from tools.tts.piper_client import (  # noqa: E402
    PiperClient,
    PiperError,
    PiperVoiceMissingError,
    SynthesisResult,
)
from tools.tts.normalize import (  # noqa: E402
    Normalizer,
    NormalizeError,
    NormalizeResult,
)
from tools.tts.manifest_writer import (  # noqa: E402
    write_audio_manifest,
    text_hash as compute_text_hash,
    ReviewGateError,
)

log = logging.getLogger("bake_audio")


@dataclass
class BakePlan:
    started_at: str
    finished_at: str | None
    total_utterances: int
    per_utterance: dict = field(default_factory=dict)
    manifest_written: bool = False
    next_action: str = ""

    def to_dict(self) -> dict:
        return {
            "started_at": self.started_at,
            "finished_at": self.finished_at,
            "total_utterances": self.total_utterances,
            "per_utterance": self.per_utterance,
            "manifest_written": self.manifest_written,
            "next_action": self.next_action,
        }


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _read_yaml(path: Path) -> dict:
    return yaml.safe_load(path.read_text()) or {}


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


def _process_one(
    entry: dict,
    overrides: dict,
    manifest_voice: str,
    client: PiperClient,
    normalizer: Normalizer,
    skip_normalize: bool,
) -> dict:
    """Run synthesis + normalize for a single utterance. Returns a status dict."""
    key = entry["key"]
    used_text, used_voice = _resolve_used_text_voice(entry, overrides, manifest_voice)
    status: dict = {
        "key": key,
        "used_text": used_text,
        "used_voice": used_voice,
    }

    try:
        result = client.synthesize(entry, overrides)
        status["raw_path"] = str(result.raw_path)
        status["cached"] = result.cached
        status["fingerprint"] = result.fingerprint
    except (PiperError, PiperVoiceMissingError) as exc:
        status["stage"] = "generate_failed"
        status["error"] = str(exc)
        return status

    if skip_normalize:
        status["stage"] = "generated"
        return status

    target = Path(entry["asset"])
    try:
        nr = normalizer.normalize_to_aac(result.raw_path, target)
        status["stage"] = "normalized"
        status["target_path"] = str(target)
        status["measured_lufs"] = nr.measured_lufs
        status["true_peak"] = nr.true_peak
        status["duration_ms"] = nr.duration_ms
        status["sample_rate"] = nr.sample_rate
        status["channels"] = nr.channels
        status["codec"] = nr.codec
    except NormalizeError as exc:
        status["stage"] = "normalize_failed"
        status["error"] = str(exc)

    return status


def run_pipeline(
    manifest_path: Path = Path("manifest.yaml"),
    overrides_path: Path = Path("pronunciation_overrides.yaml"),
    reviewed_path: Path = Path("reviewed.yaml"),
    *,
    dry_run: bool = False,
    force_regenerate: bool = False,
    skip_review_gate: bool = False,
    skip_normalize: bool = False,
    workers: int = 4,
    last_run_path: Path = Path("tools/tts/last-run.json"),
    out_manifest_path: Path = Path("lib/gen/audio_manifest.g.dart"),
    out_enum_path: Path = Path("lib/core/manifest/utterance_key.dart"),
    client: PiperClient | None = None,
    normalizer: Normalizer | None = None,
) -> BakePlan:
    started = _now()
    manifest = _read_yaml(manifest_path)
    overrides = _read_yaml(overrides_path) if overrides_path.is_file() else {"version": 1, "overrides": {}}
    reviewed = _read_yaml(reviewed_path) if reviewed_path.is_file() else {"version": 1, "entries": {}}

    # Validate inputs.
    for label, data, validator in (
        ("manifest", manifest, validate_manifest),
        ("overrides", overrides, validate_overrides),
        ("reviewed", reviewed, validate_reviewed),
    ):
        result = validator(data)
        if not result.ok:
            raise SystemExit(f"FAIL: {label}.yaml invalid: {result.errors}")

    plan = BakePlan(
        started_at=started,
        finished_at=None,
        total_utterances=len(manifest["utterances"]),
    )

    if dry_run:
        # Plan stage only.
        for u in manifest["utterances"]:
            target = Path(u["asset"])
            cached = target.is_file() and target.stat().st_size > 0
            plan.per_utterance[u["key"]] = {
                "key": u["key"],
                "stage": "cached" if cached else "to_generate",
                "target_path": u["asset"],
            }
        plan.finished_at = _now()
        plan.next_action = "Dry-run complete. Re-run without --plan to actually bake."
        last_run_path.parent.mkdir(parents=True, exist_ok=True)
        last_run_path.write_text(json.dumps(plan.to_dict(), indent=2, ensure_ascii=False))
        return plan

    if force_regenerate:
        # Wipe cache so PiperClient re-synthesizes.
        for u in manifest["utterances"]:
            for ext in (".wav", ".meta.json"):
                p = Path("tools/tts/_raw") / f"{u['key']}{ext}"
                if p.exists():
                    p.unlink()

    client = client or PiperClient(voice_default=manifest["voice"])
    normalizer = normalizer or Normalizer()

    # Synthesize + normalize concurrently.
    overrides_dict = (overrides or {}).get("overrides") or {}
    statuses: dict = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
        futures = {
            ex.submit(
                _process_one,
                u,
                overrides_dict,
                manifest["voice"],
                client,
                normalizer,
                skip_normalize,
            ): u["key"]
            for u in manifest["utterances"]
        }
        for fut in concurrent.futures.as_completed(futures):
            key = futures[fut]
            try:
                status = fut.result()
            except Exception as exc:
                status = {
                    "key": key,
                    "stage": "generate_failed",
                    "error": f"unhandled exception: {exc}",
                }
            statuses[key] = status

    plan.per_utterance = statuses

    # Tally for next-action message.
    failed_gen = [s for s in statuses.values() if s.get("stage") == "generate_failed"]
    failed_norm = [s for s in statuses.values() if s.get("stage") == "normalize_failed"]
    normalized_ok = [s for s in statuses.values() if s.get("stage") == "normalized"]

    # Review gate + manifest write.
    used_texts = {s["key"]: (s["used_text"], s["used_voice"]) for s in normalized_ok}
    durations_ms = {s["key"]: s.get("duration_ms", 0) for s in normalized_ok}

    can_write_manifest = (
        not failed_gen
        and not failed_norm
        and len(normalized_ok) == len(manifest["utterances"])
    )

    if can_write_manifest or skip_review_gate:
        try:
            # If skip_review_gate is True but durations are missing for some keys,
            # fill with 0 (used by Plan 06 CI sync check).
            full_durations = {u["key"]: durations_ms.get(u["key"], 0) for u in manifest["utterances"]}
            full_used_texts = {
                u["key"]: used_texts.get(
                    u["key"],
                    _resolve_used_text_voice(u, overrides_dict, manifest["voice"]),
                )
                for u in manifest["utterances"]
            }
            write_audio_manifest(
                manifest,
                reviewed,
                full_used_texts,
                full_durations,
                out_manifest_path=out_manifest_path,
                out_enum_path=out_enum_path,
                skip_review_gate=skip_review_gate,
            )
            plan.manifest_written = True
            plan.next_action = (
                f"Manifest written. {len(normalized_ok)} clips ready in assets/audio/."
            )
        except ReviewGateError as exc:
            plan.next_action = f"REVIEW GATE BLOCKED:\n{exc}"
    elif failed_gen or failed_norm:
        plan.next_action = (
            f"Errors during bake: {len(failed_gen)} generate, "
            f"{len(failed_norm)} normalize. See last-run.json."
        )
    else:
        plan.next_action = "Pipeline complete; review pending. Run python tools/tts/review_server.py."

    plan.finished_at = _now()
    last_run_path.parent.mkdir(parents=True, exist_ok=True)
    last_run_path.write_text(json.dumps(plan.to_dict(), indent=2, ensure_ascii=False))
    return plan


def _check_sync_mode(
    manifest_path: Path,
    out_manifest_path: Path,
    *,
    allow_stub_baseline: bool,
) -> int:
    """--check-sync mode for Plan 06 CI guard.

    Renders the audio_manifest.g.dart from current manifest.yaml + existing
    durations in the committed Dart file, prints to stdout. Bash diff catches
    drift. The carve-out for Phase 3 not-yet-baked state is also handled here.
    """
    from tools.tts.manifest_writer import render_audio_manifest

    manifest = _read_yaml(manifest_path)
    result = validate_manifest(manifest)
    if not result.ok:
        print(f"FAIL: manifest.yaml invalid: {result.errors}", file=sys.stderr)
        return 1

    manifest_keys = {u["key"] for u in manifest["utterances"]}

    if out_manifest_path.is_file():
        existing = out_manifest_path.read_text()
        dart_keys = set(re.findall(r"UtteranceKey\.(\w+):", existing))
    else:
        existing = ""
        dart_keys = set()

    if allow_stub_baseline:
        stub = {"letterA", "letterEth", "letterThorn", "wordHundur", "narrationWelcome"}
        reviewed = _read_yaml(Path("reviewed.yaml")) if Path("reviewed.yaml").is_file() else {}
        empty_reviewed = not (reviewed.get("entries") or {})
        if dart_keys == stub and stub <= manifest_keys and empty_reviewed:
            print(
                "skip(03-06): Phase 3 pipeline has not yet been run end-to-end (Plan 07). "
                "Manifest sync check skipped."
            )
            return 0

    # Extract durations from existing Dart for keys present.
    durations: dict = {}
    for m in re.finditer(
        r"UtteranceKey\.(\w+):\s*AudioAsset\(\s*path:\s*'[^']+',\s*approximateDuration:\s*Duration\(milliseconds:\s*(\d+)\)",
        existing,
        re.DOTALL,
    ):
        durations[m.group(1)] = int(m.group(2))
    for k in manifest_keys - durations.keys():
        durations[k] = 0

    rendered = render_audio_manifest(manifest, durations, generated_at="<check-sync>")
    sys.stdout.write(rendered)
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Phase 3 audio bake pipeline (Piper).")
    parser.add_argument("--plan", "--dry-run", action="store_true", dest="dry_run")
    parser.add_argument("--force-regenerate", action="store_true")
    parser.add_argument("--skip-review-gate", action="store_true")
    parser.add_argument("--skip-normalize", action="store_true")
    parser.add_argument("--check-sync", action="store_true",
                        help="Plan 06 CI mode: render Dart to stdout for diff against committed file.")
    parser.add_argument("--allow-stub-baseline", action="store_true",
                        help="With --check-sync: skip with informational message if state matches Phase 2 stub.")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--manifest", default="manifest.yaml")
    parser.add_argument("--overrides", default="pronunciation_overrides.yaml")
    parser.add_argument("--reviewed", default="reviewed.yaml")
    parser.add_argument("--out-manifest", default="lib/gen/audio_manifest.g.dart")
    parser.add_argument("--out-enum", default="lib/core/manifest/utterance_key.dart")
    parser.add_argument("--last-run", default="tools/tts/last-run.json")
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(message)s")

    if args.check_sync:
        return _check_sync_mode(
            Path(args.manifest),
            Path(args.out_manifest),
            allow_stub_baseline=args.allow_stub_baseline,
        )

    plan = run_pipeline(
        manifest_path=Path(args.manifest),
        overrides_path=Path(args.overrides),
        reviewed_path=Path(args.reviewed),
        dry_run=args.dry_run,
        force_regenerate=args.force_regenerate,
        skip_review_gate=args.skip_review_gate,
        skip_normalize=args.skip_normalize,
        workers=args.workers,
        last_run_path=Path(args.last_run),
        out_manifest_path=Path(args.out_manifest),
        out_enum_path=Path(args.out_enum),
    )

    print(f"started_at: {plan.started_at}")
    print(f"finished_at: {plan.finished_at}")
    print(f"total: {plan.total_utterances}")
    by_stage: dict[str, int] = {}
    for s in plan.per_utterance.values():
        by_stage[s.get("stage", "?")] = by_stage.get(s.get("stage", "?"), 0) + 1
    for stage, n in sorted(by_stage.items()):
        print(f"  {stage}: {n}")
    print(f"manifest_written: {plan.manifest_written}")
    print(f"next_action: {plan.next_action}")
    return 0 if (plan.manifest_written or args.dry_run) else 1


if __name__ == "__main__":
    sys.exit(main())
