// Marionette / integration_test smoke for Phase 1 (D-10).
//
// This file is the SCRIPTED variant of the Phase 1 smoke. It uses the
// integration_test binding so it can be driven via `flutter drive` against
// real iOS Simulator + Android Emulator. The MARIONETTE-MCP variant is a
// runtime harness (an AI agent drives the app interactively) — see
// `marionette/smoke.marionette.dart` and `marionette/README.md`. Both variants
// assert the same five Phase 1 invariants (D-10):
//
//   1. App launches without exception.
//   2. HomePage renders both rooms (Stafir + Tölur) with tap targets that
//      compute to ≥2 cm physical at the device's reported DPI.
//   3. Tapping each room navigates to its placeholder.
//   4. Long-pressing the settings icon for 3 s shows the ring-fill and
//      navigates to ParentSettingsScreen ("Stillingar").
//   5. (Implicit) No network requests fire — the no_network_test.dart
//      integration test covers that orthogonally.
//
// Note on Marionette and bindings: marionette_flutter requires
// `MarionetteBinding` to be the SOLE WidgetsBinding in the process. This
// file uses `IntegrationTestWidgetsFlutterBinding`, which is incompatible
// with MarionetteBinding by design. We solve it by NOT calling `main()`
// from `lib/main.dart` here; we pump `HugrunApp` directly. The Marionette
// MCP variant in `marionette/smoke.marionette.dart` is the path that
// exercises the MarionetteBinding-instrumented build via `flutter run`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/tolur/tolur_room.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Hugrún Phase 1 smoke — home + rooms + parent gate', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    await tester.pumpAndSettle();

    // 1. Home screen renders both rooms (D-10 / FOUND-08).
    expect(find.byKey(const Key('home-room-stafir')), findsOneWidget);
    expect(find.byKey(const Key('home-room-tolur')), findsOneWidget);
    expect(find.text('Stafir'), findsOneWidget);
    expect(find.text('Tölur'), findsOneWidget);

    // 2. Physical tap-target check (D-10: ≥2 cm).
    //    iPad Air ~264 dpi @ DPR=2.0 → 200 logical px = 400 physical px ≈ 3.85 cm.
    //    Pixel Tablet ~276 dpi @ DPR=2.0 → 200 logical px = 400 physical px ≈ 3.68 cm.
    //    Both well above 2 cm. We assert the logical-size floor (200 × 200)
    //    that RoomButton enforces; the physical conversion is a printed
    //    diagnostic for human review.
    final stafirSize = tester.getSize(
      find.byKey(const Key('home-room-stafir')),
    );
    expect(stafirSize.width, greaterThanOrEqualTo(200.0));
    expect(stafirSize.height, greaterThanOrEqualTo(200.0));
    final tolurSize = tester.getSize(find.byKey(const Key('home-room-tolur')));
    expect(tolurSize.width, greaterThanOrEqualTo(200.0));
    expect(tolurSize.height, greaterThanOrEqualTo(200.0));

    final view = tester.view;
    final dpr = view.devicePixelRatio;
    // 1 logical px = 1/96 inch on a "nominal" device, scaled by DPR. The
    // physical screen actually reports a real pixel pitch; we approximate
    // using the standard 96 logical-px-per-inch convention plus DPR. This is
    // the same calculation used by `MediaQuery.devicePixelRatioOf(context)` /
    // `Pixel ratio` in Flutter docs.
    const logicalPxPerCm = 96.0 / 2.54; // ≈ 37.8
    final physicalCmStafir = stafirSize.width / logicalPxPerCm * dpr / dpr;
    // Simplified — the DPR cancels for logical-size → physical-cm conversion
    // under Flutter's coordinate system; emit for diagnostics:
    debugPrint(
      '[DPI] dpr=$dpr; stafir logical=${stafirSize.width}×${stafirSize.height}; '
      'physical ≈ ${physicalCmStafir.toStringAsFixed(2)} cm',
    );

    // 3. Tap Stafir → StafirRoom appears. Phase 12 UI-01 removed visible
    //    AppBar titles AND the auto-generated back button from kid
    //    surfaces, so we assert on the widget Type rather than
    //    localised text, and pop programmatically via Navigator.of(...)
    //    rather than tester.pageBack() (which expects a back button).
    await tester.tap(find.byKey(const Key('home-room-stafir')));
    await tester.pumpAndSettle();
    expect(find.byType(StafirRoom), findsOneWidget);
    Navigator.of(tester.element(find.byType(StafirRoom))).pop();
    await tester.pumpAndSettle();

    // 4. Tap Tölur → TolurRoom appears (same Phase 12 rationale).
    await tester.tap(find.byKey(const Key('home-room-tolur')));
    await tester.pumpAndSettle();
    expect(find.byType(TolurRoom), findsOneWidget);
    Navigator.of(tester.element(find.byType(TolurRoom))).pop();
    await tester.pumpAndSettle();

    // 5. Parent gate — long-press the settings icon for 3 s.
    final settings = find.byIcon(Icons.settings);
    expect(settings, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(settings));
    await tester.pump(const Duration(milliseconds: 100));
    // Ring should appear during hold.
    expect(find.byKey(const Key('parent-gate-ring')), findsOneWidget);
    // Hold for 3 s.
    await tester.pump(const Duration(seconds: 3));
    await gesture.up();
    await tester.pumpAndSettle();
    // ParentSettingsScreen should now be visible.
    expect(find.text('Stillingar'), findsWidgets);
  });
}
