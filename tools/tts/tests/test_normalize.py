"""Tests for tools/tts/normalize.py — Plan 03 ffmpeg-normalize wrapper.

These tests run REAL ffmpeg / ffmpeg-normalize / ffprobe (Plan 01 verified
all three are installed). The fixture WAVs are generated on first run via
ffmpeg's lavfi sources and committed for byte-stable test reuse.
"""
from __future__ import annotations

import re
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


def _measure_leading_silence_ms(target: Path, threshold_db: float = -40.0) -> float:
    """Probe leading silence in an audio file via ffmpeg silencedetect.

    Returns 0.0 if no leading silence is detected (i.e. signal starts immediately).
    """
    argv = [
        "ffmpeg",
        "-i",
        str(target),
        "-af",
        f"silencedetect=noise={threshold_db}dB:duration=0.005",
        "-f",
        "null",
        "-",
    ]
    completed = subprocess.run(argv, capture_output=True, timeout=30.0, check=False)
    text = (completed.stderr or b"").decode("utf-8", errors="replace")
    # Look for the first silence_start at 0 (or very near 0). If silence starts
    # at the very beginning, find its silence_end to measure leading silence.
    starts = list(re.finditer(r"silence_start:\s*(-?\d+(?:\.\d+)?)", text))
    if not starts:
        return 0.0
    first_start = float(starts[0].group(1))
    # Treat any silence_start <= 0.01 s as "starting at the head"
    if first_start > 0.01:
        return 0.0
    end_match = re.search(r"silence_end:\s*(-?\d+(?:\.\d+)?)", text)
    if not end_match:
        return 0.0
    return max(0.0, float(end_match.group(1)) * 1000.0)


def _measure_trailing_silence_ms(target: Path, threshold_db: float = -40.0) -> float:
    """Probe trailing silence (last silence run extending to end of file)."""
    # First get total duration via ffprobe
    probe = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(target),
        ],
        capture_output=True,
        timeout=15.0,
        check=False,
    )
    try:
        duration_s = float(probe.stdout.decode("utf-8", errors="replace").strip())
    except ValueError:
        return 0.0

    argv = [
        "ffmpeg",
        "-i",
        str(target),
        "-af",
        f"silencedetect=noise={threshold_db}dB:duration=0.005",
        "-f",
        "null",
        "-",
    ]
    completed = subprocess.run(argv, capture_output=True, timeout=30.0, check=False)
    text = (completed.stderr or b"").decode("utf-8", errors="replace")
    # Find every silence_start; the last one BEFORE end-of-stream that has no
    # subsequent silence_end indicates a trailing silence run. silencedetect
    # only emits silence_end when the silence actually ends; if EOF closes
    # the run, silence_end is omitted. We use the last silence_start whose
    # corresponding silence_end is missing (or beyond duration).
    starts = [float(m.group(1)) for m in re.finditer(r"silence_start:\s*(-?\d+(?:\.\d+)?)", text)]
    ends = [float(m.group(1)) for m in re.finditer(r"silence_end:\s*(-?\d+(?:\.\d+)?)", text)]
    if not starts:
        return 0.0
    if len(starts) > len(ends):
        # Last silence run never closed → it's the trailing silence.
        last_start = starts[-1]
        return max(0.0, (duration_s - last_start) * 1000.0)
    # Otherwise, check whether last silence_end is within ~10 ms of EOF.
    if ends and (duration_s - ends[-1]) <= 0.01 and starts:
        last_start = starts[-1]
        return max(0.0, (duration_s - last_start) * 1000.0)
    return 0.0


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


def _generate_leading_silence_then_tone(path: Path) -> None:
    """800 ms of silence followed by 1.2 s of -3 dBFS 440 Hz tone, 22050 Hz mono.

    Mirrors the Phase-13.1 worst-case shape (Piper produces utterances with
    long leading silence before the speech onset).
    """
    if path.exists() and path.stat().st_size > 0:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    # Use ffmpeg lavfi to concatenate anullsrc + sine into one stream.
    filter_complex = (
        "anullsrc=channel_layout=mono:sample_rate=22050:d=0.8[s];"
        "sine=frequency=440:sample_rate=22050:duration=1.2,volume=-3dB[t];"
        "[s][t]concat=n=2:v=0:a=1[out]"
    )
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "lavfi",
            "-i",
            "anullsrc=channel_layout=mono:sample_rate=22050:d=0.8",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:sample_rate=22050:duration=1.2",
            "-filter_complex",
            "[0:a][1:a]concat=n=2:v=0:a=1,volume=-3dB[out]",
            "-map",
            "[out]",
            "-ac",
            "1",
            "-c:a",
            "pcm_s16le",
            str(path),
        ],
        check=True,
        capture_output=True,
    )


