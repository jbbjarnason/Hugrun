---
phase: 01-skeleton-drift-schema
plan: 04
type: execute
wave: 3
depends_on:
  - "01-03"
files_modified:
  - pubspec.yaml
  - marionette/smoke.marionette.dart
  - marionette/README.md
  - integration_test/marionette_smoke_test.dart
  - test_driver/integration_driver.dart
  - tools/run-marionette.sh
autonomous: false

requirements:
  - FOUND-07

user_setup:
  - service: ios-simulator
    why: "Marionette E2E smoke test runs against an iOS Simulator (iPad Air) per D-11"
    env_vars: []
    dashboard_config:
      - task: "Confirm Xcode and at least one iPad Air simulator are installed"
        location: "Xcode → Settings → Platforms (or `xcrun simctl list devices`)"
  - service: android-emulator
    why: "Marionette E2E smoke test runs against an Android Emulator (Pixel Tablet) per D-11"
    env_vars: []
    dashboard_config:
      - task: "Confirm Android Studio + a Pixel Tablet AVD exist"
        location: "Android Studio → Tools → Device Manager (or `emulator -list-avds`)"

must_haves:
  truths:
    - "Marionette package (or its 2026 equivalent) is installed as a dev_dependency at a verified version"
    - "A Marionette smoke test exists at marionette/smoke.marionette.dart that exercises home + parent gate"
    - "The smoke test asserts: app launches without exceptions"
    - "The smoke test asserts: HomePage renders both RoomButtons (Stafir, Tölur) per D-10"
    - "The smoke test asserts: tapping each RoomButton navigates to its placeholder room (D-10)"
    - "The smoke test asserts: parent-gate hold for 3s shows ring fill animation and navigates to ParentSettingsScreen (D-10)"
    - "The smoke test asserts: physical tap target sizes for room buttons are at least 2cm × 2cm using device DPI"
    - "The smoke test runs successfully against iOS Simulator (iPad Air) locally"
    - "The smoke test runs successfully against Android Emulator (Pixel Tablet) locally"
    - "tools/run-marionette.sh launches the smoke test on a chosen platform with sensible defaults"
    - "marionette/README.md documents the actual package name + version installed (since CONTEXT D-09 flagged that name might not be 'marionette')"
  artifacts:
    - path: "pubspec.yaml"
      provides: "marionette dev_dependency at verified version"
      contains: "marionette"
    - path: "marionette/smoke.marionette.dart"
      provides: "End-to-end smoke test script"
      contains: "MarionetteTest"
    - path: "marionette/README.md"
      provides: "Documentation: package name resolved, how to run, ground-truth versions"
      contains: "marionette"
    - path: "integration_test/marionette_smoke_test.dart"
      provides: "integration_test entry point that Marionette drives"
      contains: "IntegrationTestWidgetsFlutterBinding"
    - path: "test_driver/integration_driver.dart"
      provides: "Driver for `flutter drive` orchestration of the integration test"
      contains: "integrationDriver"
    - path: "tools/run-marionette.sh"
      provides: "Convenience script: run-marionette.sh ios | android"
      contains: "flutter drive"
  key_links:
    - from: "marionette/smoke.marionette.dart"
      to: "lib/features/home/home_page.dart"
      via: "Marionette finds RoomButton by Key('home-room-stafir') / Key('home-room-tolur')"
      pattern: "home-room-(stafir|tolur)"
    - from: "marionette/smoke.marionette.dart"
      to: "lib/core/parent_gate/parent_gate.dart"
      via: "Marionette long-presses the settings icon and asserts ring widget appears"
      pattern: "parent-gate-ring"
    - from: "tools/run-marionette.sh"
      to: "marionette/smoke.marionette.dart"
      via: "flutter drive --driver=test_driver/integration_driver.dart --target=integration_test/marionette_smoke_test.dart"
      pattern: "flutter drive"
---

<objective>
Install Marionette (the project-mandated E2E framework — D-09) and ship a single smoke test that, on both iOS Simulator (iPad Air) and Android Emulator (Pixel Tablet), launches the Hugrún app, asserts the home screen renders both rooms, taps into each room, and exercises the 3-second parent gate down to the ring-fill animation.

