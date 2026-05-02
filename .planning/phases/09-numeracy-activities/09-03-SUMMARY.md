---
phase: 09
plan: 03
title: Addition Activity (NUM-07)
status: complete
date: 2026-05-02
tags: [phase-9, tolur, addition, num-07, tdd]
requirements_satisfied:
  - NUM-07   # addition with objects, no `+` symbol
metrics:
  tests-added: 15    # 8 model + 7 widget
  files-created: 4
  flutter-analyze: clean
  domain-purity: passes
---

# Plan 09-03: Addition with Objects — Summary

Pure-Dart `AdditionRound` (addend1, addend2, noun) and the
`AdditionActivity` widget. Two object groups appear side-by-side
(NO `+` symbol, NO operator glyph anywhere — D-12), child taps the
correct total numeral from 5 options.

## Files created

- `lib/core/numbers/addition_round.dart` (110 lines)
  - `AdditionRound` with asserting factory (sum ≤ 5 per D-11)
  - `AdditionRoundGenerator(seed)` picks total 2..5, splits into valid
    addend pair, draws noun from `kCorrespondenceNouns`
  - Computed `totalValue` getter
- `lib/features/tolur/addition/addition_activity.dart` (303 lines)
- `lib/features/tolur/addition/addition_providers.dart`
- `test/core/numbers/addition_round_test.dart` (8 tests)
- `test/features/tolur/addition/addition_activity_test.dart` (7 tests)

## Commits

- `37e4f23` test(09-03) RED — model tests
- `f76a0ec` feat(09-03) GREEN — model + generator
- `d498321` test(09-03) RED — widget tests
- `b3bfc75` feat(09-03) GREEN — AdditionActivity widget

## Quality gate

- [x] Pure Dart in `lib/core/numbers/`
- [x] **NO `+` symbol or Icons.add anywhere in widget tree (AD1 test
      pins the invariant per D-12)**
- [x] addend1 + addend2 noun copies render in two distinct groups
      keyed `add-group1-N` / `add-group2-N`
- [x] 5 numeral options (1..5) rendered with keys `add-option-N`
- [x] Wrong tap = silent (D-13)
- [x] Correct tap = celebration + auto-advance
- [x] No fail UI; no narration audio fired (D-20: no new manifest entries)

## Decisions exercised

D-10 (addend1 + addend2 + noun model), D-11 (sum ≤ 5), D-12 (NO `+`
symbol — explicitly asserted in test AD1), D-13 (silent wrong tap +
celebrate correct).

## Deviations from plan

**1. [Rule 3 - Blocking] No round-entry narration.** Plan called for
"narrates 'Tveir hundar koma. Einn hundur kemur til viðbótar.'" Per
CONTEXT D-20 ("no new manifest entries needed"), Phase 9 ships without
the round-entry narration audio. The activity is silently functional;
when Phase 3's audio pipeline regenerates with the addition narration
keys, AdditionActivity can wire `audioEngine.play(narrationKey)` in
`_generateRound()` without a structural change. Documented inline.
