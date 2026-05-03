// Phase 11 fix-pass — tests for icelandicWordToSlug.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/lexicon/icelandic_slug.dart';
import 'package:hugrun/core/lexicon/lexicon.dart';

void main() {
  group('icelandicWordToSlug', () {
    test('plain ASCII words pass through unchanged', () {
      expect(icelandicWordToSlug('hundur'), 'hundur');
      expect(icelandicWordToSlug('fiskur'), 'fiskur');
      expect(icelandicWordToSlug('lampi'), 'lampi');
      expect(icelandicWordToSlug('epli'), 'epli');
      expect(icelandicWordToSlug('vatn'), 'vatn');
    });

    test('acute-accent vowels map to their plain counterparts', () {
      expect(icelandicWordToSlug('kýr'), 'kyr');
      expect(icelandicWordToSlug('sól'), 'sol');
      expect(icelandicWordToSlug('hús'), 'hus');
      expect(icelandicWordToSlug('rós'), 'ros');
      expect(icelandicWordToSlug('mús'), 'mus');
      expect(icelandicWordToSlug('hár'), 'har');
      expect(icelandicWordToSlug('gás'), 'gas');
      expect(icelandicWordToSlug('máni'), 'mani');
      expect(icelandicWordToSlug('tré'), 'tre');
    });

    test('special letters: ð → d, þ → th, æ → ae, ö → o', () {
      expect(icelandicWordToSlug('brauð'), 'braud');
      expect(icelandicWordToSlug('þorn'), 'thorn');
      expect(icelandicWordToSlug('köttur'), 'kottur');
      expect(icelandicWordToSlug('mjólk'), 'mjolk');
    });

    test('case-insensitive: uppercase input lowercases first', () {
      expect(icelandicWordToSlug('Hundur'), 'hundur');
      expect(icelandicWordToSlug('KÝR'), 'kyr');
      expect(icelandicWordToSlug('Brauð'), 'braud');
    });

    test('every word in kStarterLexicon transliterates to its file slug', () {
      // The lexicon's defaultImagePath is the canonical slug source. If this
      // test fails, either the helper or the lexicon disagrees with Phase 2
      // D-03 conventions — both should match.
      for (final entry in kStarterLexicon) {
        final expectedPath =
            'assets/images/letters/words/${icelandicWordToSlug(entry.word)}.webp';
        expect(
          expectedPath,
          entry.defaultImagePath,
          reason:
              'slug for ${entry.word} should resolve to ${entry.defaultImagePath}',
        );
      }
    });

    test('empty string returns empty string', () {
      expect(icelandicWordToSlug(''), '');
    });
  });
}
