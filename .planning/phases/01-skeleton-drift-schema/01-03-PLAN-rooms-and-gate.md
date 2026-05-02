---
phase: 01-skeleton-drift-schema
plan: 03
type: execute
wave: 2
depends_on:
  - "01-01"
files_modified:
  - lib/features/home/home_page.dart
  - lib/features/home/room_button.dart
  - lib/features/stafir/stafir_room.dart
  - lib/features/tolur/tolur_room.dart
  - lib/features/parent_settings/parent_settings_screen.dart
  - lib/core/parent_gate/parent_gate.dart
  - lib/core/parent_gate/parent_gate_controller.dart
  - lib/app/app.dart
  - test/features/home/home_page_test.dart
  - test/features/home/room_button_test.dart
  - test/features/stafir/stafir_room_test.dart
  - test/features/tolur/tolur_room_test.dart
  - test/features/parent_settings/parent_settings_screen_test.dart
  - test/core/parent_gate/parent_gate_test.dart
autonomous: true
requirements:
  - FOUND-08
  - FOUND-09

user_setup: []

must_haves:
  truths:
    - "Home screen shows two visible room entry points: Stafir and Tölur (FOUND-08)"
    - "Tapping Stafir navigates to a placeholder StafirRoom screen via Navigator 1.0 + MaterialPageRoute (D-25)"
    - "Tapping Tölur navigates to a placeholder TolurRoom screen via Navigator 1.0 + MaterialPageRoute (D-25)"
    - "A ParentGate widget primitive in lib/core/parent_gate/parent_gate.dart wraps any child widget (D-22)"
    - "Long-pressing the parent-gate-wrapped surface for 3 seconds completes the gate and navigates to the wrapped target screen"
    - "The parent gate displays a circular ring fill that animates from 0 to full as the 3-second timer progresses (D-22)"
    - "Releasing before 3 seconds aborts the gate (ring resets, no navigation)"
    - "ParentSettingsScreen exists as a placeholder showing the Icelandic word 'Stillingar' (D-24)"
    - "The parent gate primitive is wired into the home screen so an adult can hold the parent-settings entry point for 3s to reach ParentSettingsScreen"
    - "No haptic feedback is triggered on parent gate completion in v1 (D-23)"
  artifacts:
    - path: "lib/features/home/home_page.dart"
      provides: "Two-room home screen with parent-gate entry to settings"
      contains: "StafirRoom"
    - path: "lib/features/home/room_button.dart"
      provides: "Tappable room entry tile widget"
      contains: "class RoomButton"
    - path: "lib/features/stafir/stafir_room.dart"
      provides: "Placeholder Stafir room screen"
      contains: "class StafirRoom"
    - path: "lib/features/tolur/tolur_room.dart"
      provides: "Placeholder Tölur room screen"
      contains: "class TolurRoom"
    - path: "lib/features/parent_settings/parent_settings_screen.dart"
      provides: "Placeholder parent settings screen with 'Stillingar' label (D-24)"
      contains: "Stillingar"
    - path: "lib/core/parent_gate/parent_gate.dart"
      provides: "ParentGate widget primitive — 3s hold + ring fill animation (D-22)"
      contains: "class ParentGate"
    - path: "lib/core/parent_gate/parent_gate_controller.dart"
      provides: "ParentGateController state machine for the 3s hold timing (testable in isolation)"
      contains: "class ParentGateController"
  key_links:
    - from: "lib/features/home/home_page.dart"
      to: "lib/features/stafir/stafir_room.dart"
      via: "Navigator.push(MaterialPageRoute(builder: (_) => StafirRoom()))"
      pattern: "MaterialPageRoute.*StafirRoom"
    - from: "lib/features/home/home_page.dart"
      to: "lib/features/tolur/tolur_room.dart"
      via: "Navigator.push(MaterialPageRoute(builder: (_) => TolurRoom()))"
      pattern: "MaterialPageRoute.*TolurRoom"
    - from: "lib/features/home/home_page.dart"
      to: "lib/core/parent_gate/parent_gate.dart"
      via: "ParentGate(onCompleted: () => Navigator.push(...ParentSettingsScreen))"
      pattern: "ParentGate"
    - from: "lib/core/parent_gate/parent_gate.dart"
      to: "lib/core/parent_gate/parent_gate_controller.dart"
      via: "AnimationController-driven controller, 3000ms duration"
      pattern: "duration:.*Duration\\(seconds:\\s*3"
