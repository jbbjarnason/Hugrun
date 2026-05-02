---
phase: 09
plan: 02
title: Subitizing Activity (NUM-05)
status: complete
date: 2026-05-02
tags: [phase-9, tolur, subitizing, num-05, tdd]
requirements_satisfied:
  - NUM-05   # subitizing 1-5 with varied arrangements
metrics:
  tests-added: 18    # 12 model + 6 widget
  files-created: 4
  flutter-analyze: clean (modulo documented riverpod_lint warnings)
  domain-purity: passes
---

# Plan 09-02: Subitizing Activity — Summary

Pure-Dart `SubitizingRound` + `DotArrangement` enum + `DotPosition` and
the `SubitizingActivity` widget. Three-phase activity:

1. **Flash** (1.5s default): renders 1..5 dots in dice/line/random/finger arrangement
2. **Question**: dots disappear, 5 numeral options 1..5 shown
3. **Celebration**: correct tap → MatchingCelebration overlay + auto-advance

## Files created

- `lib/core/numbers/subitizing_round.dart` (243 lines)
  - `DotArrangement` enum (dice, line, random, finger — D-06)
  - `kSubitizingFlashDuration` = 1.5s (D-08)
  - `DotPosition` (normalized x,y in [0..1])
  - `SubitizingRound` with asserting factory
  - `SubitizingRoundGenerator(seed)` rotates arrangements (D-07)
- `lib/features/tolur/subitizing/subitizing_activity.dart` (217 lines)
- `lib/features/tolur/subitizing/subitizing_providers.dart`
- `test/core/numbers/subitizing_round_test.dart` (12 tests)
- `test/features/tolur/subitizing/subitizing_activity_test.dart` (6 tests)

## Commits

- `d2b08ad` test(09-02) RED — model tests
- `ea6cf06` feat(09-02) GREEN — model + 4 arrangement layouts
- `1477c11` test(09-02) RED — widget tests
- `23643d3` feat(09-02) GREEN — SubitizingActivity widget

## Quality gate

- [x] Pure Dart in `lib/core/numbers/`
- [x] All 4 dot arrangements (dice, line, random, finger) reachable;
      generator round-robins through DotArrangement.values to ensure
      variety (D-07)
- [x] Wrong tap = silent no-op (D-09)
- [x] Correct tap = celebration + auto-advance (D-13)
- [x] No fail UI

## Decisions exercised

D-06 (round flashes dots, then 5 numeral options), D-07 (arrangement
rotation), D-08 (1.5s flash duration), D-09 (silent wrong tap).

## Deviations from plan

None substantive. The `_DotFlashArea` math constrains the surface to
70% of width × 85% of height to avoid edge clipping for the random
arrangement. Documented inline in the widget.
