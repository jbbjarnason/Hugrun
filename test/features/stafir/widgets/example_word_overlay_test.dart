// Plan 04-04 RED tests for ExampleWordOverlay.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/features/stafir/widgets/example_word_overlay.dart';

void main() {
  testWidgets('starts hidden when controller has no word', (tester) async {
    final ctl = ExampleWordOverlayController();
    addTearDown(ctl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExampleWordOverlay(controller: ctl)),
      ),
    );
    // No content visible (overlay returns SizedBox.shrink when no slug).
    expect(find.byType(Container), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows placeholder when controller.show fires (no asset)', (
    tester,
  ) async {
    final ctl = ExampleWordOverlayController();
    addTearDown(ctl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExampleWordOverlay(
            controller: ctl,
            visibleDuration: const Duration(milliseconds: 100),
            fadeDuration: const Duration(milliseconds: 50),
          ),
        ),
      ),
    );
    ctl.show('hundur');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Either the image asset loads or the placeholder text shows.
    // In tests, asset bundle doesn't have the image, so placeholder fires.
    expect(find.text('hundur'), findsOneWidget);
    // Advance past the visible+fade so the pending timers fire before tear-
    // down (otherwise the no-pending-timers invariant trips).
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('hides after visibleDuration', (tester) async {
    final ctl = ExampleWordOverlayController();
    addTearDown(ctl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExampleWordOverlay(
            controller: ctl,
            visibleDuration: const Duration(milliseconds: 200),
            fadeDuration: const Duration(milliseconds: 50),
          ),
        ),
      ),
    );
    ctl.show('hundur');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('hundur'), findsOneWidget);
    // Past the visibleDuration + fadeDuration:
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('hundur'), findsNothing);
  });
}
