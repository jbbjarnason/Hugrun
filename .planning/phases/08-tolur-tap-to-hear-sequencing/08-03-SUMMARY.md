---
phase: 08
plan: 08-03
title: Sequencing Activity (Drag-to-Order)
status: complete
date: 2026-05-02
tags: [phase-8, tolur, sequencing, drag-and-drop, tdd]
metrics:
  tests-added: 18   # 11 SequencingRound model + 7 SequencingActivity widget
  files-created: 3  # SequencingRound, SequencingActivity, sequencing_providers
---

# Phase 8 Plan 03: Sequencing Activity

The drag-to-order Tölur surface. Pure-Dart round model + Flutter widget
with `Draggable` / `DragTarget`. Covers NUM-06.

## Workstream

C from `08-CONTEXT.md`.

## TDD cycle

| Cycle | Subject | Commit |
|-------|---------|--------|
| RED   | `SequencingRound` model + Generator tests | `5aadd45` |
| GREEN | Pure-Dart implementation | `12c0233` |
| RED   | `SequencingActivity` widget tests | `58d00be` |
| GREEN | Activity widget + providers | `f6f9041` |

## What was built

### `lib/core/numbers/sequencing_round.dart`
- `SequencingRound` value class: `targetSequence` (5 contiguous ascending
  ints in 1..10), `scrambledOrder` (4 or 5 entries), optional
  `missingPosition`. Defensive asserting factory rejects invalid shapes.
- `isSort` / `isFillMissing` / `missingValue` accessors.
- `SequencingRoundGenerator` with seeded `Random`. `generate()` picks a
  random run start in 1..6, ~50/50 between Sort / FillMissing variants,
  then shuffles. Pure Dart per Phase 8 D-04.

### `lib/features/tolur/sequencing/sequencing_activity.dart`
- `SequencingActivity` ConsumerStatefulWidget. Top half = 5
  `_TargetSlot` `DragTarget`s (some pre-filled in FillMissing variant);
  bottom half = `_SourceChip` `Draggable` source row.
- `_TargetSlot.onWillAcceptWithDetails` is the soft-acceptance gate
  (D-12) — wrong values are silently rejected; correct values get
  accepted into `_filled`. No audio penalty on rejection.
- `_isComplete` checks `_filled` matches `targetSequence` exactly. On
  completion: `MatchingCelebration` overlay (reused from Phase 5),
  auto-advance Timer at `MatchingCelebration.duration` (1.5s).
- `debugCompleteRound` + `debugRejectDrop` test escape hatches per the
  Phase 5/6 pattern (DragTarget gestures are flaky in widget-test mode).

### `lib/features/tolur/sequencing/sequencing_providers.dart`
- `sequencingRoundGeneratorProvider: Provider<SequencingRoundGenerator>`.
  Tests override with a stub that returns deterministic rounds.

## Tests

11 model tests:
- S1..S6: model invariants (Sort vs FillMissing, equality, defensive
  asserts on length / range / contiguity).
- G1..G5: generator invariants (5 numerals in 1..10 contiguous,
  determinism with seed, scramble = permutation of target / target-minus-
  one, both variants appear over 50 rounds, scramble != target most of
  the time).

7 widget tests:
- Q1..Q2: layout for Sort + FillMissing variants.
- Q3: completion shows celebration.
- Q4: no auto-narration on round start.
- Q5: D-12 wrong drops are silent (zero `playCalls` / zero `stopCalls`).
- Q6: NUM-08 no fail icons.
- Q7: auto-advance after celebration duration.

`flutter test test/core/numbers/sequencing_round_test.dart
test/features/tolur/sequencing/` → all 18 pass.

## Reuse posture

- `MatchingCelebration` from Phase 5 — reused directly (single Icon
  check_circle_rounded; D-13).
- `paletteForIndex` from Phase 4 for tile colors.
- `MatchingCelebration.duration` = 1.5s — adopted as the auto-advance
  cadence so behavior is consistent across activities.

## Deviations from plan

1. **`debugCompleteRound` / `debugRejectDrop` escape hatches** — same
   posture as Phase 5/6. DragTarget gestures in `flutter_test` are flaky;
   integration_test exercises end-to-end. Documented in the activity's
   header comment.

2. **`_SourceRow` dual rendering branch** (Rule 1 — bug discovered during
   widget test Q2). Initial implementation rendered source chips from
   `round.scrambledOrder` regardless of variant; for FillMissing this
   meant the missing value (3) was never in the source row. Fixed to
   branch: Sort uses `scrambledOrder`; FillMissing uses
   `available.toList()..sort()` (sole entry = missing value).

## Self-Check: PASSED

- [x] `lib/core/numbers/sequencing_round.dart` exists, pure Dart
- [x] `lib/features/tolur/sequencing/{sequencing_activity,sequencing_providers}.dart` exist
- [x] All 18 plan tests pass
- [x] `tools/check-domain-purity.sh` passes (sequencing_round.dart has no
      Flutter import)
- [x] No new banned packages
