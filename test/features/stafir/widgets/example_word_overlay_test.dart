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
    // Phase 11 note: the lexicon images now ship in the asset bundle
    // (assets/images/letters/words/hundur.webp etc.), so using a real
    // lexicon slug here would render Image.asset instead of the
    // placeholder. Use a deliberately-missing slug to keep this test
    // exercising the no-asset → placeholder-text fallback path.
    ctl.show('zz_no_asset');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Asset bundle does not have a 'zz_no_asset' image, so placeholder fires.
    expect(find.text('zz_no_asset'), findsOneWidget);
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
    // Phase 11 note: see comment in the previous test — use a slug with
    // no shipped image so the placeholder text path is exercised
    // independently of the (now real) lexicon asset bundle.
    ctl.show('zz_no_asset');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('zz_no_asset'), findsOneWidget);
    // Past the visibleDuration + fadeDuration:
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('zz_no_asset'), findsNothing);
  });
}
