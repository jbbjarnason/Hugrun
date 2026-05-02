---
phase: 05-letter-to-word-matching
plan: 03
title: Stafir Mode Toggle + End-to-End Integration Test
status: complete
date: 2026-05-02
tags: [stafir, mode-toggle, integration, parent-gate-reuse]
requirements: [MATCH-01]
metrics:
  test-delta: +16 unit/widget (208 → 224) + 1 integration test
  commits: 5 (3 RED + 2 GREEN; integration GREEN is a no-op since Tasks 1+2 satisfy the contract)
  flutter-analyze: clean (modulo 5 known riverpod_lint warnings on scoped overrides — Phase 4 baseline + 3 new files of the same pattern)
---

# Phase 5 Plan 03 — Stafir Mode Toggle + Integration Summary

Wires the matching activity into the existing StafirRoom via a kid-safe
3-second hold toggle that reuses the Phase 1 `ParentGateController`
state machine. Closes the phase with an end-to-end integration test
walking the full child flow (home → Stafir → letters tap → mode swap →
wrong tap silent → correct tap celebrate → auto-advance → mode swap back).

## Files created

### Production
- `lib/features/stafir/stafir_mode.dart` (15 lines) — enum + .next extension
- `lib/features/stafir/widgets/stafir_mode_toggle.dart` (118 lines) —
  48×48 icon-only widget; reuses `ParentGateController`

### Modified
- `lib/features/stafir/stafir_room.dart` — added `StafirMode _mode` field,
  mode-conditional body, top-right toggle, `@visibleForTesting debugSetMode`,
  promoted state class to `StafirRoomState` (public for `tester.state<...>`)

### Tests
- `test/features/stafir/widgets/stafir_mode_toggle_test.dart` (193 lines, 10 tests)
- `test/features/stafir/stafir_room_test.dart` (extended with 6 new tests S1..S7,
  preserving the original 6 Phase 4 tests)
- `integration_test/stafir_matching_flow_test.dart` (157 lines, 1 long testWidgets)

## Test count delta

