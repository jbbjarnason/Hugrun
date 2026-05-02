import 'package:flutter/material.dart';

/// 6-color pastel rotation locked palette per D-30.
///
/// Saturations chosen in [0.20, 0.45] for soft pastel feel; lightness near
/// 0.72 so the dark letter glyph reads cleanly on top. Hues spread across
/// the wheel: dusty peach, butter, mint, sky-teal, periwinkle, lavender.
/// Order is **locked** — changing it visually shifts every tile across the
/// alphabet (and breaks parents' visual mental map of "the letter that's
/// pink").
///
/// Saturation values via HSLColor.fromColor (Flutter HSL formula):
///   peach       — l=0.749 s=0.406
///   butter      — l=0.737 s=0.418
///   mint        — l=0.720 s=0.217
///   sky-teal    — l=0.704 s=0.272
///   periwinkle  — l=0.741 s=0.318
///   lavender    — l=0.692 s=0.248
const List<Color> kLetterTilePalette = <Color>[
  Color(0xFFD9B8A5), // dusty peach
  Color(0xFFD8C9A0), // dusty butter
  Color(0xFFA8C7B0), // dusty mint
  Color(0xFF9FBCC8), // dusty sky-teal
  Color(0xFFA8B4D2), // dusty periwinkle
  Color(0xFFB89DC4), // dusty lavender
];

/// Pure function. paletteForIndex(i) wraps modulo 6.
///
/// `letterIndex.abs()` defends against an accidentally-negative index from
/// upstream code (Phase 4 alphabet always feeds 0..31, but Phase 8+ may
/// add other grids).
Color paletteForIndex(int letterIndex) =>
    kLetterTilePalette[letterIndex.abs() % kLetterTilePalette.length];
