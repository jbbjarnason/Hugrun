"""Tests for tools/tts/manifest_writer.py — Plan 04 Dart codegen."""
from __future__ import annotations

from pathlib import Path

import pytest


def _basic_manifest():
    return {
        "version": 1,
        "voice": "is_IS-steinn-medium",
        "language": "is-IS",
        "utterances": [
            {
                "key": "letterA",
                "text": "a",
                "asset": "assets/audio/letters/names/a.aac",
                "kind": "letter_name",
            },
            {
                "key": "letterEth",
                "text": "eð",
                "asset": "assets/audio/letters/names/eth.aac",
                "kind": "letter_name",
            },
            {
                "key": "letterThorn",
                "text": "þorn",
                "asset": "assets/audio/letters/names/thorn.aac",
                "kind": "letter_name",
            },
            {
                "key": "wordHundur",
                "text": "hundur",
                "asset": "assets/audio/letters/words/hundur.aac",
                "kind": "example_word",
                "starts_with": "h",
            },
            {
                "key": "narrationWelcome",
                "text": "Halló",
                "asset": "assets/audio/narration/welcome_hugrun.aac",
                "kind": "narration",
            },
        ],
    }


def _full_reviewed(manifest, voice="is_IS-steinn-medium"):
    """Build a reviewed.yaml dict with reviewed:true for every entry."""
    from tools.tts.manifest_writer import text_hash

    entries = {}
    for u in manifest["utterances"]:
        entries[u["key"]] = {
            "reviewed": True,
            "reviewer": "Jon",
            "timestamp": "2026-05-02T14:30:00Z",
            "voice": voice,
            "text_hash": text_hash(u["text"], voice),
            "notes": "OK",
        }
    return {"version": 1, "entries": entries}


def _all_technically_reviewed(manifest):
    """Build a reviewed.yaml dict with ONLY technically_reviewed:true for every entry."""
    entries = {}
    for u in manifest["utterances"]:
        entries[u["key"]] = {
            "technically_reviewed": True,
            "technically_reviewed_at": "2026-05-02T18:00:00Z",
            "technically_reviewed_lufs": -19.1,
            "technically_reviewed_duration_ms": 600,
        }
    return {"version": 1, "entries": entries}


def _mixed_partial(manifest):
    """First entry technically_reviewed; the rest absent (block)."""
    first = manifest["utterances"][0]["key"]
    return {
        "version": 1,
        "entries": {first: {"technically_reviewed": True}},
    }


def _used_texts(manifest, voice="is_IS-steinn-medium"):
    return {u["key"]: (u["text"], voice) for u in manifest["utterances"]}


def _durations(manifest):
    return {u["key"]: 500 for u in manifest["utterances"]}


def test_module_imports():
    from tools.tts.manifest_writer import (  # noqa: F401
        write_audio_manifest,
        render_audio_manifest,
        render_utterance_key,
        text_hash,
        ReviewGateError,
        PHASE2_STUB_KEYS,
    )


def test_text_hash_deterministic():
    from tools.tts.manifest_writer import text_hash

    h1 = text_hash("hundur", "is_IS-steinn-medium")
    h2 = text_hash("hundur", "is_IS-steinn-medium")
    assert h1 == h2
    assert h1.startswith("sha256:")
    # Different inputs → different hashes
    assert h1 != text_hash("hund-ur", "is_IS-steinn-medium")
    assert h1 != text_hash("hundur", "another-voice")


def test_render_audio_manifest_happy_path():
    from tools.tts.manifest_writer import render_audio_manifest

    m = _basic_manifest()
    rendered = render_audio_manifest(m, _durations(m), generated_at="2026-05-02T14:30:00Z")
    assert "GENERATED FILE" in rendered
    assert "UtteranceKey.letterA" in rendered
    assert "UtteranceKey.letterEth" in rendered
    assert "UtteranceKey.narrationWelcome" in rendered
    assert "assets/audio/letters/names/a.aac" in rendered
    assert "Duration(milliseconds: 500)" in rendered
    # Sorted by key — letterA < letterEth < letterThorn < narrationWelcome < wordHundur
    a_idx = rendered.index("UtteranceKey.letterA")
    eth_idx = rendered.index("UtteranceKey.letterEth")
    word_idx = rendered.index("UtteranceKey.wordHundur")
    assert a_idx < eth_idx < word_idx


