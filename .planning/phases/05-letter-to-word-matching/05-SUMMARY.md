---
phase: 05
title: Letter-to-Word Matching
status: complete
date: 2026-05-02
plans:
  - 05-01-round-generator
  - 05-02-matching-activity-widget
  - 05-03-stafir-mode-toggle
tags: [flutter, riverpod, freezed, matching, post-mvp]
metrics:
  total-tests: 224
  test-delta: +59 (165 → 224)
  flutter-analyze: clean (modulo 5 documented riverpod_lint warnings on scoped overrides)
  flutter-build-apk-debug: passes
  domain-purity: passes
  asset-paths: passes
  no-tracking: passes
---

# Phase 5: Letter-to-Word Matching — Master Summary

A small post-MVP activity. Phase 5 adds a letter-to-word matching mini-game
to the Stafir room. Image of an object appears, child taps the correct
starting letter from 4 options. Wrong taps are silent no-ops. Correct taps
celebrate with a soft animation + audio cue. Activity is wired to consume
personalized photos at ~40% frequency once Phase 10 lands.

Plans executed: all 3 (05-01 through 05-03). No human-verify checkpoints
encountered.

## Plan summaries

| Plan | Subject | Commits | Tests |
|------|---------|---------|-------|
| 05-01 | Round generator (pure-Dart core) | 6 | +20 |
| 05-02 | Matching activity widget | 6 | +23 |
| 05-03 | Stafir mode toggle + integration | 5 | +16 unit + 1 integration |

## What was built (the matching loop)

```
StafirRoom (Letters mode by default)
  ↓
[Adult holds top-right toggle for 3 seconds]
  ↓
StafirModeToggle.onToggle fires (ParentGateController state machine)
  ↓
StafirRoom._mode swaps to StafirMode.match
  ↓
MatchingActivity mounts → schedules first round in postFrameCallback
  ↓
RoundGenerator.generate() picks word* manifest entry + 4 distinct
  letters (correct + 3 distractors, no similar pairs)
  ↓
Render: MatchingRoundImage (60% top) + 4 LetterTile widgets (row below)
  ↓
[Child taps WRONG letter]
  ↓
LetterTile intrinsic squeeze fires (Phase 4 visual feedback)
  → No audio, no celebration, no state change. PURE no-op (D-07).
  ↓
[Child taps CORRECT letter]
  ↓
audioEngine.play(round.targetWordKey) — wordHundur audio
  ↓
MatchingCelebration overlay shown (visible: true)
  → check_circle_rounded fades + scales in over 600ms
  ↓
Auto-advance Timer fires after MatchingCelebration.duration (1500ms)
  ↓
RoundGenerator.generate() — new round (image + 4 tiles)
  ↓
[Loop continues — infinite rounds, no counter, no score]
```

## Quality gate

- [x] All 3 plans executed
- [x] LetterTile reused (no duplicate tile widget) — verified by `find.byType(LetterTile).evaluate().length == 4`
- [x] AudioEngine reused via `audioEngineProvider`
- [x] ParentGateController reused (NOT duplicated) — `grep ParentGateController lib/features/stafir/widgets/stafir_mode_toggle.dart` returns 1+ hits
- [x] Wrong-tap silent test (A4) passes — `engine.playCalls.isEmpty` invariant
- [x] Round generator pure-Dart — `tools/check-domain-purity.sh` passes with `lib/core/matching` in DOMAIN_PATHS
- [x] Photo override hook stub — `EmptyPhotoOverrideSource` returns empty list
- [x] Auto-advance after correct tap (1.5s) — A6 test verifies celebration disappears
- [x] StafirRoom mode toggle (3s hold) — M5 (3.1s holds → toggles)
- [x] Integration test compile-clean (runs on device binding only — same posture as Phase 4)
- [x] flutter analyze clean (modulo 5 documented riverpod_lint warnings)
- [x] flutter test all pass (224 / 224)
- [x] flutter build apk --debug succeeds
- [x] tools/check-domain-purity.sh passes
- [x] tools/check-asset-paths.sh passes
- [x] tools/check-no-tracking.sh passes
- [x] Atomic commits per RED/GREEN cycle (17 task commits across the 3 plans)
- [x] Untracked plan files committed at the start of Phase 5

## Architectural commitments — preserved

- **Pure-Dart `lib/core/matching/`**: enforced via CI script. No Flutter imports under that subtree.
- **Reuse-not-duplicate**: LetterTile, AudioEngine, ParentGateController each imported and used directly; no fork-and-modify.
- **No fail-state UI**: 0 stars, 0 trophies, 0 score numbers, 0 "wrong" text anywhere in the diff. A7+A8 tests assert.
- **Photo abstraction wired now**: Phase 10's photo override path is a Riverpod binding swap, NOT a code change in the activity.

## Key decisions exercised

