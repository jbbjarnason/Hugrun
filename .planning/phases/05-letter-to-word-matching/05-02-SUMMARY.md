---
phase: 05-letter-to-word-matching
plan: 02
title: Matching Activity Widget
status: complete
date: 2026-05-02
tags: [matching, widget, stafir, riverpod, silent-no-op]
requirements: [MATCH-01, MATCH-02, MATCH-03, MATCH-04]
metrics:
  test-delta: +23 (185 → 208)
  commits: 6 (3 RED + 3 GREEN, no refactor needed)
  flutter-analyze: clean
---

# Phase 5 Plan 02 — Matching Activity Widget Summary

The Flutter widget surface for the Letter-to-Word Matching activity.
Renders one round at a time, handles wrong-tap silent no-op
(MATCH-02 / D-07), correct-tap celebration + auto-advance
(MATCH-03 / D-08 / D-09), and reuses Phase 4's `LetterTile` and
`AudioEngine` without duplication (D-15).

## Files created

### Production (lib/features/stafir/matching/)
- `matching_providers.dart` (28 lines) — keepAlive Riverpod providers
  for `photoOverrideSource` and `roundGenerator`
- `matching_round_image.dart` (63 lines) — image area widget; switches
  on `ImageSource` sealed cases
- `matching_celebration.dart` (103 lines) — overlay with
  scale+fade animation; exposes `static const duration = 1500ms`
- `matching_activity.dart` (138 lines) — the screen itself

### Tests (test/features/stafir/matching/)
- `matching_round_image_test.dart` (128 lines, 6 tests)
- `matching_celebration_test.dart` (88 lines, 6 tests)
- `matching_activity_test.dart` (350 lines, 11 tests)

## Test count delta

208 total (was 185 after Plan 05-01). +23 in this plan:
- Task 1: +6 tests (provider tests + 4 image tests)
- Task 2: +6 tests (celebration overlay)
- Task 3: +11 tests (activity behavior — A1..A11)

## Decisions exercised

| Decision | How |
|----------|-----|
| D-02 | `MatchingActivity` is a standalone widget; renders one round at a time |
| D-07 / MATCH-02 | A4 (CRITICAL) — wrong tap is `engine.playCalls.isEmpty` invariant |
| D-08 / MATCH-03 | A5 — correct tap fires `wordHundur` audio + celebration overlay |
| D-09 | A6 — auto-advance after `MatchingCelebration.duration` (1500ms) |
| D-10 | A8 — no score/streak/timer/digits visible at any point |
| D-12 | `MatchingRoundImage` ships text-on-color placeholder for stock case |
| D-14 | `MatchingActivity` reserves upper 60% of screen for image; tiles below |
| D-15 | A10 — exactly 4 LetterTile widgets, NO duplicate tile class |
| D-17 | Widget tests cover layout + tap behavior + animation + photo source |
| D-21 | A5 — example-word audio (`wordHundur`) is the celebration cue; no separate `narrationCelebrationCorrect` clip |
| MATCH-01 | `MatchingActivity` is the visible activity surface |
| MATCH-04 | Phase 5 ships `EmptyPhotoOverrideSource` as default; Phase 10 swaps the binding |

## Implementation notes

### LetterTile + AudioEngine reuse

- `MatchingActivity` imports `package:hugrun/features/stafir/widgets/letter_tile.dart`
  directly — A10 confirms exactly 4 LetterTile widgets per round (no
  duplicate tile widget shipped).
- `MatchingActivity` reads `audioEngineProvider` from
  `lib/core/audio/audio_engine_provider.dart` — same provider Phase 4's
  StafirRoom uses. No new audio plumbing.

### FakeAudioEngine reuse from integration_test

The widget test imports `FakeAudioEngine` from
`integration_test/test_helpers/fake_audio_engine.dart` (the Phase 4
test helper). This is the same pattern Phase 4's `stafir_room_test.dart`
established — keeps the audio fake in one place rather than ship a
duplicate widget-test helper.

### Wrong-tap silence canary (A4)

This is the single most important test in Phase 5. It asserts:
- `engine.playCalls.isEmpty` after a wrong tap
- `engine.stopCallCount == 0` after a wrong tap
- `find.byKey(Key('matching-celebration-active'))` returns nothing
- The activity is still on the same round (4 LetterTile widgets unchanged)
- A second wrong tap preserves all of the above

If A4 ever fails, the activity has accidentally introduced fail-state
feedback (an explicit STAFIR-07 / MATCH-02 violation).

### A11 pending-Timer safety

The auto-advance Timer is canceled in `dispose()`. A11 verifies that
unmounting the activity mid-celebration does not trigger an exception
or a setState-on-unmounted error.

### Implementation deviations

| Rule | Issue | Fix |
|------|-------|-----|
| Rule 3 - Blocking | `<Override>[]` typed list breaks Dart compilation; Riverpod test code uses untyped list | Switched to `overrides: [...]` matching the Phase 4 convention (no behavior change) |
| Rule 3 - Analyze | `unnecessary_import` on flutter_riverpod when riverpod_annotation already imports it; `_wrap` local underscore lint | Dropped redundant import; renamed local helper to `wrap` (no behavior change) |

## Self-Check

- [x] `lib/features/stafir/matching/matching_providers.dart` exists
- [x] `lib/features/stafir/matching/matching_round_image.dart` exists
- [x] `lib/features/stafir/matching/matching_celebration.dart` exists
- [x] `lib/features/stafir/matching/matching_activity.dart` exists
- [x] 6 commits (3 RED + 3 GREEN)
- [x] All 23 new tests pass
- [x] All 208 project tests pass (no regressions)
- [x] `flutter analyze` clean for the matching subtree
- [x] LetterTile + AudioEngine reused (NOT duplicated)

## Self-Check: PASSED

## Commits

- `4ba56c0` test(05-02): add failing tests for MatchingRoundImage + matching providers
- `336d984` feat(05-02): MatchingRoundImage + matching_providers (Phase 5 stub)
- `9d54f8c` test(05-02): add failing tests for MatchingCelebration overlay
- `243fd11` feat(05-02): MatchingCelebration overlay (checkmark + scale fade)
- `b5ba70f` test(05-02): add failing tests for MatchingActivity (wrong-tap silent, correct-tap celebrate, auto-advance)
- `5799089` feat(05-02): MatchingActivity widget with silent wrong-tap + celebrate-on-correct + auto-advance

## Ready for Plan 05-03

Plan 05-03 can now import:
- `package:hugrun/features/stafir/matching/matching_activity.dart` —
  `MatchingActivity` (self-contained, schedules its own first round)
- `package:hugrun/features/stafir/matching/matching_celebration.dart` —
  `MatchingCelebration.duration` for integration-test pumping