---

<objective>
Build the two-room home shell (FOUND-08) and the parent gate primitive (FOUND-09) — the visible chrome of Phase 1. Replace Plan 01's placeholder home page with a real `HomePage` that shows two `RoomButton`s ("Stafir", "Tölur") plus a parent-gate-wrapped entry point that, after a 3-second hold with an animated ring fill, navigates to a `ParentSettingsScreen` showing "Stillingar". Both rooms are placeholder Scaffolds in Phase 1; Phase 2-7 fills Stafir and Phase 8-9 fills Tölur.

Purpose: Implements FOUND-08 (two-room home shell with both rooms tappable to placeholders) and FOUND-09 (3s hold-to-open parent gate with visible ring fill, gating parent-only screens). This is the visible foundation Marionette E2E tests in Plan 04 will exercise.

Output: Three new screens (HomePage replacement, StafirRoom, TolurRoom, ParentSettingsScreen), one room-button widget, the ParentGate primitive + controller, and a comprehensive widget-test suite covering the gate's timing behavior and navigation paths.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/01-skeleton-drift-schema/01-CONTEXT.md
@.planning/phases/01-skeleton-drift-schema/01-01-SUMMARY.md
@.planning/research/ARCHITECTURE.md
@.planning/research/PITFALLS.md

<interfaces>
<!-- This plan creates the user-visible chrome of Phase 1. Plan 04 (Marionette
     E2E) consumes these widgets and asserts they behave correctly on real
     iOS/Android. The contracts below are what Plan 04 will tap and inspect. -->

From `lib/features/home/home_page.dart`:
```dart
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  // Renders Scaffold with:
  //   - Title "Hugrún"
  //   - Two RoomButtons stacked vertically (or side-by-side on tablet
  //     landscape) labeled "Stafir" and "Tölur"
  //   - A small ParentGate-wrapped entry point (gear/cog icon) that gates
  //     ParentSettingsScreen
}
```

From `lib/features/home/room_button.dart`:
```dart
class RoomButton extends StatelessWidget {
  final String label;            // "Stafir" or "Tölur"
  final VoidCallback onTap;
  final Key? testKey;            // semantic key for Marionette + widget tests
  const RoomButton({super.key, required this.label, required this.onTap, this.testKey});
}
```

From `lib/features/stafir/stafir_room.dart`:
```dart
class StafirRoom extends StatelessWidget {
  const StafirRoom({super.key});
  // Phase 1 placeholder — Scaffold with AppBar(title: 'Stafir') and
  // centered placeholder text. Phase 2/4 replaces body with the 32-letter grid.
}
```

From `lib/features/tolur/tolur_room.dart`:
```dart
class TolurRoom extends StatelessWidget {
  const TolurRoom({super.key});
  // Phase 1 placeholder — Scaffold with AppBar(title: 'Tölur') and
  // centered placeholder text. Phase 8 replaces body with digit grid.
}
```

From `lib/features/parent_settings/parent_settings_screen.dart`:
```dart
class ParentSettingsScreen extends StatelessWidget {
  const ParentSettingsScreen({super.key});
  // Phase 1 placeholder — Scaffold with AppBar(title: 'Stillingar') and
  // centered "Stillingar" text per D-24. Phase 4 fills with child name form.
}
```

