---
phase: 05-letter-to-word-matching
plan: 03
type: tdd
wave: 3
depends_on:
  - 05-01
  - 05-02
files_modified:
  - lib/features/stafir/stafir_mode.dart
  - lib/features/stafir/widgets/stafir_mode_toggle.dart
  - lib/features/stafir/stafir_room.dart
  - test/features/stafir/widgets/stafir_mode_toggle_test.dart
  - test/features/stafir/stafir_room_test.dart
  - integration_test/stafir_matching_flow_test.dart
autonomous: true
requirements:
  - MATCH-01
tags: [stafir, mode-toggle, integration, parent-gate-reuse]

must_haves:
  truths:
    - "StafirRoom renders the existing letter grid by default (Letters mode)"
    - "Top-right corner shows a small icon-only toggle button (no text labels — STAFIR-08 spirit)"
    - "Toggle requires a 3-second hold to activate (kid-mode safe; D-01)"
    - "Hold-to-toggle reuses the Phase 1 ParentGateController state machine (no duplicate timer logic)"
    - "Releasing the hold before 3s does NOT switch modes (and does NOT trip a parent gate)"
    - "After successful 3s hold, StafirRoom swaps to render MatchingActivity (Match mode)"
    - "Holding the toggle again for 3s in Match mode swaps back to Letters mode"
    - "An integration test exercises the full child-perspective flow: open Stafir → tap letter (audio fires) → hold toggle 3s → matching screen → tap wrong letter (NO audio) → tap correct letter (audio fires + celebration) → auto-advance to next round"
  artifacts:
    - path: "lib/features/stafir/stafir_mode.dart"
      provides: "StafirMode enum (letters, match) — pure-Dart-friendly constant"
      contains: "enum StafirMode"
    - path: "lib/features/stafir/widgets/stafir_mode_toggle.dart"
      provides: "Small icon-only widget that wraps a hold-3s gesture; calls onToggle on completion"
      contains: "class StafirModeToggle"
    - path: "lib/features/stafir/stafir_room.dart"
      provides: "Updated StafirRoom: Stack(LetterGrid OR MatchingActivity, StafirModeToggle in top-right)"
      contains: "StafirMode"
    - path: "test/features/stafir/widgets/stafir_mode_toggle_test.dart"
      provides: "Widget tests: icon-only render, 3s hold fires onToggle, early release does not"
    - path: "test/features/stafir/stafir_room_test.dart"
      provides: "Updated tests: mode switching shows correct child widget"
    - path: "integration_test/stafir_matching_flow_test.dart"
      provides: "End-to-end: home → Stafir → letters tap → toggle hold → matching tap flow"
  key_links:
    - from: "lib/features/stafir/widgets/stafir_mode_toggle.dart"
      to: "lib/core/parent_gate/parent_gate_controller.dart"
      via: "reuses ParentGateController state machine for hold-3s timing (D-01)"
      pattern: "ParentGateController"
    - from: "lib/features/stafir/stafir_room.dart"
      to: "lib/features/stafir/matching/matching_activity.dart"
      via: "renders MatchingActivity when StafirMode.match is selected"
      pattern: "MatchingActivity"
    - from: "integration_test/stafir_matching_flow_test.dart"
      to: "integration_test/test_helpers/fake_audio_engine.dart"
      via: "FakeAudioEngine asserts wrong-tap silence + correct-tap audio in full flow"
      pattern: "FakeAudioEngine"
---

<objective>
Wire the matching activity into the existing StafirRoom by adding a kid-safe mode toggle (Letters ↔ Match). The toggle is a small top-right icon that requires a 3-second hold to activate, reusing the Phase 1 `ParentGateController` state machine so we don't duplicate hold-timing logic. End the phase with an integration test that walks through the full child experience: tap letters → switch modes → tap wrong (silent) → tap correct (celebrate + advance).

Purpose:
- Make the matching activity reachable from a child's tablet in the same room as the letter grid (D-01, MATCH-01).
- Prevent accidental mode switches during play — the 3s hold is short enough for an adult to do casually, long enough that a child mid-tap won't trigger it (D-01).
- Reuse the parent gate's hold mechanic so we have ONE source of truth for "press-and-hold-N-seconds" timing (D-01 reuse note).
- Prove the entire phase loop works end-to-end via integration_test (D-18).

