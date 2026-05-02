# Phase 13 — Spectral / acoustic review (sibling artifact)

**Filed by:** parallel spectral-review workstream (independent of Phase 13's main planning)
**Date:** 2026-05-02
**Scope:** Acoustic / magnitude analysis of all 118 baked AAC clips currently on disk, baked from the `is_IS-steinn-medium` Piper voice (Phase 3 / D-04…D-06 corpus).
**Sources:** `audio-review/clip_stats.json`, `audio-review/anomalies.json`, `audio-review/outliers.json`, `audio-review/all-spectrograms.png`.
**Full report:** [`audio-review/REVIEW.md`](../../../audio-review/REVIEW.md) (top-level repo, gitignored output).

> **Acoustic-only.** This artifact does not validate Icelandic pronunciation. It tells
> Phase 13 what the corpus looks like in terms of magnitude, dynamic range, edge
> silence, and spectral shape — i.e. things visible on a spectrogram. Phonetic
> correctness still belongs to the native-speaker review pass.

---

## Headline finding for Phase 13 planners

**The corpus is acoustically healthy but has systematic edge-silence padding that
Phase 13 should fix during regeneration.**

- 118/118 clips decode cleanly to 48 kHz mono PCM.
- RMS is tightly clustered (mean -20.81 dBFS, σ 1.41 dB) → loudness normalization works.
- 116/118 clips have >100 ms trailing silence; 41/118 have >100 ms leading silence; **worst case 1140 ms leading (`phonemeEAcute`), 1000 ms trailing (`letterEAcute`)**.
- 1 clip near-clipping: `numberOneFem` at -0.23 dBFS peak.
- 13 RMS outliers — 8 are fricatives (acoustically expected to be quiet), 3 are louder-than-mean clips that warrant a listen.

If Phase 13 re-bakes from manifest.yaml, the `tools/tts/normalize.py` step should be
revisited so that edge silence is trimmed to ≤ 50 ms (or whatever Phase 3 originally
specified — current behavior diverges from that target by 5–20×).

---

## Anomaly counts

| Category                  | Count | Severity |
| ------------------------- | ----- | -------- |
| `excess_trailing_silence` | 116   | low (systemic, not per-clip) |
| `silence_heavy`           | 44    | low (downstream of edge padding) |
| `excess_leading_silence`  | 41    | low (systemic) |
| `rms_outlier`             | 13    | medium |
| `clipping`                | 1     | medium |
| `centroid_low/high`       | 0     | — |
| `near_empty`              | 0     | — |
| `duration_short/long`     | 0     | — |
| `decode_error`            | 0     | — |
| `missing_file`            | 0     | — |

After deduplication, the **non-systemic** issue list is ~14 clips (1 clipping + 13 RMS
outliers, with overlap on fricatives like `letterF` / `wordF`).

---

## What Phase 13 should consider

1. **Re-trim edge silence on regeneration.** Inspect `tools/tts/normalize.py` (silence trim threshold + minimum-pad parameter). Target ≤ 50 ms leading and trailing.
2. **Re-bake `numberOneFem`.** Single near-clip incident; lower the input gain (or the normalize.py true-peak ceiling) just for this entry.
3. **Spot-check the loud RMS outliers** (`wordD`, `letterUAcute`, `wordHundur`) — these are +2 to +2.6 dB above mean, which is the opposite of fricative-physics, so it's worth a manual listen for over-driven samples.
4. **Leave fricatives alone.** `phonemeF`, `phonemeS`, `letterF`, `letterS`, `letterX`, `numberFive` ("fimm"), `numberSeven` ("sjö") all flag as RMS-low because /f/, /s/, /sj/ are acoustically quiet phonemes. Loudness-equalizing them would distort the natural relative dynamics.
5. **No re-bake needed for edge-silence-only flags.** A pure trim is sufficient; the underlying speech audio is fine.

---

## Files Phase 13 can consume

| File                                   | Format     | Purpose                                          |
| -------------------------------------- | ---------- | ------------------------------------------------ |
| `audio-review/clip_stats.json`         | JSON       | Per-clip stats for all 118 clips                 |
| `audio-review/anomalies.json`          | JSON       | Flagged clips with reasons + thresholds          |
| `audio-review/outliers.json`           | JSON       | Per-dimension extreme keys                       |
| `audio-review/corpus-summary.md`       | Markdown   | Human-readable distribution summary              |
| `audio-review/REVIEW.md`               | Markdown   | Full review (this artifact's parent)             |
| `audio-review/all-spectrograms.png`    | PNG, 2000×1500 | Single-image montage of all 118 spectrograms |
| `audio-review/spectrograms/<key>.png`  | PNG, ~800×400 | Per-clip waveform + mel-spectrogram          |
| `audio-review/histograms/{rms,peak,duration,centroid}.png` | PNG | Distribution plots |

Outputs are listed in `.gitignore` (regenerable from `tools/audio_review/*.py`).

---

## Reproduction

```bash
source tools/audio_review/.venv/bin/activate
python tools/audio_review/analyze_clips.py
python tools/audio_review/build_montage.py
python tools/audio_review/flag_anomalies.py
python tools/audio_review/compare_corpus.py
```

Total runtime on this corpus: ~30 s (single-threaded librosa, MacBook M-series).

---

## Out of scope (deliberately)

This review **does not** speak to:
- Pronunciation accuracy (eth/thorn/ø/æ hot spots, etc.)
- Whether Steinn pronounced the intended text vs. e.g. spelling out a letter
- Prosody, intonation, kid-friendly tone
- Comparison against a reference voice

These remain Phase 6's native-speaker review responsibility (`reviewed.yaml`,
`tools/tts/review_server.py`).
