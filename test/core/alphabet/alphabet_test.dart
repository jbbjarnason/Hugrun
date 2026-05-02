// Phase 2 Plan 01 D-04 unit tests for kIcelandicAlphabet.
//
// Source of truth: 02-CONTEXT.md D-02 (MMS school order) and D-03 (slug map).
// PITFALLS #2 (alphabet drift) — these assertions lock the canonical 32-letter
// set in MMS school order so the shipped app teaches Hugrún the same alphabet
// her school does.
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/alphabet/icelandic_letter.dart';

/// Authoritative MMS school order (CONTEXT D-02).
const List<String> kExpectedGlyphs = <String>[
  'a', 'á', 'b', 'd', 'ð', 'e', 'é', 'f',
  'g', 'h', 'i', 'í', 'j', 'k', 'l', 'm',
  'n', 'o', 'ó', 'p', 'r', 's', 't', 'u',
  'ú', 'v', 'x', 'y', 'ý', 'þ', 'æ', 'ö',
];

/// CONTEXT D-03 mapping table (verbatim).
const Map<String, String> kExpectedSlugs = <String, String>{
  'a': 'a',
  'á': 'a_acute',
  'b': 'b',
  'd': 'd',
  'ð': 'eth',
  'e': 'e',
  'é': 'e_acute',
  'f': 'f',
  'g': 'g',
  'h': 'h',
  'i': 'i',
  'í': 'i_acute',
  'j': 'j',
  'k': 'k',
  'l': 'l',
  'm': 'm',
  'n': 'n',
  'o': 'o',
  'ó': 'o_acute',
  'p': 'p',
  'r': 'r',
  's': 's',
  't': 't',
  'u': 'u',
  'ú': 'u_acute',
  'v': 'v',
  'x': 'x',
  'y': 'y',
  'ý': 'y_acute',
  'þ': 'thorn',
  'æ': 'ae',
  'ö': 'o_umlaut',
};

void main() {
  group('kIcelandicAlphabet', () {
    test('contains exactly 32 letters (D-04 length)', () {
      expect(kIcelandicAlphabet.length, 32);
    });

    test('matches the MMS school order glyph-by-glyph (D-02)', () {
      final actualGlyphs = kIcelandicAlphabet.map((l) => l.glyph).toList();
      expect(actualGlyphs, kExpectedGlyphs);
    });

    test('contains no C, Q, W, or Z (D-04)', () {
      const forbidden = <String>{'c', 'q', 'w', 'z'};
      for (final letter in kIcelandicAlphabet) {
        expect(
          forbidden.contains(letter.glyph),
          isFalse,
          reason: 'Forbidden glyph "${letter.glyph}" found in alphabet',
        );
      }
    });

    test("each letter's assetSlug matches the D-03 mapping table", () {
      for (final letter in kIcelandicAlphabet) {
        final expected = kExpectedSlugs[letter.glyph];
        expect(
          expected,
          isNotNull,
          reason: 'No expected slug for glyph "${letter.glyph}"',
        );
        expect(
          letter.assetSlug,
          expected,
          reason:
              'Slug mismatch for glyph "${letter.glyph}": expected "$expected", got "${letter.assetSlug}"',
        );
      }
    });

    test('all 32 assetSlug values are unique (D-04)', () {
      final slugs = kIcelandicAlphabet.map((l) => l.assetSlug).toList();
      expect(slugs.toSet().length, kIcelandicAlphabet.length);
    });

    test(r'every assetSlug matches ^[a-z][a-z0-9_]*$ (D-04)', () {
      final regex = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final letter in kIcelandicAlphabet) {
        expect(
          regex.hasMatch(letter.assetSlug),
          isTrue,
          reason:
              'Slug "${letter.assetSlug}" for glyph "${letter.glyph}" does not match ^[a-z][a-z0-9_]*\$',
        );
      }
    });

    test("each letter's name is non-empty", () {
      for (final letter in kIcelandicAlphabet) {
        expect(
          letter.name,
          isNotEmpty,
          reason: 'Empty name for glyph "${letter.glyph}"',
        );
      }
    });
  });
}
