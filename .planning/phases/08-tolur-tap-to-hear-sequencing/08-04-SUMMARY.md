---
phase: 08
plan: 08-04
title: TolurMode Toggle + Integration Test
status: complete
date: 2026-05-02
tags: [phase-8, tolur, mode-toggle, integration-test]
metrics:
  tests-added: 11   # 8 toggle widget + 3 room toggle integration
  integration-test-added: 1
  files-created: 3  # tolur_mode.dart, tolur_mode_toggle.dart, tolur_flow_test.dart
---

# Phase 8 Plan 04: TolurMode Toggle + Integration Test

Two-mode (TapToHear / Sequence) toggle + end-to-end integration test
covering the full Tölur flow.

## Workstreams

D + E from `08-CONTEXT.md`.

## TDD cycle

| Cycle | Subject | Commit |
|-------|---------|--------|
| RED   | TolurModeToggle widget tests + room toggle tests + enum | `<commit>` |
| GREEN | TolurModeToggle widget + TolurRoom Stack rewrite | `<commit>` |
| —     | Integration test (compile-clean) | `<commit>` |

## What was built

### `lib/features/tolur/tolur_mode.dart`
- `TolurMode { tapToHear, sequence }` enum.
- `TolurModeToggleExt.next` cycles `tapToHear → sequence → tapToHear`.

### `lib/features/tolur/widgets/tolur_mode_toggle.dart`
- `TolurModeToggle` StatefulWidget. Mirror of Phase 5/6's
  `StafirModeToggle`. Reuses `ParentGateController` from Phase 1 for the
  3-second hold state machine. Two distinct icons:
  `Icons.image_outlined` (tapToHear) / `Icons.format_list_numbered`
  (sequence). 48×48 logical-px footprint.

### `lib/features/tolur/tolur_room.dart`
- Final shape (replaces the Plan 08-02 mid-state). `Stack` body switches
  on `_mode`: NumberGrid for `tapToHear`, SequencingActivity for
  `sequence`. `TolurModeToggle` lives top-right. `debugSetMode` /
  `debugMode` for tests.

### `integration_test/tolur_flow_test.dart`
- End-to-end scenario:
  1. Boot HugrunApp with `FakeAudioEngine` + stub
     `SequencingRoundGenerator`.
  2. Tap the home Tölur button.
  3. Tap digit 3 — verify `engine.playCalls.last ==
     UtteranceKey.numberThreeMasc`.
  4. Hold the toggle 3.2s — body swaps to `SequencingActivity`.
  5. `state.debugCompleteRound()` → celebration overlay visible →
     auto-advance after `MatchingCelebration.duration`.
  6. Hold toggle 3.2s — back to `NumberGrid`.
  - Asserts no exceptions, no Timer leaks.
- Compile-clean (`flutter analyze` reports no issues on the file). Runs
  on a real device binding only — same posture as Phase 5/6 integration
  tests.

## Tests

8 toggle widget tests (TM1..TM8):
- TM1, TM1b: enum + `next` extension.
- TM2: single Icon, zero Text.
- TM3: distinct icons per mode.
- TM4: <3s hold doesn't toggle.
- TM5: 3s+ hold toggles once.
- TM6: pointer cancel mid-hold aborts.
- TM7: ≤64×64 footprint.
- TM8: hold ring visible only while holding.

3 room-toggle widget tests (TR1..TR3):
- TR1: TolurRoom hosts a TolurModeToggle.
- TR2: defaults to TapToHear (NumberGrid visible).
- TR3: `debugSetMode(sequence)` swaps body to SequencingActivity.

## Reuse posture

- `ParentGateController` (Phase 1) — imported and used directly.
- `StafirModeToggle` pattern — copied widget shape, NOT extracted into a
  shared base. Per the same rationale as `LetterTile` / `NumberTile`:
  evolution stays per-room.

## Deviations from plan

1. **One commit accidentally pulled in Phase 7 files** (caught + fixed).
   The first attempt at the RED commit included
   `lib/features/stafir/tracing/*` and modified
   `test/features/stafir/tracing/tracing_activity_test.dart` (Phase 7's
   territory). Soft-reset and recommitted with explicit per-file
   `git add`. Future commits stage files individually.

## Self-Check: PASSED

- [x] `lib/features/tolur/tolur_mode.dart` exists
- [x] `lib/features/tolur/widgets/tolur_mode_toggle.dart` exists
- [x] `lib/features/tolur/tolur_room.dart` final form (mode switch, toggle)
- [x] `integration_test/tolur_flow_test.dart` exists, `flutter analyze`
      reports no issues
- [x] All 11 plan tests pass
- [x] `flutter build apk --debug` succeeds
