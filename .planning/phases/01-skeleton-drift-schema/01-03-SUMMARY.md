---
phase: 1
plan: 03
subsystem: ui-shell
tags: [home, parent-gate, room, navigator-1, tdd]
tech-stack:
  added: []  # All in Plans 01-02
  patterns:
    - Listener (raw pointer events) for parent gate timing — bypasses GestureDetector long-press 500ms threshold
    - LayoutBuilder for tablet-aware Column→Row at 600px breakpoint
    - Navigator 1.0 + MaterialPageRoute (D-25)
    - Pure-Dart ParentGateController for D-08 domain purity
key-files:
  created:
    - lib/core/parent_gate/parent_gate_controller.dart
    - lib/core/parent_gate/parent_gate.dart
    - lib/features/home/room_button.dart
    - lib/features/stafir/stafir_room.dart
    - lib/features/tolur/tolur_room.dart
    - lib/features/parent_settings/parent_settings_screen.dart
    - test/core/parent_gate/parent_gate_test.dart (9 tests)
    - test/features/home/room_button_test.dart (3 tests)
    - test/features/stafir/stafir_room_test.dart (2 tests)
    - test/features/tolur/tolur_room_test.dart (2 tests)
    - test/features/parent_settings/parent_settings_screen_test.dart (2 tests)
  modified:
    - lib/features/home/home_page.dart (replaces Plan 01 placeholder)
    - test/features/home/home_page_test.dart (8 tests total — 5 new for rooms+gate)
decisions: []
metrics:
  duration: ~12 min
  tasks: 3
  tests: 26 new (9 gate + 3 button + 2 stafir + 2 tolur + 2 parent_settings + 5 home_page additions); 54 cumulative
  completed: 2026-05-02
---

# Phase 1 Plan 03: Rooms + Parent Gate Summary

Built the visible Phase 1 chrome: a two-room home shell (Stafir, Tölur) with a parent-gate-protected entry point to a placeholder ParentSettings screen. Per FOUND-08 + FOUND-09 + D-22 / D-23 / D-24 / D-25.

## Test counts
| File | Count | Status |
|---|---|---|
| `test/core/parent_gate/parent_gate_test.dart` | 9 | green |
| `test/features/home/room_button_test.dart` | 3 | green |
| `test/features/stafir/stafir_room_test.dart` | 2 | green |
| `test/features/tolur/tolur_room_test.dart` | 2 | green |
| `test/features/parent_settings/parent_settings_screen_test.dart` | 2 | green |
| `test/features/home/home_page_test.dart` | 8 | green (3 from Plan 01 + 5 new) |
| **New tests this plan** | **26** | green |
| **Cumulative (Plans 01+02+03)** | **54** | green |

## Confirmation of locked decisions
- **D-22 (3s hold + ring fill):** Default `holdDuration: const Duration(seconds: 3)`. `CircularProgressIndicator(value: _animation.value)` with `Key('parent-gate-ring')` overlays during hold and animates 0 → 1.
- **D-23 (no haptics):** Searched `lib/core/parent_gate/`: zero `HapticFeedback` references. Confirmed.
- **D-24 (Stillingar placeholder):** `ParentSettingsScreen` shows `Text('Stillingar')` in body and `AppBar(title: Text('Stillingar'))`.
- **D-25 (Navigator 1.0):** All transitions use `Navigator.of(context).push(MaterialPageRoute<void>(builder: ...))`. No `go_router` import in pubspec.yaml or anywhere in the source tree.

## Implementation note (deviation from plan: GestureDetector → Listener)
Plan 03 specified `GestureDetector(onTapDown/onTapUp/onTapCancel)` for the gate. The actual implementation uses `Listener(onPointerDown/onPointerUp/onPointerCancel)` because:
- `GestureDetector` runs the gesture-arena algorithm. When the parent widget is wrapped by other gesture detectors (e.g., InkWell ancestors, AppBar's tap targets), the long-press recognizer can lose the arena to a sibling tap recognizer at the ~500ms threshold, killing the timer mid-hold.
- `Listener` reports raw pointer events without arena participation, giving us a clean "begin timer the instant a finger touches" semantic. This matches D-22's "long-press *anywhere* on the wrapped surface starts a 3-second timer" wording better than `GestureDetector`'s long-press detector would.
- Functional outcome is identical to the plan; widget tests confirm 3-second hold completes and short hold aborts.

## Commits
- `7ff0c05` test(01-03): add failing tests for two-room shell + parent gate (RED)
- `b09d95f` feat(01-03): implement ParentGate primitive (3s hold + ring fill, no haptics) (GREEN)
- `22c03c6` feat(01-03): two-room home shell + Stafir/Tölur/ParentSettings placeholders + parent-gate-wired settings entry (GREEN)

## Self-Check
- All 54 tests pass under `flutter test`
- `flutter analyze` clean (0 issues)
- `dart format --set-exit-if-changed .` clean
- `lib/core/parent_gate/parent_gate_controller.dart` is pure Dart (verified — only `import 'dart:async'`)
- HomePage / RoomButton / room placeholders / parent_settings all rendered
- Tap routes verified by widget test (find.byType(StafirRoom)/TolurRoom/ParentSettingsScreen)

## Status
**COMPLETE — GREEN**. All Plan 03 success criteria met.