def test_render_utterance_key_happy_path():
    from tools.tts.manifest_writer import render_utterance_key

    m = _basic_manifest()
    rendered = render_utterance_key(m, generated_at="2026-05-02T14:30:00Z")
    assert "enum UtteranceKey" in rendered
    for k in ("letterA", "letterEth", "letterThorn", "wordHundur", "narrationWelcome"):
        assert f"  {k}," in rendered


def test_byte_stable_across_runs():
    """Same inputs produce byte-identical output."""
    from tools.tts.manifest_writer import render_audio_manifest

    m = _basic_manifest()
    fixed_time = "2026-05-02T14:30:00Z"
    r1 = render_audio_manifest(m, _durations(m), generated_at=fixed_time)
    r2 = render_audio_manifest(m, _durations(m), generated_at=fixed_time)
    assert r1 == r2


def test_review_gate_blocks_when_unreviewed():
    from tools.tts.manifest_writer import write_audio_manifest, ReviewGateError

    m = _basic_manifest()
    reviewed = {"version": 1, "entries": {}}  # nothing reviewed
    with pytest.raises(ReviewGateError) as exc_info:
        write_audio_manifest(
            m,
            reviewed,
            _used_texts(m),
            _durations(m),
            out_manifest_path=Path("/tmp/test_manifest_ignored.dart"),
            out_enum_path=Path("/tmp/test_enum_ignored.dart"),
        )
    msg = str(exc_info.value)
    assert "5" in msg  # 5 keys missing from reviewed
    assert "review_server" in msg or "review" in msg.lower()


def test_review_gate_blocks_on_text_hash_drift(tmp_path):
    from tools.tts.manifest_writer import write_audio_manifest, ReviewGateError

    m = _basic_manifest()
    reviewed = _full_reviewed(m)
    # Tamper one entry's hash.
    reviewed["entries"]["letterA"]["text_hash"] = "sha256:0000"

    with pytest.raises(ReviewGateError) as exc_info:
        write_audio_manifest(
            m,
            reviewed,
            _used_texts(m),
            _durations(m),
            out_manifest_path=tmp_path / "m.dart",
            out_enum_path=tmp_path / "e.dart",
        )
    assert "drift" in str(exc_info.value).lower() or "letterA" in str(exc_info.value)


def test_review_gate_passes_writes_files(tmp_path):
    from tools.tts.manifest_writer import write_audio_manifest

    m = _basic_manifest()
    reviewed = _full_reviewed(m)
    out_m = tmp_path / "audio_manifest.g.dart"
    out_e = tmp_path / "utterance_key.dart"

    write_audio_manifest(
        m,
        reviewed,
        _used_texts(m),
        _durations(m),
        out_manifest_path=out_m,
        out_enum_path=out_e,
        generated_at="2026-05-02T14:30:00Z",
    )
    assert out_m.exists()
    assert out_e.exists()
    body = out_m.read_text()
    assert "UtteranceKey.letterA" in body
    assert "Duration(milliseconds: 500)" in body


def test_skip_review_gate_emits_anyway(tmp_path):
    from tools.tts.manifest_writer import write_audio_manifest

    m = _basic_manifest()
    reviewed = {"version": 1, "entries": {}}  # empty
    out_m = tmp_path / "audio_manifest.g.dart"
    out_e = tmp_path / "utterance_key.dart"

    # skip_review_gate=True bypasses the gate (used by Plan 06 CI sync check).
    write_audio_manifest(
        m,
        reviewed,
        _used_texts(m),
        _durations(m),
        out_manifest_path=out_m,
        out_enum_path=out_e,
        skip_review_gate=True,
        generated_at="2026-05-02T14:30:00Z",
    )
    assert out_m.exists()


