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
    pending_pronunciation: bool = False


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
    *,
    allow_technically_reviewed: bool = False,
) -> set[str]:
    """D-18 review gate. Returns the set of keys that are
    technically_reviewed only (pending native-speaker pronunciation
    review).

    When `allow_technically_reviewed=False` (default — Phase 3 behavior)
    every entry must have `reviewed: true` with a matching text_hash.
    When `allow_technically_reviewed=True` (Phase 13 soft gate) entries
    with `technically_reviewed: true` (and no full audit trail) are
    permitted; their keys come back in the returned set so the caller
    can render warning comments.
    """
    entries = (reviewed or {}).get("entries") or {}
    failures: list[str] = []
    pending_pronunciation: set[str] = set()

    for u in manifest["utterances"]:
        key = u["key"]
        rev = entries.get(key) or {}

        if rev.get("reviewed") is True:
            # Native-speaker reviewed — verify audit trail integrity.
            if key not in used_texts:
                failures.append(
                    f"{key}: missing used_text/used_voice (call bake first)"
                )
                continue
            used_text, used_voice = used_texts[key]
            expected = text_hash(used_text, used_voice)
            if rev.get("text_hash") != expected:
                failures.append(
                    f"{key}: text_hash drift "
                    f"(reviewed={rev.get('text_hash', '<absent>')[:30]}..., "
                    f"expected={expected[:30]}...) — re-record needed"
                )
            continue

        # Not natively reviewed. Soft gate path?
        if allow_technically_reviewed and rev.get("technically_reviewed") is True:
            pending_pronunciation.add(key)
            continue

        # Both gates failed.
        if not rev:
            failures.append(f"{key}: not in reviewed.yaml")
        elif "reviewed" in rev:
            issue = rev.get("issue", "")
            failures.append(f"{key}: reviewed=false ({issue!r})")
        else:
            failures.append(
                f"{key}: missing reviewed and technically_reviewed flags"
            )

    if failures:
        gate_label = (
            "Soft review gate (D-18 + Phase 13 technically_reviewed)"
            if allow_technically_reviewed
            else "Review gate (D-18)"
        )
        msg = (
            f"{gate_label} blocks manifest emission. "
            f"{len(failures)}/{len(manifest['utterances'])} unresolved:\n"
            + "\n".join(f"  - {f}" for f in failures[:10])
            + (f"\n  ... and {len(failures) - 10} more" if len(failures) > 10 else "")
            + "\nRun: python tools/tts/review_server.py "
            + "(or: python tools/tts/technical_review.py + "
            + "tools/tts/populate_technically_reviewed.py for the Phase 13 soft gate)"
        )
        raise ReviewGateError(msg)

    return pending_pronunciation


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
    pending_pronunciation: set[str] | None = None,
) -> str:
    """Render the audio_manifest.g.dart text (no file write).

    If `pending_pronunciation` is non-empty, the rendered Dart includes
    a file-level header warning + per-entry `// PRONUNCIATION REVIEW
    PENDING` markers (Phase 13 soft gate).
    """
    env = Environment(
        loader=FileSystemLoader(str(templates_dir)),
        undefined=StrictUndefined,
        trim_blocks=False,
        lstrip_blocks=False,
        keep_trailing_newline=True,
    )
    tpl = env.get_template("audio_manifest.g.dart.j2")
    pending = pending_pronunciation or set()
    rows = sorted(
        (
            _Row(
                key=u["key"],
                asset=u["asset"],
                duration_ms=durations_ms.get(u["key"], 0),
                pending_pronunciation=u["key"] in pending,
            )
            for u in manifest["utterances"]
        ),
        key=lambda r: r.key,
    )
    return tpl.render(
        entries=rows,
        generated_at=generated_at
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        pending_pronunciation_count=len(pending),
        any_pending=bool(pending),
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
    allow_technically_reviewed: bool = False,
) -> None:
    """Generate both Dart files atomically.

    Atomicity: write to .tmp, then os.replace. Both files are written; if either
    write fails the partial file is left in place (caller can retry).

    Phase 13 soft gate: when `allow_technically_reviewed=True`, entries
    with `technically_reviewed: true` (but no `reviewed: true` audit
    trail) are permitted; the rendered Dart carries per-entry
    `PRONUNCIATION REVIEW PENDING` markers so callers / readers can
    grep for unverified keys.
    """
    _check_backward_compat(manifest)
    pending_pronunciation: set[str] = set()
    if not skip_review_gate:
        pending_pronunciation = _check_review_gate(
            manifest,
            reviewed,
            used_texts,
            allow_technically_reviewed=allow_technically_reviewed,
        )

    rendered_manifest = render_audio_manifest(
        manifest,
        durations_ms,
        templates_dir=templates_dir,
        generated_at=generated_at,
        pending_pronunciation=pending_pronunciation,
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