Purpose: Implements FOUND-07 (Marionette E2E test harness installed, configured, and runs at least one smoke test on both iOS and Android). Plan 05 then wires this same smoke test into a GitHub Actions macOS job. Without this plan, FOUND-07 is unmet and the project's "TDD with Marionette" project-level constraint has no E2E layer.

Output: Marionette installed at a verified version, one smoke test script, an integration_test entry point, a `flutter drive` test_driver, a convenience `tools/run-marionette.sh` script, and documentation of the actual package name + version since CONTEXT D-09 flagged that "marionette" might not be the right pub.dev name in 2026.
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
@.planning/phases/01-skeleton-drift-schema/01-03-SUMMARY.md
@.planning/research/STACK.md

<interfaces>
<!-- This plan exercises the Plan 03 home shell + parent gate end-to-end on real
     simulators/emulators. It does NOT add new production code — only test
     harness, smoke script, and docs. -->

Existing widgets we drive (from Plan 03):
- `HomePage` AppBar settings icon → wrapped in ParentGate
- `RoomButton(key: Key('home-room-stafir'))`
- `RoomButton(key: Key('home-room-tolur'))`
- `ParentGate` ring overlay → `Key('parent-gate-ring')`
- `StafirRoom` AppBar title 'Stafir'
- `TolurRoom` AppBar title 'Tölur'
- `ParentSettingsScreen` body text 'Stillingar'

These keys + AppBar titles are the test fixtures Marionette uses to find widgets across platforms.

Marionette package (D-09 — pub.dev name verified at install time):
```dart
// marionette/smoke.marionette.dart (skeleton)
import 'package:marionette/marionette.dart';  // <- exact import path verified at install

void main() {
  marionetteTest('Hugrún Phase 1 smoke', (m) async {
    await m.launch();
    await m.expect(find.text('Stafir')).toExist();
    // ... etc.
  });
}
```
</interfaces>
</context>