D-01 (mode toggle), D-02 (matching as standalone screen), D-03..D-06 (round
generator), D-07 (silent wrong tap), D-08 (tasteful celebration), D-09
(auto-advance), D-10 (no fail UI / scoring), D-11 (wrong tap = nothing
changes), D-12..D-13 (image source + photo override), D-14..D-15
(layout + reuse), D-16..D-18 (test strategy), D-19..D-21 (manifest
posture).

All 21 decisions in 05-CONTEXT.md were reached or explicitly deferred.

## Deviations summary

The full deviation list is in each plan's SUMMARY.md. Highlights:

1. **Freezed assertion pattern** (Plan 05-01). Original plan called for a
   `_internal` private factory + public asserting factory. That pattern
   collides with Freezed's union codegen which generates `when/map` arms
   keyed on factory names — `_internal` becomes a parameter starting
   with underscore (illegal Dart). Switched to `@Assert(...)` annotations
   directly on the factory.

2. **`.freezed.dart` not committed** (Plan 05-01). Project `.gitignore`
   line 44 ignores `**/*.freezed.dart`. Honored existing convention
   instead of plan's explicit "commit them" instruction.

3. **`<Override>[]` typed list dropped** (Plans 05-02, 05-03). Riverpod
   3.x test code conventionally uses untyped `overrides: [...]` lists.
   The plan example used `<Override>[...]`. Matched Phase 4 convention.

4. **`ignore_for_file: scoped_providers_should_specify_dependencies`**
   doesn't suppress riverpod_lint warnings (Phase 4 documented this).
   Tolerated; analyze count grows from 2 (Phase 4) to 5 (Phase 5) — all
   the same lint at scoped overrides in test files.

5. **M7 platform-channel mock** (Plan 05-03). Returning `null` from a
   blanket mock handler broke MaterialApp's `Title` widget chrome
   bootstrap. Switched to a spy-only handler that records method names
   and clears the log after `pumpWidget` returns, so only toggle
   interactions are surveyed.

6. **`StafirRoomState` made public** (Plan 05-03). Test S3/S4 needed
   `tester.state<StafirRoomState>(...)` to drive the mode without
   simulating a 3-second gesture. Added `@visibleForTesting void
   debugSetMode(StafirMode m)` escape hatch.

## Files created/modified summary

### Created (lib/)
- `lib/core/matching/matching_round.dart` (74 lines) — Freezed value class
- `lib/core/matching/photo_override_source.dart` (34 lines) — abstract + Empty stub
- `lib/core/matching/round_generator.dart` (192 lines) — RoundGenerator
- `lib/features/stafir/stafir_mode.dart` (15 lines) — StafirMode enum
- `lib/features/stafir/widgets/stafir_mode_toggle.dart` (118 lines) — toggle widget
- `lib/features/stafir/matching/matching_providers.dart` (28 lines) — Riverpod providers
- `lib/features/stafir/matching/matching_round_image.dart` (63 lines) — image area
- `lib/features/stafir/matching/matching_celebration.dart` (103 lines) — overlay
- `lib/features/stafir/matching/matching_activity.dart` (138 lines) — main screen

### Modified (lib/)
- `lib/features/stafir/stafir_room.dart` — added mode-aware body + toggle
- `tools/check-domain-purity.sh` — added `lib/core/matching` to DOMAIN_PATHS

### Created (test/)
- `test/core/matching/matching_round_test.dart` (165 lines)
- `test/core/matching/round_generator_test.dart` (282 lines)
- `test/features/stafir/matching/matching_round_image_test.dart` (128 lines)
- `test/features/stafir/matching/matching_celebration_test.dart` (88 lines)
- `test/features/stafir/matching/matching_activity_test.dart` (350 lines)
- `test/features/stafir/widgets/stafir_mode_toggle_test.dart` (193 lines)

### Modified (test/)
- `test/features/stafir/stafir_room_test.dart` — added 6 tests S1..S7

### Created (integration_test/)
- `integration_test/stafir_matching_flow_test.dart` (157 lines)

### Created (.planning/)
- `.planning/phases/05-letter-to-word-matching/05-{01..03}-SUMMARY.md`
- `.planning/phases/05-letter-to-word-matching/05-SUMMARY.md` (this file)
- `.planning/phases/05-letter-to-word-matching/05-VERIFICATION.md`

## Phase 5 closing posture

The matching activity is **fully shipped from a code-quality standpoint**:
224 tests pass, flutter analyze is clean (modulo 5 documented warnings),
the debug APK builds, the activity correctly renders + responds to taps
+ advances rounds without ever showing a fail/error/score/timer indicator.

The Phase 5 scope is closed. Phase 6 (CVC blending) can begin.

When Phase 3 ships its expanded manifest (more `wordX` entries than the
current Phase 2 stub's `wordHundur`), the activity automatically picks
them up — `RoundGenerator` iterates `kAudioManifest` keys and any new
`word*` entries become eligible round targets immediately. No code
change in the matching layer.
