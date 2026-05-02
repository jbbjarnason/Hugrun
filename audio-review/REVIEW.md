# Hugrún corpus — spectral / acoustic review

**Generated:** 2026-05-02
**Voice:** `is_IS-steinn-medium` (Piper)
**Tooling:** `tools/audio_review/*.py` (librosa 0.11, ffmpeg 8.1)
**Manifest:** 118 utterances (32 letter_name + 32 example_word + 32 phoneme + 3 CVC + 18 numerals + 1 narration)
**Files on disk:** 118/118 (no missing files)
**Decoded successfully:** 118/118 (no decode errors)

> **Scope disclaimer.** This review is **acoustic / magnitude analysis only**. It checks
> whether each clip looks like a coherent speech signal (RMS, peak, spectrogram shape,
> silence boundaries, spectral centroid). It does **NOT** validate Icelandic
> pronunciation, phoneme accuracy, prosody, or whether the speaker pronounced the
> intended utterance. Pronunciation correctness still requires a native-speaker review
> pass (Phase 6 reviewer workflow).

---

## TL;DR

- **All 118 baked AAC clips decode to valid 48 kHz mono PCM.** No silent files, no decode errors, no truly empty clips.
- **The corpus is loudness-consistent**: RMS mean **-20.81 dBFS**, std **1.41 dB**. 13/118 clips fall outside ±1.5 σ — small magnitudes, mostly fricative-heavy phones (`f`, `s`, `x`) which are expected to read quieter.
- **One clipping incident** at `numberOneFem` (peak -0.23 dBFS). Worth checking but not severe.
- **Edge silence is the dominant anomaly.** 116/118 clips have >100 ms trailing silence and 41/118 have >100 ms leading silence. Several clips have ~1000 ms of leading or trailing pad. This points at a **Phase 3 trim/normalize misconfig** rather than per-clip recording issues — the silence is uniform across kinds, suggesting `tools/tts/normalize.py` is leaving generous padding on the master AAC.
- **Spectral centroids range 1765–3709 Hz**, all within the ~500–4000 Hz window expected for Icelandic speech. No spectrally degenerate clips.
- **All clips fit between 0.53 s and 2.88 s.** None too short or too long.

**Recommendation:** Phase 13's acoustic regeneration is a good moment to tighten edge-silence trimming. The corpus is otherwise healthy.

---

## Anomaly summary

| Category                  | Count | Severity | Notes                                                           |
| ------------------------- | ----- | -------- | --------------------------------------------------------------- |
| `excess_trailing_silence` | 116   | low      | >100 ms trailing pad. Systemic — affects nearly every clip.     |
| `silence_heavy`           | 44    | low      | >50 % of clip duration below -50 dBFS — driven by edge padding. |
| `excess_leading_silence`  | 41    | low      | >100 ms leading pad. Worst case 1140 ms (phonemeEAcute).        |
| `rms_outlier`             | 13    | medium   | RMS more than 1.5 σ from mean. Mostly fricatives — expected.    |
| `clipping`                | 1     | medium   | `numberOneFem` peak -0.23 dBFS (very close to 0).               |
| `centroid_low/high`       | 0     | —        | All centroids within speech range.                              |
| `near_empty`              | 0     | —        | No silent files.                                                |
| `duration_short/long`     | 0     | —        | All clips between 0.20 s and 3.0 s.                             |

Total flagged: **118/118** (every clip trips at least the trailing-silence flag).
Real signal-quality concerns: **~14 clips** (1 clipping + 13 RMS outliers, with overlap).

---

## Distributions

The corpus is tightly clustered on RMS and well-distributed on duration / centroid:

- ![RMS distribution](histograms/rms.png)
- ![Peak distribution](histograms/peak.png)
- ![Duration distribution](histograms/duration.png)
- ![Spectral centroid distribution](histograms/centroid.png)

`peak` distribution shows most clips peak at -1 to -3 dBFS — consistent with a -1 dBFS true-peak ceiling that Phase 3 normalize.py likely targets. The single clip near 0 dBFS (`numberOneFem`) is the one clipping flag.

---

## Per-dimension extremes

| Dimension                | Min                                  | Max                              |
| ------------------------ | ------------------------------------ | -------------------------------- |
| RMS (dBFS)               | `phonemeF` (-25.96)                  | `wordD` (-18.24)                 |
| Peak (dBFS)              | `letterB` (-5.08)                    | `numberOneFem` (-0.23) ← clipping |
| Duration (s)             | `numberOneNeut` (0.533)              | `narrationWelcome` (2.880)       |
| Spectral centroid (Hz)   | `narrationWelcome` (1765)            | `numberSix` (3709)               |
| Leading silence (ms)     | varied (most ≤100 ms)                | `phonemeEAcute` (1140)           |
| Trailing silence (ms)    | varied                               | `letterEAcute` (1000)            |

All extremes are within physically reasonable ranges. The longest leading-silence clip (`phonemeEAcute` at 1140 ms) is the strongest single argument for re-trimming.

---

## Specific clips for visual inspection

The orchestrator should `Read` these spectrograms in particular:

