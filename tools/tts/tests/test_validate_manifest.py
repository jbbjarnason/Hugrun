"""Contract tests for the real repo-level YAML files (Plan 02 Task 2).

Asserts the actual manifest.yaml + pronunciation_overrides.yaml + reviewed.yaml
satisfy the Phase 3 invariants. These tests fail RED until manifest.yaml is
authored with the full 65-entry list.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import pytest
import yaml


REPO_ROOT = Path(__file__).resolve().parents[3]


def _load_manifest() -> dict:
    return yaml.safe_load((REPO_ROOT / "manifest.yaml").read_text())


def test_repo_manifest_valid():
    """Test 10: real manifest.yaml passes the schema validator."""
    from tools.tts.schema import validate_manifest

    data = _load_manifest()
    result = validate_manifest(data)
    assert result.ok, f"manifest.yaml invalid: {result.errors}"


def test_repo_overrides_valid():
    from tools.tts.schema import validate_overrides

    data = yaml.safe_load((REPO_ROOT / "pronunciation_overrides.yaml").read_text())
    result = validate_overrides(data)
    assert result.ok, f"pronunciation_overrides.yaml invalid: {result.errors}"


def test_repo_reviewed_valid():
    from tools.tts.schema import validate_reviewed

    data = yaml.safe_load((REPO_ROOT / "reviewed.yaml").read_text())
    result = validate_reviewed(data)
    assert result.ok, f"reviewed.yaml invalid: {result.errors}"


def test_phase2_stub_keys_preserved():
    """Test 11: D-22 — Phase 2 stub keys MUST appear in manifest.yaml."""
    data = _load_manifest()
    keys = {u["key"] for u in data["utterances"]}
    expected = {"letterA", "letterEth", "letterThorn", "wordHundur", "narrationWelcome"}
    missing = expected - keys
    assert not missing, f"Phase 2 stub keys missing from manifest.yaml: {missing}"


def test_count_breakdown():
    """Test 12: 32 letter_name + 32 example_word + 1 narration = 65 total."""
    data = _load_manifest()
    utterances = data["utterances"]

    by_kind: dict[str, int] = {}
    for u in utterances:
        by_kind[u["kind"]] = by_kind.get(u["kind"], 0) + 1

    assert len(utterances) == 65, f"Expected 65 utterances, got {len(utterances)}"
    assert by_kind.get("letter_name") == 32, f"Expected 32 letter_name, got {by_kind.get('letter_name')}"
    assert by_kind.get("example_word") == 32, f"Expected 32 example_word, got {by_kind.get('example_word')}"
    assert by_kind.get("narration") == 1, f"Expected 1 narration, got {by_kind.get('narration')}"


def test_all_keys_unique():
    data = _load_manifest()
    keys = [u["key"] for u in data["utterances"]]
    assert len(keys) == len(set(keys)), f"Duplicate keys: {[k for k in keys if keys.count(k) > 1]}"


def test_starts_with_consistency():
    """Test 13: every example_word's text starts with its starts_with letter (Icelandic-aware)."""
    data = _load_manifest()
    for u in data["utterances"]:
        if u["kind"] != "example_word":
            continue
        text = u["text"]
        sw = u["starts_with"]
        # Allow a known exception: wordEth uses 'maður' (medial ð) per planning context.
        if u["key"] == "wordEth":
            continue
        assert text.startswith(sw), (
            f"{u['key']}: text {text!r} does not start with {sw!r}"
        )


def test_phase2_stub_paths_compatible():
    """Test 14: stub keys preserve the asset paths Phase 2 already wrote into
    lib/gen/audio_manifest.g.dart, so the regenerated manifest doesn't relocate
    existing AAC files."""
    data = _load_manifest()
    by_key = {u["key"]: u for u in data["utterances"]}

    expected_paths = {
        "letterA": "assets/audio/letters/names/a.aac",
        "letterEth": "assets/audio/letters/names/eth.aac",
        "letterThorn": "assets/audio/letters/names/thorn.aac",
        "wordHundur": "assets/audio/letters/words/hundur.aac",
        "narrationWelcome": "assets/audio/narration/welcome_hugrun.aac",
    }
    for key, expected in expected_paths.items():
        assert by_key[key]["asset"] == expected, (
            f"{key}: expected asset {expected}, got {by_key[key]['asset']}"
        )


def test_cli_validates_repo_files():
    """Test 15: invoking the CLI from repo root exits 0."""
    result = subprocess.run(
        [sys.executable, str(REPO_ROOT / "tools/tts/validate_manifest.py")],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"CLI failed: stdout={result.stdout} stderr={result.stderr}"


def test_cli_rejects_bad_fixture():
    """Test 16: invoking the CLI on a bad fixture exits non-zero."""
    fixture = REPO_ROOT / "tools/tts/tests/fixtures/manifest_duplicate_key.yaml"
    result = subprocess.run(
        [sys.executable, str(REPO_ROOT / "tools/tts/validate_manifest.py"), str(fixture)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "duplicate" in (result.stdout + result.stderr).lower() or "letterA" in result.stdout + result.stderr
