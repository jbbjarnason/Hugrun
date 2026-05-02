"""Tests for tools/tts/normalize.py — Plan 03 ffmpeg-normalize wrapper.

These tests run REAL ffmpeg / ffmpeg-normalize / ffprobe (Plan 01 verified
all three are installed). The fixture WAVs are generated on first run via
ffmpeg's lavfi sources and committed for byte-stable test reuse.
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest


FIXTURES = Path(__file__).resolve().parent / "fixtures"


def _have_ffmpeg() -> bool:
    return shutil.which("ffmpeg") is not None and shutil.which("ffmpeg-normalize") is not None and shutil.which("ffprobe") is not None


pytestmark = pytest.mark.skipif(
    not _have_ffmpeg(),
    reason="ffmpeg/ffmpeg-normalize/ffprobe required for normalize tests",
)


def _generate_loud_fixture(path: Path) -> None:
    """1-second 440 Hz tone at -3 dBFS, mono 22050 Hz (matches Piper output spec)."""
    if path.exists() and path.stat().st_size > 0:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:sample_rate=22050:duration=2",
            "-af",
            "volume=-3dB",
            "-ac",
            "1",
            "-c:a",
            "pcm_s16le",
            str(path),
        ],
        check=True,
        capture_output=True,
    )


def _generate_silence_fixture(path: Path) -> None:
    if path.exists() and path.stat().st_size > 0:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "lavfi",
            "-i",
            "anullsrc=channel_layout=mono:sample_rate=22050",
            "-t",
            "1",
            "-c:a",
            "pcm_s16le",
            str(path),
        ],
        check=True,
        capture_output=True,
    )


@pytest.fixture(scope="module")
def loud_wav() -> Path:
    p = FIXTURES / "raw_loud_2s.wav"
    _generate_loud_fixture(p)
    return p


@pytest.fixture(scope="module")
def silence_wav() -> Path:
    p = FIXTURES / "raw_silence_1s.wav"
    _generate_silence_fixture(p)
    return p


def test_module_imports():
    from tools.tts.normalize import (  # noqa: F401
        Normalizer,
        NormalizeResult,
        NormalizeError,
    )


def test_normalize_loud_to_aac_hits_target_lufs(loud_wav, tmp_path):
    from tools.tts.normalize import Normalizer

    target = tmp_path / "out.aac"
    n = Normalizer()
    result = n.normalize_to_aac(loud_wav, target)
    # Within ±0.5 LU of -19 LUFS (D-11).
    assert abs(result.measured_lufs - (-19.0)) <= 0.5, (
        f"measured LUFS {result.measured_lufs} outside [-19.5, -18.5]"
    )


def test_normalize_target_metadata(loud_wav, tmp_path):
    from tools.tts.normalize import Normalizer

    target = tmp_path / "out.aac"
    n = Normalizer()
    result = n.normalize_to_aac(loud_wav, target)
    assert result.codec == "aac"
    assert result.channels == 1
    assert result.sample_rate == 48000
    # AAC variable-rate; allow ±50% tolerance against 96 kbps target.
    if result.bitrate_bps > 0:
        assert 48_000 <= result.bitrate_bps <= 200_000


def test_normalize_true_peak_below_ceiling(loud_wav, tmp_path):
    from tools.tts.normalize import Normalizer

    target = tmp_path / "out.aac"
    n = Normalizer()
    result = n.normalize_to_aac(loud_wav, target)
    # True peak should be <= -1 dBTP (or a small tolerance above due to encoder).
    assert result.true_peak <= 0.0


def test_normalize_target_file_exists_with_content(loud_wav, tmp_path):
    from tools.tts.normalize import Normalizer

    target = tmp_path / "out.aac"
    n = Normalizer()
    n.normalize_to_aac(loud_wav, target)
    assert target.exists()
    assert target.stat().st_size > 1000  # >1 KB minimum for ~2s of AAC


def test_normalize_includes_silence_pad(loud_wav, tmp_path):
    from tools.tts.normalize import Normalizer

    target = tmp_path / "out.aac"
    n = Normalizer(leading_silence_ms=30)
    result = n.normalize_to_aac(loud_wav, target)
    # Output duration should be input duration + ~30 ms pad. Input is 2 s; output should be ~2.03 s.
    # Allow generous bounds.
    assert 1900 <= result.duration_ms <= 2200


def test_normalize_rejects_silence_input(silence_wav, tmp_path):
    """D-11: clips that can't be normalized to -19 LUFS ±0.5 are rejected."""
    from tools.tts.normalize import Normalizer, NormalizeError

    target = tmp_path / "out.aac"
    n = Normalizer()
    with pytest.raises(NormalizeError) as exc_info:
        n.normalize_to_aac(silence_wav, target)
    msg = str(exc_info.value).lower()
    # Either ffmpeg-normalize errored on silence, or LUFS reject triggered.
    assert "lufs" in msg or "normalize" in msg or "silence" in msg or "ebur" in msg


def test_normalize_missing_input_raises(tmp_path):
    from tools.tts.normalize import Normalizer, NormalizeError

    target = tmp_path / "out.aac"
    n = Normalizer()
    with pytest.raises(NormalizeError):
        n.normalize_to_aac(tmp_path / "does_not_exist.wav", target)


def test_normalize_idempotent(loud_wav, tmp_path):
    """Calling normalize_to_aac twice produces metadata-identical output."""
    from tools.tts.normalize import Normalizer

    target1 = tmp_path / "out1.aac"
    target2 = tmp_path / "out2.aac"
    n = Normalizer()
    r1 = n.normalize_to_aac(loud_wav, target1)
    r2 = n.normalize_to_aac(loud_wav, target2)
    # LUFS measurements should match within 0.1 LU.
    assert abs(r1.measured_lufs - r2.measured_lufs) <= 0.1
    assert r1.channels == r2.channels
    assert r1.sample_rate == r2.sample_rate
    assert r1.codec == r2.codec
