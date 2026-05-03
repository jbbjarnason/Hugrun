// Phase 10 Plan 02 — Curated lexicon collection tests (RED first).
//
// Tests integrity of the kStarterLexicon list:
//   * Has at least 30 entries (Phase 10 starter set per scope).
//   * All words are unique.
//   * All words are non-empty lowercase Icelandic strings.
//   * All defaultImagePaths follow the canonical assets/images/letters/words/
//     prefix.
//   * Includes the canonical Phase 4 example word "hundur".
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/lexicon/gender.dart';
import 'package:hugrun/core/lexicon/lexicon.dart';
import 'package:hugrun/core/lexicon/lexicon_entry.dart';

void main() {
  group('kStarterLexicon', () {
    test('contains at least 30 entries', () {
      expect(kStarterLexicon.length, greaterThanOrEqualTo(30));
    });

    test('all words are unique', () {
      final words = kStarterLexicon.map((e) => e.word).toList();
      expect(words.toSet().length, words.length);
    });

    test('all words are non-empty + lowercase', () {
      for (final entry in kStarterLexicon) {
        expect(entry.word, isNotEmpty, reason: 'Empty word: ${entry.word}');
        expect(
          entry.word,
          equals(entry.word.toLowerCase()),
          reason: 'Word is not lowercase: ${entry.word}',
        );
      }
    });

    test('all defaultImagePaths follow canonical prefix', () {
      for (final entry in kStarterLexicon) {
        expect(
          entry.defaultImagePath,
          startsWith('assets/images/letters/words/'),
          reason: 'Bad path: ${entry.defaultImagePath} (${entry.word})',
        );
      }
    });

    test('contains canonical example word "hundur"', () {
      final hundur = kStarterLexicon.where((e) => e.word == 'hundur').toList();
      expect(hundur, hasLength(1));
      expect(hundur.first.gender, Gender.masculine);
    });

    test('every entry has a non-null gender', () {
      for (final entry in kStarterLexicon) {
        expect(entry.gender, isA<Gender>());
      }
    });

    test('every word is pure Icelandic (no spaces, no punctuation)', () {
      // Allowed: a-z plus Icelandic special letters.
      final pattern = RegExp(r'^[a-záðéíóúýþæö]+$');
      for (final entry in kStarterLexicon) {
        expect(
          pattern.hasMatch(entry.word),
          isTrue,
          reason: 'Bad characters in word: ${entry.word}',
        );
      }
    });

    test('looking up by word returns the same entry', () {
      final dog = lookupLexiconEntry('hundur');
      expect(dog, isA<LexiconEntry>());
      expect(dog!.word, 'hundur');
    });

    test('looking up unknown word returns null', () {
      expect(lookupLexiconEntry('zzz_not_a_word'), isNull);
    });
  });
}
