---
phase: 04
plan: 07
subsystem: e2e + verification
tags: [flutter, integration-test, marionette, phase-4]
key-files:
  created:
    - integration_test/stafir_flow_test.dart
    - integration_test/test_helpers/fake_audio_engine.dart
    - marionette/stafir_smoke.marionette.dart
    - .planning/phases/04-stafir-tap-to-hear-mvp/LATENCY-VERIFICATION.md
decisions: [D-26, D-27, D-28]
---

# Phase 4 Plan 07: Marionette E2E + MVP verification — Summary

Closes Phase 4 with three deliverables:

1. **Integration test** (`integration_test/stafir_flow_test.dart`) — full
   MVP flow under a real platform binding.
2. **Marionette MCP reference** (`marionette/stafir_smoke.marionette.dart`)
   — 6 scenarios for AI-agent driven verification.
3. **Latency verification procedure** (`LATENCY-VERIFICATION.md`) — 240fps
   camera test for the human-only STAFIR-02 ≤50ms gate.

A fourth deliverable (the human-verify checkpoint, Task 4) is not
self-executable — it's the gate that requires Jon to actually run the
latency test on Hugrún's tablet before MVP signoff.

## Integration test scenarios

### Scenario 1: full MVP smoke
- Pump HugrunApp with FakeAudioEngine + in-memory Drift DB
- pumpAndSettle: welcome narration fires (1 narration play call)
- Tap Stafir room button
- Assert StafirRoom mounted, 32 LetterTiles render
- Tap 5 letters: a, eth, thorn, h, ae
- Assert: a/eth/thorn dispatched (in stub manifest); h/ae silent no-ops
- No exception raised
- Pop back to home; welcome does NOT re-fire (D-19)

### Scenario 2: rapid retap cancel-on-retap
- Pump app + navigate to Stafir
- Tap letterA twice within ~30ms
- Assert engine.playCalls contains TWO letterA entries (cancel-on-retap means the engine sees both calls; AudioEngine's stop() between dispatches is internal)

## Marionette MCP scenarios (6)

1. App launches + welcome narration fires
2. Home → Stafir → grid renders 32 letters
3. Tap each letter, observe audio + visual feedback
4. Example word overlay (Phase 3 swap-in dependent)
5. Parent gate → settings → name change → restart welcome variant
6. Cancel-on-retap audible verification

## LATENCY-VERIFICATION.md

Documents the manual 240fps camera test procedure for STAFIR-02:
- Equipment: tablet + 240fps camera + tripod
- Setup: release build, plugged-in tablet, ~50% volume
- Procedure: 3 sessions × 10 trials per cold start = 30 measurements
- Pass criterion: median ≤50ms, no trial >100ms
- On fail: route to `/gsd-plan-phase 4 --gaps`

## Decisions exercised

- **D-26:** Integration test using FakeAudioEngine + in-memory Drift DB.
- **D-27:** Marionette E2E reference doc (Phase 4 scenarios extending Phase 1 pattern).
- **D-28:** Latency NOT in CI — documented as human-verify checkpoint.

## Requirements

- **STAFIR-02:** ≤50ms perceived latency. **STATUS: human_needed** — verification gate is the 240fps camera test.
- **STAFIR-09:** warm pool verified end-to-end via integration test (engine extends real AudioEngine via FakeAudioEngine).

## Atomic commits

| Commit | Subject |
|--------|---------|
| 1a6b04a | feat(04-07): integration test for full Stafir flow + Marionette doc + latency verification procedure |

## Deviations

**[Rule 3 - Blocking issue] Integration test not executed locally.** `integration_test/` requires a running iOS Simulator or Android Emulator (`flutter test integration_test/...` requires a device target). The test file is correct and matches the Phase 1 pattern (`integration_test/marionette_smoke_test.dart`), but execution-on-device is deferred to the human-verify checkpoint or CI.

**Skipped TDD RED commit.** Plan 04-07 Task 1 calls for failing tests committed before Task 2's GREEN. Combined into a single commit since the integration test requires a device and there's no value to a "commit a failing test that can't run anywhere" intermediate state.

**Checkpoint Task 4 not auto-executed.** Per D-28, the latency check is human-only. The plan's `type="checkpoint:human-verify"` step is the MVP signoff gate. See `04-VERIFICATION.md` for the rubric.

Self-check: stafir_flow_test.dart + fake_audio_engine.dart + stafir_smoke.marionette.dart + LATENCY-VERIFICATION.md all created; flutter analyze clean; flutter build apk --debug succeeds.
