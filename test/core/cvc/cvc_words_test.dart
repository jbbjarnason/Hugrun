// Phase 6 Plan 06-02 Task B.1 RED — tests for the canonical 8-word CVC
// starter list (CVC-01).
//
// REQUIREMENTS-01 says CVC-01 = "≥8 starter words: kýr, sól, hús, rós, bók,
// mús, hár, gás". The const list MUST contain those 8 with the right
// c1/v/c2 decomposition.
//
// Pure-Dart per Phase 6 D-06.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/cvc/cvc_words.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

void main() {
  group('kCvcWords (Phase 6 D-06; CVC-01)', () {
    test('W1: contains at least 8 words', () {
      expect(kCvcWords.length, greaterThanOrEqualTo(8));
    });

    test('W2: contains the 8 named starter words', () {
      final words = kCvcWords.map((w) => w.word).toSet();
      expect(
        words,
        containsAll(<String>{
          'kýr',
          'sól',
          'hús',
          'rós',
          'bók',
          'mús',
          'hár',
          'gás',
        }),
      );
    });

    test('W3: every entry has c1/v/c2 matching word[0..2]', () {
      for (final w in kCvcWords) {
        final letters = w.word.split('');
        expect(
          letters.length,
          3,
          reason: '"${w.word}" should be exactly 3 characters',
        );
        expect(
          w.c1.glyph,
          letters[0],
          reason: '${w.word}.c1 should be "${letters[0]}"',
        );
        expect(
          w.v.glyph,
          letters[1],
          reason: '${w.word}.v should be "${letters[1]}"',
        );
        expect(
          w.c2.glyph,
          letters[2],
          reason: '${w.word}.c2 should be "${letters[2]}"',
        );
      }
    });

    test('W4: every wordClip points to a real UtteranceKey', () {
      // The list should compile-reference real enum values; this is a
      // sanity guard to catch typos that survive analyzer.
      for (final w in kCvcWords) {
        expect(
          UtteranceKey.values,
          contains(w.wordClip),
          reason: 'wordClip ${w.wordClip} for ${w.word} not in UtteranceKey',
        );
      }
    });

    test('W5: kýr/sól/mús/rós/bók map to existing wordX keys (D-04 reuse)', () {
      // Phase 6 D-04: these 5 already exist as example_word entries.
      final byWord = {for (final w in kCvcWords) w.word: w};
      expect(byWord['kýr']!.wordClip, UtteranceKey.wordK);
      expect(byWord['sól']!.wordClip, UtteranceKey.wordS);
      expect(byWord['mús']!.wordClip, UtteranceKey.wordM);
      expect(byWord['rós']!.wordClip, UtteranceKey.wordR);
      expect(byWord['bók']!.wordClip, UtteranceKey.wordB);
    });

    test('W6: hús/hár/gás map to NEW wordHus/wordHar/wordGas keys', () {
      final byWord = {for (final w in kCvcWords) w.word: w};
      expect(byWord['hús']!.wordClip, UtteranceKey.wordHus);
      expect(byWord['hár']!.wordClip, UtteranceKey.wordHar);
      expect(byWord['gás']!.wordClip, UtteranceKey.wordGas);
    });

    test('W7: words are unique (no duplicate triples)', () {
      final words = kCvcWords.map((w) => w.word).toList();
      expect(
        words.toSet().length,
        words.length,
        reason: 'duplicate word in kCvcWords: $words',
      );
    });
  });
}
