---
phase: 13
title: Audio Manifest Regeneration (Technical Pass) — Context
date: 2026-05-02
depends_on: [02, 03, 06, 08]
parallel_with: [11, 12]
---

# Phase 13 Context

## Why this phase exists

Phases 1-10 shipped. Phases 3, 6, and 8 collectively baked 118 AAC clips
(32 letter names, 35 example words including 3 CVC additions, 32
phonemes, 18 numerals, 1 narration) from the `is_IS-steinn-medium`
Piper voice. The pipeline's strict review gate (D-18) correctly blocked
`lib/gen/audio_manifest.g.dart` from being regenerated until every
entry has `reviewed: true` in `reviewed.yaml` — and that requires a
native-speaker pronunciation review pass that is the user's
responsibility, not an executor agent's.

As a result, the runtime app shipped through Phase 10 still pointed at
the **Phase 2 hand-written 5-key stub manifest**. The audio file paths
existed on disk; the Dart contract simply didn't reference them. The
Stafir room played 5 placeholder clips; the Tölur numerals, the CVC
phonemes, and most letter audio fell back to silence.

Phase 13 inverts this without lying about pronunciation correctness.

## The two gates

Phase 13 introduces a **technical** review pass distinct from the
native-speaker pronunciation review:

| Gate | Owner | Verifies | Field in reviewed.yaml |
|---|---|---|---|
| Technical | Automated (`tools/tts/technical_review.py`) | Codec, channels, sample rate, bitrate, integrated LUFS, non-empty | `technically_reviewed: true` |
| Pronunciation | Human (native Icelandic speaker via `tools/tts/review_server.py`) | Each clip's word/sound is correct Icelandic | `reviewed: true` (+ reviewer + timestamp + voice + text_hash audit trail) |

Both fields are independent. Either is sufficient for the Phase 13
**soft gate** (`allow_technically_reviewed=True`) to emit
`audio_manifest.g.dart`. The strict gate
(`allow_technically_reviewed=False`, default) still requires
`reviewed: true` for every entry.

The emitted Dart file always carries per-entry
`// PRONUNCIATION REVIEW PENDING` markers for any entry that has
`technically_reviewed: true` but not `reviewed: true`. This makes the
runtime contract explicit: the app plays the audio, but a native
speaker has not certified it.

## What Phase 13 does NOT do

- Does NOT mark `reviewed: true`. That field implies native-speaker
  approval and the audit trail required is reviewer + timestamp + voice
  + text_hash. The technical pass cannot supply those honestly.
- Does NOT re-bake clips. The 118 AAC files on disk are the inputs;
  Phase 13 only verifies them and emits Dart pointing at them.
- Does NOT touch `lib/features/`, `lib/core/` widget/domain code, or
  `assets/images/`. Those are Phase 11/12 territory.

## Sibling artifact: spectral review

A parallel spectral / acoustic analysis ran (see `SPECTRAL-REVIEW.md`
in this directory and the gitignored `audio-review/` output). It found
the corpus to be acoustically healthy but with systematic edge silence
beyond Phase 3's target. That finding is **out of scope** for Phase 13
(no re-baking) but recorded for a follow-up pass if pronunciation
correctness ever motivates a full re-bake.

## Success criteria (mirroring ROADMAP.md Phase 13)

1. `tools/tts/technical_review.py` exists, runs ffprobe + ebur128 on
   every manifest entry, writes per-clip pass/fail to
   `tools/tts/last-technical-review.json`.
2. Every clip currently in `assets/audio/` passes (or failures are
   surfaced for re-bake).
3. `reviewed.yaml` auto-populated with `technically_reviewed: true` for
   each passing clip; existing `reviewed: true` entries preserved.
4. `lib/gen/audio_manifest.g.dart` regenerated and committed; `flutter
   test` 455+ pass; `flutter run` produces audio when tapping
   letters/numbers (verifiable manually).
5. 03/06/08-VERIFICATION.md updated to clarify that pronunciation
   review (native-speaker) is still pending.
