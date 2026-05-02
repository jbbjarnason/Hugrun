// Phase 8 Plan 08-02 Workstream B — RED tests for NumberTile widget.
//
// Mirror of LetterTile (Phase 4) but renders a digit glyph instead of a
// letter glyph. Same locked palette, same tap-target dimensions, same
// scale animation, same synchronous-feedback contract (D-01, D-02; NUM-01).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/numbers/icelandic_number.dart';
import 'package:hugrun/core/numbers/numbers.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile_palette.dart';
import 'package:hugrun/features/tolur/widgets/number_tile.dart';

Widget _hostTile({
  required IcelandicNumber number,
  required int numberIndex,
  required ValueChanged<IcelandicNumber> onNumberTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: NumberTile(
            number: number,
            numberIndex: numberIndex,
            onNumberTap: onNumberTap,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('NumberTile rendering (NUM-08 — no instructions, no fail UI)', () {
    testWidgets('NT1: renders the digit glyph as a Text widget', (tester) async {
      await tester.pumpWidget(
        _hostTile(
          number: kIcelandicNumbers[2], // value=3
          numberIndex: 2,
          onNumberTap: (_) {},
        ),
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('NT2: renders only ONE Text widget (no labels, no instructions)',
        (tester) async {
      await tester.pumpWidget(
        _hostTile(
          number: kIcelandicNumbers[0], // value=1
          numberIndex: 0,
          onNumberTap: (_) {},
        ),
      );
      final textInTile = find.descendant(
        of: find.byType(NumberTile),
        matching: find.byType(Text),
      );
      expect(textInTile, findsOneWidget,
          reason: 'NUM-08: only the digit glyph, no labels');
    });

    testWidgets('NT3: renders no failure-state Icon (no error/check/close)',
        (tester) async {
      await tester.pumpWidget(
        _hostTile(
          number: kIcelandicNumbers[6], // value=7
          numberIndex: 6,
          onNumberTap: (_) {},
        ),
      );
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });
  });

  group('NumberTile sizing (NUM-01 — match Stafir tap target)', () {
    testWidgets('NT4: tap target ≥200 logical-px when given a 240×240 host',
        (tester) async {
      await tester.pumpWidget(
        _hostTile(
          number: kIcelandicNumbers[0],
          numberIndex: 0,
          onNumberTap: (_) {},
        ),
      );
      final size = tester.getSize(find.byType(NumberTile));
      expect(size.width, greaterThanOrEqualTo(200.0));
      expect(size.height, greaterThanOrEqualTo(200.0));
    });
  });

  group('NumberTile gesture (mirrors STAFIR-06 — synchronous feedback)', () {
    testWidgets('NT5: fires onNumberTap on tap-DOWN (before tap-up)',
        (tester) async {
      IcelandicNumber? tapped;
      await tester.pumpWidget(
        _hostTile(
          number: kIcelandicNumbers[3], // value=4
          numberIndex: 3,
          onNumberTap: (n) => tapped = n,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(NumberTile)),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(tapped, isNotNull);
      expect(tapped!.value, 4);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('NumberTile palette (D-01 — reuse Phase 4 locked palette)', () {
    testWidgets('NT6: applies paletteForIndex(numberIndex) to the BoxDecoration',
        (tester) async {
      await tester.pumpWidget(
        _hostTile(
          number: kIcelandicNumbers[0],
          numberIndex: 0,
          onNumberTap: (_) {},
        ),
      );
      final container = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(NumberTile),
            matching: find.byType(Container),
          ))
          .firstWhere((c) => c.decoration is BoxDecoration);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, paletteForIndex(0));
    });
  });
}
