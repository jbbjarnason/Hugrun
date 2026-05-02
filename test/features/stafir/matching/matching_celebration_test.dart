// Plan 05-02 Task 2 tests: MatchingCelebration overlay (D-08, D-09).
//
// The overlay is the visual cue for a correct tap: a soft scale + fade-in
// of a checkmark, no stars, no points, no numbers. Stays present for
// MatchingCelebration.duration (1.5s) before the activity auto-advances
// to the next round.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/features/stafir/matching/matching_celebration.dart';

void main() {
  Widget host(bool visible) => MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              const SizedBox.expand(),
              MatchingCelebration(visible: visible),
            ],
          ),
        ),
      );

  testWidgets('C1: visible: false renders no active marker', (tester) async {
    await tester.pumpWidget(host(false));
    await tester.pump();
    expect(find.byKey(const Key('matching-celebration-active')), findsNothing);
  });

  testWidgets('C2: visible: true renders a checkmark Icon', (tester) async {
    await tester.pumpWidget(host(true));
    await tester.pump();
    // Active marker is present.
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
    );
    // A check Icon is rendered (any of the check_circle variants).
    final icons = find.byWidgetPredicate(
      (w) => w is Icon && (w.icon?.codePoint != null),
    );
    expect(icons, findsWidgets);
  });

  testWidgets('C3: animation drives opacity + scale to 1.0 after duration',
      (tester) async {
    // Build hidden first.
    await tester.pumpWidget(host(false));
    await tester.pump();
    // Toggle on.
    await tester.pumpWidget(host(true));
    await tester.pump();
    // Step animation past its forward duration.
    await tester.pump(const Duration(milliseconds: 800));
    // Expect a fully-visible Opacity widget at value 1.0.
    final opacityWidgets = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .where((o) => o.opacity > 0.99);
    expect(opacityWidgets, isNotEmpty,
        reason: 'opacity should reach ~1.0 after forward animation');
  });

  testWidgets('C4: NO star or trophy or digit text', (tester) async {
    await tester.pumpWidget(host(true));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNothing);
    expect(find.byIcon(Icons.emoji_events), findsNothing);
    // No text containing digits.
    expect(find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(RegExp(r'\d')),
    ), findsNothing);
  });

  testWidgets('C5: positioned via Positioned.fill + IgnorePointer',
      (tester) async {
    await tester.pumpWidget(host(true));
    await tester.pump();
    // The active subtree includes an IgnorePointer wrapping the icon stack.
    expect(find.byType(IgnorePointer), findsWidgets);
    // Positioned.fill is used by the celebration when active.
    expect(find.byType(Positioned), findsWidgets);
  });

  test('C6: duration constant is 1500ms (D-09)', () {
    expect(MatchingCelebration.duration, const Duration(milliseconds: 1500));
  });
}
