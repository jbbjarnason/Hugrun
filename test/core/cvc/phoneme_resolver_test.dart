// Phase 6 Plan 06-02 Task B.1 RED — tests for slug → phoneme UtteranceKey
// resolution (D-07).
//
// Pattern: IcelandicLetter.assetSlug → UtteranceKey.phoneme<PascalCase>.
// Returns null when the enum doesn't yet have an entry — same posture as
// example_word_resolver.letterToUtteranceKey for letter-name keys.
//
// Pure Dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/cvc/phoneme_resolver.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

void main() {
  group('phonemeKeyForSlug (Phase 6 D-07)', () {
    test('PR1: "a" → phonemeA', () {
      expect(phonemeKeyForSlug('a'), UtteranceKey.phonemeA);
    });

    test('PR2: "a_acute" → phonemeAAcute', () {
      expect(phonemeKeyForSlug('a_acute'), UtteranceKey.phonemeAAcute);
    });

    test('PR3: "eth" → phonemeEth (ð diacritic)', () {
      expect(phonemeKeyForSlug('eth'), UtteranceKey.phonemeEth);
    });

    test('PR4: "thorn" → phonemeThorn (þ diacritic)', () {
      expect(phonemeKeyForSlug('thorn'), UtteranceKey.phonemeThorn);
    });

    test('PR5: "o_umlaut" → phonemeOumlaut', () {
      expect(phonemeKeyForSlug('o_umlaut'), UtteranceKey.phonemeOumlaut);
    });

    test('PR6: "ae" → phonemeAe', () {
      expect(phonemeKeyForSlug('ae'), UtteranceKey.phonemeAe);
    });

    test('PR7: "y_acute" → phonemeYAcute', () {
      expect(phonemeKeyForSlug('y_acute'), UtteranceKey.phonemeYAcute);
    });

    test('PR8: empty string → null', () {
      expect(phonemeKeyForSlug(''), isNull);
    });

    test('PR9: unknown slug → null', () {
      expect(phonemeKeyForSlug('xyz_not_a_letter'), isNull);
    });

    test('PR10: every letter in kIcelandicAlphabet resolves to a UtteranceKey',
        () {
      // CVC-02 says all 32 letters have a phoneme audio set. Resolver MUST
      // return a real key for every alphabet member.
      for (final l in kIcelandicAlphabet) {
        final k = phonemeKeyForSlug(l.assetSlug);
        expect(k, isNotNull,
            reason: 'No phoneme key for letter ${l.glyph} (slug=${l.assetSlug})');
        expect(UtteranceKey.values, contains(k),
            reason: 'Resolved key $k for ${l.glyph} not in UtteranceKey enum');
      }
    });
  });
}
