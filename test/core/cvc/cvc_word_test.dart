// Phase 6 Plan 06-02 (Workstream B) Task B.1 RED — pure-Dart unit tests
// for the CvcWord value class.
//
// CvcWord captures one CVC starter-word triple (consonant–vowel–consonant)
// plus the audio key for the full-word blend clip. It's used by the
// CvcActivity widget to drive the per-letter phoneme tap experience.
//
// Decisions exercised:
//   D-05  CvcWord shape: { word, c1, v, c2, wordClip }. Pure Dart.
//   D-06  cvc_words.dart constants reference this class.
//
// No package:flutter imports allowed — tools/check-domain-purity.sh
// covers lib/core/cvc/.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/alphabet/icelandic_letter.dart';
import 'package:hugrun/core/cvc/cvc_word.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

void main() {
  // Pull canonical letter instances from kIcelandicAlphabet so the test's
  // identity comparisons line up with what the activity will consume.
  IcelandicLetter byGlyph(String g) =>
      kIcelandicAlphabet.firstWhere((l) => l.glyph == g);

  group('CvcWord (Phase 6 D-05)', () {
    test('CW1: stores word + c1/v/c2 + wordClip', () {
      final w = CvcWord(
        word: 'hús',
        c1: byGlyph('h'),
        v: byGlyph('ú'),
        c2: byGlyph('s'),
        wordClip: UtteranceKey.wordHus,
      );
      expect(w.word, 'hús');
      expect(w.c1.glyph, 'h');
      expect(w.v.glyph, 'ú');
      expect(w.c2.glyph, 's');
      expect(w.wordClip, UtteranceKey.wordHus);
    });

    test('CW2: letters list is [c1, v, c2] in tap-display order', () {
      final w = CvcWord(
        word: 'kýr',
        c1: byGlyph('k'),
        v: byGlyph('ý'),
        c2: byGlyph('r'),
        wordClip: UtteranceKey.wordK,
      );
      expect(w.letters.map((l) => l.glyph).toList(), <String>['k', 'ý', 'r']);
    });

    test('CW3: equal CvcWords are == and hashCode-equivalent', () {
      final a = CvcWord(
        word: 'sól',
        c1: byGlyph('s'),
        v: byGlyph('ó'),
        c2: byGlyph('l'),
        wordClip: UtteranceKey.wordS,
      );
      final b = CvcWord(
        word: 'sól',
        c1: byGlyph('s'),
        v: byGlyph('ó'),
        c2: byGlyph('l'),
        wordClip: UtteranceKey.wordS,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('CW4: differing wordClip ⇒ not equal', () {
      final a = CvcWord(
        word: 'rós',
        c1: byGlyph('r'),
        v: byGlyph('ó'),
        c2: byGlyph('s'),
        wordClip: UtteranceKey.wordR,
      );
      final b = CvcWord(
        word: 'rós',
        c1: byGlyph('r'),
        v: byGlyph('ó'),
        c2: byGlyph('s'),
        wordClip: UtteranceKey.wordHus, // mismatch
      );
      expect(a == b, isFalse);
    });

    test('CW5: toString includes the word + glyphs', () {
      final w = CvcWord(
        word: 'mús',
        c1: byGlyph('m'),
        v: byGlyph('ú'),
        c2: byGlyph('s'),
        wordClip: UtteranceKey.wordM,
      );
      expect(w.toString(), contains('mús'));
      expect(w.toString(), contains('m'));
      expect(w.toString(), contains('ú'));
      expect(w.toString(), contains('s'));
    });
  });
}