<tasks>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 1 (CHECKPOINT): Verify Marionette package name on pub.dev (D-09 escalation gate)</name>
  <what-built>
    Plan 04's first action: confirm what package CONTEXT D-09 calls "Marionette" actually is on pub.dev as of execution time. CONTEXT explicitly notes: "verify name and version at install time; if naming differs from `marionette`, document in CONTEXT or escalate."
    
    Before this checkpoint, the executor has run:
    - `flutter pub search marionette` (or `dart pub` equivalent)
    - Inspected https://pub.dev/packages/marionette
    - Inspected pub.dev for any of: `marionette`, `marionette_flutter`, `marionette_test`, or alternative names
    - Captured the exact package name + latest stable version + license + maintainer
    - Captured the example/README from pub.dev to confirm it's an E2E test framework (not, e.g., an unrelated mocking library)
    
    The executor brings the findings to the user.
  </what-built>
  <how-to-verify>
    Confirm one of three outcomes:

    1. **`marionette` exists on pub.dev as the expected E2E framework**: The package is published, last updated within ~12 months, README shows it drives Flutter widgets via integration_test, and it is by a recognizable maintainer. → Approve and proceed to Task 2 with the captured version.

    2. **`marionette` exists but the API/docs don't match an E2E framework**: It's a different library (e.g., a mocking helper, a ROS-style robotics tool, etc.). → Investigate alternatives that the user mentioned (`marionette_test`, `flutter_marionette`, etc.) and report findings. User decides which to use OR escalates to a project-level decision change.

    3. **No package matching the description exists**: The user's "Marionette" reference is to a not-yet-published or internal package. → Escalate. User decides whether to (a) wait for it, (b) substitute with `patrol` or stock `integration_test` (NOTE: STACK.md specifically flags `patrol` as "skip — heavyweight"; this is a project-level decision change), or (c) write a thin local Marionette-like wrapper around `integration_test`.

    Steps for the user:
    - Read the executor's findings (will be presented as a chat message before this checkpoint pauses).
    - Visit https://pub.dev/packages/marionette in a browser to confirm.
    - Approve the proposed path forward.
  </how-to-verify>
  <resume-signal>
    Reply with one of:
    - `approved: marionette ^X.Y.Z` (proceed with that exact version)
    - `approved: <alternative-package> ^X.Y.Z` (proceed with the user-chosen alternative)
    - `escalate` (project-level decision needed; pause planning, possibly trigger /gsd-discuss-phase update)
  </resume-signal>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Install Marionette + write failing smoke test (RED)</name>
  <files>
    pubspec.yaml,
    marionette/smoke.marionette.dart,
    marionette/README.md,
    integration_test/marionette_smoke_test.dart,
    test_driver/integration_driver.dart
  </files>
  <behavior>
    A test that drives the app via Marionette + integration_test exists. Running it on a simulator/emulator FAILS at this point because (a) the smoke test asserts behaviors not yet wired, OR (b) the smoke test's assertion targets compile but the script logic is incomplete. Either way: RED is the verifiable property "this test can be invoked and it fails / errors out for a known reason."

    For pure TDD honesty: at this point we already have the production code (Plan 03 shipped HomePage, ParentGate, etc.). The "test-first" purity of TDD doesn't apply to E2E smokes against pre-built UI — we cannot make Marionette-against-nonexistent-UI fail in a useful way. So this task's RED proof is: smoke test FILE exists and compiles, and we've documented (in the commit message) one assertion that can briefly be made to fail (e.g., assert presence of widget Key('does-not-exist')) before being corrected in Task 3. This is a TDD spirit compromise — the executor must NOT skip this discipline simply because it's E2E.
  </behavior>
  <action>
    1. Add the user-approved Marionette package + version to pubspec.yaml under `dev_dependencies`. Use the exact name + version returned from Task 1's checkpoint. If the user approved an alternative (e.g., `patrol` after escalation), use that. The rest of this plan refers to "Marionette" generically.

       Also ensure `integration_test` is in dev_dependencies (Plan 01 already added it; verify).

       Run `flutter pub get`. Must succeed.

    2. Create `test_driver/integration_driver.dart`:
       ```dart
       import 'package:integration_test/integration_test_driver.dart';

       Future<void> main() => integrationDriver();
       ```

    3. Create `integration_test/marionette_smoke_test.dart` — the integration_test entry point Marionette drives:
       ```dart
       import 'package:flutter/material.dart';
       import 'package:flutter_riverpod/flutter_riverpod.dart';
       import 'package:flutter_test/flutter_test.dart';
       import 'package:integration_test/integration_test.dart';
       import 'package:hugrun/app/app.dart';

       void main() {
         IntegrationTestWidgetsFlutterBinding.ensureInitialized();

         testWidgets('Hugrún Phase 1 smoke — home + rooms + parent gate',
             (tester) async {
           await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
           await tester.pumpAndSettle();

           // 1. Home screen renders both rooms (FOUND-08).
           expect(find.byKey(const Key('home-room-stafir')), findsOneWidget);
           expect(find.byKey(const Key('home-room-tolur')), findsOneWidget);
           expect(find.text('Stafir'), findsOneWidget);
           expect(find.text('Tölur'), findsOneWidget);

           // 2. Tap Stafir → StafirRoom appears.
           await tester.tap(find.byKey(const Key('home-room-stafir')));
           await tester.pumpAndSettle();
           expect(find.text('Stafir'), findsWidgets);  // app bar + body
           // Pop back.
           await tester.pageBack();
           await tester.pumpAndSettle();

           // 3. Tap Tölur → TolurRoom appears.
           await tester.tap(find.byKey(const Key('home-room-tolur')));
           await tester.pumpAndSettle();
           expect(find.text('Tölur'), findsWidgets);
           await tester.pageBack();
           await tester.pumpAndSettle();

           // 4. Parent gate — long-press the settings icon for 3s.
           final settings = find.byIcon(Icons.settings);
           expect(settings, findsOneWidget);
           final gesture = await tester.startGesture(tester.getCenter(settings));
           await tester.pump(const Duration(milliseconds: 100));
           // Ring should appear during hold.
           expect(find.byKey(const Key('parent-gate-ring')), findsOneWidget);
           // Hold for 3s (use pump to advance time deterministically).
           await tester.pump(const Duration(seconds: 3));
           await gesture.up();
           await tester.pumpAndSettle();
           // ParentSettingsScreen should now be visible.
           expect(find.text('Stillingar'), findsWidgets);
         });
       }
       ```

       Note: this is a pure `integration_test`. Marionette wraps/parallelizes it across iOS + Android via `flutter drive`.

    4. Create `marionette/smoke.marionette.dart` — the Marionette-specific entry point. Exact API depends on the package version approved in Task 1. Use the maintainer's documented pattern. Skeleton:
       ```dart
       // Adjust import path per the package the user approved in Task 1.
       import 'package:marionette/marionette.dart';

       /// Marionette E2E smoke for Hugrún Phase 1 (D-10).
       /// Asserts: app launches, two rooms render, room nav works, parent gate
       /// opens after 3s hold. Runs on iPad Air simulator + Pixel Tablet AVD.
       Future<void> main() async {
         // The exact Marionette boilerplate may differ. The semantic is:
         //   1. Launch the app on the target device.
         //   2. Wait for HomePage.
         //   3. Assert RoomButton(Stafir) and RoomButton(Tölur) are visible.
         //   4. Tap each room, assert placeholder appears, pop back.
         //   5. Long-press the settings icon for 3 seconds.
         //   6. Assert ring appears mid-hold.
         //   7. Assert ParentSettingsScreen ('Stillingar') appears after release.
         //   8. Tablet tap target check: query device DPI, compute physical size
         //      of each RoomButton, assert >= 2cm × 2cm.
         //
         // If Marionette's API offers Page Object / step DSL, structure the test
         // accordingly. Otherwise raw await calls are fine.
         //
         // Fallback if Marionette package supports shelling out to flutter drive:
         //   await Marionette.drive(
         //     target: 'integration_test/marionette_smoke_test.dart',
         //     driver: 'test_driver/integration_driver.dart',
         //     devices: ['ios-simulator-ipad-air', 'android-emulator-pixel-tablet'],
         //   );
       }
       ```

       The executor MUST verify the exact API against the package's README + examples on pub.dev and produce a working test. If the package is a thin wrapper over `integration_test` + `flutter drive`, this file may simply be a small orchestrator that calls into the integration_test entry above. If Marionette is itself the test runner, this file is the primary test source and `integration_test/marionette_smoke_test.dart` becomes optional (but keep it — it's still useful for `flutter test integration_test/`).

    5. Add the physical-tap-target assertion. CONTEXT D-10 requires: "tap targets ≥2 cm physical." Implementation:
       ```dart
       // Inside the smoke test, after asserting RoomButtons exist:
       final mediaQuery = tester.element(find.byType(MaterialApp)).widget;
       // Compute the physical pixel-to-cm conversion:
       //   pxPerCm = devicePixelRatio * logicalPxPerCm
       // Where 1 inch = 2.54 cm and devices report DPI ~ pixels per inch.
       // For a tablet at 264 dpi (iPad Air), 2cm = ~208 px = ~104 logical px at 2.0 DPR.
       // We assert: tester.getSize(find.byKey(Key('home-room-stafir'))).width / dpr * 2.54 / 96 >= 2.0
       // ... or just assert logical size >= 200 (matches RoomButton's minWidth: 200) and
       // separately assert the device's DPR + screen DPI imply >= 2cm at runtime.
       ```
       Realistic Phase 1 approach: assert logical size >= 200×200 (which we already enforce in RoomButton) AND emit a printed line like `[DPI] device: $dpi → physical room button size: ${physical}cm`. The CI smoke test can then grep for that line and fail if physical < 2.0. Document the actual DPI math in a comment.

    6. Create `tools/run-marionette.sh`:
       ```bash
       #!/usr/bin/env bash
       set -euo pipefail
       PLATFORM="${1:-ios}"
       case "$PLATFORM" in
         ios)
           DEVICE_ID="$(xcrun simctl list devices available | grep -E 'iPad Air' | head -n1 | grep -oE '\([0-9A-F-]+\)' | tr -d '()')"
           if [[ -z "$DEVICE_ID" ]]; then
             echo "ERROR: No iPad Air simulator available. Install one in Xcode." >&2
             exit 1
           fi
           xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
           ;;
         android)
           AVD="$(emulator -list-avds | grep -E 'Pixel.*Tablet' | head -n1)"
           if [[ -z "$AVD" ]]; then
             echo "ERROR: No Pixel Tablet AVD. Create one in Android Studio." >&2
             exit 1
           fi
           emulator -avd "$AVD" -no-window -no-audio -no-snapshot &
           ADB_WAIT="$(adb wait-for-device shell getprop sys.boot_completed)"
           DEVICE_ID="$(adb devices | awk 'NR==2 {print $1}')"
           ;;
         *)
           echo "Usage: $0 ios|android" >&2
           exit 2
           ;;
       esac
       echo "Running Marionette smoke on $PLATFORM ($DEVICE_ID)..."
       flutter drive \
         --driver=test_driver/integration_driver.dart \
         --target=integration_test/marionette_smoke_test.dart \
         -d "$DEVICE_ID"
       ```
       `chmod +x tools/run-marionette.sh`.

    7. Create `marionette/README.md` documenting the resolved package name, version, and how to run:
       ```markdown
       # Marionette E2E

       **Package:** `<actual-name>` ^<actual-version>  (per CONTEXT D-09; resolved 2026-05-02)
       **Coverage:** Phase 1 smoke — home + rooms + parent gate (D-10).

       ## Run locally

       Prereqs:
       - iPad Air simulator installed (iOS): `xcrun simctl list devices`
       - Pixel Tablet AVD installed (Android): `emulator -list-avds`

       Run on iOS:
       ```
       tools/run-marionette.sh ios
       ```

       Run on Android:
       ```
       tools/run-marionette.sh android
       ```

       ## CI

       This smoke is also wired into `.github/workflows/ci.yml` job `marionette-e2e` on `macos-latest` (Plan 05). The CI matrix runs both platforms.

       ## Phase 1 assertions

       1. App launches without exception.
       2. HomePage shows `RoomButton('Stafir')` and `RoomButton('Tölur')`.
       3. Tap each room → placeholder loads.
       4. Long-press settings icon for 3s → ring fills → ParentSettingsScreen appears.
       5. Each RoomButton is ≥2 cm × 2 cm physical at the device's DPI (computed from MediaQuery + screen reports).
       ```

    8. Add a deliberately-failing assertion to demonstrate RED (then immediately remove in Task 3). E.g., `expect(find.byKey(Key('this-key-does-not-exist')), findsOneWidget);`. Run the test, capture failure output, then revert the line. Commit message documents the RED proof.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter pub get &amp;&amp; flutter analyze marionette/ integration_test/ test_driver/ &amp;&amp; test -x tools/run-marionette.sh</automated>
  </verify>
  <done>
    - Marionette package (verified name + version) is in pubspec.yaml dev_dependencies.
    - `flutter pub get` succeeds.
    - marionette/smoke.marionette.dart, integration_test/marionette_smoke_test.dart, test_driver/integration_driver.dart, tools/run-marionette.sh, marionette/README.md exist.
    - `flutter analyze` exits 0 on the new files.
    - tools/run-marionette.sh is executable.
    - Briefly-introduced failing assertion has been reverted; commit captures the RED proof.
    - Commit: `test(01-04): install Marionette + scaffold E2E smoke (RED proof)`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Run smoke test on iOS Simulator + Android Emulator (GREEN)</name>
  <files>
    marionette/smoke.marionette.dart,
    integration_test/marionette_smoke_test.dart,
    marionette/README.md
  </files>
  <behavior>
    The smoke test passes on:
    - iOS Simulator (iPad Air) — `tools/run-marionette.sh ios` exits 0
    - Android Emulator (Pixel Tablet) — `tools/run-marionette.sh android` exits 0

    All assertions from Task 2 (rooms render, room nav, parent gate timing, physical tap target ≥ 2cm) succeed.
  </behavior>
  <action>
    1. Boot an iPad Air simulator: `xcrun simctl list devices available | grep 'iPad Air'`. If none, install one via Xcode → Settings → Platforms.

    2. Run `tools/run-marionette.sh ios`. Capture output. Expected: smoke test passes; the test driver reports successful run with all assertions green.

    3. If the test fails, diagnose:
       - Widget Key not found? → confirm Plan 03's `Key('home-room-stafir')`, `Key('home-room-tolur')`, `Key('parent-gate-ring')` are committed and match.
       - 3s timer not firing inside `tester.pump(Duration(seconds: 3))`? → integration_test uses real time (not fake clock); use `tester.pump(Duration(milliseconds: 50))` in a loop while still holding the gesture if needed, OR adjust ParentGate to also accept a test-only override duration via a Provider/InheritedWidget. For Phase 1 simplicity, the integration test SHOULD use the real 3-second timer (acceptable on simulator).
       - DPI assertion failing on iPad Air simulator? → log `WidgetsBinding.instance.window.physicalSize` and `.devicePixelRatio` and recompute. iPad Air at 264 dpi gives 2cm = ~208 physical px; 200 logical px at DPR 2.0 = 400 physical px = ~3.85 cm. Should pass comfortably.

    4. Boot an Android Pixel Tablet AVD: `emulator -list-avds | grep Pixel.*Tablet`. If none, create one via Android Studio Device Manager.

    5. Run `tools/run-marionette.sh android`. Capture output. Expected: passes.

    6. If Android fails but iOS passed: typical issues:
       - Cold-start time longer on Android emulator → wrap initial `pumpAndSettle` with a longer timeout: `pumpAndSettle(timeout: Duration(seconds: 30))`.
       - DPR differences: Pixel Tablet AVD at 276 dpi at DPR 2.0 → 200 logical px = 400 physical px = ~3.7 cm. Passes.

    7. Update `marionette/README.md` "Phase 1 assertions" section with confirmed pass timestamps + emulator/simulator versions for traceability.

    8. Commit final passing state: `feat(01-04): Marionette smoke green on iOS Simulator + Android Emulator (GREEN)`.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; tools/run-marionette.sh ios &amp;&amp; tools/run-marionette.sh android</automated>
  </verify>
  <done>
    - `tools/run-marionette.sh ios` exits 0 (smoke test passes on iPad Air simulator).
    - `tools/run-marionette.sh android` exits 0 (smoke test passes on Pixel Tablet AVD).
    - All four Phase 1 assertions covered (home renders rooms; room nav; parent gate ring + completion; physical tap target).
    - marionette/README.md reflects the actually-tested environment versions.
    - Commit: `feat(01-04): Marionette smoke green on iOS Simulator + Android Emulator (GREEN)`.
  </done>
