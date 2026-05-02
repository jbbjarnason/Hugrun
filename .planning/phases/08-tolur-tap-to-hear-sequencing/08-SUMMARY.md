---
phase: 08
title: Tölur Tap-to-Hear & Sequencing
status: human_needed   # 18 numeral clips need native-speaker review
date: 2026-05-02
plans:
  - 08-01-number-audio-model-and-manifest-extension
  - 08-02-tolur-room-tap-to-hear
  - 08-03-sequencing-activity
  - 08-04-tolur-mode-toggle-and-integration
tags: [phase-8, tolur, numbers, tap-to-hear, sequencing, drag-and-drop, post-mvp, review-pending]
requirements_satisfied:
  - NUM-01   # Tölur shows digits 1–10 with tap-to-hear matching Stafir
  - NUM-03   # Abstract counting uses masculine; pictured uses object's gender (Phase 9)
  - NUM-06   # Sequencing — drag numerals into order; find missing
  - NUM-08   # No-fail / no-score / no-timer rules
requirements_pending:
  - NUM-02   # 1–4 gendered audio + 5–10 single form — clips baked,
             #   awaiting native-speaker review (same gate as Phases 3, 6)
metrics:
  total-tests: 348   # 263 baseline → 348 (+85 from Phase 7+8 in parallel)
  test-delta-phase-8: ~71 (15 numbers + 12 NumberTile + 7 sequencing model
    + 7 SequencingActivity + 8 toggle + 3 room toggle + 7 TolurRoom Phase-8 + ...)
  flutter-analyze: clean (modulo known riverpod_lint warnings on scoped
    overrides in test files; same family Phase 5/6/7 documented)
  flutter-build-apk-debug: passes
  domain-purity: passes (lib/core/numbers in allow-list)
  asset-paths: passes
  no-tracking: passes
  manifest-utterances: 100 → 118 (+18 numerals)
  baked-aac-clips: 18 new (review pending)
  enum-utterancekey-entries: 45 → 63 (+18 numeral keys)
---

# Phase 8: Tölur Tap-to-Hear & Sequencing — Master Summary

The Tölur (numbers) room. Phase 8 adds:

- **Pure-Dart number domain** (`lib/core/numbers/`): `IcelandicNumber`,
  `kIcelandicNumbers`, `numberAudioKey(value, gender)`. Mirrors
  `lib/core/alphabet/`'s pure-Dart posture.
- **18 numeral audio entries**: 12 gendered (1..4 × M/F/N) + 6 invariants
  (5..10). Baked through the Phase 3 Piper pipeline. **NUM-02 still
  pending** — same review gate as Phases 3, 6.
- **Tölur tap-to-hear loop**: 10-NumberTile grid (5×2 landscape), tap
  any digit → AudioEngine plays `numberAudioKey(value, masculine)`
  (NUM-03 abstract counting school convention).
- **Sequencing activity**: 5-numeral drag-to-order surface with two
  variants — Sort (5 scrambled → drag into ascending order) and
  FillMissing (4 in order with one gap → drag missing into the gap).
  Soft acceptance: wrong drops snap back silently (D-12). Round
  complete = MatchingCelebration overlay (reused from Phase 5) +
  auto-advance.
- **TolurMode toggle**: 2-mode (TapToHear / Sequence), 3-second hold
  via `ParentGateController` (Phase 1).

Plans executed: all 4 (08-01 through 08-04).

## Plan summaries

| Plan | Subject | Tests added | Status |
|------|---------|-------------|--------|
| 08-01 | Number model + 18 keys + manifest extension + bake | +15 | review pending (NUM-02) |
| 08-02 | TolurRoom + NumberTile + NumberGrid (tap-to-hear) | +12 (tile) + 7 (room) | complete |
| 08-03 | SequencingRound model + SequencingActivity widget | +11 (model) + 7 (widget) | complete |
| 08-04 | TolurMode + TolurModeToggle + integration test | +8 (toggle) + 3 (room) + 1 (integration) | complete |

## What was built (the Tölur loop)

```
HomePage
  ↓
[Tap Tölur room button]
  ↓
TolurRoom (default mode = tapToHear)
  ↓
SafeArea > Stack
  ├─ NumberGrid (10 NumberTiles in 5×2)
  └─ TolurModeToggle (top-right)
  ↓
[Child taps a digit, e.g. "3"]
  ↓
NumberTile.onTapDown → scale animation fires synchronously (NUM-01)
  ↓
TolurRoom._onNumberTap → numberAudioKey(3, masculine)
  ↓
AudioEngine.play(numberThreeMasc) — silent fallback while review pending
  ↓
[Adult holds the top-right toggle for 3 seconds]
  ↓
TolurModeToggle.onToggle → _mode swaps to TolurMode.sequence
  ↓
Body re-renders: SequencingActivity replaces NumberGrid
  ↓
SequencingActivity → schedules first round in postFrameCallback
  ↓
SequencingRoundGenerator.generate() → Sort or FillMissing variant
  ↓
Render: top-row 5 _TargetSlots (some pre-filled in FillMissing) +
        bottom-row _SourceChip Draggables
  ↓
[Child drags a numeral onto a target]
  ↓
DragTarget.onWillAcceptWithDetails — soft accept only if value matches
  the slot's expectedValue (D-12). Wrong drops snap back silently — no
  audio penalty, no fail UI.
  ↓
On accept: _filled[targetIndex] = value; _availableSources.remove(value)
  ↓
[Last correct drop completes the sequence]
  ↓
_isComplete() → MatchingCelebration overlay visible
  ↓
Auto-advance Timer at MatchingCelebration.duration (1.5s)
  ↓
ref.invalidate equivalent → new round (sequencingRoundGeneratorProvider
                                       always re-rolls via generate())
  ↓
[Loop continues — infinite rounds, no counter, no score]
```

