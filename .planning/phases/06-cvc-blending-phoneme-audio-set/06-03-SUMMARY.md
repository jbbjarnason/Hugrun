---
phase: 06
plan: 06-03
title: Mode toggle expansion + integration test
subsystem: stafir-room
status: complete
date: 2026-05-02
tags: [phase-6, stafir, mode-toggle, integration-test, tdd]
requires:
  - phase-5 StafirMode enum + StafirModeToggle (2-mode baseline)
  - phase-6 plan 02 CvcActivity widget
provides:
  - 3-mode StafirMode enum (letters / match / cvc)
  - 3-icon StafirModeToggle widget
  - StafirRoom switch handling all 3 modes
  - Phase 6 CVC end-to-end integration test
key-files:
  modified:
    - lib/features/stafir/stafir_mode.dart (2 → 3 enum values + cycle next)
    - lib/features/stafir/widgets/stafir_mode_toggle.dart (3-arm icon switch)
    - lib/features/stafir/stafir_room.dart (cvc → CvcActivity arm)
    - test/features/stafir/widgets/stafir_mode_toggle_test.dart (M1, M3 + new M1b)
    - test/features/stafir/stafir_room_test.dart (S4b, S4c new)
  created:
    - integration_test/stafir_cvc_flow_test.dart (153 lines, 1 device-only test)
decisions:
  - D-15 Hold-to-cycle: letters → match → cvc → letters
  - D-16 Each mode change still requires 3-second hold
metrics:
  tdd-cycles: 1 (RED+GREEN)
  unit-tests-added: 4 (M1b, M3 rewrite, S4b, S4c)
  integration-tests-added: 1 (compile-clean only — device required to run)
  flutter-test-pass: 263 / 263
  flutter-build-apk-debug: passes
---

# Phase 6 Plan 06-03 — Mode toggle expansion + integration test Summary

## What this plan ships

Workstream C. Extends the Phase 5 2-mode (letters/match) toggle to a 3-mode
cycle (letters/match/cvc) and lands the Phase 6 end-to-end integration
test.

## Changes

### Enum + cycle

`lib/features/stafir/stafir_mode.dart`:
- Was: `enum StafirMode { letters, match }`
- Now: `enum StafirMode { letters, match, cvc }`
- `StafirModeToggleExt.next` rewritten as a switch over all 3 values:
  letters → match → cvc → letters.

### Toggle widget

`lib/features/stafir/widgets/stafir_mode_toggle.dart`:
- Replaced the binary ternary with a 3-arm switch on `currentMode`:
  - letters → `Icons.image_outlined` (existing)
  - match → `Icons.grid_view_outlined` (existing)
  - cvc → `Icons.spellcheck` (NEW)
- Hold semantics unchanged — `ParentGateController` 3-second gate per
  D-16. No haptics. Same kid-mode-safe contract.

### Room switch

`lib/features/stafir/stafir_room.dart`:
- Body switch extended:
  ```dart
  switch (_mode) {
    StafirMode.letters => LetterGrid(onLetterTap: _onLetterTap),
    StafirMode.match => const MatchingActivity(),
    StafirMode.cvc => const CvcActivity(),  // NEW
  }
  ```
- New import for cvc/cvc_activity.dart.

## Tests

### Unit (RED then GREEN; same commit cycle)

`stafir_mode_toggle_test.dart`:
- `M1`: updated to assert `StafirMode.values == [letters, match, cvc]`.
- `M1b` (NEW): asserts the cycle order via `.next`.
- `M3`: rewritten to compare 3 distinct icons across modes (was: 2-mode pair).

`stafir_room_test.dart`:
- `S4b` (NEW): programmatic `debugSetMode(StafirMode.cvc)` shows `CvcActivity`
  and hides both `LetterGrid` and `MatchingActivity`.
- `S4c` (NEW): full cycle (letters → match → cvc → letters) preserves the
  room and swaps the body widget correctly.

### Integration (compile-clean, device-only)

`integration_test/stafir_cvc_flow_test.dart` exercises the full child flow
on a connected device:

```
1. Boot HugrunApp with FakeAudioEngine + cvcCurrentWord = "hús" override.
2. Tap into Stafir from home — LetterGrid mounted.
3. Hold StafirModeToggle 3.2s → MatchingActivity mounts (letters → match).
4. Hold again 3.2s → CvcActivity mounts (match → cvc).
5. Verify 3 LetterTile widgets present.
6. Tap c2 ("s"): engine.play(phonemeS).
7. Tap c1 ("h"): engine.play(phonemeH). Blend NOT yet fired.
8. Tap v ("ú"): engine.play(phonemeUAcute), then engine.play(wordHus) as
   the blend.
9. Verify the call sequence: 3 phonemes + 1 blend = 4 new playCalls.
10. Pump 2.2s — auto-advance fires; tile state resets.
11. Re-tap c2: engine.play(phonemeS). Blend does NOT re-fire (only 1/3
    tapped post-reset).
```

Posture: **compile-clean** under `flutter analyze` (0 issues), **runs only
on a connected device**. Same posture as Phase 5's
`stafir_matching_flow_test.dart`. The lack of a connected device during
this build does not block phase closure — the test exists and compiles.

## Verifications

| Check | Status |
|-------|--------|
| `flutter test` | 263 / 263 pass |
| `flutter analyze` integration_test/stafir_cvc_flow_test.dart | 0 issues |
| `flutter analyze` overall | 7 warnings (all riverpod_lint scoped-providers — same family Phase 5 documented) |
| `flutter build apk --debug` | passes |
| `bash tools/check-domain-purity.sh` | passes |
| `bash tools/check-asset-paths.sh` | passes |
| `bash tools/check-no-tracking.sh` | passes |
| `bash tools/check-manifest-sync.sh` | passes (correctly skips with stub-baseline carve-out) |

## Deviations from plan

None of substance. The plan asked for "widget tests for the 3-mode toggle"
— I extended the existing M1/M3 tests in place rather than duplicating
them, which keeps the test file as the single source of truth for toggle
behavior. M1b is the only purely additive new test.

## Self-Check: PASSED

- StafirMode.cvc value present ✓
- StafirModeToggleExt.next cycles through 3 values ✓
- StafirModeToggle renders distinct icon for cvc ✓
- StafirRoom switch arms cvc → CvcActivity ✓
- integration_test/stafir_cvc_flow_test.dart compiles clean ✓
- 2 commits in this plan visible in git log:
  - `e899041` test(06-03): RED tests for 3-mode toggle
  - `741ee66` feat(06-03): extend StafirMode enum + 3-mode toggle (GREEN)
  - `67838a9` test(06-03): add Phase 6 CVC flow integration test
  (3 commits total)
- 263 / 263 flutter test pass ✓