def test_phase2_backward_compat_enforced():
    from tools.tts.manifest_writer import write_audio_manifest, ReviewGateError

    # Manifest that drops letterA — should be rejected by D-22.
    m = _basic_manifest()
    m["utterances"] = [u for u in m["utterances"] if u["key"] != "letterA"]
    reviewed = _full_reviewed(m)

    with pytest.raises(ReviewGateError) as exc_info:
        write_audio_manifest(
            m,
            reviewed,
            _used_texts(m),
            _durations(m),
            out_manifest_path=Path("/tmp/m_ignored.dart"),
            out_enum_path=Path("/tmp/e_ignored.dart"),
        )
    assert "D-22" in str(exc_info.value)
    assert "letterA" in str(exc_info.value)


def test_real_repo_manifest_renders(tmp_path):
    """Smoke test: the real manifest.yaml + a synthetic full reviewed.yaml
    produce valid Dart output without errors."""
    import yaml as _yaml
    from tools.tts.manifest_writer import write_audio_manifest

    repo_root = Path(__file__).resolve().parents[3]
    m = _yaml.safe_load((repo_root / "manifest.yaml").read_text())
    expected_entries = len(m["utterances"])

    reviewed = _full_reviewed(m, voice=m["voice"])
    used_texts = _used_texts(m, voice=m["voice"])
    durations = _durations(m)

    out_m = tmp_path / "audio_manifest.g.dart"
    out_e = tmp_path / "utterance_key.dart"
    write_audio_manifest(
        m,
        reviewed,
        used_texts,
        durations,
        out_manifest_path=out_m,
        out_enum_path=out_e,
        generated_at="2026-05-02T14:30:00Z",
    )
    body_m = out_m.read_text()
    # Each entry contributes 1× UtteranceKey.X plus 1× kAudioManifest[UtteranceKey.X]
    # in the getAudioAsset wrapper? Actually no — the wrapper uses
    # kAudioManifest[key], not UtteranceKey.X by name. So we just count entries.
    assert body_m.count("UtteranceKey.") == expected_entries
    # All 5 stub keys present
    for k in ("letterA", "letterEth", "letterThorn", "wordHundur", "narrationWelcome"):
        assert f"UtteranceKey.{k}" in body_m


# ============================================================================
# Phase 13 soft-gate tests (Workstream C)
# ============================================================================


def test_soft_gate_emits_when_only_technically_reviewed(tmp_path):
    """Phase 13: technically_reviewed:true is sufficient with allow_technically_reviewed=True.

    The emitted manifest MUST include warning comments per entry and a
    file-level header warning about pending pronunciation review.
    """
    from tools.tts.manifest_writer import write_audio_manifest

    m = _basic_manifest()
    reviewed = _all_technically_reviewed(m)
    out_m = tmp_path / "audio_manifest.g.dart"
    out_e = tmp_path / "utterance_key.dart"

    write_audio_manifest(
        m,
        reviewed,
        _used_texts(m),
        _durations(m),
        out_manifest_path=out_m,
        out_enum_path=out_e,
        allow_technically_reviewed=True,
        generated_at="2026-05-02T14:30:00Z",
    )

    body = out_m.read_text()
    # File-level warning header in comments.
    assert "PRONUNCIATION REVIEW PENDING" in body
    # All 5 entries rendered.
    assert body.count("UtteranceKey.") == 5
    # Per-entry warning comment.
    pending_count = body.count("// PRONUNCIATION REVIEW PENDING")
    # 5 per-entry markers + 1 in header = at least 6.
    assert pending_count >= 5