Output:
- `StafirMode` enum.
- `StafirModeToggle` widget — icon-only, hold-to-engage.
- `StafirRoom` updated to swap children based on mode.
- Updated `stafir_room_test.dart` and a new integration test.

Wave 3 — depends on 05-01 (round generator) and 05-02 (matching activity).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/05-letter-to-word-matching/05-CONTEXT.md
@.planning/phases/05-letter-to-word-matching/05-01-PLAN-round-generator.md
@.planning/phases/05-letter-to-word-matching/05-02-PLAN-matching-activity-widget.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-SUMMARY.md

@lib/features/stafir/stafir_room.dart
@lib/features/stafir/widgets/letter_grid.dart
@lib/features/stafir/example_word_resolver.dart
@lib/core/parent_gate/parent_gate.dart
@lib/core/parent_gate/parent_gate_controller.dart
@integration_test/stafir_flow_test.dart
@integration_test/test_helpers/fake_audio_engine.dart

<interfaces>
<!-- Existing widgets/state machines reused. -->

From lib/core/parent_gate/parent_gate_controller.dart (REUSED):
```dart
class ParentGateController {
  ParentGateController({required Duration duration, required void Function() onCompleted});
  void onPressStart();   // begins hold timer
  void onPressEnd();     // aborts if not yet completed
  void dispose();        // cancels pending timer
  bool get isHolding;
  bool get isCompleted;
}
```
Pure-Dart, no Flutter dependency. The mode toggle widget uses Flutter Listener
events to drive ParentGateController callbacks — same pattern as ParentGate
widget itself. We do NOT reuse the ParentGate widget directly because:
  - We don't want the visible ring (the toggle should be small + minimal).
  - ParentGate wraps a child to gate it; we want a button-like element.
  - The CONTROLLER (state machine) is the reusable part; the chrome differs.

From lib/features/stafir/stafir_room.dart (current Phase 4 implementation):
```dart
class StafirRoom extends ConsumerStatefulWidget { ... }
class _StafirRoomState extends ConsumerState<StafirRoom> {
  final ExampleWordOverlayController _overlayCtl = ExampleWordOverlayController();
  void _onLetterTap(IcelandicLetter letter) { /* dispatches to AudioEngine */ }
  Widget build() => Scaffold(
    appBar: AppBar(title: const Text('Stafir')),
    body: SafeArea(child: Stack([LetterGrid(...), ExampleWordOverlay(...)])),
  );
}
```
The body's Stack is what we extend with a third child (the mode toggle) and a
mode-conditional swap of the first child (LetterGrid vs MatchingActivity).

From lib/features/stafir/matching/matching_activity.dart (Plan 05-02 output):
```dart
class MatchingActivity extends ConsumerStatefulWidget {
  const MatchingActivity({super.key});
}
```
Self-contained — schedules its own first-round generation in initState.

From integration_test/stafir_flow_test.dart:
- Pattern for booting the app under a ProviderScope with FakeAudioEngine override.
- Uses `WidgetTester` + `find.byKey` + `tester.tap` + `tester.pumpAndSettle`.
</interfaces>
</context>

<tasks>

