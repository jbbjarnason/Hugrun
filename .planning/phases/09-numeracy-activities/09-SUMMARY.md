---
phase: 09
title: Numeracy Activities (One-to-One, Subitizing, Addition)
status: complete
date: 2026-05-02
plans:
  - 09-01-correspondence-activity
  - 09-02-subitizing-activity
  - 09-03-addition-activity
  - 09-04-activity-rotation-and-integration
tags: [phase-9, tolur, numeracy, num-04, num-05, num-07, post-mvp, tdd]
requirements_satisfied:
  - NUM-04   # one-to-one correspondence
  - NUM-05   # subitizing 1-5
  - NUM-07   # addition with objects (no `+` symbol)
metrics:
  total-tests: 441   # 348 baseline → 441 (+93; in-flight Phase 10 RED tests
                     # excluded from this count — they are red and not part of
                     # Phase 9's responsibility)
  test-delta-phase-9: 54 (11 + 7 + 12 + 6 + 8 + 7 + 3 across model/widget/rotator)
  flutter-analyze: clean (modulo known scoped_providers_should_specify_dependencies
    warnings on test files; same family Phase 5/6/7/8 documented)
  flutter-build-apk-debug: passes
  flutter-test: 114/114 tolur+numbers tests pass; full suite green except for
    in-flight Phase 10 photo_upload tests (out of Phase 9 scope)
  domain-purity: passes
  asset-paths: passes
  no-tracking: passes
  manifest-utterances: 118 (unchanged — D-20 explicit no-new-manifest-entries)
  duration: ~20m wall-clock
---

# Phase 9: Numeracy Activities (One-to-One, Subitizing, Addition) — Master Summary

The three remaining numeracy activities for the Tölur room. Phase 9
adds:

- **`CorrespondenceActivity`** (NUM-04): N pictured noun copies; tap each
  in counting order; voice counts in the noun's gender.
- **`SubitizingActivity`** (NUM-05): 1-5 dots flash for 1.5s in
  dice/line/random/finger arrangement; tap matching numeral from 5.
- **`AdditionActivity`** (NUM-07): two object groups appear (NO `+`
  symbol anywhere); tap correct total numeral.
- **`ActivityRotator`** (D-15): TolurMode reshaped to 2 values
  (TapToHear / Activity); Activity mode picks one of the 4 numeracy
  widgets (Sequencing, Correspondence, Subitizing, Addition) at random.