From `lib/core/parent_gate/parent_gate.dart`:
```dart
class ParentGate extends StatefulWidget {
  /// The child widget that's tappable. The gate intercepts long-press
  /// gestures on it; a normal tap can still propagate via [onTap] if provided.
  final Widget child;
  /// Fires when the user holds for the full 3 seconds. Use this to navigate
  /// to the gated destination.
  final VoidCallback onCompleted;
  /// Optional fast-tap callback (NOT used for navigation in Phase 1; can be
  /// null). Kept in the API for Phase 4 if needed.
  final VoidCallback? onTap;
  /// Configurable for tests. Default 3 seconds (D-22).
  final Duration holdDuration;
  /// Diameter of the ring overlay in logical pixels. Default 64.
  final double ringDiameter;

  const ParentGate({
    super.key,
    required this.child,
    required this.onCompleted,
    this.onTap,
    this.holdDuration = const Duration(seconds: 3),
    this.ringDiameter = 64,
  });
}
```

From `lib/core/parent_gate/parent_gate_controller.dart`:
```dart
/// State machine for the parent gate. Pure Dart, no Flutter import — testable
/// in isolation without pumping widgets.
/// States: idle -> holding (timer running) -> completed | aborted
class ParentGateController {
  final Duration duration;
  final void Function() onCompleted;
  ParentGateController({required this.duration, required this.onCompleted});
  void onPressStart();
  void onPressEnd();
  void dispose();
  // Test-only fields:
  bool get isHolding;
  bool get isCompleted;
}
```

