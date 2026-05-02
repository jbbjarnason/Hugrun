#!/usr/bin/env python3
"""Per-clip spectral / magnitude analysis for baked AAC narration.

Reads manifest.yaml (Phase 3 schema), decodes each clip via librosa, computes
acoustic statistics, and renders a 2-panel waveform+spectrogram PNG per clip.

Outputs (under audio-review/):
  - spectrograms/{utterance_key}.png   (one per clip)
  - clip_stats.json                    (corpus-wide stats)

This is acoustic analysis only — it does NOT validate Icelandic pronunciation.
"""
from __future__ import annotations

import json
import math
import os
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import librosa
import matplotlib

matplotlib.use("Agg")  # headless
import matplotlib.pyplot as plt
import numpy as np
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST = REPO_ROOT / "manifest.yaml"
OUTPUT_DIR = REPO_ROOT / "audio-review"
SPEC_DIR = OUTPUT_DIR / "spectrograms"
STATS_PATH = OUTPUT_DIR / "clip_stats.json"

SILENCE_DB_THRESHOLD = -50.0  # below this is "silent"


@dataclass
class ClipStats:
    key: str
    text: str
    kind: str
    asset: str
    file_exists: bool
    duration_s: float = 0.0
    sample_rate: int = 0
    rms_db: float = -120.0
    peak_db: float = -120.0
    dynamic_range_db: float = 0.0
    zcr_mean: float = 0.0
    zcr_std: float = 0.0
    spectral_centroid_mean_hz: float = 0.0
    spectral_centroid_std_hz: float = 0.0
    spectral_rolloff_mean_hz: float = 0.0
    leading_silence_ms: float = 0.0
    trailing_silence_ms: float = 0.0
    silence_fraction: float = 0.0
    spectrogram_path: str = ""
    error: str = ""


def db(x: float) -> float:
    if x <= 1e-10:
        return -120.0
    return 20.0 * math.log10(x)


def load_clip(path: Path) -> tuple[np.ndarray, int]:
    # librosa handles AAC via audioread/ffmpeg backend; preserve native sample rate.
    y, sr = librosa.load(str(path), sr=None, mono=True)
    return y, sr


def find_silence_edges(y: np.ndarray, sr: int, db_thresh: float = SILENCE_DB_THRESHOLD,
                       frame_ms: float = 10.0) -> tuple[float, float, float]:
    """Return (leading_ms, trailing_ms, silence_fraction) using frame-wise RMS."""
    if y.size == 0:
        return 0.0, 0.0, 1.0
    frame_len = max(1, int(sr * frame_ms / 1000.0))
    hop = frame_len
    n_frames = max(1, (len(y) - frame_len) // hop + 1)
    if n_frames < 2:
        return 0.0, 0.0, 0.0

    frames = np.lib.stride_tricks.sliding_window_view(y, frame_len)[::hop]
    frame_rms = np.sqrt(np.mean(frames * frames, axis=1) + 1e-12)
    frame_db = 20.0 * np.log10(frame_rms + 1e-12)

    silent = frame_db < db_thresh

    # Leading silence: count leading silent frames
    leading = 0
    for s in silent:
        if s:
            leading += 1
        else:
            break
    trailing = 0
    for s in silent[::-1]:
        if s:
            trailing += 1
        else:
            break

    leading_ms = leading * frame_ms
    trailing_ms = trailing * frame_ms
    silence_fraction = float(np.mean(silent))
    return leading_ms, trailing_ms, silence_fraction


def render_spectrogram(y: np.ndarray, sr: int, key: str, out_path: Path) -> None:
    fig, axes = plt.subplots(2, 1, figsize=(8, 4), dpi=100,
                             gridspec_kw={"height_ratios": [1, 2]})
    # Waveform
    t = np.linspace(0, len(y) / sr, num=len(y))
    axes[0].plot(t, y, linewidth=0.5, color="#1565C0")
    axes[0].set_xlim(0, len(y) / sr if len(y) else 1)
    axes[0].set_ylim(-1.05, 1.05)
    axes[0].set_ylabel("amp")
    axes[0].set_title(f"{key}  ({len(y)/sr:.2f}s @ {sr} Hz)", fontsize=9)
    axes[0].grid(True, alpha=0.3, linewidth=0.4)

    # Mel-log spectrogram
    n_mels = 64
    S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=n_mels,
                                       n_fft=1024, hop_length=256, power=2.0)
    S_db = librosa.power_to_db(S, ref=np.max)
    img = librosa.display.specshow(S_db, sr=sr, hop_length=256,
                                   x_axis="time", y_axis="mel",
                                   ax=axes[1], cmap="magma", vmin=-80, vmax=0)
    axes[1].set_ylabel("mel Hz")
    fig.colorbar(img, ax=axes[1], format="%+2.0f dB", pad=0.01, fraction=0.04)

    fig.tight_layout()
    fig.savefig(out_path, dpi=100, bbox_inches="tight")
    plt.close(fig)


