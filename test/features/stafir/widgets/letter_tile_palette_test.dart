// Plan 04-03 RED tests for the locked 6-color pastel palette (D-30).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile_palette.dart';

void main() {
  test('kLetterTilePalette has exactly 6 colors (D-30)', () {
    expect(kLetterTilePalette.length, 6);
  });

  test('every palette color has saturation in [0.20, 0.45] (pastel range)', () {
    for (final color in kLetterTilePalette) {
      final hsl = HSLColor.fromColor(color);
      expect(
        hsl.saturation,
        inInclusiveRange(0.20, 0.45),
        reason: 'color $color saturation=${hsl.saturation} not in pastel range',
      );
    }
  });

  test('paletteForIndex is deterministic (same index → same color)', () {
    for (var i = 0; i < 32; i++) {
      expect(paletteForIndex(i), paletteForIndex(i));
    }
  });

  test('paletteForIndex returns 6 distinct colors for indices 0..5', () {
    final colors = <int, Color>{
      for (var i = 0; i < 6; i++) i: paletteForIndex(i),
    };
    final unique = colors.values.toSet();
    expect(
      unique.length,
      6,
      reason: 'all 6 palette slots produce distinct colors',
    );
  });

  test('paletteForIndex wraps mod 6', () {
    expect(paletteForIndex(6), paletteForIndex(0));
    expect(paletteForIndex(7), paletteForIndex(1));
    expect(paletteForIndex(31), paletteForIndex(31 % 6));
  });
}
