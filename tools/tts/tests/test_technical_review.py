"""Tests for tools/tts/technical_review.py — Phase 13 Workstream A.

Phase 13 introduces a *technical* review pass distinct from the
native-speaker pronunciation review. The technical pass verifies:
  - asset file exists at the declared path
  - ffprobe reports AAC-LC, mono, 48 kHz, M4A container
  - bitrate within target tolerance (~96 kbps; VBR AAC encoder output
    typically lands at 100-110 kbps so ±15% is the empirically observed
    band — see tools/tts/normalize.py)
  - integrated LUFS within -19 ±0.5 LU (matches Plan 03 D-09/D-11)
  - duration > 50 ms (non-empty)

Per-entry pass/fail records get written to
tools/tts/last-technical-review.json. Auto-generated entries in
reviewed.yaml get the `technically_reviewed: true` field; the existing
`reviewed: true` (native-speaker) stays untouched.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest


FIXTURES = Path(__file__).resolve().parent / "fixtures"


def _make_aac_fixture(
    wav: Path,
    out: Path,
    *,
    target_lufs: float = -19.0,
    bitrate: str = "96k",
    sample_rate: int = 48000,
    channels: int = 1,
) -> None:
    """Generate a deterministic AAC fixture by running through ffmpeg.

    Uses ebur128 normalize via loudnorm filter (single-pass approximation
    of -19 LUFS) followed by AAC-LC encode. Good enough for the
    technical_review tests because they probe codec/container/duration —
    not strict LUFS reproducibility (LUFS-band tests use a separate
    fixture).
    """
    out.parent.mkdir(parents=True, exist_ok=True)
    argv = [
        "ffmpeg",
        "-y",
        "-i",
        str(wav),
        "-af",
        f"loudnorm=I={target_lufs}:TP=-1.0:LRA=11,aresample={sample_rate}",
        "-ac",
        str(channels),
        "-c:a",
        "aac",
        "-b:a",
        bitrate,
        "-movflags",
        "+faststart",
        str(out),
    ]
    completed = subprocess.run(argv, capture_output=True, timeout=60.0, check=False)
    if completed.returncode != 0:
        stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
        raise RuntimeError(
            f"ffmpeg fixture generation failed: rc={completed.returncode}\n{stderr[-500:]}"
        )


def _make_stereo_aac(wav: Path, out: Path) -> None:
    """Generate a stereo AAC clip (should fail mono-only check)."""
    out.parent.mkdir(parents=True, exist_ok=True)
    argv = [
        "ffmpeg",
        "-y",
        "-i",
        str(wav),
        "-af",
        "loudnorm=I=-19.0:TP=-1.0:LRA=11,aresample=48000",
        "-ac",
        "2",
        "-c:a",
        "aac",
        "-b:a",
        "96k",
        str(out),
    ]
    completed = subprocess.run(argv, capture_output=True, timeout=60.0, check=False)
    assert completed.returncode == 0, completed.stderr.decode(errors="replace")


def _make_loud_aac(wav: Path, out: Path) -> None:
    """Generate a clip far outside the -19 LUFS target (≈ -8 LUFS)."""
    out.parent.mkdir(parents=True, exist_ok=True)
    argv = [
        "ffmpeg",
        "-y",
        "-i",
        str(wav),
        "-af",
        "loudnorm=I=-8.0:TP=-1.0:LRA=11,aresample=48000",
        "-ac",
        "1",
        "-c:a",
        "aac",
        "-b:a",
        "96k",
        str(out),
    ]
    completed = subprocess.run(argv, capture_output=True, timeout=60.0, check=False)
    assert completed.returncode == 0, completed.stderr.decode(errors="replace")


def _basic_manifest(asset_paths: dict) -> dict:
    """Synthesize a minimal manifest dict pointing at the given fixture paths."""
    return {
        "version": 1,
        "voice": "is_IS-steinn-medium",
        "language": "is-IS",
        "utterances": [
            {
                "key": key,
                "text": "x",
                "asset": str(asset),
                "kind": "letter_name",
            }
            for key, asset in asset_paths.items()
        ],
    }


# ---------- module-level imports -----------------------------------------


def test_module_imports():
    from tools.tts.technical_review import (  # noqa: F401
        TechnicalReviewResult,
        TechnicalReviewer,
        run_technical_review,
        TARGET_LUFS,
        LUFS_TOLERANCE,
        TARGET_SAMPLE_RATE,
        TARGET_CHANNELS,
        TARGET_CODEC,
    )


# ---------- happy path ---------------------------------------------------


def test_passing_clip_marks_technically_reviewed(tmp_path):
    from tools.tts.technical_review import run_technical_review

    aac = tmp_path / "good.aac"
    _make_aac_fixture(FIXTURES / "raw_loud_2s.wav", aac)

    manifest = _basic_manifest({"letterA": aac})
    result = run_technical_review(manifest, repo_root=tmp_path)

    assert result.total == 1
    assert result.passed == 1
    assert result.failed == 0
    rec = result.per_entry["letterA"]
    assert rec["passed"] is True
    assert rec["codec"] == "aac"
    assert rec["channels"] == 1
    assert rec["sample_rate"] == 48000
    assert "measured_lufs" in rec
    assert "duration_ms" in rec
    assert rec["duration_ms"] > 50


# ---------- missing file -------------------------------------------------


def test_missing_file_fails(tmp_path):
    from tools.tts.technical_review import run_technical_review

    manifest = _basic_manifest({"letterA": tmp_path / "does_not_exist.aac"})
    result = run_technical_review(manifest, repo_root=tmp_path)

    assert result.passed == 0
    assert result.failed == 1
    rec = result.per_entry["letterA"]
    assert rec["passed"] is False
    assert "missing" in rec["reason"].lower() or "not found" in rec["reason"].lower()


# ---------- empty / zero-byte file ---------------------------------------


def test_empty_file_fails(tmp_path):
    from tools.tts.technical_review import run_technical_review

    aac = tmp_path / "empty.aac"
    aac.write_bytes(b"")

    manifest = _basic_manifest({"letterA": aac})
    result = run_technical_review(manifest, repo_root=tmp_path)

    assert result.failed == 1
    rec = result.per_entry["letterA"]
    assert rec["passed"] is False
    assert "empty" in rec["reason"].lower() or "0" in rec["reason"]


# ---------- wrong channel count (stereo) ---------------------------------


def test_stereo_fails_mono_only_check(tmp_path):
    from tools.tts.technical_review import run_technical_review

    aac = tmp_path / "stereo.aac"
    _make_stereo_aac(FIXTURES / "raw_loud_2s.wav", aac)

    manifest = _basic_manifest({"letterA": aac})
    result = run_technical_review(manifest, repo_root=tmp_path)

    assert result.failed == 1
    rec = result.per_entry["letterA"]
    assert rec["passed"] is False
    assert "channel" in rec["reason"].lower() or "mono" in rec["reason"].lower()


# ---------- LUFS out of range -------------------------------------------


def test_loud_clip_fails_lufs_band(tmp_path):
    from tools.tts.technical_review import run_technical_review

    aac = tmp_path / "loud.aac"
    _make_loud_aac(FIXTURES / "raw_loud_2s.wav", aac)

    manifest = _basic_manifest({"letterA": aac})
    result = run_technical_review(manifest, repo_root=tmp_path)

    assert result.failed == 1
    rec = result.per_entry["letterA"]
    assert rec["passed"] is False
    assert "lufs" in rec["reason"].lower() or "loudness" in rec["reason"].lower()


# ---------- last-technical-review.json output ----------------------------


def test_writes_json_report(tmp_path):
    from tools.tts.technical_review import run_technical_review

    aac = tmp_path / "good.aac"
    _make_aac_fixture(FIXTURES / "raw_loud_2s.wav", aac)
    manifest = _basic_manifest({"letterA": aac})

    out_json = tmp_path / "last-technical-review.json"
    run_technical_review(manifest, repo_root=tmp_path, report_path=out_json)

    assert out_json.is_file()
    data = json.loads(out_json.read_text())
    assert data["total"] == 1
    assert data["passed"] == 1
    assert "letterA" in data["per_entry"]
    assert "started_at" in data
    assert "finished_at" in data


# ---------- mixed pass/fail summary --------------------------------------


def test_mixed_pass_fail_summary(tmp_path):
    from tools.tts.technical_review import run_technical_review

    good = tmp_path / "good.aac"
    _make_aac_fixture(FIXTURES / "raw_loud_2s.wav", good)
    missing = tmp_path / "missing.aac"

    manifest = _basic_manifest({"letterA": good, "letterB": missing})
    result = run_technical_review(manifest, repo_root=tmp_path)

    assert result.total == 2
    assert result.passed == 1
    assert result.failed == 1
    assert result.per_entry["letterA"]["passed"] is True
    assert result.per_entry["letterB"]["passed"] is False


# ---------- exit code semantics ------------------------------------------


def test_main_exits_nonzero_on_failure(tmp_path, monkeypatch):
    from tools.tts.technical_review import main

    missing = tmp_path / "missing.aac"
    manifest_yaml = tmp_path / "manifest.yaml"
    manifest_yaml.write_text(
        "version: 1\n"
        "voice: is_IS-steinn-medium\n"
        "language: is-IS\n"
        "utterances:\n"
        "  - key: letterA\n"
        "    text: a\n"
        f"    asset: {missing}\n"
        "    kind: letter_name\n"
    )
    report = tmp_path / "report.json"

    rc = main(["--manifest", str(manifest_yaml), "--report", str(report), "--repo-root", str(tmp_path)])
    assert rc != 0


def test_main_exits_zero_on_success(tmp_path):
    from tools.tts.technical_review import main

    aac_dir = tmp_path / "audio"
    aac_dir.mkdir()
    aac = aac_dir / "good.aac"
    _make_aac_fixture(FIXTURES / "raw_loud_2s.wav", aac)

    manifest_yaml = tmp_path / "manifest.yaml"
    # Use a relative path so repo_root resolution kicks in.
    manifest_yaml.write_text(
        "version: 1\n"
        "voice: is_IS-steinn-medium\n"
        "language: is-IS\n"
        "utterances:\n"
        "  - key: letterA\n"
        "    text: a\n"
        "    asset: audio/good.aac\n"
        "    kind: letter_name\n"
    )
    report = tmp_path / "report.json"

    rc = main(["--manifest", str(manifest_yaml), "--report", str(report), "--repo-root", str(tmp_path)])
    assert rc == 0
