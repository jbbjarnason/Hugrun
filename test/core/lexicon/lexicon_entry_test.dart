// Phase 10 Plan 02 — LexiconEntry value class tests (RED first).
//
// Tests structural invariants of the LexiconEntry value class only — no
// alphabet/manifest cross-references (those live in lexicon_test.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/lexicon/gender.dart';
import 'package:hugrun/core/lexicon/lexicon_entry.dart';

void main() {
  group('LexiconEntry', () {
    test('constructs with all fields', () {
      const entry = LexiconEntry(
        word: 'hundur',
        gender: Gender.masculine,
        defaultImagePath: 'assets/images/letters/words/hundur.webp',
      );
      expect(entry.word, 'hundur');
      expect(entry.gender, Gender.masculine);
      expect(entry.defaultImagePath, 'assets/images/letters/words/hundur.webp');
    });

    test('equality is value-based', () {
      const a = LexiconEntry(
        word: 'hundur',
        gender: Gender.masculine,
        defaultImagePath: 'assets/images/letters/words/hundur.webp',
      );
      const b = LexiconEntry(
        word: 'hundur',
        gender: Gender.masculine,
        defaultImagePath: 'assets/images/letters/words/hundur.webp',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different word implies inequality', () {
      const a = LexiconEntry(
        word: 'hundur',
        gender: Gender.masculine,
        defaultImagePath: 'assets/images/letters/words/hundur.webp',
      );
      const b = LexiconEntry(
        word: 'köttur',
        gender: Gender.masculine,
        defaultImagePath: 'assets/images/letters/words/kottur.webp',
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('Gender enum', () {
    test('has masculine, feminine, neuter', () {
      expect(Gender.values, hasLength(3));
      expect(Gender.values, contains(Gender.masculine));
      expect(Gender.values, contains(Gender.feminine));
      expect(Gender.values, contains(Gender.neuter));
    });
  });
}