Existing from Plan 01:
- `lib/app/app.dart`: `HugrunApp` MaterialApp with `home: HomePage()` — this plan keeps the wiring; only `HomePage` body changes.
- `lib/features/home/home_page.dart`: Plan 01 placeholder — this plan REPLACES the body.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write failing tests for ParentGateController + ParentGate widget + room navigation (RED)</name>
  <files>
    test/core/parent_gate/parent_gate_test.dart,
    test/features/home/home_page_test.dart,
    test/features/home/room_button_test.dart,
    test/features/stafir/stafir_room_test.dart,
    test/features/tolur/tolur_room_test.dart,
    test/features/parent_settings/parent_settings_screen_test.dart
  </files>
  <behavior>
    parent_gate_test.dart (mix of unit tests on ParentGateController and widget tests on ParentGate):
    - Test 1: `ParentGateController(duration: 3s)` is in idle state initially (`isHolding == false`, `isCompleted == false`).
    - Test 2: After `onPressStart()`, `isHolding` is true.
    - Test 3: If `onPressEnd()` is called before `duration` elapses, `onCompleted` is NOT invoked and state returns to idle.
    - Test 4: If hold persists for `duration`, `onCompleted` IS invoked exactly once and `isCompleted == true`.
    - Test 5: `onPressStart()` after `onPressEnd()` mid-hold restarts the timer (does not resume).
    - Test 6 (widget): Pumping `ParentGate(holdDuration: 100ms, child: Text('press'), onCompleted: ...)` and a long-press for 100ms calls onCompleted (use `tester.longPress` and `tester.pump(Duration(milliseconds: 100))`).
    - Test 7 (widget): A short long-press (50ms when holdDuration is 100ms) does NOT call onCompleted.
    - Test 8 (widget): During hold, a `CircularProgressIndicator` (or equivalent ring widget) is visible and its value progresses from 0 toward 1.
    - Test 9 (widget): After `onPressEnd` mid-hold, the ring widget disappears or resets.
    - Test 10 (widget): Released before completion — no `Haptic` feedback fires (D-23 — verified by ensuring no `HapticFeedback` static calls; we can use `MethodChannelMock` or just assert no crash + no extra widget appears).

    home_page_test.dart (extends/replaces existing tests from Plan 01):
    - Test 11: HomePage shows two RoomButtons with labels "Stafir" and "Tölur".
    - Test 12: Tapping the "Stafir" RoomButton pushes a `MaterialPageRoute` whose builder returns a `StafirRoom`.
    - Test 13: Tapping the "Tölur" RoomButton pushes a `MaterialPageRoute` whose builder returns a `TolurRoom`.
    - Test 14: HomePage contains a ParentGate-wrapped widget with an icon (e.g. Icons.settings) gating the parent settings entry.
    - Test 15: Long-pressing the parent-gate icon for 3 seconds (use `pumpAndSettle` with simulated time) navigates to ParentSettingsScreen.

    room_button_test.dart:
    - Test 16: RoomButton renders the provided `label` text.
    - Test 17: Tapping a RoomButton invokes its `onTap` callback exactly once.
    - Test 18: RoomButton minimum tap target size is at least 88×88 logical pixels (proxy for the 2cm physical target on Hugrún's tablet — full physical sizing is verified in Plan 04 Marionette E2E).

    stafir_room_test.dart:
    - Test 19: StafirRoom Scaffold has an AppBar with title 'Stafir'.
    - Test 20: StafirRoom can be popped via the back button without crashing.

    tolur_room_test.dart:
    - Test 21: TolurRoom Scaffold has an AppBar with title 'Tölur'.
    - Test 22: TolurRoom can be popped via the back button without crashing.

    parent_settings_screen_test.dart:
    - Test 23: ParentSettingsScreen shows the text 'Stillingar' (D-24).
    - Test 24: ParentSettingsScreen has an AppBar.

    All tests MUST fail at this stage (RED) — production code doesn't exist.
  </behavior>
  <action>
    Write all six test files with the 24 tests described above. The tests import production paths that don't exist yet, producing compile errors as RED proof.

    Implementation notes for the executor:

    1. ParentGateController tests — pure Dart unit tests. No `pumpWidget`. Use a fake timer pattern: the controller takes a `Duration` and `onCompleted` callback; internally it uses `Timer(duration, onCompleted)` started on `onPressStart`. Tests can use Dart's `FakeAsync` from `package:fake_async` if needed (add to dev_dependencies if not already there) or just use `Future.delayed` with very short durations (5–10ms) and `await Future.delayed(15ms)`.

    2. ParentGate widget tests — use `flutter_test`'s built-in fake clock via `tester.pump(duration)`. Standard pattern:
       ```dart
       await tester.pumpWidget(MaterialApp(home: ParentGate(
         holdDuration: const Duration(milliseconds: 100),
         child: const SizedBox(width: 100, height: 100, child: Text('press')),
         onCompleted: () => completed = true,
       )));
       final gesture = await tester.startGesture(tester.getCenter(find.text('press')));
       await tester.pump(const Duration(milliseconds: 110));
       await gesture.up();
       expect(completed, isTrue);
       ```

    3. Ring fill assertion — the ParentGate widget overlays a `CircularProgressIndicator` (or custom CustomPainter ring) when actively holding. Tests look for a widget that exposes a `value` between 0 and 1. Use a `ValueKey` like `Key('parent-gate-ring')` in the production widget so tests can find it reliably.

    4. Navigation tests — use `find.byWidgetPredicate((w) => w is StafirRoom)` after `await tester.tap(...); await tester.pumpAndSettle();` to confirm the new route is on top.

    5. Tap-target-size test — use `tester.getSize(find.byType(RoomButton))` and assert `size.width >= 88 && size.height >= 88`. (Plan 04 Marionette E2E does the real-tablet ≥2cm assertion via DPI math.)

    6. After writing all tests, run `flutter test test/core/parent_gate/ test/features/home/ test/features/stafir/ test/features/tolur/ test/features/parent_settings/`. Tests must fail with compile errors — RED proof.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter pub get &amp;&amp; ! flutter test test/core/parent_gate/ test/features/home/ test/features/stafir/ test/features/tolur/ test/features/parent_settings/ 2&gt;&amp;1 | tee /tmp/hugrun-task1-red.log; grep -qE "error|Error|FAILED|cannot find|Undefined" /tmp/hugrun-task1-red.log</automated>
  </verify>
  <done>
    - All six test files exist with the 24 tests described above.
    - Running them fails with compile errors because production code is not yet implemented.
    - Commit: `test(01-03): add failing tests for two-room shell + parent gate (RED)`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Implement ParentGateController + ParentGate widget + ring fill (GREEN for gate)</name>
  <files>
    lib/core/parent_gate/parent_gate_controller.dart,
    lib/core/parent_gate/parent_gate.dart
  </files>
  <behavior>
    Tests 1–10 from parent_gate_test.dart pass GREEN. Tests 11–24 still fail (rooms/home not yet wired).
  </behavior>
  <action>
    Implement the parent gate primitive per D-22, D-23.

    1. Create `lib/core/parent_gate/parent_gate_controller.dart`:
       ```dart
       import 'dart:async';

       /// Pure-Dart state machine for the parent gate. No Flutter dependency
       /// (D-08 domain purity for testable logic). The widget wraps this with
       /// AnimationController for the visual ring; this controller owns the
       /// timing semantics: idle -> holding (timer running) -> completed | aborted.
       class ParentGateController {
         ParentGateController({
           required this.duration,
           required this.onCompleted,
         });

         final Duration duration;
         final void Function() onCompleted;

         Timer? _timer;
         bool _isHolding = false;
         bool _isCompleted = false;

         bool get isHolding => _isHolding;
         bool get isCompleted => _isCompleted;

         /// Begin the hold. Cancels any previous timer (restart, not resume).
         void onPressStart() {
           _timer?.cancel();
           _isHolding = true;
           _isCompleted = false;
           _timer = Timer(duration, () {
             _isHolding = false;
             _isCompleted = true;
             onCompleted();
           });
         }

         /// Release before duration. Aborts the timer; gate does not fire.
         /// Released after completion (rare race) is harmless.
         void onPressEnd() {
           if (_isCompleted) return;
           _timer?.cancel();
           _isHolding = false;
         }

         void dispose() {
           _timer?.cancel();
         }
       }
       ```

    2. Create `lib/core/parent_gate/parent_gate.dart`:
       ```dart
       import 'package:flutter/material.dart';
       import 'parent_gate_controller.dart';

       /// 3-second hold-to-open parent gate (D-22). Wraps any [child] widget;
       /// long-pressing it for [holdDuration] (default 3 s) calls [onCompleted].
       /// During hold, an animated ring fills clockwise around the press point.
       /// No haptic feedback in v1 per D-23.
       class ParentGate extends StatefulWidget {
         const ParentGate({
           super.key,
           required this.child,
           required this.onCompleted,
           this.onTap,
           this.holdDuration = const Duration(seconds: 3),
           this.ringDiameter = 64,
         });

         final Widget child;
         final VoidCallback onCompleted;
         final VoidCallback? onTap;
         final Duration holdDuration;
         final double ringDiameter;

         @override
         State<ParentGate> createState() => _ParentGateState();
       }

       class _ParentGateState extends State<ParentGate>
           with SingleTickerProviderStateMixin {
         late final AnimationController _animation;
         late final ParentGateController _controller;
         bool _isHolding = false;

         @override
         void initState() {
           super.initState();
           _animation = AnimationController(
             vsync: this,
             duration: widget.holdDuration,
           );
           _controller = ParentGateController(
             duration: widget.holdDuration,
             onCompleted: () {
               if (mounted) widget.onCompleted();
             },
           );
         }

         @override
         void dispose() {
           _animation.dispose();
           _controller.dispose();
           super.dispose();
         }

         void _start() {
           setState(() => _isHolding = true);
           _controller.onPressStart();
           _animation.forward(from: 0);
         }

         void _end() {
           setState(() => _isHolding = false);
           _controller.onPressEnd();
           _animation.stop();
           _animation.value = 0;
         }

         @override
         Widget build(BuildContext context) {
           return GestureDetector(
             behavior: HitTestBehavior.opaque,
             onTap: widget.onTap,
             onTapDown: (_) => _start(),
             onTapUp: (_) => _end(),
             onTapCancel: _end,
             child: Stack(
               alignment: Alignment.center,
               children: [
                 widget.child,
                 if (_isHolding)
                   IgnorePointer(
                     child: SizedBox(
                       key: const Key('parent-gate-ring'),
                       width: widget.ringDiameter,
                       height: widget.ringDiameter,
                       child: AnimatedBuilder(
                         animation: _animation,
                         builder: (context, _) => CircularProgressIndicator(
                           value: _animation.value,
                           strokeWidth: 4,
                         ),
                       ),
                     ),
                   ),
               ],
             ),
           );
         }
       }
       ```

       Notes:
       - Uses `onTapDown` / `onTapUp` (not `onLongPress`) because we want to begin the timer immediately on touch, not after the system long-press threshold (~500 ms). This gives the user 3 seconds total from touch, not 3 seconds after Flutter's long-press fires.
       - `IgnorePointer` on the ring overlay so it doesn't steal taps.
       - No `HapticFeedback` import — per D-23, no haptics in v1.

    3. Run `flutter test test/core/parent_gate/`. Tests 1–10 must pass GREEN. If a test fails, fix the implementation, not the test.

    4. Run `flutter analyze`. Must exit 0.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter analyze lib/core/parent_gate/ &amp;&amp; flutter test test/core/parent_gate/</automated>
  </verify>
  <done>
    - ParentGateController + ParentGate widget exist.
    - Tests 1–10 (parent_gate_test.dart) pass GREEN.
    - Ring fill animation is visible during hold and disappears on release.
    - No haptics fire (D-23).
    - `flutter analyze` exits 0.
    - Commit: `feat(01-03): implement ParentGate primitive (3s hold + ring fill, no haptics) (GREEN)`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Implement RoomButton, StafirRoom, TolurRoom, ParentSettingsScreen, and HomePage with rooms + parent-gate entry (GREEN for rooms)</name>
  <files>
    lib/features/home/room_button.dart,
    lib/features/home/home_page.dart,
    lib/features/stafir/stafir_room.dart,
    lib/features/tolur/tolur_room.dart,
    lib/features/parent_settings/parent_settings_screen.dart
  </files>
  <behavior>
    Tests 11–24 from home_page_test.dart, room_button_test.dart, stafir_room_test.dart, tolur_room_test.dart, parent_settings_screen_test.dart all pass GREEN.
    Tests 1–10 from Task 2 remain green.
  </behavior>
  <action>
    Implement the four screens + RoomButton, then rewire HomePage to use them. All navigation uses Navigator 1.0 + MaterialPageRoute (D-25) — go_router is explicitly NOT used.

    1. Create `lib/features/parent_settings/parent_settings_screen.dart` (D-24):
       ```dart
       import 'package:flutter/material.dart';

       /// Phase 1 placeholder. Phase 4 fills with child name form (PERS-01..03).
       /// 'Stillingar' is Icelandic for 'Settings' (D-24).
       class ParentSettingsScreen extends StatelessWidget {
         const ParentSettingsScreen({super.key});

         @override
         Widget build(BuildContext context) {
           return Scaffold(
             appBar: AppBar(title: const Text('Stillingar')),
             body: const Center(
               child: Text('Stillingar', style: TextStyle(fontSize: 24)),
             ),
           );
         }
       }
       ```

    2. Create `lib/features/stafir/stafir_room.dart`:
       ```dart
       import 'package:flutter/material.dart';

       /// Phase 1 placeholder for the Stafir (Letters) room.
       /// Phase 2 lands the 32-letter alphabet constant; Phase 4 fills the body
       /// with the tap-to-hear letter grid (STAFIR-01..10).
       class StafirRoom extends StatelessWidget {
         const StafirRoom({super.key});

         @override
         Widget build(BuildContext context) {
           return Scaffold(
             appBar: AppBar(title: const Text('Stafir')),
             body: const Center(
               child: Text('Stafir', style: TextStyle(fontSize: 32)),
             ),
           );
         }
       }
       ```

    3. Create `lib/features/tolur/tolur_room.dart`:
       ```dart
       import 'package:flutter/material.dart';

       /// Phase 1 placeholder for the Tölur (Numbers) room.
       /// Phase 8 fills the body with the digit grid (NUM-01..03).
       class TolurRoom extends StatelessWidget {
         const TolurRoom({super.key});

         @override
         Widget build(BuildContext context) {
           return Scaffold(
             appBar: AppBar(title: const Text('Tölur')),
             body: const Center(
               child: Text('Tölur', style: TextStyle(fontSize: 32)),
             ),
           );
         }
       }
       ```

    4. Create `lib/features/home/room_button.dart`:
       ```dart
       import 'package:flutter/material.dart';

       /// Generic room entry button. Phase 1 — text label only. Phase 4 may
       /// gain illustrations + per-room theming.
       class RoomButton extends StatelessWidget {
         const RoomButton({
           super.key,
           required this.label,
           required this.onTap,
         });

         final String label;
         final VoidCallback onTap;

         @override
         Widget build(BuildContext context) {
           return InkWell(
             onTap: onTap,
             child: Container(
               // Min 88x88 logical px tap target — proxy for the 2cm physical
               // target on Hugrún's tablet (verified end-to-end by Plan 04
               // Marionette E2E using device DPI).
               constraints: const BoxConstraints(minWidth: 200, minHeight: 200),
               margin: const EdgeInsets.all(16),
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surfaceContainerHighest,
                 borderRadius: BorderRadius.circular(24),
                 border: Border.all(
                   color: Theme.of(context).colorScheme.outline,
                   width: 2,
                 ),
               ),
               child: Center(
                 child: Text(
                   label,
                   style: Theme.of(context).textTheme.headlineLarge,
                 ),
               ),
             ),
           );
         }
       }
       ```

    5. Replace `lib/features/home/home_page.dart` body with the real two-room shell + parent-gate entry:
       ```dart
       import 'package:flutter/material.dart';

       import '../../core/parent_gate/parent_gate.dart';
       import '../parent_settings/parent_settings_screen.dart';
       import '../stafir/stafir_room.dart';
       import '../tolur/tolur_room.dart';
       import 'room_button.dart';

       /// Two-room home shell (FOUND-08) with a parent-gate-protected entry to
       /// settings (FOUND-09). Both rooms are Phase 1 placeholders; Phase 4
       /// (Stafir) and Phase 8 (Tölur) fill them. Navigator 1.0 (D-25).
       class HomePage extends StatelessWidget {
         const HomePage({super.key});

         @override
         Widget build(BuildContext context) {
           return Scaffold(
             appBar: AppBar(
               title: const Text('Hugrún'),
               actions: [
                 // Parent-gate-wrapped settings entry. Long-press 3s to open.
                 ParentGate(
                   onCompleted: () {
                     Navigator.of(context).push(
                       MaterialPageRoute<void>(
                         builder: (_) => const ParentSettingsScreen(),
                       ),
                     );
                   },
                   child: const Padding(
                     padding: EdgeInsets.all(12),
                     child: Icon(Icons.settings, size: 32),
                   ),
                 ),
               ],
             ),
             body: const SafeArea(
               child: Center(
                 child: _RoomGrid(),
               ),
             ),
           );
         }
       }

       class _RoomGrid extends StatelessWidget {
         const _RoomGrid();

         @override
         Widget build(BuildContext context) {
           // Tablet-friendly: side-by-side on landscape, stacked on portrait.
           return LayoutBuilder(
             builder: (context, constraints) {
               final isWide = constraints.maxWidth > 600;
               final children = [
                 RoomButton(
                   key: const Key('home-room-stafir'),
                   label: 'Stafir',
                   onTap: () => Navigator.of(context).push(
                     MaterialPageRoute<void>(
                       builder: (_) => const StafirRoom(),
                     ),
                   ),
                 ),
                 RoomButton(
                   key: const Key('home-room-tolur'),
                   label: 'Tölur',
                   onTap: () => Navigator.of(context).push(
                     MaterialPageRoute<void>(
                       builder: (_) => const TolurRoom(),
                     ),
                   ),
                 ),
               ];
               return isWide
                   ? Row(mainAxisAlignment: MainAxisAlignment.center, children: children)
                   : Column(mainAxisAlignment: MainAxisAlignment.center, children: children);
             },
           );
         }
       }
       ```

       Note: the existing Plan 01 widget tests asserted that HomePage contains a Scaffold and the MaterialApp has Icelandic locale — those still pass with this replacement. The "renders centered 'Hugrún' text" assertion from Plan 01's placeholder is no longer literally true (the title is now in the AppBar), but those tests asserted Scaffold presence + MaterialApp config, NOT the body text. Verify Plan 01 tests still pass after this swap; if any specifically check for the old centered text, update them to look for AppBar 'Hugrún' instead and document the test change in the commit.

    6. Run `flutter test`. ALL tests should pass:
       - Plan 01 tests (4 widget tests + skeleton tests + pubspec tests) — green
       - Plan 02 tests (DAO + bootstrap + migration) — green
       - This plan's tests 1–24 — green
       Total: ~30+ tests green.

    7. Run `flutter analyze`. Must exit 0.

    8. (Optional manual smoke) — if a device is attached, run `flutter run -d <device>`, tap each RoomButton (verify it navigates to placeholder), back out, hold the gear icon for 3s (ring fills, navigates to ParentSettingsScreen). Otherwise leave for Plan 04 Marionette E2E.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter analyze &amp;&amp; flutter test</automated>
  </verify>
  <done>
    - All four new screens (StafirRoom, TolurRoom, ParentSettingsScreen, HomePage update) exist.
    - RoomButton widget exists with min 88×88 tap target.
    - HomePage shows two RoomButtons + parent-gate-wrapped settings icon.
    - Tapping each RoomButton navigates to its placeholder via Navigator 1.0 + MaterialPageRoute (D-25).
    - Long-pressing the parent gate icon for 3s navigates to ParentSettingsScreen.
    - All 24 new tests pass GREEN; all Plan 01 + Plan 02 tests still pass.
    - `flutter analyze` exits 0.
    - Commit: `feat(01-03): two-room home shell + Stafir/Tölur/ParentSettings placeholders + parent-gate-wired settings entry (GREEN)`.
  </done>
</task>

</tasks>

<verification>
- `flutter analyze` exits 0.
- `flutter test` passes 30+ tests (cumulative across Plan 01, 02, 03).
- `dart format --set-exit-if-changed .` exits 0.
- HomePage shows two RoomButtons labeled "Stafir" and "Tölur" plus a parent-gate-wrapped settings icon.
- Tapping each room button navigates to its placeholder room screen using `Navigator.push(MaterialPageRoute(...))` (D-25).
- Long-pressing the parent gate icon for 3 seconds (with visible ring fill animation) navigates to ParentSettingsScreen showing "Stillingar".
- Releasing before 3s aborts the gate (no navigation, ring resets).
- No haptic feedback fires (D-23).
- `lib/core/parent_gate/parent_gate_controller.dart` is pure Dart (no Flutter imports — verified by Plan 05's domain-purity script later).
</verification>

<success_criteria>
1. Home screen shows two visible rooms (Stafir, Tölur) per FOUND-08.
2. Tapping Stafir opens a placeholder StafirRoom; tapping Tölur opens a placeholder TolurRoom.
3. The app has a 3-second hold-to-open parent gate primitive with a visible ring fill (FOUND-09 / D-22).
4. The parent gate gates a stub `ParentSettingsScreen` showing 'Stillingar' (D-24).
5. No haptic feedback on gate completion (D-23).
6. Routing uses Navigator 1.0 + MaterialPageRoute (D-25); go_router is NOT in pubspec.
7. ParentGateController is pure Dart (testable without Flutter); ParentGate widget composes it with AnimationController for the visual ring.
8. ~24 tests cover gate timing semantics, ring visibility, navigation paths, and screen rendering.
</success_criteria>

<output>
After completion, create `.planning/phases/01-skeleton-drift-schema/01-03-SUMMARY.md` covering:
- Files added (full list of widgets + tests)
- Test counts by file (parent_gate: 10, home_page: 5, room_button: 3, stafir: 2, tolur: 2, parent_settings: 2 = 24)
- Total cumulative passing tests after this plan
- Any deviations from CONTEXT.md decisions and why (should be zero)
- Confirmation that ParentGate uses 3s default + animated ring + no haptics
- Confirmation that navigation is Navigator 1.0 (no go_router import)
- Commit hashes for RED/GREEN x2 cycles (3 atomic commits expected)
</output>