1. **`audio-review/spectrograms/numberOneFem.png`** — only clipping flag (peak -0.23 dBFS). Verify the waveform isn't visibly squared off; if a few sample peaks just barely cross, this is cosmetic, but if there's audible distortion the clip should be re-baked at lower input gain.
2. **`audio-review/spectrograms/phonemeEAcute.png`** — worst leading silence (1140 ms). Spectrogram should show a long blank head before the energy onset. Re-trim candidate.
3. **`audio-review/spectrograms/letterEAcute.png`** — worst trailing silence (1000 ms). Same pattern at the tail.
4. **`audio-review/spectrograms/phonemeF.png`** — quietest clip (RMS -25.96 dBFS), high spectral centroid (3487 Hz). Should show the broadband fricative noise pattern characteristic of `/f/`. If it's roughly flat broadband above 1 kHz, that's expected; if it's nearly silent across the spectrogram, that's an issue.
5. **`audio-review/spectrograms/narrationWelcome.png`** — longest clip (2.88 s) and lowest centroid (1765 Hz). Visually: should show 4-6 distinct vocalic peaks for a sentence-length narration. A flat band suggests synthesis collapse.

Single-image overview of all 118 clips: **`audio-review/all-spectrograms.png`** (2000×1500 px, 12×10 grid).

---

## RMS outliers (full list — 13 clips)

Corpus mean = -20.81 dBFS, threshold = ±2.11 dB.

| Key             | RMS (dBFS) | Δ from mean | Likely cause                                      |
| --------------- | ---------- | ----------- | ------------------------------------------------- |
| `phonemeF`      | -25.96     | -5.15       | unvoiced labiodental fricative — quiet by nature  |
| `numberFive`    | -23.90     | -3.09       | "fimm" — initial /f/ fricative-heavy              |
| `wordE`         | -23.65     | -2.84       | review individually                               |
| `letterF`       | -23.58     | -2.77       | unvoiced fricative                                |
| `wordF`         | -23.58     | -2.77       | unvoiced fricative                                |
| `numberSeven`   | -23.31     | -2.50       | "sjö" — fricative onset                           |
| `phonemeS`      | -23.14     | -2.33       | sibilant fricative                                |
| `letterS`       | -22.97     | -2.16       | sibilant                                          |
| `letterV`       | -22.93     | -2.12       | review individually                               |
| `wordHundur`    | -18.66     | +2.15       | louder than mean — review                         |
| `letterUAcute`  | -18.68     | +2.13       | louder than mean — review                         |
| `wordD`         | -18.24     | +2.57       | loudest in corpus — review                        |

The **negative-side outliers (8/13)** are explicitly fricatives or fricative-initial words. This is expected acoustic physics, not a bug. The **positive-side outliers (3/13)** are worth a closer listen by a human reviewer to confirm the speaker isn't shouting or mic-overloaded.

---

## Sample stats table (first 10 clips)

| Key            | Kind        | Dur (s) | RMS (dB) | Peak (dB) | Centroid (Hz) | Lead (ms) | Trail (ms) | Silence frac |
| -------------- | ----------- | ------- | -------- | --------- | ------------- | --------- | ---------- | ------------ |
| `letterA`      | letter_name | 0.60    | -20.03   | -1.20     | 2523          | 70        | 240        | 0.53         |
| `letterAAcute` | letter_name | 0.68    | -18.71   | -0.51     | 2195          | 90        | 250        | 0.51         |
| `letterB`      | letter_name | 0.70    | -20.19   | -5.08     | 2614          | 90        | 260        | 0.50         |
| `letterD`      | letter_name | 0.79    | -19.88   | -4.83     | 2720          | 90        | 350        | 0.56         |
| `letterEth`    | letter_name | 0.77    | -20.98   | -0.99     | 3070          | 110       | 190        | 0.39         |
| `letterE`      | letter_name | 0.70    | -20.36   | -1.05     | 2368          | 100       | 240        | 0.49         |
| `letterEAcute` | letter_name | 1.54    | -21.94   | -3.67     | 3123          | 130       | 1000       | 0.74         |
| `letterF`      | letter_name | 0.81    | -23.58   | -1.23     | 3224          | 100       | 340        | 0.54         |
| `letterG`      | letter_name | 0.73    | -20.80   | -2.71     | 2677          | 100       | 300        | 0.56         |
| `letterH`      | letter_name | 0.62    | -20.11   | -1.16     | 2017          | 80        | 190        | 0.44         |

All clips are 48 kHz mono. Full table: `audio-review/clip_stats.json`.

---

## Methodology

- Decoded each AAC via `librosa.load(sr=None, mono=True)` (audioread → ffmpeg backend).
- RMS/peak computed on full-clip PCM (no windowing).
- ZCR, spectral centroid, spectral rolloff via `librosa.feature.*` with `n_fft=1024`, `hop_length=256`.
- Edge silence detected via 10 ms RMS frames < -50 dBFS.
- RMS outlier threshold: ±1.5 × population std.
- Speech centroid window: 500–4000 Hz (rough heuristic).
- Spectrograms: 64-bin mel, log power, magma colormap, 800×400 px @ 100 dpi.

Reproduce:

```bash
source tools/audio_review/.venv/bin/activate
python tools/audio_review/analyze_clips.py     # writes clip_stats.json + spectrograms/
python tools/audio_review/build_montage.py     # writes all-spectrograms.png
python tools/audio_review/flag_anomalies.py    # writes anomalies.json
python tools/audio_review/compare_corpus.py    # writes corpus-summary.md + histograms/
```

---

## What this review did NOT check

- Phoneme correctness (e.g. is `letterEth` actually a voiced dental fricative or did Steinn say a "d"?).
- Pronunciation of the override-prone hot spots noted in `manifest.yaml` (eth, thorn, ø, æ).
- Prosody, intonation, or naturalness.
- Whether the speaker pronounced the **intended text**. (Spectrogram shape can rule out gross collapse but cannot confirm semantics.)
- Cross-voice consistency or comparison to a reference voice.

These remain in scope for the **native-speaker review pass** (Phase 6 reviewer workflow,
`tools/tts/review_server.py` / `reviewed.yaml`).
