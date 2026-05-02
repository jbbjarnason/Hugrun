---
phase: 13.1
title: Leading Silence Trim Fix — Context
status: in-progress
date: 2026-05-02
parent_phase: 13
---

# Phase 13.1: Leading Silence Trim Fix — Context

## Why this phase exists

Phase 13's spectral review (`audio-review/REVIEW.md` + `audio-review/anomalies.json`)
flagged a systemic Phase-3 pipeline misconfig: 41 of 118 baked AAC clips have
**>100 ms leading silence**, and 116/118 have **>100 ms trailing silence**.
Worst-case leading silence: `phonemeEAcute` at **1140 ms**.

User-perceptible cost: every tap on a letter waits 100–1200 ms before sound
plays. Catastrophic perceived latency for the 4-year-old target user.

## Root cause

`tools/tts/normalize.py` runs:

1. `ffmpeg-normalize` (EBU R128 to -19 LUFS / -1 dBTP, AAC encode at 96 kbps)
2. `adelay=30|30` (intentional 30 ms leading silence — D-10, masks AAC priming
   delay so kid never hears phoneme onset clipped on AAC frame boundary)

But Piper's raw WAV output already contains its own leading silence (varies by
phoneme, often 70–1140 ms). The pipeline never trims that — it just adds
30 ms on top. Net leading silence = Piper's silence + 30 ms.

## Fix

Insert an `ffmpeg silenceremove` filter BEFORE step 1. Trim Piper's
leading + trailing silence aggressively (-40 dB threshold, 10 ms detection at
start, 200 ms at end), THEN run ffmpeg-normalize, THEN apply the deliberate
30 ms pad. Net leading silence after fix: ~30 ms.

The 30 ms intentional padding stays as-is — that's a deliberate codec decision
to mask AAC encoder priming delay (D-10).

## Trade-off acknowledged

Re-baking changes file content (different leading-silence patterns produce
different MDCT frames, so AAC bytes differ). Per Phase 3 D-17, content change
should require re-review. For this phase, the underlying *text* is unchanged
and the pronunciation isn't being modified — only the silence around it. We
preserve `technically_reviewed: true` flags (the technical pass still passes
on the re-baked clips) and explicitly call out in SUMMARY that pronunciation
review status is unaffected.

## Scope boundaries

- DO modify `tools/tts/normalize.py`, its tests, and re-bake all 118 clips.
- DO re-run `tools/audio_review/*` and update `audio-review/REVIEW.md`.
- DO regenerate `lib/gen/audio_manifest.g.dart` if any durations shifted enough
  to be visible (>5 ms; ffprobe rounds to whole ms).
- DO NOT touch `lib/features/`, `assets/images/`, `lib/core/` (other than
  the regenerated manifest file).
- DO NOT change the 30 ms intentional padding constant.

## Quality gate

- normalize.py has silenceremove pre-step covered by pytest
- All 118 clips re-baked successfully (technical_review pass = 118/118)
- Spectral re-review: leading silence ≤ 50 ms for ≥95% of clips
- `flutter test` 455+ pass
- `flutter analyze` clean
- `flutter build apk --debug` succeeds
- `tools/check-manifest-sync.sh` passes
- Atomic per-task commits (RED, GREEN, re-bake, review)
