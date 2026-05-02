"""Tests for tools/tts/schema.py — Plan 02 schema validators."""
from __future__ import annotations

from pathlib import Path

import pytest
import yaml


FIXTURES = Path(__file__).resolve().parent / "fixtures"


def _load(name: str) -> dict:
    return yaml.safe_load((FIXTURES / name).read_text())


def test_module_imports():
    """Test 1: validate_manifest, validate_overrides, validate_reviewed importable."""
    from tools.tts.schema import (  # noqa: F401
        validate_manifest,
        validate_overrides,
        validate_reviewed,
        ALLOWED_KINDS,
        ManifestError,
        ValidationResult,
    )


def test_validate_manifest_good():
    from tools.tts.schema import validate_manifest

    result = validate_manifest(_load("manifest_good.yaml"))
    assert result.ok is True
    assert result.errors == []


def test_validate_manifest_missing_field():
    from tools.tts.schema import validate_manifest

    result = validate_manifest(_load("manifest_missing_field.yaml"))
    assert result.ok is False
    msg = " ".join(result.errors)
    assert "wordHundur" in msg
    assert "asset" in msg


def test_validate_manifest_duplicate_key():
    from tools.tts.schema import validate_manifest

    result = validate_manifest(_load("manifest_duplicate_key.yaml"))
    assert result.ok is False
    msg = " ".join(result.errors).lower()
    assert "duplicate" in msg or "letterA".lower() in msg


def test_validate_manifest_unknown_kind():
    from tools.tts.schema import validate_manifest

    result = validate_manifest(_load("manifest_unknown_kind.yaml"))
    assert result.ok is False
    msg = " ".join(result.errors).lower()
    assert "kind" in msg
    assert "not_a_real_kind" in " ".join(result.errors)


def test_validate_manifest_bad_asset_path():
    from tools.tts.schema import validate_manifest

    result = validate_manifest(_load("manifest_bad_asset_path.yaml"))
    assert result.ok is False
    msg = " ".join(result.errors).lower()
    assert "asset" in msg or "path" in msg


def test_validate_manifest_example_word_requires_starts_with():
    """example_word entries without starts_with are rejected."""
    from tools.tts.schema import validate_manifest

    bad = {
        "version": 1,
        "voice": "is_IS-steinn-medium",
        "language": "is-IS",
        "utterances": [
            {
                "key": "wordX",
                "text": "xýló",
                "asset": "assets/audio/letters/words/xylo.aac",
                "kind": "example_word",
                # no starts_with
            }
        ],
    }
    result = validate_manifest(bad)
    assert result.ok is False
    assert any("starts_with" in e for e in result.errors)


def test_validate_overrides_good():
    from tools.tts.schema import validate_overrides

    result = validate_overrides(_load("overrides_good.yaml"))
    assert result.ok is True


def test_validate_overrides_invalid_field():
    from tools.tts.schema import validate_overrides

    result = validate_overrides(_load("overrides_invalid_field.yaml"))
    assert result.ok is False


def test_validate_overrides_empty():
    from tools.tts.schema import validate_overrides

    # An empty overrides file is valid (Plan 02's day-one state).
    result = validate_overrides({"version": 1, "overrides": {}})
    assert result.ok is True


def test_validate_reviewed_good():
    from tools.tts.schema import validate_reviewed

    result = validate_reviewed(_load("reviewed_good.yaml"))
    assert result.ok is True


def test_validate_reviewed_bad_timestamp():
    from tools.tts.schema import validate_reviewed

    result = validate_reviewed(_load("reviewed_bad_timestamp.yaml"))
    assert result.ok is False
    assert any("timestamp" in e for e in result.errors)


def test_validate_reviewed_empty():
    from tools.tts.schema import validate_reviewed

    # Empty entries are valid (Plan 02's day-one state).
    result = validate_reviewed({"version": 1, "entries": {}})
    assert result.ok is True


def test_validate_manifest_text_max_length():
    """Threat T-03-02-03: extreme text length is rejected (≤500 chars)."""
    from tools.tts.schema import validate_manifest

    huge = "a" * 600
    bad = {
        "version": 1,
        "voice": "is_IS-steinn-medium",
        "language": "is-IS",
        "utterances": [
            {
                "key": "narrationLong",
                "text": huge,
                "asset": "assets/audio/narration/long.aac",
                "kind": "narration",
            }
        ],
    }
    result = validate_manifest(bad)
    assert result.ok is False
    assert any("text" in e.lower() and ("500" in e or "long" in e.lower()) for e in result.errors)