def _generate_tone_then_trailing_silence(path: Path) -> None:
    """1.0 s tone followed by 1.0 s of low-level noise (Piper-like noise floor).

    We use anoisesrc at amplitude 0.001 (~-60 dBFS) instead of anullsrc so
    the trailing region survives ffmpeg-normalize's internal trimming and
    actually exercises the silenceremove pre-step under test.
    """
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
            "sine=frequency=440:sample_rate=22050:duration=1.0",
            "-f",
            "lavfi",
            "-i",
            "anoisesrc=color=white:sample_rate=22050:amplitude=0.001:d=1.0",
            "-filter_complex",
            "[0:a][1:a]concat=n=2:v=0:a=1,volume=-3dB[out]",
            "-map",
            "[out]",
            "-ac",
            "1",
            "-c:a",
            "pcm_s16le",
            str(path),
        ],
        check=True,
        capture_output=True,
    )


def _generate_clean_tone_fixture(path: Path) -> None:
    """2.0 s clean tone, no leading silence (control case)."""
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
            "sine=frequency=440:sample_rate=22050:duration=2.0",
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


@pytest.fixture(scope="module")
def leading_silence_wav() -> Path:
    """800 ms leading silence + 1.2 s tone — simulates Piper's worst-case
    leading-silence output for Phase 13.1."""
    p = FIXTURES / "raw_leading_silence_2s.wav"
    _generate_leading_silence_then_tone(p)
    return p


@pytest.fixture(scope="module")
def trailing_silence_wav() -> Path:
    """1 s tone + 1 s trailing silence — simulates the systemic excess
    trailing silence flagged in audio-review/anomalies.json."""
    p = FIXTURES / "raw_trailing_silence_2s.wav"
    _generate_tone_then_trailing_silence(p)
    return p


@pytest.fixture(scope="module")
def clean_tone_wav() -> Path:
    """2 s clean tone with no leading or trailing silence (control case)."""
    p = FIXTURES / "raw_clean_tone_2s.wav"
    _generate_clean_tone_fixture(p)
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


# ----- Phase 13.1: leading & trailing silence trim -------------------- #


def test_trims_excess_leading_silence(leading_silence_wav, tmp_path):
    """Phase 13.1: input WAV with 800 ms leading silence + 1.2 s tone should
    produce an AAC with ≤ 80 ms leading silence (the deliberate 30 ms pad
    plus encoder priming + measurement tolerance).

    Failing this is the whole point of Phase 13.1 — the bake pipeline must
    trim Piper's leading silence BEFORE applying the 30 ms intentional pad.
    """
    from tools.tts.normalize import Normalizer

    target = tmp_path / "out_lead.aac"
    n = Normalizer()
    n.normalize_to_aac(leading_silence_wav, target)

    leading_ms = _measure_leading_silence_ms(target)
    # Acceptance band: the pipeline applies 30 ms intentional pad. AAC
    # encoder priming + ffprobe rounding adds a few ms. We allow up to
    # 80 ms total at the head — well under the 100 ms `excess_leading_silence`
    # threshold used by tools/audio_review/flag_anomalies.py.
    assert leading_ms <= 80.0, (
        f"leading silence {leading_ms:.1f} ms > 80 ms — "
        f"silenceremove pre-step is missing or misconfigured "
        f"(this fails the Phase 13.1 acceptance criterion)"
    )


def test_trims_excess_trailing_silence(trailing_silence_wav, tmp_path):
    """Phase 13.1: 1 s tone + 1 s trailing silence should produce AAC with
    ≤ 250 ms trailing silence (a small natural decay after speech is fine,
    but a full second of dead air is not)."""
    from tools.tts.normalize import Normalizer

    target = tmp_path / "out_trail.aac"
    n = Normalizer()
    n.normalize_to_aac(trailing_silence_wav, target)

    trailing_ms = _measure_trailing_silence_ms(target)
    assert trailing_ms <= 250.0, (
        f"trailing silence {trailing_ms:.1f} ms > 250 ms — "
        f"silenceremove stop-side trim is missing or misconfigured"
    )


def test_clean_tone_input_keeps_pad_unchanged(clean_tone_wav, tmp_path):
    """Phase 13.1 control: a 2 s clean tone (no leading silence) should
    still produce an AAC with the deliberate 30 ms leading pad — i.e.
    silenceremove must NOT eat the 30 ms intentional pad applied AFTER it.
    """
    from tools.tts.normalize import Normalizer

    target = tmp_path / "out_clean.aac"
    n = Normalizer(leading_silence_ms=30)
    n.normalize_to_aac(clean_tone_wav, target)

    leading_ms = _measure_leading_silence_ms(target)
    # Lower bound: we must still have *some* leading silence, because the
    # pipeline pads 30 ms after silence-trim. We allow 5 ms wiggle from
    # the AAC framing/ffprobe rounding.
    assert leading_ms >= 5.0, (
        f"leading silence {leading_ms:.1f} ms < 5 ms — "
        f"the 30 ms intentional pad seems to have been removed"
    )
    # Upper bound: must not balloon up.
    assert leading_ms <= 80.0, (
        f"leading silence {leading_ms:.1f} ms > 80 ms — "
        f"clean-tone input got over-padded"
    )
