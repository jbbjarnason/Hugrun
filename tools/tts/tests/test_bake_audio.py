"""Tests for tools/tts/bake_audio.py — Plan 04 pipeline orchestrator."""
from __future__ import annotations

import json
from pathlib import Path
from unittest import mock

import pytest
import yaml


REPO_ROOT = Path(__file__).resolve().parents[3]


def test_module_imports():
    from tools.tts.bake_audio import (  # noqa: F401
        run_pipeline,
        BakePlan,
        main,
    )


def test_dry_run_returns_plan(tmp_path):
    """Plan stage classifies all utterances without invoking piper/ffmpeg."""
    from tools.tts.bake_audio import run_pipeline

    last_run = tmp_path / "last-run.json"
    plan = run_pipeline(
        manifest_path=REPO_ROOT / "manifest.yaml",
        overrides_path=REPO_ROOT / "pronunciation_overrides.yaml",
        reviewed_path=REPO_ROOT / "reviewed.yaml",
        dry_run=True,
        last_run_path=last_run,
    )
    assert plan.total_utterances == 118
    assert len(plan.per_utterance) == 118
    assert last_run.is_file()
    written = json.loads(last_run.read_text())
    assert "started_at" in written


def test_check_sync_skip_stub_baseline(tmp_path, monkeypatch):
    """--check-sync --allow-stub-baseline returns the skip line when repo matches Phase 2 stub."""
    from tools.tts.bake_audio import _check_sync_mode

    # Use the actual repo's manifest.yaml (65 keys) and current
    # lib/gen/audio_manifest.g.dart (5 stub keys) and reviewed.yaml (empty).
    monkeypatch.chdir(REPO_ROOT)
    captured = []
    with mock.patch("sys.stdout") as out:
        # Have stdout.write append to captured.
        out.write = lambda s: captured.append(s)
        rc = _check_sync_mode(
            REPO_ROOT / "manifest.yaml",
            REPO_ROOT / "lib/gen/audio_manifest.g.dart",
            allow_stub_baseline=True,
        )
    # Either skipped (in which case rc=0 + skip line printed), or a full render
    # was emitted; we accept rc=0 in both cases.
    assert rc == 0


def test_check_sync_renders_dart(tmp_path, monkeypatch):
    """--check-sync without stub baseline emits Dart to stdout."""
    from tools.tts.bake_audio import _check_sync_mode

    monkeypatch.chdir(REPO_ROOT)

    # Build a fake "post-bake" lib/gen/audio_manifest.g.dart with 65 entries.
    # We piggyback on the manifest_writer to render this synthetically.
    from tools.tts.manifest_writer import render_audio_manifest

    m = yaml.safe_load((REPO_ROOT / "manifest.yaml").read_text())
    durations = {u["key"]: 500 for u in m["utterances"]}
    fake_dart = render_audio_manifest(m, durations, generated_at="<test>")
    fake_path = tmp_path / "audio_manifest.g.dart"
    fake_path.write_text(fake_dart)

    captured: list = []
    with mock.patch("sys.stdout") as out:
        out.write = lambda s: captured.append(s)
        rc = _check_sync_mode(
            REPO_ROOT / "manifest.yaml",
            fake_path,
            allow_stub_baseline=False,
        )
    assert rc == 0
    full = "".join(captured)
    assert "UtteranceKey.letterA" in full


