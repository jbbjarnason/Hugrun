#!/usr/bin/env python3
"""Generate a single grid PNG of all clip spectrogram thumbnails.

Reads audio-review/clip_stats.json, downsizes each per-clip spectrogram into a
small thumbnail, and tiles them with key-labels into a single image. The grid
is bounded to ≤ 2000×1500 px so a vision model can read it in one shot.

Output: audio-review/all-spectrograms.png
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.image as mpimg
import matplotlib.pyplot as plt

REPO_ROOT = Path(__file__).resolve().parents[2]
STATS_PATH = REPO_ROOT / "audio-review" / "clip_stats.json"
OUTPUT = REPO_ROOT / "audio-review" / "all-spectrograms.png"

# Grid sizing
MAX_WIDTH_PX = 2000
MAX_HEIGHT_PX = 1500
COLS = 10  # 10 columns × 12 rows = 120 cells (>= 118 clips)


def main() -> int:
    payload = json.loads(STATS_PATH.read_text())
    clips = [c for c in payload["clips"] if c.get("spectrogram_path")]
    n = len(clips)
    rows = math.ceil(n / COLS)

    # Compute cell size to fit within bounds (with small label space)
    fig_w_in = MAX_WIDTH_PX / 100.0   # dpi=100
    fig_h_in = MAX_HEIGHT_PX / 100.0
    fig, axes = plt.subplots(rows, COLS, figsize=(fig_w_in, fig_h_in), dpi=100)
    fig.patch.set_facecolor("#111111")

    for idx in range(rows * COLS):
        r = idx // COLS
        c = idx % COLS
        ax = axes[r, c] if rows > 1 else axes[c]
        ax.set_xticks([])
        ax.set_yticks([])
        for spine in ax.spines.values():
            spine.set_visible(False)
        if idx < n:
            clip = clips[idx]
            img_path = REPO_ROOT / clip["spectrogram_path"]
            if img_path.exists():
                img = mpimg.imread(str(img_path))
                ax.imshow(img, aspect="auto")
                key = clip["key"]
                # Truncate key to ~16 chars
                short = key if len(key) <= 18 else key[:16] + "…"
                ax.set_title(short, fontsize=6, color="white", pad=1)
            else:
                ax.text(0.5, 0.5, "no img", ha="center", va="center",
                        fontsize=6, color="red", transform=ax.transAxes)
        else:
            ax.set_visible(False)

    fig.suptitle(
        f"Hugrún corpus spectrogram montage  —  {n} clips  "
        f"(voice: {payload.get('voice')})",
        color="white", fontsize=10, y=0.998,
    )
    fig.subplots_adjust(left=0.005, right=0.995, top=0.97, bottom=0.005,
                        wspace=0.05, hspace=0.35)
    fig.savefig(OUTPUT, dpi=100, facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"Wrote {OUTPUT.relative_to(REPO_ROOT)}  ({n} thumbnails, {rows}×{COLS})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
