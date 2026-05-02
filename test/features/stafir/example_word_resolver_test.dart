// Plan 04-04 RED tests for example_word_resolver — pure unit.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/stafir/example_word_resolver.dart';

void main() {
  group('letterToUtteranceKey (Phase 2 stub)', () {
    test('"a" -> letterA', () {
      expect(letterToUtteranceKey('a'), UtteranceKey.letterA);
    });
    test('"eth" -> letterEth', () {
      expect(letterToUtteranceKey('eth'), UtteranceKey.letterEth);
    });
    test('"thorn" -> letterThorn', () {
      expect(letterToUtteranceKey('thorn'), UtteranceKey.letterThorn);
    });
    test('"h" -> null in Phase 2 stub (letterH not yet in enum)', () {
      // Phase 3 will populate this; document Phase 2 behavior.
      expect(letterToUtteranceKey('h'), isNull);
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
    test('wordHundur -> hundur', () {
      expect(slugFromWordKey(UtteranceKey.wordHundur), 'hundur');
    });
    test('non-word key falls back to enum name', () {
      // Defensive — we only call this on word* keys, but the function
      // should return the enum name unchanged if no `word` prefix.
      expect(slugFromWordKey(UtteranceKey.letterA), 'letterA');
    });
  });
}