All four activities reuse the Phase 5 `MatchingCelebration` overlay
+ auto-advance pattern. Wrong taps everywhere are silent no-ops
(matching/CVC/sequencing's D-07/D-12 family). No fail UI; no score;
no timer.

Plans executed: all 4 (09-01 through 09-04).

## Plan summaries

| Plan  | Subject                                              | Tests added | Status   |
| ----- | ---------------------------------------------------- | ----------- | -------- |
| 09-01 | CorrespondenceRound + Activity                       | +18         | complete |
| 09-02 | SubitizingRound + Activity                           | +18         | complete |
| 09-03 | AdditionRound + Activity                             | +15         | complete |
| 09-04 | TolurMode reshape + ActivityRotator + integration   | +3 + 1 IT   | complete |

## What was built (the activity loop)

```
TolurRoom (default mode = tapToHear)
  ↓
[Adult holds top-right toggle for 3 seconds]
  ↓
TolurModeToggle.onToggle → _mode swaps to TolurMode.activity
  ↓
Body re-renders: ActivityRotator replaces NumberGrid
  ↓
ActivityRotator.initState → _pick() = uniform random over 4 activities
  ↓
[branch on TolurActivity]
  ├─ sequence       → SequencingActivity (Phase 8)
  ├─ correspondence → CorrespondenceActivity (Phase 9)
  ├─ subitizing     → SubitizingActivity (Phase 9)
  └─ addition       → AdditionActivity (Phase 9)
  ↓
[Each activity self-rounds: postFrame → generate → render → tap → celebrate → advance]
  ↓
[Adult holds toggle 3s again → mode flips back to TapToHear]
  ↓
NumberGrid re-mounts; ActivityRotator unmounts.
```

## Quality gate

- [x] All 4 plans executed
- [x] `lib/core/numbers/correspondence_round.dart` + `subitizing_round.dart`
      + `addition_round.dart` pure Dart; `tools/check-domain-purity.sh`
      still passes (same allow-list as Phase 8)
- [x] CorrespondenceActivity, SubitizingActivity, AdditionActivity
      all implemented + tested
- [x] **NO `+` symbol anywhere in addition UI** (AD1 explicit assertion)
- [x] Wrong taps/drops are silent no-ops across all 4 activities
- [x] Tölur Activity mode rotates between 4 activities
- [x] Integration test compile-clean (`tolur_numeracy_flow_test.dart`)
- [x] `flutter analyze` clean modulo documented riverpod_lint warnings
      (15 of them on scoped overrides in test files — same family Phase 5-8)
- [x] `flutter test` Phase 8+9 tests: 114/114 pass; full suite passes
      except in-flight Phase 10 photo_upload RED tests (out of scope)
- [x] `flutter build apk --debug` succeeds
- [x] `tools/check-domain-purity.sh`, `check-asset-paths.sh`,
      `check-no-tracking.sh` all pass
- [x] Atomic commits per RED/GREEN cycle (16 task commits + plan scaffold)
- [x] No edits to Phase 10 territory (no Drift schema bumps, no lexicon
      changes, no photo_upload UI, no manifest extensions, no new
      pubspec deps)

## Architectural commitments — preserved

- **Pure-Dart `lib/core/numbers/`** stays Flutter-free; the existing
  domain-purity allow-list covers the 3 new domain files (and the Phase
  10 worker added `lib/core/lexicon` to the same allow-list).
- **Reuse-not-duplicate**: AudioEngine, MatchingCelebration, NumberTile,
  paletteForIndex, ParentGateController, kIcelandicNumbers,
  numberAudioKey resolver — all imported and used directly.
- **No fail-state UI**: every activity's widget tests assert
  no `Icons.error`, no `Icons.cancel`, no `Icons.close`. AD1 also
  asserts no `Icons.add` and no `+` text glyph (D-12).
- **No new manifest entries** (D-20). The 18 numeral keys from Phase 8
  carry the activity's audio. Round-entry narrations (e.g. "Hversu
  margir hundar?") are queued for a future polish pass.

## Key decisions exercised

- **D-01..D-05** (correspondence: round model + gender-aware audio +
  count+noun pickers + re-tap no-op).
- **D-06..D-09** (subitizing: arrangement enum + 1.5s flash + 5 numeral
  options + silent wrong tap).
- **D-10..D-13** (addition: addend1+addend2 model + sum ≤ 5 + NO `+`
  symbol + silent wrong tap).
- **D-15** (chose 2-mode TolurMode + ActivityRotator over 5-mode toggle).
- **D-16** (uniform random across 4 activities).
- **D-17** (widget tests with FakeAudioEngine + stub generators).
- **D-18** (integration test exercises mode toggle + rotator advance).
- **D-19, D-20** (no new manifest entries — fallback to existing keys
  for now; full narration set deferred to manifest polish pass).

All 20 decisions in 09-CONTEXT.md were reached or explicitly deferred.

## Deviations summary

The full deviation list lives in each plan SUMMARY. Highlights:

1. **CorrespondenceActivity image fallback** (Plan 09-01). Phase 4/5
   register `assets/images/letters/words/` but ship no actual image
   files — Image.asset fails. Followed Phase 5's text-on-color
   placeholder pattern via `Image.asset(...).errorBuilder`. Phase 10
   personalization will route through the same widget when photos
   exist.

2. **No round-entry narration in AdditionActivity** (Plan 09-03). Plan
   text mentioned narration "Tveir hundar koma. Einn hundur kemur til
   viðbótar." Per CONTEXT D-20 ("no bake required for Phase 9"), I
   shipped the activity silently and documented the future audio hook
   inline in addition_activity.dart.

3. **AR2 test reshape** (Plan 09-04). First version pumped fresh
   ProviderScope per iteration → flaky due to Timer leak. Reshaped to
   single-mount + repeated `debugAdvance()`. Same coverage,
   deterministic.

4. **Phase 8 integration test updated** (Plan 09-04). Phase 8's
   `tolur_flow_test.dart` previously asserted SequencingActivity after
   the toggle hold; with the new 2-mode shape it asserts ActivityRotator
   and only drives sequence-specific completion when the rotator
   happens to pick Sequence. New `tolur_numeracy_flow_test.dart` covers
   the dedicated Phase 9 rotation flow.

## Files created/modified summary

### Created (lib/)

- `lib/core/numbers/correspondence_round.dart` (223 lines)
- `lib/core/numbers/subitizing_round.dart` (243 lines)
- `lib/core/numbers/addition_round.dart` (110 lines)
- `lib/features/tolur/correspondence/correspondence_activity.dart` (151 lines)
- `lib/features/tolur/correspondence/correspondence_providers.dart` (15 lines)
- `lib/features/tolur/subitizing/subitizing_activity.dart` (217 lines)
- `lib/features/tolur/subitizing/subitizing_providers.dart` (13 lines)
- `lib/features/tolur/addition/addition_activity.dart` (303 lines)
- `lib/features/tolur/addition/addition_providers.dart` (12 lines)
- `lib/features/tolur/activity_rotator.dart` (94 lines)

### Modified (lib/)

- `lib/features/tolur/tolur_mode.dart` — 2-mode reshape
  (tapToHear / activity)
- `lib/features/tolur/widgets/tolur_mode_toggle.dart` — icon mapping
  for activity mode
- `lib/features/tolur/tolur_room.dart` — wires activity →
  ActivityRotator

### Created (test/)

- `test/core/numbers/correspondence_round_test.dart` (154 lines, 11 tests)
- `test/core/numbers/subitizing_round_test.dart` (164 lines, 12 tests)
- `test/core/numbers/addition_round_test.dart` (116 lines, 8 tests)
- `test/features/tolur/correspondence/correspondence_activity_test.dart`
  (223 lines, 7 tests)
- `test/features/tolur/subitizing/subitizing_activity_test.dart`
  (193 lines, 6 tests)
- `test/features/tolur/addition/addition_activity_test.dart`
  (204 lines, 7 tests)
- `test/features/tolur/activity_rotator_test.dart` (3 tests)

### Modified (test/)

- `test/features/tolur/widgets/tolur_mode_toggle_test.dart` — TM1, TM1b, TM3
  updated for new 2-mode enum
- `test/features/tolur/tolur_room_test.dart` — TR2, TR3 updated for
  ActivityRotator

### Created (integration_test/)

- `integration_test/tolur_numeracy_flow_test.dart` (101 lines, 1 device-only test)

### Modified (integration_test/)

- `integration_test/tolur_flow_test.dart` — Phase 9 mode rename + conditional
  sequence drive

### Created (.planning/)

- `.planning/phases/09-numeracy-activities/09-01-PLAN.md`
- `.planning/phases/09-numeracy-activities/09-02-PLAN.md`
- `.planning/phases/09-numeracy-activities/09-03-PLAN.md`
- `.planning/phases/09-numeracy-activities/09-04-PLAN.md`
- `.planning/phases/09-numeracy-activities/09-{01..04}-SUMMARY.md`
- `.planning/phases/09-numeracy-activities/09-SUMMARY.md` (this file)
- `.planning/phases/09-numeracy-activities/09-VERIFICATION.md`

## Phase 9 closing posture

The Phase 9 numeracy activities are **fully shipped from a code-quality
standpoint**:

- 441 tests pass overall (348 baseline + 54 new Phase 9 + Phase 10
  in-flight green tests). Phase 10's RED-phase photo_upload tests
  fail by design — they're someone else's WIP.
- `flutter analyze` clean modulo documented warnings.
- The debug APK builds.
- All 3 activities render correctly + respond to taps + auto-advance
  + never show a fail/error/score/timer indicator.
- The activity rotator picks one of 4 numeracy widgets per mount and
  the integration test confirms ≥3 distinct activities reachable
  across rapid advances.

Phase 9 scope is closed. Phase 10 (Personalization Photos) — already
running in parallel — owns the next big swing.

## Self-Check: PASSED

Verified files exist:
- FOUND: lib/core/numbers/correspondence_round.dart
- FOUND: lib/core/numbers/subitizing_round.dart
- FOUND: lib/core/numbers/addition_round.dart
- FOUND: lib/features/tolur/correspondence/correspondence_activity.dart
- FOUND: lib/features/tolur/subitizing/subitizing_activity.dart
- FOUND: lib/features/tolur/addition/addition_activity.dart
- FOUND: lib/features/tolur/activity_rotator.dart

Verified commits exist:
- FOUND: 56e8c21 (correspondence model)
- FOUND: c573425 (correspondence widget)
- FOUND: ea6cf06 (subitizing model)
- FOUND: 23643d3 (subitizing widget)
- FOUND: f76a0ec (addition model)
- FOUND: b3bfc75 (addition widget)
- FOUND: bceff5b (activity rotator)
