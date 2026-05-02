// Plan 04-03 RED tests for LetterTile.
//
// Validates STAFIR-01 (≥200 logical-px tap target proxy for ≥2 cm physical),
// STAFIR-06 (synchronous visual feedback on onTapDown, NOT onTap),
// STAFIR-07 (no failure-state UI),
// STAFIR-08 (zero text instructions — only the glyph),
// D-13 (no selected state retained after tap),
// D-30 (6-color pastel palette, 200 ms ease-out scale animation).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/alphabet/icelandic_letter.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile_palette.dart';

const _letterA = IcelandicLetter(glyph: 'a', name: 'a', assetSlug: 'a');
const _letterEth = IcelandicLetter(glyph: 'ð', name: 'eð', assetSlug: 'eth');

Widget _hostTile({
  required IcelandicLetter letter,
  required int letterIndex,
  required ValueChanged<IcelandicLetter> onLetterTap,
  Size size = const Size(800, 600),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: LetterTile(
            letter: letter,
            letterIndex: letterIndex,
            onLetterTap: onLetterTap,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('LetterTile rendering (STAFIR-08)', () {
    testWidgets('renders the letter glyph as a Text widget', (tester) async {
      await tester.pumpWidget(
        _hostTile(
          letter: _letterA,
          letterIndex: 0,
          onLetterTap: (_) {},
        ),
      );
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('renders only ONE Text widget (no instructions)', (tester) async {
      await tester.pumpWidget(
        _hostTile(
          letter: _letterA,
          letterIndex: 0,
          onLetterTap: (_) {},
        ),
      );
      // Anchor under the LetterTile subtree.
      final textInTile = find.descendant(
        of: find.byType(LetterTile),
        matching: find.byType(Text),
      );
      expect(
        textInTile,
        findsOneWidget,
        reason: 'STAFIR-08: only the glyph, no labels',
      );
    });

    testWidgets('renders no failure-state Icon (no error/check/close)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostTile(
          letter: _letterEth,
          letterIndex: 4,
          onLetterTap: (_) {},
        ),
      );
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });
  });

  group('LetterTile sizing (STAFIR-01)', () {
    testWidgets('tap target ≥200 logical-px when given a 240×240 host', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostTile(
          letter: _letterA,
          letterIndex: 0,
          onLetterTap: (_) {},
        ),
      );
      final size = tester.getSize(find.byType(LetterTile));
      expect(size.width, greaterThanOrEqualTo(200.0));
      expect(size.height, greaterThanOrEqualTo(200.0));
      // Diagnostic: emit physical-cm conversion.
      final dpr = tester.view.devicePixelRatio;
      const logicalPxPerCm = 96.0 / 2.54;
      // ignore: avoid_print
      print(
        '[STAFIR-01 diagnostic] dpr=$dpr; tile=${size.width}×${size.height} '
        '≈ ${(size.width / logicalPxPerCm).toStringAsFixed(2)} cm',
      );
    });
  });

  group('LetterTile gesture (STAFIR-06)', () {
    testWidgets('fires onLetterTap on tap-DOWN (before tap-up)', (tester) async {
      IcelandicLetter? tapped;
      await tester.pumpWidget(
        _hostTile(
          letter: _letterA,
          letterIndex: 0,
          onLetterTap: (l) => tapped = l,
        ),
      );
      // Start a gesture but DON'T release it yet.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LetterTile)),
      );
      await tester.pump(const Duration(milliseconds: 1));
      // Callback should fire on tap-down.
      expect(tapped, isNotNull);
      expect(tapped, _letterA);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('LetterTile palette (D-30)', () {
    testWidgets('applies paletteForIndex(0) when letterIndex=0', (tester) async {
      await tester.pumpWidget(
        _hostTile(
          letter: _letterA,
          letterIndex: 0,
          onLetterTap: (_) {},
        ),
      );
      // Find the inner Container's BoxDecoration color.
      final containerFinder = find.descendant(
        of: find.byType(LetterTile),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);
      // The first Container in the subtree should carry the palette color.
      final container = tester.widgetList<Container>(containerFinder).firstWhere(
        (c) => c.decoration is BoxDecoration,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, paletteForIndex(0));
    });
  });

  group('LetterTile no-selected-state (D-13, STAFIR-07)', () {
    testWidgets('no persistent visual state after tap', (tester) async {
      await tester.pumpWidget(
        _hostTile(
          letter: _letterA,
          letterIndex: 0,
          onLetterTap: (_) {},
        ),
      );
      Container preTapContainer = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(LetterTile),
              matching: find.byType(Container),
            ),
          )
          .firstWhere((c) => c.decoration is BoxDecoration);
      final preColor = (preTapContainer.decoration! as BoxDecoration).color;

      await tester.tap(find.byType(LetterTile));
      // Past the 200ms scale animation cycle.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      Container postTapContainer = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(LetterTile),
              matching: find.byType(Container),
            ),
          )
          .firstWhere((c) => c.decoration is BoxDecoration);
      final postColor = (postTapContainer.decoration! as BoxDecoration).color;
      expect(
        postColor,
        preColor,
        reason: 'D-13: no selected state — color unchanged after tap',
      );
    });
  });

  group('LetterTile scale animation (D-30)', () {
    testWidgets('animates scale during tap (mid-animation 0.9-1.0)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostTile(
          letter: _letterA,
          letterIndex: 0,
          onLetterTap: (_) {},
        ),
      );
      // Tap-down to trigger the squeeze-then-bounce-back.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LetterTile)),
      );
      // 50ms into the squeeze: scale should be < 1.0.
      await tester.pump(const Duration(milliseconds: 50));
      // Find Transform widget in the LetterTile subtree.
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(LetterTile),
          matching: find.byType(Transform),
        ),
      );
      // Transform.scale uses a Matrix4 — extract the scale factor from the
      // X/Y diagonal entries. (0..0 for X, 1..1 for Y)
      final activeTransforms = transforms.where(
        (t) => t.transform.storage[0] < 1.0 || t.transform.storage[5] < 1.0,
      );
      expect(
        activeTransforms,
        isNotEmpty,
        reason: 'mid-animation scale should be < 1.0',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('LetterTile compatibility with kIcelandicAlphabet', () {
    testWidgets('renders any letter from kIcelandicAlphabet', (tester) async {
      // Smoke: render the diacritic glyphs we know are tricky.
      for (final letter in [
        kIcelandicAlphabet[4], // ð
        kIcelandicAlphabet[29], // þ
        kIcelandicAlphabet[30], // æ
        kIcelandicAlphabet[31], // ö
      ]) {
        await tester.pumpWidget(
          _hostTile(
            letter: letter,
            letterIndex: kIcelandicAlphabet.indexOf(letter),
            onLetterTap: (_) {},
          ),
        );
        expect(find.text(letter.glyph), findsOneWidget);
      }
    });
  });
}
