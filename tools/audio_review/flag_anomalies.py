#!/usr/bin/env python3
"""Flag acoustic anomalies in baked AAC corpus.

Reads audio-review/clip_stats.json, applies threshold-based and outlier-based
detectors, writes audio-review/anomalies.json, and prints a summary.

Detectors:
  - clipping:           peak ≥ -0.5 dBFS
  - silence_heavy:      silence_fraction > 0.50
  - excess_leading:     leading_silence_ms > 100
  - excess_trailing:    trailing_silence_ms > 100
  - rms_outlier:        |rms - mean| > 1.5 * std
  - centroid_outlier:   centroid < 500 Hz or > 4000 Hz
  - duration_outlier:   duration < 0.20 s or > 3.0 s
  - near_empty:         rms_db < -60
  - decode_error:       error or missing file
"""
from __future__ import annotations

import json
import statistics
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
STATS_PATH = REPO_ROOT / "audio-review" / "clip_stats.json"
OUTPUT = REPO_ROOT / "audio-review" / "anomalies.json"

CLIP_DBFS_THRESHOLD = -0.5
SILENCE_FRACTION_THRESHOLD = 0.50
LEADING_SILENCE_MS_THRESHOLD = 100.0
TRAILING_SILENCE_MS_THRESHOLD = 100.0
RMS_STD_K = 1.5
CENTROID_LOW = 500.0
CENTROID_HIGH = 4000.0
DURATION_MIN_S = 0.20
DURATION_MAX_S = 3.0
NEAR_EMPTY_DB = -60.0


def main() -> int:
    payload = json.loads(STATS_PATH.read_text())
    clips = payload["clips"]

    valid = [c for c in clips if c["file_exists"] and not c["error"]]
    rms_values = [c["rms_db"] for c in valid]
    rms_mean = statistics.fmean(rms_values) if rms_values else -120.0
    rms_std = statistics.pstdev(rms_values) if len(rms_values) > 1 else 0.0

    flags_by_clip: dict[str, list[str]] = {}
    flag_counts: dict[str, int] = {}

    def flag(key: str, reason: str) -> None:
        flags_by_clip.setdefault(key, []).append(reason)
        flag_counts[reason] = flag_counts.get(reason, 0) + 1

    for c in clips:
        key = c["key"]
        if not c["file_exists"]:
            flag(key, "missing_file")
            continue
        if c["error"]:
            flag(key, f"decode_error:{c['error']}")
            continue

        if c["peak_db"] >= CLIP_DBFS_THRESHOLD:
            flag(key, "clipping")
        if c["rms_db"] < NEAR_EMPTY_DB:
            flag(key, "near_empty")
        if c["silence_fraction"] > SILENCE_FRACTION_THRESHOLD:
            flag(key, "silence_heavy")
        if c["leading_silence_ms"] > LEADING_SILENCE_MS_THRESHOLD:
            flag(key, "excess_leading_silence")
        if c["trailing_silence_ms"] > TRAILING_SILENCE_MS_THRESHOLD:
            flag(key, "excess_trailing_silence")
        if rms_std > 0 and abs(c["rms_db"] - rms_mean) > RMS_STD_K * rms_std:
            flag(key, "rms_outlier")
        cent = c["spectral_centroid_mean_hz"]
        if cent < CENTROID_LOW:
            flag(key, "centroid_low")
        elif cent > CENTROID_HIGH:
            flag(key, "centroid_high")
        if c["duration_s"] < DURATION_MIN_S:
            flag(key, "duration_short")
        elif c["duration_s"] > DURATION_MAX_S:
            flag(key, "duration_long")

    flagged_clips = []
    for c in clips:
        reasons = flags_by_clip.get(c["key"])
        if reasons:
            flagged_clips.append({
                "key": c["key"],
                "kind": c["kind"],
                "asset": c["asset"],
                "duration_s": c["duration_s"],
                "rms_db": c["rms_db"],
                "peak_db": c["peak_db"],
                "spectral_centroid_mean_hz": c["spectral_centroid_mean_hz"],
                "leading_silence_ms": c["leading_silence_ms"],
                "trailing_silence_ms": c["trailing_silence_ms"],
                "silence_fraction": c["silence_fraction"],
                "reasons": reasons,
                "spectrogram_path": c.get("spectrogram_path", ""),
            })

    out = {
        "total": len(clips),
        "valid": len(valid),
        "flagged": len(flagged_clips),
        "clean": len(valid) - len(flagged_clips),
        "rms_mean_db": rms_mean,
        "rms_std_db": rms_std,
        "rms_outlier_threshold_db": RMS_STD_K * rms_std,
        "thresholds": {
            "clip_dbfs": CLIP_DBFS_THRESHOLD,
            "silence_fraction": SILENCE_FRACTION_THRESHOLD,
            "leading_silence_ms": LEADING_SILENCE_MS_THRESHOLD,
            "trailing_silence_ms": TRAILING_SILENCE_MS_THRESHOLD,
            "rms_std_multiplier": RMS_STD_K,
            "centroid_hz": [CENTROID_LOW, CENTROID_HIGH],
            "duration_s": [DURATION_MIN_S, DURATION_MAX_S],
            "near_empty_db": NEAR_EMPTY_DB,
        },
        "counts_by_reason": dict(sorted(flag_counts.items(), key=lambda kv: -kv[1])),
        "flagged_clips": flagged_clips,
    }
    OUTPUT.write_text(json.dumps(out, indent=2, ensure_ascii=False))

    print(f"Total clips:     {out['total']}")
    print(f"Valid (decoded): {out['valid']}")
    print(f"Clean:           {out['clean']}")
    print(f"Flagged:         {out['flagged']}")
    print(f"RMS corpus:      mean={rms_mean:.2f} dB  std={rms_std:.2f} dB")
    print()
    print("Counts by reason:")
    for reason, count in out["counts_by_reason"].items():
        print(f"  {reason:<28} {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
