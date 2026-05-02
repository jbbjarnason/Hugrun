"""tools/tts/manifest_writer.py — Plan 04 Dart codegen.

Renders `lib/gen/audio_manifest.g.dart` and `lib/core/manifest/utterance_key.dart`
from manifest.yaml + reviewed.yaml + per-utterance measured durations. Enforces
the review gate (D-18): aborts unless every manifest key has reviewed: true
with a matching text_hash.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, StrictUndefined


PHASE2_STUB_KEYS = frozenset(
    {"letterA", "letterEth", "letterThorn", "wordHundur", "narrationWelcome"}
)
DEFAULT_TEMPLATES_DIR = Path(__file__).resolve().parent / "templates"


class ReviewGateError(Exception):
    """Raised when the review gate (D-18) blocks manifest emission."""


@dataclass(frozen=True)
class _Row:
    key: str
    asset: str
    duration_ms: int


def text_hash(used_text: str, used_voice: str) -> str:
    """Compute the text_hash field used in reviewed.yaml.

    Plan 05's review server MUST use this same function so the hashes are
    consistent (Plan 04 ↔ Plan 05).
    """
    h = hashlib.sha256(f"{used_text}:{used_voice}".encode("utf-8")).hexdigest()
    return f"sha256:{h}"


def _check_review_gate(
    manifest: dict,
    reviewed: dict,
    used_texts: dict,  # key -> (used_text, used_voice)
) -> None:
    """D-18: every manifest entry must have reviewed: true + matching text_hash."""
    entries = (reviewed or {}).get("entries") or {}
    failures: list[str] = []

    for u in manifest["utterances"]:
        key = u["key"]
        rev = entries.get(key)
        if rev is None:
            failures.append(f"{key}: not in reviewed.yaml")
            continue
        if rev.get("reviewed") is not True:
            issue = rev.get("issue", "")
            failures.append(f"{key}: reviewed=false ({issue!r})")
            continue
        if key not in used_texts:
            failures.append(f"{key}: missing used_text/used_voice (call bake first)")
            continue
        used_text, used_voice = used_texts[key]
        expected = text_hash(used_text, used_voice)
        if rev.get("text_hash") != expected:
            failures.append(
                f"{key}: text_hash drift "
                f"(reviewed={rev.get('text_hash', '<absent>')[:30]}..., "
                f"expected={expected[:30]}...) — re-record needed"
            )

    if failures:
        msg = (
            f"Review gate (D-18) blocks manifest emission. "
            f"{len(failures)}/{len(manifest['utterances'])} unresolved:\n"
            + "\n".join(f"  - {f}" for f in failures[:10])
            + (f"\n  ... and {len(failures) - 10} more" if len(failures) > 10 else "")
            + "\nRun: python tools/tts/review_server.py"
        )
        raise ReviewGateError(msg)


def _check_backward_compat(manifest: dict) -> None:
    keys = {u["key"] for u in manifest["utterances"]}
    missing = PHASE2_STUB_KEYS - keys
    if missing:
        raise ReviewGateError(
            f"D-22 backward compat broken: Phase 2 stub keys missing from "
            f"manifest.yaml: {sorted(missing)}"
        )


def render_audio_manifest(
    manifest: dict,
    durations_ms: dict,
    *,
    templates_dir: Path = DEFAULT_TEMPLATES_DIR,
    generated_at: str | None = None,
) -> str:
    """Render the audio_manifest.g.dart text (no file write)."""
    env = Environment(
        loader=FileSystemLoader(str(templates_dir)),
        undefined=StrictUndefined,
        trim_blocks=False,
        lstrip_blocks=False,
        keep_trailing_newline=True,
    )
    tpl = env.get_template("audio_manifest.g.dart.j2")
    rows = sorted(
        (
            _Row(
                key=u["key"],
                asset=u["asset"],
                duration_ms=durations_ms.get(u["key"], 0),
            )
            for u in manifest["utterances"]
        ),
        key=lambda r: r.key,
    )
    return tpl.render(
        entries=rows,
        generated_at=generated_at
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    )


def render_utterance_key(
    manifest: dict,
    *,
    templates_dir: Path = DEFAULT_TEMPLATES_DIR,
    generated_at: str | None = None,
) -> str:
    env = Environment(
        loader=FileSystemLoader(str(templates_dir)),
        undefined=StrictUndefined,
        trim_blocks=False,
        lstrip_blocks=False,
        keep_trailing_newline=True,
    )
    tpl = env.get_template("utterance_key.dart.j2")
    keys = sorted(u["key"] for u in manifest["utterances"])
    return tpl.render(
        keys=keys,
        generated_at=generated_at
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    )


def write_audio_manifest(
    manifest: dict,
    reviewed: dict,
    used_texts: dict,
    durations_ms: dict,
    *,
    out_manifest_path: Path = Path("lib/gen/audio_manifest.g.dart"),
    out_enum_path: Path = Path("lib/core/manifest/utterance_key.dart"),
    templates_dir: Path = DEFAULT_TEMPLATES_DIR,
    generated_at: str | None = None,
    skip_review_gate: bool = False,
) -> None:
    """Generate both Dart files atomically.

    Atomicity: write to .tmp, then os.replace. Both files are written; if either
    write fails the partial file is left in place (caller can retry).
    """
    _check_backward_compat(manifest)
    if not skip_review_gate:
        _check_review_gate(manifest, reviewed, used_texts)

    rendered_manifest = render_audio_manifest(
        manifest, durations_ms, templates_dir=templates_dir, generated_at=generated_at
    )
    rendered_enum = render_utterance_key(
        manifest, templates_dir=templates_dir, generated_at=generated_at
    )

    out_manifest_path.parent.mkdir(parents=True, exist_ok=True)
    out_enum_path.parent.mkdir(parents=True, exist_ok=True)

    tmp_m = out_manifest_path.with_suffix(out_manifest_path.suffix + ".tmp")
    tmp_e = out_enum_path.with_suffix(out_enum_path.suffix + ".tmp")
    tmp_m.write_text(rendered_manifest)
    tmp_e.write_text(rendered_enum)
    tmp_m.replace(out_manifest_path)
    tmp_e.replace(out_enum_path)
