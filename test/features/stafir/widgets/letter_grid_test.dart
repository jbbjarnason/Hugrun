// Plan 04-04 RED tests for LetterGrid widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/alphabet/icelandic_letter.dart';
import 'package:hugrun/features/stafir/widgets/letter_grid.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile.dart';

void main() {
  testWidgets('LetterGrid renders exactly 32 LetterTile widgets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LetterGrid(onLetterTap: (_) {})),
      ),
    );
    expect(find.byType(LetterTile), findsNWidgets(32));
  });

  testWidgets('LetterGrid uses 8 columns in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LetterGrid(onLetterTap: (_) {})),
      ),
    );
    final gridView = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 8);
  });

  testWidgets('LetterGrid uses 4 columns in portrait', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LetterGrid(onLetterTap: (_) {})),
      ),
    );
    final gridView = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);
  });

  testWidgets('LetterGrid renders glyphs in MMS order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final taps = <IcelandicLetter>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LetterGrid(onLetterTap: taps.add)),
      ),
    );
    // Tap the first tile by Key. Key format: 'letter-tile-{i}-{slug}'.
    await tester.tap(find.byKey(const Key('letter-tile-0-a')));
    await tester.pump();
    expect(taps.length, 1);
    expect(taps.first.glyph, kIcelandicAlphabet[0].glyph);
  });
}
