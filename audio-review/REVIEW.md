# Hugrún corpus — spectral / acoustic review

**Generated:** 2026-05-02 (re-run after Phase 13.1 silence-trim fix)
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

## TL;DR (Phase 13.1 re-run)

- **All 118 baked AAC clips decode to valid 48 kHz mono PCM.** No silent files, no decode errors, no truly empty clips.
- **Leading silence: fixed.** Max **70 ms** (was 1140 ms), mean **58 ms** (was ~150 ms), 0/118 clips above the 100 ms `excess_leading_silence` threshold (was 41/118). User-perceptible tap-to-sound latency dropped from a worst-case **1.2 s → 70 ms**.
- **Trailing silence: substantially reduced.** Max **290 ms** (was 1000 ms), mean **217 ms** (was ~430 ms). 116/118 clips still trip the 100 ms flagger threshold, but this is intentional natural decay (silenceremove `stop_silence=0.20` leaves 200 ms by design — see Phase 13.1 normalize.py rationale). Below the threshold would risk eating fricative coda noise.
- **The corpus is loudness-consistent**: RMS mean **-20.29 dBFS**, std **1.25 dB**. 18/118 clips fall outside ±1.5 σ — small magnitudes, mostly fricative-heavy phones (`f`, `s`, `x`) which are expected to read quieter.
- **No clipping incidents.** Peak max **-0.90 dBFS** (was -0.23 dBFS at `numberOneFem` pre-fix; the silence trim shifted true-peak measurements slightly).
- **Spectral centroids range 1707–3656 Hz**, all within the ~500–4000 Hz window expected for Icelandic speech. No spectrally degenerate clips.
- **All clips fit between 0.53 s and 2.88 s.** None too short or too long.

**Recommendation:** Phase 13.1's silence-trim fix successfully addresses the user-perceptible latency issue. The corpus is now ready for native-speaker pronunciation review.

---

## Anomaly summary (post-fix)

| Category                  | Count | Δ vs pre-fix | Severity | Notes                                                           |
| ------------------------- | ----- | ------------ | -------- | --------------------------------------------------------------- |
| `excess_trailing_silence` | 116   | +0           | low      | >100 ms trailing pad. Intentional 200 ms natural-decay band.    |
| `rms_outlier`             | 18    | +5           | medium   | RMS more than 1.5 σ from mean. Mostly fricatives — expected. The slight tightening of corpus mean/std after silence-trim shifts a few more clips outside the band. |
| `silence_heavy`           | 11    | -33          | low      | >50 % of clip duration below -50 dBFS. Sharp drop because the silence-heavy clips were silence-padded, not silence-encoding-the-utterance. |
| `excess_leading_silence`  | **0** | **-41**      | —        | **Fixed.** Was 41/118 with worst case 1140 ms.                  |
| `clipping`                | 0     | -1           | —        | **Fixed.** Was 1 (`numberOneFem` at -0.23 dBFS).                |
| `centroid_low/high`       | 0     | 0            | —        | All centroids within speech range.                              |
| `near_empty`              | 0     | 0            | —        | No silent files.                                                |
| `duration_short/long`     | 0     | 0            | —        | All clips between 0.53 s and 2.88 s.                            |

Total flagged: **116/118** (every clip except `numberThreeFem` and `numberOneFem` trips the trailing-silence flag). Real signal-quality concerns: ~18 clips (RMS outliers — physics-driven for fricatives).

---

## Distributions

The corpus remains tightly clustered on RMS and well-distributed on duration / centroid:

- ![RMS distribution](histograms/rms.png)
- ![Peak distribution](histograms/peak.png)
- ![Duration distribution](histograms/duration.png)
- ![Spectral centroid distribution](histograms/centroid.png)

`peak` distribution shows most clips peak at -1 to -3 dBFS — consistent with a -1 dBFS true-peak ceiling that normalize.py targets. No clip near 0 dBFS anymore.

---

## Per-dimension extremes (post-fix)

| Dimension                | Min                                  | Max                              |
| ------------------------ | ------------------------------------ | -------------------------------- |
| RMS (dBFS)               | `numberFive` (-23.46)                | `wordD` (-17.59)                 |
| Peak (dBFS)              | `letterB` (≈-5)                      | `letterE` (-0.90)                |
| Duration (s)             | `numberOneNeut` (0.533)              | `narrationWelcome` (2.880)       |
| Spectral centroid (Hz)   | `numberNine` (1707)                  | `numberSix` (3656)               |
| Leading silence (ms)     | 50                                   | `letterOAcute` (70)              |
| Trailing silence (ms)    | 80                                   | `phonemeF` (290)                 |

All extremes are within physically reasonable ranges. **No outlier silence values remain — the longest leading silence is 70 ms and the longest trailing silence is 290 ms**, both within the design bands of normalize.py's silenceremove + adelay pipeline.

---

## Phase 13.1 fix summary

The `tools/tts/normalize.py` pipeline now runs an `ffmpeg silenceremove` pre-step
before ffmpeg-normalize:

```
silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.01:detection=peak,
silenceremove=stop_periods=-1:stop_threshold=-40dB:stop_silence=0.20:detection=peak
```

This trims Piper's upstream silence (which previously survived all the way to
the baked AAC) before applying the deliberate 30 ms intentional pad (D-10) that
masks AAC encoder priming delay. Net result: every clip starts with ~60 ms of
leading silence, instead of the 70-1140 ms variable lag that caused the
catastrophic perceived latency on every tap.

See `.planning/phases/13.1-leading-silence-trim/13_1-SUMMARY.md` for the full
fix narrative and verification results.

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