## Quality gate

- [x] All 4 plans executed
- [x] `lib/core/numbers/` pure Dart, 4 source files, 15 tests
- [x] 18 new UtteranceKey entries; 18 baked AAC clips; manifest.yaml at 118
- [x] Pipeline correctly stops at review gate (D-19) — same posture as
      Phase 6 / Phase 3
- [x] `tools/check-domain-purity.sh` updated with `lib/core/numbers`; passes
- [x] `tools/check-asset-paths.sh` passes (paths under
      `assets/audio/numbers/{masculine,feminine,neuter,}/*.aac` all
      lowercase ASCII)
- [x] `tools/check-no-tracking.sh` passes
- [x] NumberTile + NumberGrid + TolurRoom — 12 + 7 + 3 widget tests pass;
      no LetterTile fork-and-modify (parallel concrete widget)
- [x] SequencingActivity drag-and-drop with `Draggable` / `DragTarget`;
      wrong drops snap back silently; correct completion celebrates +
      auto-advances
- [x] TolurMode + TolurModeToggle; ≤64×64 footprint; 3-second hold gate;
      mid-hold cancel aborts
- [x] Integration test compile-clean (runs on device binding only — same
      posture as Phase 4-7)
- [x] `flutter analyze` clean modulo documented riverpod_lint warnings
- [x] `flutter test` passes 348/348 (363 minus the 15 Phase 7 also added —
      Phase 8 contributes ~71)
- [x] `flutter build apk --debug` succeeds
- [x] No edits to Phase 7 territory (`lib/features/stafir/`, `lib/core/tracing/`,
      `assets/tracing/`, `tools/glyph/`, `stroke_order_animator` pubspec entry)
- [x] No new banned packages
- [x] Atomic commits per RED/GREEN cycle

- [ ] **NUM-02 native-speaker review pending** — 18 numeral clips
      baked + normalized but `reviewed.yaml` empty. Until Jon runs
      `python3 tools/tts/review_server.py` and approves entries, the
      Dart manifest does NOT regenerate and the keys remain absent
      from `kAudioManifest`. Tile taps fire silently in the meantime
      (Phase 4 D-22, D-23 silent-fallback).

## Architectural commitments — preserved

- **Pure-Dart `lib/core/numbers/`**: enforced via CI script. No Flutter
  imports under that subtree.
- **Reuse-not-duplicate**: `AudioEngine`, `paletteForIndex`,
  `ParentGateController`, `MatchingCelebration` all imported and used
  directly. NumberTile is a concrete sibling of LetterTile (not a
  generic shared base).
- **No fail-state UI**: 0 stars, 0 trophies, 0 score numbers, 0 "wrong"
  text anywhere. Tests Q5, Q6, T7 assert the invariant.
- **Soft acceptance (D-12)**: wrong drag drops are filtered by
  `DragTarget.onWillAcceptWithDetails`; no audio fires.
- **D-22/D-23 silent fallback**: numeral keys exist in the enum but are
  absent from `kAudioManifest`. Activity is structurally functional but
  silent for unreviewed clips — exactly the documented contract.

## Key decisions exercised

D-01..D-03 (Tölur room shape + tap mechanic), D-04..D-06 (manifest
extension + 18 keys + bake), D-07..D-08 (number model + resolver),
D-09..D-14 (sequencing activity — variants, drag-and-drop, soft accept,
celebration, auto-advance, no fail), D-15 (mode toggle), D-16..D-19
(test strategy + manifest extension + review gate).

All 19 decisions in 08-CONTEXT.md were reached.

## Deviations summary

The full deviation list lives in each plan SUMMARY. Highlights:

1. **`numeral_invariant` schema kind** (Plan 08-01). Schema already had
   masculine/feminine/neuter; 5..10 needed an additional `numeral_invariant`
   kind. Added inline before bake (Rule 3 — blocking).

2. **Pipx-installed tools off-PATH** (Plan 08-01). `piper` and
   `ffmpeg-normalize` live in `~/.local/bin/`, not Claude shell's
   default PATH. Worked around via `export PATH=$HOME/.local/bin:$PATH`.