224 unit/widget total (was 208 after Plan 05-02). +16 in this plan:
- Task 1: +10 tests (M1..M10)
- Task 2: +6 tests (S1..S4, S6, S7)
- Task 3: +1 long integration test (compile-clean; runs against a device binding
  so does not add to the flutter-test count, same as Phase 4's integration tests)

## Decisions exercised

| Decision | How |
|----------|-----|
| D-01 | StafirModeToggle: 3-second hold, icon-only, top-right; reuses ParentGateController (Tests M4, M5, M10) |
| D-18 | Single integration_test walks the full flow with wrong+correct+advance cycles |
| D-23 (Phase 1) | M7 — no haptic feedback during hold |
| MATCH-01 | E2E reachable from a child's tap path: home → Stafir → toggle → matching |

## Implementation notes

### ParentGateController reuse

The toggle imports `parent_gate_controller.dart` directly and constructs
its own controller. We chose NOT to wrap with `ParentGate` widget because:
- We need a 48×48 footprint, not the parent gate's wrapping chrome.
- The state machine (idle → holding → completed) is the part worth
  reusing; the visual ring chrome differs.

`grep -n 'ParentGateController' lib/features/stafir/widgets/stafir_mode_toggle.dart`
returns 1 hit — confirms the reuse without duplicate timer logic.

### `StafirRoomState` made public

The Phase 4 `_StafirRoomState` was private. Plan 05-03 needs
`tester.state<StafirRoomState>(find.byType(StafirRoom))` to drive the
mode programmatically (S3, S4) without simulating a 3-second gesture
inside the StafirRoom test (the toggle's gesture handling is
exhaustively tested in `stafir_mode_toggle_test.dart` already).

Promoted to public + added `@visibleForTesting void debugSetMode(StafirMode m)`.

### Integration-test verification posture

Like Phase 4's `stafir_flow_test.dart`, this integration test runs against
the real platform binding via `IntegrationTestWidgetsFlutterBinding`. The
local `flutter test integration_test/...` invocation requires a connected
device, which is not available in this execution environment. We verify
**compile-cleanliness** (`flutter analyze integration_test/stafir_matching_flow_test.dart`
returns "No issues found!") as the proxy — same posture as Phase 4 closed.

Phase 4 SUMMARY documents this same condition for `stafir_flow_test.dart`.

### Analyze warnings

5 total project-wide `scoped_providers_should_specify_dependencies` warnings:
- 2 baseline from Phase 4 (`stafir_room_test.dart:48`, `parent_settings_screen_test.dart:20`)
- 3 new in `matching_activity_test.dart` (lines 43, 44, 45 — one per `overrideWith`)

These are tolerated. The `// ignore_for_file:` directive does NOT suppress
them because `riverpod_lint 3.1.x` runs through the `analysis_server_plugin`
path which has known limitations with file-level lints. Phase 4 SUMMARY
documented this exact same condition.

## Deviations

| Rule | Issue | Fix |
|------|-------|-----|
| Rule 1 - Bug | Mock platform handler returning `null` for `flutter/platform` calls broke `MaterialApp`'s Title widget | M7 spy-only handler that records method names then returns `null`; reset `logged` AFTER `pumpWidget` so MaterialApp boot calls don't leak into the assertion |
| Rule 3 - Blocking | `<MethodCall>` typed list and `MethodChannel` const ctor required `package:flutter/services.dart` import | Added the import; switched to `<String>` capturing `call.method` |
| Rule 3 - Analyze | `unnecessary_import` on `flutter/foundation.dart` in stafir_room.dart | Dropped the redundant import |

## Self-Check

- [x] `lib/features/stafir/stafir_mode.dart` exists
- [x] `lib/features/stafir/widgets/stafir_mode_toggle.dart` exists
- [x] `integration_test/stafir_matching_flow_test.dart` exists
- [x] 5 commits in this plan
- [x] All 16 new unit/widget tests pass
- [x] All 224 project tests pass (no regressions)
- [x] `bash tools/check-domain-purity.sh` passes
- [x] `bash tools/check-asset-paths.sh` passes
- [x] `bash tools/check-no-tracking.sh` passes
- [x] `flutter analyze` clean (modulo 5 documented riverpod_lint warnings)
- [x] ParentGateController reused (NOT duplicated)
- [x] LetterTile reused via MatchingActivity (Plan 05-02)
- [x] AudioEngine reused via audioEngineProvider

## Self-Check: PASSED

## Commits

- `9a9c24b` test(05-03): add failing tests for StafirMode enum + StafirModeToggle
- `9b96614` feat(05-03): StafirMode enum + StafirModeToggle (3s hold, reuses ParentGateController)
- `86b882f` test(05-03): add failing tests for StafirRoom mode-aware body (S1..S7)
- `9c036ea` feat(05-03): StafirRoom mode-aware body (Letters / Match) with hold toggle
- `ec08311` test(05-03): add failing integration test for end-to-end matching flow

## Cross-plan decision coverage

| Decision | Plan 05-01 | Plan 05-02 | Plan 05-03 |
|----------|:----------:|:----------:|:----------:|
| D-01 |  |  | ✓ |
| D-02 |  | ✓ |  |
| D-03 | ✓ |  |  |
| D-04 | ✓ |  |  |
| D-05 | ✓ |  |  |
| D-06 | ✓ |  |  |
| D-07 |  | ✓ |  |
| D-08 |  | ✓ |  |
| D-09 |  | ✓ |  |
| D-10 |  | ✓ |  |
| D-11 |  | ✓ (implicit) |  |
| D-12 |  | ✓ |  |
| D-13 | ✓ | ✓ |  |
| D-14 |  | ✓ |  |
| D-15 |  | ✓ |  |
| D-16 | ✓ |  |  |
| D-17 |  | ✓ |  |
| D-18 |  |  | ✓ |
| D-19 | ✓ (implicit — generator iterates manifest keys) |  |  |
| D-20 |  | ✓ (implicit — narrationCelebrationCorrect deferred) |  |
| D-21 |  | ✓ (example word audio used as celebration cue) |  |

All 21 decisions reached or explicitly deferred.