</task>

</tasks>

<verification>
- pubspec.yaml dev_dependencies contains the Marionette (or approved alternative) package at the version captured in Task 1's checkpoint.
- `tools/run-marionette.sh ios` runs and the smoke test exits 0.
- `tools/run-marionette.sh android` runs and the smoke test exits 0.
- `marionette/smoke.marionette.dart`, `integration_test/marionette_smoke_test.dart`, `test_driver/integration_driver.dart`, `marionette/README.md` are committed.
- `flutter analyze` exits 0 across new files.
- Plan 05 (CI) consumes this smoke test in its `marionette-e2e` job — no further changes here required.
</verification>

<success_criteria>
1. Marionette installed as a dev_dependency at a verified pub.dev version (D-09).
2. Phase 1 smoke test exists at `marionette/smoke.marionette.dart` with the integration_test entry at `integration_test/marionette_smoke_test.dart`.
3. Smoke test asserts (per D-10):
   - App launches without exceptions
   - HomePage renders both rooms (Stafir + Tölur) with tap targets ≥2 cm physical
   - Tapping each room navigates to its placeholder
   - Parent gate ring-fill completes after 3s sustained press
   - ParentSettingsScreen ('Stillingar') opens after gate completion
4. `tools/run-marionette.sh ios` succeeds against iPad Air simulator.
5. `tools/run-marionette.sh android` succeeds against Pixel Tablet AVD.
6. README documents the actual package name + version (since CONTEXT D-09 noted name uncertainty).
</success_criteria>

<output>
After completion, create `.planning/phases/01-skeleton-drift-schema/01-04-SUMMARY.md` covering:
- Marionette package name + version actually used (resolved at Task 1 checkpoint)
- iOS simulator version + iPad Air model used for verification
- Android emulator + Pixel Tablet AVD version used for verification
- Smoke test assertion list (with checkmarks)
- Run wall-clock times on each platform (for CI budgeting)
- Any deviations from CONTEXT D-09/D-10/D-11 (e.g., if user escalated to a different package, document why)
- Commit hashes
</output>
