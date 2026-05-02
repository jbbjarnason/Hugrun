---
phase: 07
plan: 07-04
title: 4-mode toggle expansion + integration test
status: complete
date: 2026-05-02
tags: [phase-7, mode-toggle, integration-test, tdd]
requirements_satisfied:
  - TRACE-04  # tracing reachable from Stafir room toggle (no fail/timer in flow)
metrics:
  test-delta: +6 (3 toggle/cycle widget tests + 2 stafir room tests + 1 integration)
  enum-stafir-mode-entries: 3 → 4
---

# Plan 07-04: 4-mode toggle expansion + integration test — Summary

Extends the Stafir room mode toggle from 3 modes (Letters / Match / CVC)
to 4 (+ Trace). Adds a device-only integration test that walks the full
3-hold cycle from Letters → Match → CVC → Trace and drives a tracing
completion via the activity's debug hook.

## What was built

### StafirMode enum extension (D-15)
- `lib/features/stafir/stafir_mode.dart` — 4 entries:
  letters, match, cvc, **trace**.
- Cycle order locked: letters → match → cvc → trace → letters.

### Mode toggle widget icon
- `lib/features/stafir/widgets/stafir_mode_toggle.dart` — 4-arm
  switch. New icon for trace: `Icons.edit` (a pencil — kid sees a
  visual "draw a letter" cue).

### StafirRoom switch arm
- `lib/features/stafir/stafir_room.dart` — switch on `_mode`, new
  arm: `StafirMode.trace => const TracingActivity()`. Mounting/
  un-mounting follows the same pattern as the cvc arm.

### Tests (RED → GREEN, 6 new)

Widget tests (`test/features/stafir/widgets/stafir_mode_toggle_test.dart`):
- M1: `StafirMode.values` is exactly `[letters, match, cvc, trace]`.
- M1b: cycle is `letters → match → cvc → trace → letters`.
- M3: 4 distinct icons (verified via set deduplication; was 3-icon).

Room tests (`test/features/stafir/stafir_room_test.dart`):
- S4d: `state.debugSetMode(StafirMode.trace)` mounts a `TracingActivity`,
  unmounts the other 3 surface widgets.
- S4e: full 4-mode cycle round-trip from letters back to letters.

Integration test (`integration_test/stafir_tracing_flow_test.dart`):
- Boots HugrunApp under ProviderScope with FakeAudioEngine + a forced
  initial letter ('a').
- Taps into Stafir → 3 sequential 3.2-second holds → TracingActivity
  is mounted.
- Drives completion via `debugCompleteForTesting()` → asserts the
  celebration audio key fired on the engine.
- Compile-clean (`flutter analyze` 0 issues on this file).

## Architectural commitments — preserved

- **Reuse-not-duplicate** — same `StafirModeToggle`, same hold-to-toggle
  3-second gesture, same kid-mode safety. Phase 7 extends the cycle by
  one entry; the toggle widget chrome is unchanged.
- **No new banned packages** — no dep changes in this plan.
- **Atomic commits** — RED before GREEN for the 4-mode tests; toggle
  enum + toggle widget + room switch shipped together as a single
  GREEN commit (they're atomically coupled — the enum addition forces
  switch-arm exhaustiveness in stafir_room.dart, so they have to land
  together).

## Deviations from plan

None — RED/GREEN/REFACTOR ran exactly as written.

## Files changed

### Modified (lib/)
- `lib/features/stafir/stafir_mode.dart` — 3 → 4 mode values.
- `lib/features/stafir/widgets/stafir_mode_toggle.dart` — 4-arm icon
  switch.
- `lib/features/stafir/stafir_room.dart` — switch arm for trace; import
  TracingActivity.

### Modified (test/)
- `test/features/stafir/widgets/stafir_mode_toggle_test.dart` — update
  M1, M1b, M3 for the 4th mode.
- `test/features/stafir/stafir_room_test.dart` — add S4d, S4e + import.

### Created (integration_test/)
- `integration_test/stafir_tracing_flow_test.dart` (~150 lines).

## Commits

- `53f33e2 test(07-04): add failing tests for 4-mode toggle (RED — Phase 7 D-15)`
- `b108713 feat(07-04): extend StafirMode to 4 modes + render TracingActivity (GREEN)`
- `cad9fd6 test(07-05): add Phase 7 letter-tracing flow integration test`

(test 07-05 commit is the integration test — accounted for under
this plan because it exercises the 4-mode cycle E2E.)

## Self-Check: PASSED
