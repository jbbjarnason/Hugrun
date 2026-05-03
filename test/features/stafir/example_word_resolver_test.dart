// Tests for example_word_resolver — pure unit.
//
// Phase 2 stub assertions (only `a`, `eth`, `thorn` resolved) were lifted
// after Phase 3 shipped the full 32-letter manifest. The resolver now
// covers all 32 IcelandicLetter slugs and returns null only for
// genuinely unknown slugs.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/stafir/example_word_resolver.dart';

void main() {
  group('letterToUtteranceKey', () {
    test('"a" -> letterA', () {
      expect(letterToUtteranceKey('a'), UtteranceKey.letterA);
    });
    test('"eth" -> letterEth', () {
      expect(letterToUtteranceKey('eth'), UtteranceKey.letterEth);
    });
    test('"thorn" -> letterThorn', () {
      expect(letterToUtteranceKey('thorn'), UtteranceKey.letterThorn);
    });
    test('"h" -> letterH (full 32-letter coverage post-Phase-3)', () {
      expect(letterToUtteranceKey('h'), UtteranceKey.letterH);
    });
    test('"o_umlaut" -> letterOumlaut', () {
      expect(letterToUtteranceKey('o_umlaut'), UtteranceKey.letterOumlaut);
    });
    test('"ae" -> letterAe', () {
      expect(letterToUtteranceKey('ae'), UtteranceKey.letterAe);
    });
    test('all 32 alphabet slugs resolve to a non-null UtteranceKey', () {
      for (final letter in kIcelandicAlphabet) {
        expect(
          letterToUtteranceKey(letter.assetSlug),
          isNotNull,
          reason:
              'slug ${letter.assetSlug} (glyph ${letter.glyph}) must resolve',
        );
      }
    });
    test('unknown slug -> null', () {
      expect(letterToUtteranceKey('zzz'), isNull);
    });
  });

  group('exampleWordImagePath', () {
    test('"hundur" -> assets path', () {
      expect(
        exampleWordImagePath('hundur'),
        'assets/images/letters/words/hundur.webp',
      );
    });
  });

  group('exampleWordPlaceholderText', () {
    test('returns the slug verbatim', () {
      expect(exampleWordPlaceholderText('hundur'), 'hundur');
      expect(exampleWordPlaceholderText('api'), 'api');
    });
  });

  group('slugFromWordKey', () {
    test('wordHundur -> hundur (manifest-derived)', () {
      expect(slugFromWordKey(UtteranceKey.wordHundur), 'hundur');
    });
    test('wordA -> api (manifest-derived, NOT "a")', () {
      // Pre-fix: this returned "a" (wordA stripped of "word" prefix). Post-
      // fix: returned "api" (the actual asset filename root). The image and
      // overlay layers depend on this returning the real slug.
      expect(slugFromWordKey(UtteranceKey.wordA), 'api');
    });
    test('wordT -> tonn (manifest-derived)', () {
      expect(slugFromWordKey(UtteranceKey.wordT), 'tonn');
    });
    test('non-word key falls back to enum name', () {
      // Defensive — we only call this on word* keys, but the function
      // should return the enum name unchanged if the key isn't in the
      // manifest. letterA IS in the manifest (path `a.aac`), so the
      // manifest-derived slug is `a` (matching the enum-strip behavior).
      expect(slugFromWordKey(UtteranceKey.letterA), 'a');
    });
  });
}