def test_soft_gate_no_warning_when_fully_reviewed(tmp_path):
    """When every entry has reviewed:true, no warning comments emit."""
    from tools.tts.manifest_writer import write_audio_manifest

    m = _basic_manifest()
    reviewed = _full_reviewed(m)
    out_m = tmp_path / "audio_manifest.g.dart"
    out_e = tmp_path / "utterance_key.dart"

    write_audio_manifest(
        m,
        reviewed,
        _used_texts(m),
        _durations(m),
        out_manifest_path=out_m,
        out_enum_path=out_e,
        allow_technically_reviewed=True,
        generated_at="2026-05-02T14:30:00Z",
    )

    body = out_m.read_text()
    assert "PRONUNCIATION REVIEW PENDING" not in body


def test_soft_gate_blocks_when_neither_review_present(tmp_path):
    """Soft gate ON, but some entries have neither flag → still blocked."""
    from tools.tts.manifest_writer import write_audio_manifest, ReviewGateError

    m = _basic_manifest()
    reviewed = _mixed_partial(m)  # only the first entry has technically_reviewed

    with pytest.raises(ReviewGateError) as exc_info:
        write_audio_manifest(
            m,
            reviewed,
            _used_texts(m),
            _durations(m),
            out_manifest_path=tmp_path / "m.dart",
            out_enum_path=tmp_path / "e.dart",
            allow_technically_reviewed=True,
            generated_at="2026-05-02T14:30:00Z",
        )
    msg = str(exc_info.value)
    # 4 of 5 entries are missing both reviewed and technically_reviewed.
    assert "4" in msg


def test_soft_gate_mixed_reviewed_and_technically_reviewed(tmp_path):
    """Some entries reviewed:true, others technically_reviewed:true → emit
    with warning comments only on the technically_reviewed-only entries."""
    from tools.tts.manifest_writer import write_audio_manifest, text_hash

    m = _basic_manifest()
    voice = m["voice"]
    reviewed = {
        "version": 1,
        "entries": {
            # Two fully reviewed.
            "letterA": {
                "reviewed": True,
                "reviewer": "Jon",
                "timestamp": "2026-05-02T14:30:00Z",
                "voice": voice,
                "text_hash": text_hash("a", voice),
                "notes": "OK",
            },
            "letterEth": {
                "reviewed": True,
                "reviewer": "Jon",
                "timestamp": "2026-05-02T14:30:00Z",
                "voice": voice,
                "text_hash": text_hash("eð", voice),
                "notes": "OK",
            },
            # Three technically_reviewed only.
            "letterThorn": {"technically_reviewed": True},
            "wordHundur": {"technically_reviewed": True},
            "narrationWelcome": {"technically_reviewed": True},
        },
    }

    out_m = tmp_path / "audio_manifest.g.dart"
    out_e = tmp_path / "utterance_key.dart"
    write_audio_manifest(
        m,
        reviewed,
        _used_texts(m, voice=voice),
        _durations(m),
        out_manifest_path=out_m,
        out_enum_path=out_e,
        allow_technically_reviewed=True,
        generated_at="2026-05-02T14:30:00Z",
    )

    body = out_m.read_text()
    # The 3 unreviewed-for-pronunciation entries get warning comments.
    pending = body.count("// PRONUNCIATION REVIEW PENDING")
    assert pending >= 3
    # Header should still warn since some entries are pending.
    assert "PRONUNCIATION REVIEW PENDING" in body


def test_soft_gate_off_still_blocks_technically_reviewed_only(tmp_path):
    """Without the opt-in flag, technically_reviewed:true alone still
    blocks (preserves Phase 3-7 behavior for callers that don't opt in)."""
    from tools.tts.manifest_writer import write_audio_manifest, ReviewGateError

    m = _basic_manifest()
    reviewed = _all_technically_reviewed(m)

    with pytest.raises(ReviewGateError):
        write_audio_manifest(
            m,
            reviewed,
            _used_texts(m),
            _durations(m),
            out_manifest_path=tmp_path / "m.dart",
            out_enum_path=tmp_path / "e.dart",
            # default allow_technically_reviewed=False
            generated_at="2026-05-02T14:30:00Z",
        )