def analyze_one(entry: dict[str, Any]) -> ClipStats:
    key = entry["key"]
    asset = entry["asset"]
    stats = ClipStats(
        key=key,
        text=str(entry.get("text", "")),
        kind=str(entry.get("kind", "")),
        asset=asset,
        file_exists=False,
    )
    abs_path = REPO_ROOT / asset
    if not abs_path.exists():
        stats.error = "missing_file"
        return stats
    stats.file_exists = True

    try:
        y, sr = load_clip(abs_path)
    except Exception as exc:  # noqa: BLE001 — best-effort decode
        stats.error = f"decode_failed: {exc}"
        return stats

    if y.size == 0:
        stats.error = "empty_pcm"
        return stats

    stats.sample_rate = int(sr)
    stats.duration_s = float(len(y) / sr)

    rms = float(np.sqrt(np.mean(y * y) + 1e-12))
    peak = float(np.max(np.abs(y)))
    stats.rms_db = db(rms)
    stats.peak_db = db(peak)
    stats.dynamic_range_db = float(stats.peak_db - stats.rms_db)

    # Frame-based ZCR
    zcr = librosa.feature.zero_crossing_rate(y, frame_length=1024, hop_length=256)[0]
    stats.zcr_mean = float(np.mean(zcr))
    stats.zcr_std = float(np.std(zcr))

    # Spectral centroid + rolloff
    cent = librosa.feature.spectral_centroid(y=y, sr=sr, n_fft=1024, hop_length=256)[0]
    rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr, n_fft=1024, hop_length=256,
                                               roll_percent=0.85)[0]
    stats.spectral_centroid_mean_hz = float(np.mean(cent))
    stats.spectral_centroid_std_hz = float(np.std(cent))
    stats.spectral_rolloff_mean_hz = float(np.mean(rolloff))

    leading_ms, trailing_ms, silence_frac = find_silence_edges(y, sr)
    stats.leading_silence_ms = float(leading_ms)
    stats.trailing_silence_ms = float(trailing_ms)
    stats.silence_fraction = float(silence_frac)

    spec_path = SPEC_DIR / f"{key}.png"
    try:
        render_spectrogram(y, sr, key, spec_path)
        stats.spectrogram_path = str(spec_path.relative_to(REPO_ROOT))
    except Exception as exc:  # noqa: BLE001
        stats.error = f"render_failed: {exc}"

    return stats


def main() -> int:
    if not MANIFEST.exists():
        print(f"manifest not found: {MANIFEST}", file=sys.stderr)
        return 2
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    SPEC_DIR.mkdir(parents=True, exist_ok=True)

    with MANIFEST.open() as f:
        manifest = yaml.safe_load(f)
    entries = manifest.get("utterances", [])
    print(f"Manifest entries: {len(entries)}")

    results: list[ClipStats] = []
    for i, entry in enumerate(entries, 1):
        stats = analyze_one(entry)
        results.append(stats)
        marker = "ok" if (stats.file_exists and not stats.error) else f"SKIP({stats.error or 'missing'})"
        print(f"  [{i:>3}/{len(entries)}] {stats.key:<24} {marker}")

    payload = {
        "manifest": str(MANIFEST.relative_to(REPO_ROOT)),
        "voice": manifest.get("voice"),
        "language": manifest.get("language"),
        "total": len(results),
        "analyzed": sum(1 for r in results if r.file_exists and not r.error),
        "missing": sum(1 for r in results if not r.file_exists),
        "errored": sum(1 for r in results if r.error and r.file_exists),
        "clips": [asdict(r) for r in results],
    }
    STATS_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False))
    print(f"\nWrote {STATS_PATH.relative_to(REPO_ROOT)}")
    print(f"  total={payload['total']} analyzed={payload['analyzed']} "
          f"missing={payload['missing']} errored={payload['errored']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