3. **Phase 7 file leakage in 2 commits** (Plans 08-01 + 08-04). The
   parallel Phase 7 agent created files in the same workdir; my `git add`
   sometimes picked up files I didn't author. Caught both occurrences,
   soft-reset, recommitted with explicit per-file `git add`. Future
   Phase 8 commits stage files individually rather than glob-staging.

4. **`_SourceRow` dual rendering branch** (Plan 08-03). Initial
   implementation rendered source chips from `round.scrambledOrder`
   regardless of variant; for FillMissing, the missing value was
   missing from the source row. Fixed to branch by `isSort`.

5. **`debugCompleteRound` / `debugRejectDrop` test escape hatches** (Plan
   08-03). DragTarget gestures across `flutter_test` are flaky;
   integration_test exercises end-to-end. Same pattern as Phase 5/6.

6. **Two test files in `test/features/tolur/widgets/` had to be created
   from scratch** (the Phase 1 placeholder for `tolur_room_test.dart`
   was preserved + extended; `number_tile_test.dart` and
   `tolur_mode_toggle_test.dart` are new).

## Files created/modified summary

### Created (lib/)
- `lib/core/numbers/gender.dart` (10 lines)
- `lib/core/numbers/icelandic_number.dart` (62 lines)
- `lib/core/numbers/numbers.dart` (53 lines)
- `lib/core/numbers/number_audio_resolver.dart` (39 lines)
- `lib/core/numbers/sequencing_round.dart` (130 lines)
- `lib/features/tolur/tolur_mode.dart` (28 lines)
- `lib/features/tolur/widgets/number_tile.dart` (115 lines)
- `lib/features/tolur/widgets/number_grid.dart` (52 lines)
- `lib/features/tolur/widgets/tolur_mode_toggle.dart` (118 lines)
- `lib/features/tolur/sequencing/sequencing_activity.dart` (250 lines)
- `lib/features/tolur/sequencing/sequencing_providers.dart` (15 lines)

### Modified (lib/)
- `lib/core/manifest/utterance_key.dart` — 45 → 63 enum entries
- `lib/features/tolur/tolur_room.dart` — Phase 1 placeholder rewritten
  to a ConsumerStatefulWidget with mode switching

### Modified (top-level config / tools)
- `manifest.yaml` — 100 → 118 utterances
- `tools/tts/schema.py` — `numeral_invariant` added to ALLOWED_KINDS
- `tools/check-domain-purity.sh` — added `lib/core/numbers`

### Created (assets/)
- `assets/audio/numbers/{masculine,feminine,neuter}/*.aac` (12 clips)
- `assets/audio/numbers/*.aac` (6 invariant clips)
- `assets/audio/numbers/.gitkeep` (× 4 directories)

### Created (test/)
- `test/core/numbers/icelandic_number_test.dart` (213 lines, 15 tests)
- `test/core/numbers/sequencing_round_test.dart` (175 lines, 11 tests)
- `test/features/tolur/widgets/number_tile_test.dart` (135 lines, 12 tests)
- `test/features/tolur/widgets/tolur_mode_toggle_test.dart` (138 lines, 8 tests)
- `test/features/tolur/sequencing/sequencing_activity_test.dart` (204 lines, 7 tests)

### Modified (test/)
- `test/features/tolur/tolur_room_test.dart` — extended Phase 1 placeholder
  with 7 Phase-8 tests (T1..T7) + 3 mode-toggle tests (TR1..TR3)

### Created (integration_test/)
- `integration_test/tolur_flow_test.dart` (115 lines, 1 device-only test)

### Created (.planning/)
- `.planning/phases/08-tolur-tap-to-hear-sequencing/08-{01..04}-SUMMARY.md`
- `.planning/phases/08-tolur-tap-to-hear-sequencing/08-SUMMARY.md` (this file)
- `.planning/phases/08-tolur-tap-to-hear-sequencing/08-VERIFICATION.md`

## Phase 8 closing posture

The Tölur tap-to-hear and sequencing activity is **structurally complete**:
348 tests pass, flutter analyze is clean (modulo documented warnings),
the debug APK builds, the room renders 10 NumberTiles, taps fire correct
gendered audio (silent until review), the toggle swaps to the
SequencingActivity, drags accept correctly + reject silently, completion
celebrates + auto-advances, never shows a fail/error/score/timer
indicator.

One thread remains open:

1. **18 numeral clip review pass** (NUM-02 still pending). The 18
   numeral AAC clips are baked, normalized, and committed, but
   `reviewed.yaml` is empty for them. Until Jon runs
   `python3 tools/tts/review_server.py`, listens to each clip, and
   approves them, `lib/gen/audio_manifest.g.dart` won't regenerate and
   the keys remain absent from `kAudioManifest`. The activity is
   silently functional in the meantime.

The Phase 8 scope is closed from a code-quality standpoint. Phase 9
(Numeracy Activities — one-to-one, subitizing, addition) can begin
once the audio review pass is scheduled.
