---
phase: 09
plan: 04
title: TolurMode Activity Rotation + Integration
status: complete
date: 2026-05-02
tags: [phase-9, tolur, mode-rotation, integration, tdd]
requirements_satisfied:
  - NUM-04
  - NUM-05
  - NUM-07
metrics:
  tests-added: 3 + integration update
  files-created: 2
  flutter-analyze: clean (modulo documented riverpod_lint warnings)
  flutter-test-pass: 114 / 114 (Phase 8+9 tolur + numbers tests)
  flutter-build-apk-debug: passes
---

# Plan 09-04: Tölur Activity Rotation + Integration — Summary

Per CONTEXT D-15, `TolurMode` is reshaped from `{tapToHear, sequence}`
(Phase 8) to `{tapToHear, activity}`. The `activity` mode renders an
`ActivityRotator` that picks one of the 4 numeracy activities
(Sequencing, Correspondence, Subitizing, Addition) per mount —
random uniform.

## Files created / modified

### Created

- `lib/features/tolur/activity_rotator.dart` (94 lines)
  - `TolurActivity` enum (sequence, correspondence, subitizing, addition)
  - `ActivityRotator(seed?)` widget; switches on `_current`
  - `ActivityRotatorState.debugCurrent`, `debugAdvance()` test affordances
- `test/features/tolur/activity_rotator_test.dart` (3 tests)
- `integration_test/tolur_numeracy_flow_test.dart` (1 test, device-only)

### Modified

- `lib/features/tolur/tolur_mode.dart` — `enum TolurMode {tapToHear, activity}`
- `lib/features/tolur/widgets/tolur_mode_toggle.dart` — icon mapping
  for `activity` = `Icons.category_outlined`
- `lib/features/tolur/tolur_room.dart` — `TolurMode.activity → ActivityRotator()`
- `test/features/tolur/widgets/tolur_mode_toggle_test.dart` — TM1, TM1b, TM3 updated
- `test/features/tolur/tolur_room_test.dart` — TR2, TR3 updated
- `integration_test/tolur_flow_test.dart` — assert ActivityRotator
  after toggle hold; sequence-specific debug drive only when rotator
  lands on it

## Commits

- `b01a144` test(09-04) RED — rotator + 2-mode TolurMode tests
- `bceff5b` feat(09-04) GREEN — TolurMode.activity + ActivityRotator
- `5e822e5` test(09-04) — integration test updates + new numeracy flow

## Quality gate

- [x] `TolurMode.values == [tapToHear, activity]` (TM1)
- [x] ActivityRotator picks one of the 4 activity widgets each mount (AR1)
- [x] All 4 activity types reachable across many `debugAdvance()` calls
      (AR2)
- [x] TolurRoom correctly mounts ActivityRotator for `TolurMode.activity`
      (TR3)
- [x] Integration test covers tap-to-hear → activity rotation → return
      flow without exceptions

## Decisions exercised

D-15 (2 modes; Activity rotates internally — chosen over the 5-mode
alternative D-14), D-16 (random selection), D-17 (widget tests for
each activity, mocked AudioEngine), D-18 (integration test exercises
rotation).

## Deviations from plan

**1. AR2 test reshape (initially flaky).** The first version of the
"all 4 activities appear" test re-pumped a fresh ProviderScope per
seed iteration; pending Timers from previous iterations contaminated
subsequent finds. Reshaped to mount the rotator once + drive
`debugAdvance()` repeatedly + observe `debugCurrent`. Same coverage,
deterministic.

**2. Phase 8 integration test rather than Phase-9-only.** Per scope,
Plan 09-04 produces a new `tolur_numeracy_flow_test.dart` *and* updates
the existing `tolur_flow_test.dart` to reflect the 2-mode change. The
Phase 8 test now contains a conditional sequencing-specific
debugCompleteRound block — runs only if the rotator lands on Sequence,
otherwise just confirms ActivityRotator mounted.