<task type="tdd" tdd="true">
  <name>Task 1: StafirMode enum + StafirModeToggle widget (RED + GREEN + REFACTOR)</name>
  <files>
    lib/features/stafir/stafir_mode.dart,
    lib/features/stafir/widgets/stafir_mode_toggle.dart,
    test/features/stafir/widgets/stafir_mode_toggle_test.dart
  </files>
  <behavior>
    Test M1 (enum): `StafirMode.values == [StafirMode.letters, StafirMode.match]`. (Locks enum order; lets `next()` extension unambiguously toggle.)
    Test M2 (icon-only render): Toggle widget contains exactly one Icon and ZERO Text widgets (D-01 — icon-only, STAFIR-08 spirit).
    Test M3 (mode-aware icon): When `currentMode: StafirMode.letters`, the icon is `Icons.image_outlined` (suggesting "switch to images/matching"). When `currentMode: StafirMode.match`, the icon is `Icons.grid_view_outlined` (suggesting "switch back to letter grid"). Asserted via `find.byIcon`.
    Test M4 (hold less than 3s does NOT toggle): Press down with `tester.startGesture(Offset)`, pump 1500ms, release. Assert the `onToggle` callback was NOT invoked (callback spy = a `int callCount = 0` closure passed to `onToggle: () => callCount++`).
    Test M5 (hold 3s DOES toggle): Press down, pump 3100ms (small buffer over 3000ms), release. Assert `callCount == 1`.
    Test M6 (release immediately on completion): After completion, the underlying ParentGateController's `isHolding` is false (verified via internal exposed state OR by attempting another hold immediately and asserting it can re-arm).
    Test M7 (no haptic feedback): `tester.binding.window` events do NOT include haptic calls (or assert via `HapticFeedback.method` not being invoked — match Phase 1 D-23 which forbids haptics on parent gate; consistent here).
    Test M8 (small footprint): The widget's intrinsic size is bounded (e.g. 48×48 logical px IconButton-equivalent). `find.byType(SizedBox).evaluate().first.size` or similar — flexible assertion, just confirm it's small (≤ 64×64).
    Test M9 (visible hold indicator — optional minimal): While holding, a subtle progress hint appears (e.g. an outlined ring around the icon that fills) so the adult knows the hold is registering. NOT visible when not holding. Asserted via a `Key('stafir-mode-toggle-hold-ring')` that exists only during hold. (Adult-aimed feedback, fine to render — not text, not score.)
    Test M10 (cancel on pointer cancel): Trigger a pointer cancel mid-hold. Assert callback NOT invoked even if duration would have elapsed.
  </behavior>
  <action>
    RED — Step A: Create `test/features/stafir/widgets/stafir_mode_toggle_test.dart` with all 10 tests above. Pattern after `lib/core/parent_gate/parent_gate.dart` and its test for hold timing (find a similar existing test under `test/core/parent_gate/` for the gesture-pump pattern; if absent, use `tester.startGesture(...)` + `await tester.pump(Duration(...))` + `gesture.up()`).
    Run `flutter test test/features/stafir/widgets/stafir_mode_toggle_test.dart` — must fail.
    Commit: `test(05-03): add failing tests for StafirMode enum + StafirModeToggle`.

    GREEN — Step B: Create `lib/features/stafir/stafir_mode.dart`:
    ```dart
    /// The Stafir room renders one of two child surfaces (D-01 / Phase 5).
    /// Order is locked: index 0 = letters (the original Phase 4 grid),
    /// index 1 = match (Phase 5 matching activity).
    enum StafirMode { letters, match }

    extension StafirModeToggleExt on StafirMode {
      StafirMode get next =>
          this == StafirMode.letters ? StafirMode.match : StafirMode.letters;
    }
    ```

    GREEN — Step C: Create `lib/features/stafir/widgets/stafir_mode_toggle.dart`:
    - StatefulWidget with required `StafirMode currentMode`, required `VoidCallback onToggle`, optional `holdDuration = const Duration(seconds: 3)`.
    - State holds: `late final ParentGateController _controller`, `late final AnimationController _ringAnim`, `bool _holding = false`.
    - `initState`:
      ```dart
      _controller = ParentGateController(
        duration: widget.holdDuration,
        onCompleted: () {
          if (!mounted) return;
          setState(() => _holding = false);
          _ringAnim.stop();
          _ringAnim.value = 0;
          widget.onToggle();
        },
      );
      _ringAnim = AnimationController(vsync: this, duration: widget.holdDuration);
      ```
      (Use `with TickerProviderStateMixin` since one ticker is enough but matches the project's existing pattern.)
    - `dispose`: dispose both _controller and _ringAnim.
    - `build`:
      ```dart
      final iconData = widget.currentMode == StafirMode.letters
          ? Icons.image_outlined
          : Icons.grid_view_outlined;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          setState(() => _holding = true);
          _controller.onPressStart();
          _ringAnim.forward(from: 0);
        },
        onPointerUp: (_) {
          if (!_holding) return;
          setState(() => _holding = false);
          _controller.onPressEnd();
          _ringAnim.stop();
          _ringAnim.value = 0;
        },
        onPointerCancel: (_) {
          if (!_holding) return;
          setState(() => _holding = false);
          _controller.onPressEnd();
          _ringAnim.stop();
          _ringAnim.value = 0;
        },
        child: SizedBox(
          width: 48, height: 48,
          child: Stack(alignment: Alignment.center, children: <Widget>[
            Icon(iconData, size: 28, color: const Color(0xFF555555)),
            if (_holding)
              Positioned.fill(
                child: IgnorePointer(
                  key: const Key('stafir-mode-toggle-hold-ring'),
                  child: AnimatedBuilder(
                    animation: _ringAnim,
                    builder: (context, _) => CircularProgressIndicator(
                      value: _ringAnim.value,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
      ```
    - Doc header citing D-01 (kid-safe hold mechanic, reuse ParentGateController), Phase 1 D-23 (no haptics).

    Run `flutter test test/features/stafir/widgets/stafir_mode_toggle_test.dart` — all 10 must pass.
    Commit: `feat(05-03): StafirMode enum + StafirModeToggle (3s hold, reuses ParentGateController)`.

    REFACTOR (likely): the press-up and pointer-cancel handlers are nearly identical. Extract `_endHold()`. Adjust if `flutter analyze` flags any duplication. Commit if applicable.
  </action>
  <verify>
    <automated>flutter test test/features/stafir/widgets/stafir_mode_toggle_test.dart &amp;&amp; flutter analyze lib/features/stafir/stafir_mode.dart lib/features/stafir/widgets/stafir_mode_toggle.dart</automated>
  </verify>
  <done>
    - `StafirMode` enum exists with both values + `next` extension.
    - `StafirModeToggle` reuses `ParentGateController` directly (grep `ParentGateController` in the new widget file returns 1+ hits).
    - Hold less than 3s aborts; hold 3s fires onToggle; pointer cancel aborts.
    - All 10 tests pass.
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 2: StafirRoom mode-aware body + updated widget tests (RED + GREEN)</name>
  <files>
    lib/features/stafir/stafir_room.dart,
    test/features/stafir/stafir_room_test.dart
  </files>
  <behavior>
    Test S1 (default mode = letters): On fresh mount, `find.byType(LetterGrid)` finds 1 widget; `find.byType(MatchingActivity)` finds 0.
    Test S2 (toggle visible top-right): `find.byType(StafirModeToggle)` finds 1 widget. Its position is top-right (assert via Positioned offsets — top &lt; 16 logical px from top, right &lt; 16 logical px from right edge of the body).
    Test S3 (mode swap shows MatchingActivity): Programmatically toggle the mode (simulate the toggle's onToggle callback firing — either by holding 3s in the test, or by exposing an internal `setMode` method `@visibleForTesting`). Pump. Assert `find.byType(MatchingActivity)` finds 1; `find.byType(LetterGrid)` finds 0.
    Test S4 (toggle back to letters): From Match mode, fire toggle again. Assert LetterGrid is back, MatchingActivity is gone.
    Test S5 (existing Phase 4 letter-grid test invariants STILL pass): The previous tests in this file (e.g. "tap letter A fires AudioEngine.play(letterA)") still pass — adding the mode toggle did not regress letter tap dispatch.
    Test S6 (no AppBar text changes): The Scaffold's AppBar still shows the title 'Stafir' — no per-mode title change (icon-only D-01 spirit; no text drift).
    Test S7 (toggle does NOT capture letter taps): The toggle's hit area is small (48×48) and positioned in the corner; tapping a letter tile in the same X coordinate (e.g. the rightmost tile in row 1) still routes to letter audio, not to the toggle. (Sanity test against z-order errors.)
  </behavior>
  <action>
    RED: Update `test/features/stafir/stafir_room_test.dart` (preserve existing Phase 4 tests; ADD S1..S7). For S3/S4, use an internal `@visibleForTesting` static const `kStafirInitialMode` parameter on `StafirRoom` OR expose `_StafirRoomState` mode via `tester.state` cast; the simplest is `tester.state<_StafirRoomState>(...).debugSetMode(StafirMode.match)`. Add a `@visibleForTesting void debugSetMode(StafirMode m)` to the state class.
    Run `flutter test test/features/stafir/stafir_room_test.dart` — must fail on the new tests (existing should pass).
    Commit: `test(05-03): add failing tests for StafirRoom mode-aware body`.

    GREEN: Update `lib/features/stafir/stafir_room.dart`:
    - Add field: `StafirMode _mode = StafirMode.letters;`
    - Add `@visibleForTesting void debugSetMode(StafirMode m) => setState(() => _mode = m);`
    - In `build`, reshape body:
      ```dart
      return Scaffold(
        appBar: AppBar(title: const Text('Stafir')),
        body: SafeArea(
          child: Stack(children: <Widget>[
            // Mode-conditional primary surface.
            switch (_mode) {
              StafirMode.letters => LetterGrid(onLetterTap: _onLetterTap),
              StafirMode.match => const MatchingActivity(),
            },
            // Letters-mode-only example word overlay.
            if (_mode == StafirMode.letters)
              IgnorePointer(child: ExampleWordOverlay(controller: _overlayCtl)),
            // Mode toggle, top-right.
            Positioned(
              top: 8, right: 8,
              child: StafirModeToggle(
                currentMode: _mode,
                onToggle: () => setState(() => _mode = _mode.next),
              ),
            ),
          ]),
        ),
      );
      ```
    - Add imports: `stafir_mode.dart`, `widgets/stafir_mode_toggle.dart`, `matching/matching_activity.dart`.
    - Update doc header to mention the Phase 5 mode toggle (D-01).

    Run `flutter test test/features/stafir/stafir_room_test.dart` — all S1..S7 + existing Phase 4 tests must pass.
    Commit: `feat(05-03): StafirRoom mode-aware body (Letters / Match) with hold toggle`.
  </action>
  <verify>
    <automated>flutter test test/features/stafir/ &amp;&amp; flutter analyze lib/features/stafir</automated>
  </verify>
  <done>
    - StafirRoom defaults to letters mode and renders LetterGrid as before.
    - Toggle (3s hold) swaps to MatchingActivity.
    - Phase 4 tap-to-hear behavior is preserved (existing tests still pass).
    - `flutter analyze` is clean for the modified file.
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 3: integration_test/stafir_matching_flow_test.dart — end-to-end flow (RED + GREEN)</name>
  <files>
    integration_test/stafir_matching_flow_test.dart
  </files>
  <behavior>
    Single integration test (one big `testWidgets`) that walks through:

    Step 1: Boot the app under ProviderScope with FakeAudioEngine override + RoundGenerator override (seeded, manifest has `wordHundur` only so correct letter is `h`).
    Step 2: Tap into Stafir room from home.
    Step 3: Tap a letter tile (e.g. 'a' if it's in the manifest, else any letter that maps to a UtteranceKey). Pump. Assert FakeAudioEngine.playCalls is non-empty (letter audio fired).
    Step 4: Locate the StafirModeToggle. Long-press it for 3+ seconds via `tester.startGesture` + `tester.pump(Duration(seconds: 3, milliseconds: 200))` + `gesture.up()`. Pump and settle. Assert `find.byType(MatchingActivity)` is now visible; `find.byType(LetterGrid)` is gone.
    Step 5: Find the round's options. Identify a WRONG letter tile (any tile whose letter is not 'h' — use the test's RoundGenerator override to know the correct letter and exclude it). Tap it. Pump 200ms. Assert: FakeAudioEngine has NOT received any new play calls since Step 3 (i.e. wrong tap was silent — MATCH-02). Assert: still on the same round (find the original round's letter tiles).
    Step 6: Tap the CORRECT letter (the 'h' tile). Pump 200ms. Assert: FakeAudioEngine.playCalls's last entry is `UtteranceKey.wordHundur` (D-21 — example word audio is the celebration cue). Assert: MatchingCelebration overlay is visible (find by the active key).
    Step 7: Pump 1.6 seconds (slightly past 1.5s auto-advance). Assert: a new round is rendered (celebration overlay no longer active; find the celebration's inactive state).
    Step 8: Toggle hold again (3s). Assert: back to LetterGrid.

    Throughout, assert no exceptions thrown, no Timer leaks (use `tester.binding.delayed(...)` semantics if needed).
  </behavior>
  <action>
    RED: Create `integration_test/stafir_matching_flow_test.dart` with the single `testWidgets` walking the 8 steps. Reuse `integration_test/test_helpers/fake_audio_engine.dart` and follow the structure of `integration_test/stafir_flow_test.dart` (Phase 4) for boot + ProviderScope override.
    Run: `flutter test integration_test/stafir_matching_flow_test.dart` — must fail (or partial-pass; depends on what's already wired). The failure should specifically fail at Step 4 or Step 5 if Tasks 1+2 above are not yet shipped — DO NOT ship this test in isolation.
    Commit: `test(05-03): add failing integration test for end-to-end matching flow`.

    GREEN: At this point Tasks 1 and 2 are complete; the integration test should pass without further implementation work. If it fails:
    - Check ProviderScope override list includes both `audioEngineProvider.overrideWithValue(fakeEngine)` AND `roundGeneratorProvider.overrideWithValue(seededGenerator)` AND `photoOverrideSourceProvider.overrideWithValue(const EmptyPhotoOverrideSource())` if needed.
    - Check that the home page → Stafir navigation key matches the existing Phase 4 integration test.
    - Check that the seeded RoundGenerator's first round matches assumptions (target = wordHundur, correct letter = 'h'). If the seed produces a different first round (e.g. options happen to omit 'h' due to a bug) — that's a Plan 05-01 regression, not a Plan 05-03 issue.
    - Address any flakiness from Timer/animation by using `tester.pumpAndSettle()` after toggle holds and after celebration triggers.

    Once green, commit: `feat(05-03): integration test passes — full Stafir Letters → Match flow verified`.
  </action>
  <verify>
    <automated>flutter test integration_test/stafir_matching_flow_test.dart</automated>
  </verify>
  <done>
    - Integration test passes on first run (or after minor wiring fixes in this task).
    - Test asserts wrong-tap silence in the integration context (not just unit context — D-18).
    - Test asserts mode toggle is reachable and reversible.
    - No new exceptions or timer-leak warnings during the test run.
  </done>
</task>

</tasks>

<verification>
- MATCH-01 fully reachable from a child's tap path: open app → Stafir room → mode toggle (adult helps with 3s hold) → matching activity → tap → progress.
- D-01 (mode toggle, 3s hold, kid-safe, reuses ParentGateController) exercised in Tests M4–M7 and S2.
- D-18 (integration test over 3+ rounds) exercised in Task 3 (covers the wrong/correct/advance/repeat cycle in a single integration test).
- LetterTile + AudioEngine + ParentGateController reuse confirmed by import grep:
  - `grep -rn 'LetterTile' lib/features/stafir/matching/` returns hits in matching_activity.dart only (no duplicate widget).
  - `grep -rn 'ParentGateController' lib/features/stafir/widgets/stafir_mode_toggle.dart` returns 1+ hits.
  - No new AudioPlayer instantiation outside `lib/core/audio/`.
- All Phase 4 tests still pass (regression check).
- `flutter analyze` clean.
- Banned package check (`tools/check-no-tracking.sh`) still passes — no new deps in pubspec.yaml.
</verification>

<success_criteria>
- 3 tasks complete with TDD red→green commits.
- Test count grows by ≥17 (Task 1: 10, Task 2: 7, Task 3: 1 long integration test ≈ counts as 1).
- Existing Phase 4 test suite unchanged — no regressions.
- `flutter test` all-green; `flutter test integration_test/` all-green.
- `flutter analyze` clean.
- All MATCH-01..04 are now demonstrably exercised in either unit, widget, or integration test layers.
- All D-01..D-21 referenced by tests or code in plans 05-01 / 05-02 / 05-03 (per coverage check below).
</success_criteria>

<output>
After completion, create `.planning/phases/05-letter-to-word-matching/05-03-SUMMARY.md` listing:
- Files created (lib + test + integration_test).
- Test count delta.
- Decisions exercised in this plan: D-01 (mode toggle), D-18 (integration test).
- Decisions exercised across the phase (cross-link 05-01-SUMMARY.md and 05-02-SUMMARY.md): D-01..D-21 all should be ✓.
- Confirmation: ParentGateController reused (not duplicated); LetterTile reused; AudioEngine reused.
- Note any deviations from PLAN; flag if any test was deferred (none should be — but document if it happens).
</output>