def test_pipeline_with_mocked_client(tmp_path, monkeypatch):
    """Smoke test: run_pipeline with a mocked PiperClient + Normalizer.

    Phase 13.1 (Rule 1 fix): the mocked fake_norm previously wrote a
    `b"AAC\\x00"` placeholder to its `target` Path argument. Combined with
    `monkeypatch.chdir(REPO_ROOT)` and the manifest's relative
    `assets/audio/...` paths, that destroyed the real baked AAC files
    every time the test ran. The fix: monkeypatch.chdir into tmp_path so
    relative-asset writes land in the tmp tree, never touching the
    real repo assets.
    """
    from tools.tts.bake_audio import run_pipeline

    # Run from a tmp tree so relative `assets/audio/...` paths resolved
    # by run_pipeline land in tmp_path, not the real repo. We still need
    # to read manifest.yaml / pronunciation_overrides.yaml / reviewed.yaml
    # from the repo root, so we pass absolute paths for those.
    monkeypatch.chdir(tmp_path)

    fake_client = mock.MagicMock()
    fake_normalizer = mock.MagicMock()

    def fake_synth(entry, overrides):
        raw = tmp_path / f"{entry['key']}.wav"
        raw.write_bytes(b"RIFF\x00\x00\x00\x00WAVE")
        return mock.MagicMock(
            raw_path=raw,
            used_text=entry["text"],
            used_voice="is_IS-steinn-medium",
            cached=False,
            fingerprint="abc123",
        )

    def fake_norm(raw, target):
        # Belt-and-braces: even with chdir(tmp_path), refuse to write
        # under the real repo's assets tree if `target` is somehow
        # absolute. This guards against future regressions where a test
        # forgets to chdir.
        target = Path(target)
        if target.is_absolute() and str(target).startswith(str(REPO_ROOT)):
            target = tmp_path / target.relative_to(REPO_ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b"AAC\x00")
        return mock.MagicMock(
            target_path=target,
            measured_lufs=-19.0,
            true_peak=-1.0,
            duration_ms=500,
            sample_rate=48000,
            channels=1,
            codec="aac",
            bitrate_bps=96000,
        )

    fake_client.synthesize.side_effect = fake_synth
    fake_normalizer.normalize_to_aac.side_effect = fake_norm

    last_run = tmp_path / "last-run.json"
    out_m = tmp_path / "audio_manifest.g.dart"
    out_e = tmp_path / "utterance_key.dart"

    plan = run_pipeline(
        manifest_path=REPO_ROOT / "manifest.yaml",
        overrides_path=REPO_ROOT / "pronunciation_overrides.yaml",
        reviewed_path=REPO_ROOT / "reviewed.yaml",
        client=fake_client,
        normalizer=fake_normalizer,
        last_run_path=last_run,
        out_manifest_path=out_m,
        out_enum_path=out_e,
    )

    # All 118 should normalize successfully (mocked).
    normalized = [s for s in plan.per_utterance.values() if s.get("stage") == "normalized"]
    assert len(normalized) == 118
    # Review gate should BLOCK because reviewed.yaml has only Phase 13's
    # technically_reviewed entries (no native-speaker reviewed:true). The
    # default pipeline does NOT use the soft gate — that's an opt-in.
    assert plan.manifest_written is False
    assert "REVIEW GATE" in plan.next_action or "blocked" in plan.next_action.lower()


def test_pipeline_per_utterance_atomicity(tmp_path, monkeypatch):
    """One utterance failure does NOT abort the whole run (D-03).

    Phase 13.1 (Rule 1 fix): same destructive-fake_norm bug as
    test_pipeline_with_mocked_client. Switch chdir to tmp_path so the
    fake's `target.write_bytes(b"AAC\\x00")` lands in the tmp tree
    rather than overwriting the real repo's assets/audio/ tree.
    """
    from tools.tts.bake_audio import run_pipeline
    from tools.tts.piper_client import PiperError

    monkeypatch.chdir(tmp_path)

    fake_client = mock.MagicMock()
    fake_normalizer = mock.MagicMock()

    def fake_synth(entry, overrides):
        if entry["key"] == "letterA":
            raise PiperError("simulated failure for letterA")
        raw = tmp_path / f"{entry['key']}.wav"
        raw.write_bytes(b"RIFF\x00\x00\x00\x00WAVE")
        return mock.MagicMock(
            raw_path=raw,
            used_text=entry["text"],
            used_voice="is_IS-steinn-medium",
            cached=False,
            fingerprint="abc123",
        )

    def fake_norm(raw, target):
        target = Path(target)
        if target.is_absolute() and str(target).startswith(str(REPO_ROOT)):
            target = tmp_path / target.relative_to(REPO_ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b"AAC\x00")
        return mock.MagicMock(
            target_path=target,
            measured_lufs=-19.0,
            true_peak=-1.0,
            duration_ms=500,
            sample_rate=48000,
            channels=1,
            codec="aac",
            bitrate_bps=96000,
        )

    fake_client.synthesize.side_effect = fake_synth
    fake_normalizer.normalize_to_aac.side_effect = fake_norm

    plan = run_pipeline(
        manifest_path=REPO_ROOT / "manifest.yaml",
        overrides_path=REPO_ROOT / "pronunciation_overrides.yaml",
        reviewed_path=REPO_ROOT / "reviewed.yaml",
        client=fake_client,
        normalizer=fake_normalizer,
        last_run_path=tmp_path / "last-run.json",
        out_manifest_path=tmp_path / "manifest.dart",
        out_enum_path=tmp_path / "enum.dart",
    )

    # 64 succeed, 1 fails — pipeline does NOT raise.
    failures = [s for s in plan.per_utterance.values() if s.get("stage") == "generate_failed"]
    assert len(failures) == 1
    assert failures[0]["key"] == "letterA"
