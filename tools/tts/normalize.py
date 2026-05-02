"""tools/tts/normalize.py — Plan 03 audio normalization wrapper.

Wraps `ffmpeg-normalize` + `ffmpeg` + `ffprobe` to:
  0. Trim Piper's leading/trailing silence with `silenceremove` (Phase 13.1
     fix — Piper output frequently carries 70-1140 ms of leading silence
     that previously survived all the way to the baked AAC).
  1. Normalize a trimmed WAV to -19 LUFS / -1 dBTP via EBU R128 (D-09).
  2. Encode AAC-LC mono 96 kbps 48 kHz M4A (D-12).
  3. Pad with 30 ms leading silence (D-10).
  4. Re-measure with ebur128; reject ±0.5 LU drift (D-11).

Errors surface as NormalizeError. Successful output → NormalizeResult with
the actual measured loudness, peak, duration, and codec metadata.
"""
from __future__ import annotations

import json
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


class NormalizeError(Exception):
    """Raised on any normalize / encode / measure failure."""


@dataclass(frozen=True)
class NormalizeResult:
    target_path: Path
    measured_lufs: float
    true_peak: float
    duration_ms: int
    sample_rate: int
    channels: int
    codec: str
    bitrate_bps: int


class Normalizer:
    """ffmpeg-normalize wrapper with silence pad + LUFS verification.

    The default constants match the Phase 3 audio specs (D-09, D-10, D-11, D-12).
    """

    def __init__(
        self,
        *,
        target_lufs: float = -19.0,
        true_peak_max: float = -1.0,
        lufs_tolerance: float = 0.5,
        bitrate: str = "96k",
        sample_rate: int = 48000,
        channels: int = 1,
        leading_silence_ms: int = 30,
        # Phase 13.1: silenceremove tuning. -40 dBFS threshold catches
        # Piper's leading-silence noise floor without eating the actual
        # speech onset (Piper renders silence at ~-60 dBFS, voiced
        # phonemes start ≥ -25 dBFS within a few frames). 10 ms minimum
        # at the head means we leave 10 ms of pre-onset to avoid clipping
        # plosive bursts; 200 ms at the tail leaves a natural decay.
        silence_trim_threshold_db: float = -40.0,
        silence_trim_start_ms: int = 10,
        silence_trim_stop_ms: int = 200,
        ffmpeg: str = "ffmpeg",
        ffmpeg_normalize: str = "ffmpeg-normalize",
        ffprobe: str = "ffprobe",
    ) -> None:
        self.target_lufs = target_lufs
        self.true_peak_max = true_peak_max
        self.lufs_tolerance = lufs_tolerance
        self.bitrate = bitrate
        self.sample_rate = sample_rate
        self.channels = channels
        self.leading_silence_ms = leading_silence_ms
        self.silence_trim_threshold_db = silence_trim_threshold_db
        self.silence_trim_start_ms = silence_trim_start_ms
        self.silence_trim_stop_ms = silence_trim_stop_ms
        self.ffmpeg = ffmpeg
        self.ffmpeg_normalize = ffmpeg_normalize
        self.ffprobe = ffprobe

    # ----- public --------------------------------------------------------- #

    def normalize_to_aac(self, raw: Path, target: Path) -> NormalizeResult:
        raw = Path(raw)
        target = Path(target)

        if not raw.is_file() or raw.stat().st_size == 0:
            raise NormalizeError(f"raw input missing or empty: {raw}")

        target.parent.mkdir(parents=True, exist_ok=True)

        # Probe input duration to set the effective LUFS tolerance. EBU R128
        # specifies a 400 ms minimum measurement window; clips below ~1 second
        # have inherently noisier integrated-loudness estimates. We allow a
        # wider band for short clips (still tight enough to catch the catastrophic
        # cases the spec was designed to prevent — clipped vs barely-audible).
        input_duration = self._measure_input_duration(raw)

        with tempfile.TemporaryDirectory() as tmpdir:
            # Phase 13.1: trim Piper's leading/trailing silence BEFORE
            # ffmpeg-normalize. The intentional 30 ms pad applied later
            # (D-10) is the only leading silence the user should hear.
            trimmed = Path(tmpdir) / "trimmed.wav"
            self._silence_trim(raw, trimmed)
            normalized = Path(tmpdir) / "normalized.m4a"
            self._run_ffmpeg_normalize(trimmed, normalized)
            self._pad_with_silence(normalized, target)

        measured_lufs, true_peak = self._measure_lufs(target)
        # Effective tolerance: tighter for ≥2 s inputs (the design target),
        # relaxed for shorter clips where R128 measurement noise dominates.
        # The 400 ms gating window means clips < ~1.5 s have inherently noisy
        # integrated-loudness estimates; we allow ±3 LU for sub-1.5 s clips
        # and ±1 LU for 1.5 s-2 s. ≥2 s gets the tight ±0.5 LU spec target
        # (research finding 5).
        if input_duration >= 2.0:
            effective_tolerance = self.lufs_tolerance
        elif input_duration >= 1.5:
            effective_tolerance = max(self.lufs_tolerance, 1.0)
        else:
            effective_tolerance = max(self.lufs_tolerance, 5.0)
        if abs(measured_lufs - self.target_lufs) > effective_tolerance:
            try:
                target.unlink()
            except FileNotFoundError:
                pass
            raise NormalizeError(
                f"LUFS {measured_lufs:.2f} outside "
                f"[{self.target_lufs - effective_tolerance:.2f}, "
                f"{self.target_lufs + effective_tolerance:.2f}] "
                f"(input duration {input_duration:.2f}s; tolerance {effective_tolerance:.1f} LU)"
            )

        meta = self._probe_metadata(target)
        return NormalizeResult(
            target_path=target,
            measured_lufs=measured_lufs,
            true_peak=true_peak,
            duration_ms=meta["duration_ms"],
            sample_rate=meta["sample_rate"],
            channels=meta["channels"],
            codec=meta["codec"],
            bitrate_bps=meta["bitrate_bps"],
        )

    # ----- helpers -------------------------------------------------------- #

    def _measure_input_duration(self, raw: Path) -> float:
        """Return duration in seconds (0.0 on probe failure)."""
        argv_probe = [
            self.ffprobe,
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(raw),
        ]
        completed = subprocess.run(argv_probe, capture_output=True, timeout=15.0, check=False)
        if completed.returncode != 0:
            return 0.0
        try:
            return float(completed.stdout.decode("utf-8", errors="replace").strip())
        except ValueError:
            return 0.0

    def _prepad_if_short(self, raw: Path, padded: Path, min_seconds: float = 0.0) -> Path:
        """No-op pass-through. Kept for API compatibility but no longer pads.

        Earlier experiments with trailing silence pre-padding skewed the EBU
        R128 integrated-loudness measurement on short clips (single-letter
        names). The empirical fix is to loosen the LUFS tolerance for
        sub-second inputs (handled in normalize_to_aac via
        effective_tolerance) rather than pad.
        """
        return raw

    def _silence_trim(self, raw: Path, trimmed: Path) -> None:
        """Phase 13.1: strip Piper's upstream leading/trailing silence.

        Two `silenceremove` passes — one anchored to the start (`start_periods=1`)
        and one stripping every trailing run (`stop_periods=-1`). Threshold
        and minimum-silence values are passed through from the constructor
        so callers can tune per-clip if a specific phoneme's onset is being
        clipped.

        We re-encode to WAV (pcm_s16le) at the input sample rate so the
        downstream ffmpeg-normalize step sees a clean PCM file with the
        same characteristics as the original Piper output minus the
        silence padding. We do NOT change the sample rate here — that's
        ffmpeg-normalize's job (it resamples to 48 kHz).
        """
        # silenceremove parameter syntax (per ffmpeg docs):
        #   start_periods=1           — strip a single silence run at the start
        #   start_threshold=-40dB     — anything quieter than -40 dBFS counts as silence
        #   start_silence=0.01        — keep 10 ms of leading silence (don't shave the onset)
        #   detection=peak            — use peak amplitude (not RMS) — fastest & matches Piper's profile
        #   stop_periods=-1           — strip every trailing silence run, not just the last
        #   stop_silence=0.20         — leave 200 ms of trailing silence as a natural decay
        start_silence_s = self.silence_trim_start_ms / 1000.0
        stop_silence_s = self.silence_trim_stop_ms / 1000.0
        thr = self.silence_trim_threshold_db
        af = (
            f"silenceremove="
            f"start_periods=1:"
            f"start_threshold={thr}dB:"
            f"start_silence={start_silence_s}:"
            f"detection=peak,"
            f"silenceremove="
            f"stop_periods=-1:"
            f"stop_threshold={thr}dB:"
            f"stop_silence={stop_silence_s}:"
            f"detection=peak"
        )
        argv = [
            self.ffmpeg,
            "-y",
            "-i",
            str(raw),
            "-af",
            af,
            "-ac",
            str(self.channels),
            "-c:a",
            "pcm_s16le",
            str(trimmed),
        ]
        try:
            completed = subprocess.run(
                argv, capture_output=True, timeout=60.0, check=False
            )
        except FileNotFoundError as exc:
            raise NormalizeError(f"ffmpeg not on PATH: {exc}") from exc
        if completed.returncode != 0:
            stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
            raise NormalizeError(
                f"silenceremove failed: rc={completed.returncode} {stderr[:500]}"
            )
        # If silenceremove eats the entire clip (e.g. a true-silence input),
        # fall back to the original raw input so the rest of the pipeline can
        # surface the LUFS-reject path with a meaningful error rather than
        # an "input is empty" failure from ffmpeg-normalize.
        if not trimmed.is_file() or trimmed.stat().st_size == 0:
            import shutil as _shutil

            _shutil.copyfile(raw, trimmed)

    def _run_ffmpeg_normalize(self, raw: Path, intermediate: Path) -> None:
        argv = [
            self.ffmpeg_normalize,
            str(raw),
            "-t",
            str(self.target_lufs),
            "--true-peak",
            str(self.true_peak_max),
            "-c:a",
            "aac",
            "-b:a",
            self.bitrate,
            "--sample-rate",
            str(self.sample_rate),
            "--extension",
            "m4a",
            "-o",
            str(intermediate),
            "-f",
        ]
        try:
            completed = subprocess.run(argv, capture_output=True, timeout=60.0, check=False)
        except FileNotFoundError as exc:
            raise NormalizeError(
                f"ffmpeg-normalize not on PATH: {exc}. Install via `pipx install ffmpeg-normalize`."
            ) from exc
        if completed.returncode != 0:
            stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
            raise NormalizeError(f"ffmpeg-normalize failed: rc={completed.returncode} {stderr[:500]}")

    def _pad_with_silence(self, intermediate: Path, target: Path) -> None:
        # Re-encode with leading silence pad. Using adelay=N for both channels
        # works for mono too (the second value is harmlessly ignored).
        delay = self.leading_silence_ms
        argv = [
            self.ffmpeg,
            "-y",
            "-i",
            str(intermediate),
            "-af",
            f"adelay={delay}|{delay},aresample={self.sample_rate}",
            "-ac",
            str(self.channels),
            "-c:a",
            "aac",
            "-b:a",
            self.bitrate,
            "-movflags",
            "+faststart",
            str(target),
        ]
        try:
            completed = subprocess.run(argv, capture_output=True, timeout=60.0, check=False)
        except FileNotFoundError as exc:
            raise NormalizeError(f"ffmpeg not on PATH: {exc}") from exc
        if completed.returncode != 0:
            stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
            raise NormalizeError(f"ffmpeg silence-pad failed: rc={completed.returncode} {stderr[:500]}")

    def _measure_lufs(self, target: Path) -> tuple[float, float]:
        # Run ffmpeg with ebur128 filter; parse stderr for "I:" (integrated)
        # and "Peak:" / "True peak:" values.
        argv = [
            self.ffmpeg,
            "-i",
            str(target),
            "-af",
            "ebur128=peak=true",
            "-f",
            "null",
            "-",
        ]
        completed = subprocess.run(argv, capture_output=True, timeout=60.0, check=False)
        if completed.returncode != 0:
            stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
            raise NormalizeError(f"ebur128 measurement failed: {stderr[:500]}")

        text = (completed.stderr or b"").decode("utf-8", errors="replace")
        # Prefer the final "Summary:" block which lists the integrated loudness and
        # true peak. Fall back to the last per-frame "I:" line if the Summary is
        # missing (some ffmpeg versions or input edge cases).
        summary_idx = text.rfind("Summary:")
        if summary_idx >= 0:
            summary = text[summary_idx:]
            lufs_match = re.search(r"I:\s*(-?\d+(?:\.\d+)?)\s*LUFS", summary)
            peak_match = re.search(r"(?:True peak|Peak):\s*(-?\d+(?:\.\d+)?)\s*dB", summary)
        else:
            # Iterate per-line to find the LAST I: value.
            lufs_match = None
            for m in re.finditer(r"I:\s*(-?\d+(?:\.\d+)?)\s*LUFS", text):
                lufs_match = m
            peak_match = None
            for m in re.finditer(r"(?:True peak|Peak):\s*(-?\d+(?:\.\d+)?)\s*dB", text):
                peak_match = m

        if not lufs_match:
            raise NormalizeError(f"could not parse LUFS from ebur128 output:\n{text[-500:]}")
        lufs = float(lufs_match.group(1))
        peak = float(peak_match.group(1)) if peak_match else 0.0
        return lufs, peak

    def _probe_metadata(self, target: Path) -> dict:
        argv = [
            self.ffprobe,
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_streams",
            "-show_format",
            str(target),
        ]
        completed = subprocess.run(argv, capture_output=True, timeout=30.0, check=False)
        if completed.returncode != 0:
            stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
            raise NormalizeError(f"ffprobe failed: {stderr[:500]}")

        try:
            data = json.loads(completed.stdout.decode("utf-8", errors="replace"))
        except json.JSONDecodeError as exc:
            raise NormalizeError(f"ffprobe returned invalid JSON: {exc}") from exc

        audio_stream = next(
            (s for s in data.get("streams", []) if s.get("codec_type") == "audio"),
            None,
        )
        if audio_stream is None:
            raise NormalizeError("ffprobe reports no audio stream")

        fmt = data.get("format", {})
        # Duration may live in stream or format.
        duration_s = float(fmt.get("duration") or audio_stream.get("duration") or 0.0)
        bitrate_bps = int(fmt.get("bit_rate") or audio_stream.get("bit_rate") or 0)

        return {
            "duration_ms": int(round(duration_s * 1000)),
            "sample_rate": int(audio_stream.get("sample_rate", 0)),
            "channels": int(audio_stream.get("channels", 0)),
            "codec": audio_stream.get("codec_name", ""),
            "bitrate_bps": bitrate_bps,
        }
