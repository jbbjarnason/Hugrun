// Pure-Dart loader and validator for the 32 Make-Me-A-Hanzi-format JSON
// glyphs at assets/tracing/. Phase 7 D-02 + D-04.
//
// This file MUST stay Flutter-free per CONTEXT D-08 (enforced by
// tools/check-domain-purity.sh). The loader returns a strongly-typed
// [TraceGlyph] value object that the activity layer (lib/features/stafir/
// tracing/) wraps into a [StrokeOrder] from the stroke_order_animator
// package — that wrapping happens in the widget layer and is the only
// place we touch Flutter / dart:ui types.
//
// Coordinate system: MMAH document space is 1024×1024 with Y inverted
// around y=900. Authors of the JSON files (here, the generator under
// tools/glyph/) work in document space (y up). The package's
// `StrokeOrder._parseStrokeOutlines` flips Y at parse time. We do not
// flip here — `parseGlyphJson` only validates structure and decodes.
//
// Validation contract — D-04 + Pitfall §2:
//   • `character` is the Unicode glyph (1+ chars; allows multi-codepoint
//     diacritics like 'á' which is single codepoint in NFC).
//   • `strokes` is a non-empty list of SVG path strings.
//   • `medians` is a list of polylines, each with ≥2 points
//     (each point a `[x, y]` pair of numbers in document space).
//   • `strokes.length == medians.length` (one outline per median; each
//     stroke gets one outline + one centerline).
//   • `radStrokes` is optional; defaults to an empty list.
//
// `parseGlyphJson` does NOT enforce the diacritic-as-last-stroke rule —
// that is a content-authoring invariant validated by the test suite
// against the shipped JSONs (test/core/tracing/glyph_loader_test.dart).
// The runtime loader is content-agnostic.

import 'dart:convert';

import '../alphabet/icelandic_letter.dart';

/// Canonical asset path convention for tracing JSON glyphs.
const String kTracingAssetRoot = 'assets/tracing';

/// Returns the canonical asset path for [letter]:
/// `assets/tracing/{letter.assetSlug}.json`.
///
/// Honors the Phase 2 D-03 slug map (e.g. ð → eth, ö → o_umlaut, æ → ae).
String assetPathFor(IcelandicLetter letter) =>
    '$kTracingAssetRoot/${letter.assetSlug}.json';

/// Strongly-typed in-memory representation of a single MMAH glyph.
///
/// This is a thin value-object wrapper over the JSON. It holds the data in
/// document-space (Y up) — the y-flip happens in the package's StrokeOrder
/// constructor. Phase 7 keeps this loader pure-Dart so unit tests can
/// run without a Flutter binding.
class TraceGlyph {
  const TraceGlyph({
    required this.character,
    required this.strokes,
    required this.medians,
    required this.radStrokes,
    required this.rawJson,
  });

  /// Unicode glyph (e.g. 'a', 'á', 'ð', 'þ', 'æ', 'ö').
  final String character;

  /// Closed-path SVG outlines, one per stroke. Each string is a `M ... Z`
  /// path in MMAH 1024×1024 document space. The package's CharacterPainter
  /// fills these to render the visible stroke.
  final List<String> strokes;

  /// Centerline polylines, one per stroke. Each is a list of points,
  /// each point a `[x, y]` pair of doubles. The package's tolerance
  /// algorithm uses these as the reference for stroke matching.
  final List<List<List<double>>> medians;

  /// Indices of strokes that are part of the character's "radical".
  /// Latin glyphs don't have radicals; this is empty in our shipped data.
  /// We carry it through anyway so the JSON round-trips cleanly into
  /// the package's StrokeOrder constructor.
  final List<int> radStrokes;

  /// The original JSON string. We pass this verbatim to
  /// `StrokeOrder(rawJson)` in the activity widget — the package
  /// re-parses internally. Carrying the raw string keeps the contract
  /// with the package symmetrical and avoids re-encoding.
  final String rawJson;

  /// Number of strokes in this glyph. Convenience accessor.
  int get nStrokes => strokes.length;
}

/// Parses a MMAH-format JSON string into a [TraceGlyph].
///
/// Throws [FormatException] on:
///   • invalid JSON
///   • missing or non-list `strokes`
///   • missing or non-list `medians`
///   • empty `strokes`
///   • mismatched `strokes` and `medians` lengths
///   • non-string entry inside `strokes`
///   • a median with fewer than 2 points
///   • a median point that is not a 2-element list of numbers
///
/// The function is intentionally strict — bad JSON should fail at load
/// time, NOT at first user touch. The shipped JSONs are validated in
/// the test suite, so production loads always succeed.
TraceGlyph parseGlyphJson(String rawJson) {
  Object? decoded;
  try {
    decoded = jsonDecode(rawJson);
  } catch (e) {
    throw FormatException('Invalid JSON for glyph: $e');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Glyph JSON root is not an object');
  }

  // Character is optional — some MMAH files omit it. Default to '' if
  // missing so the package's parser still accepts the data.
  final character = (decoded['character'] as String?) ?? '';

  // Strokes (required).
  final rawStrokes = decoded['strokes'];
  if (rawStrokes is! List) {
    throw const FormatException(
      'Glyph JSON missing required field "strokes" (must be a list)',
    );
  }
  if (rawStrokes.isEmpty) {
    throw const FormatException('Glyph JSON has empty "strokes" list');
  }
  final strokes = <String>[];
  for (var i = 0; i < rawStrokes.length; i++) {
    final s = rawStrokes[i];
    if (s is! String) {
      throw FormatException(
        'Glyph JSON stroke $i is not a string (got ${s.runtimeType})',
      );
    }
    strokes.add(s);
  }

  // Medians (required).
  final rawMedians = decoded['medians'];
  if (rawMedians is! List) {
    throw const FormatException(
      'Glyph JSON missing required field "medians" (must be a list)',
    );
  }
  final medians = <List<List<double>>>[];
  for (var i = 0; i < rawMedians.length; i++) {
    final m = rawMedians[i];
    if (m is! List) {
      throw FormatException(
        'Glyph JSON median $i is not a list (got ${m.runtimeType})',
      );
    }
    if (m.length < 2) {
      throw FormatException('Glyph JSON median $i has fewer than 2 points');
    }
    final stroke = <List<double>>[];
    for (var j = 0; j < m.length; j++) {
      final p = m[j];
      if (p is! List || p.length != 2) {
        throw FormatException(
          'Glyph JSON median $i point $j is not a [x, y] pair',
        );
      }
      final x = p[0];
      final y = p[1];
      if (x is! num || y is! num) {
        throw FormatException(
          'Glyph JSON median $i point $j has non-numeric coordinates',
        );
      }
      stroke.add(<double>[x.toDouble(), y.toDouble()]);
    }
    medians.add(stroke);
  }

  // Cross-field invariant: stroke count must equal median count.
  if (strokes.length != medians.length) {
    throw FormatException(
      'Glyph JSON has ${strokes.length} strokes but '
      '${medians.length} medians (must match)',
    );
  }

  // radStrokes (optional).
  final rawRadStrokes = decoded['radStrokes'];
  final radStrokes = <int>[];
  if (rawRadStrokes is List) {
    for (final r in rawRadStrokes) {
      if (r is num) {
        radStrokes.add(r.toInt());
      }
    }
  }

  return TraceGlyph(
    character: character,
    strokes: strokes,
    medians: medians,
    radStrokes: radStrokes,
    rawJson: rawJson,
  );
}
