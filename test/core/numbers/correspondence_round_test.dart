// Phase 9 Plan 09-01 Workstream A — RED tests for Noun + CorrespondenceRound
// model + CorrespondenceRoundGenerator (NUM-04).
//
// Decisions exercised:
//   D-01  CorrespondenceActivity round model: count (1..5) + noun + tap targets.
//   D-02  Picture-object counting uses GENDER of the depicted noun.
//   D-03  Round generator picks random count 1..5, random noun, generates
//         that many TapTargets.
//   D-04  Last number narrated equals the count (NUM-04).
//   D-05  Tapping a previously-tapped object is a no-op (handled in widget).
//
// Pure Dart per Phase 8 D-04 — no Flutter imports.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/numbers/correspondence_round.dart';
import 'package:hugrun/core/numbers/gender.dart';
import 'package:hugrun/core/numbers/numbers.dart';

void main() {
  group('Noun (D-01)', () {
    test('N1: Noun carries word + gender + image path', () {
      const noun = Noun(
        word: 'hundur',
        gender: Gender.masculine,
        imagePath: 'assets/images/letters/words/hundur.webp',
      );
      expect(noun.word, 'hundur');
      expect(noun.gender, Gender.masculine);
      expect(noun.imagePath, 'assets/images/letters/words/hundur.webp');
    });

    test('N2: Noun equality + hashCode', () {
      const a = Noun(
        word: 'kýr',
        gender: Gender.feminine,
        imagePath: 'assets/images/letters/words/kyr.webp',
      );
      const b = Noun(
        word: 'kýr',
        gender: Gender.feminine,
        imagePath: 'assets/images/letters/words/kyr.webp',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('kCorrespondenceNouns built-in set (D-03)', () {
    test('N3: ships at least 5 nouns drawn from Phase 4 example words', () {
      expect(kCorrespondenceNouns.length, greaterThanOrEqualTo(5));
      // All entries must have non-empty fields.
      for (final n in kCorrespondenceNouns) {
        expect(n.word, isNotEmpty);
        expect(n.imagePath, startsWith('assets/images/letters/words/'));
      }
    });

    test('N4: includes at least one masculine, feminine, and neuter noun', () {
      final genders = kCorrespondenceNouns.map((n) => n.gender).toSet();
      expect(genders.contains(Gender.masculine), isTrue,
          reason: 'need ≥1 masculine noun for gender coverage');
      expect(genders.contains(Gender.feminine), isTrue,
          reason: 'need ≥1 feminine noun for gender coverage');
      expect(genders.contains(Gender.neuter), isTrue,
          reason: 'need ≥1 neuter noun for gender coverage');
    });
  });

  group('CorrespondenceRound model (D-01, D-03)', () {
    test('C1: stores count, noun, and exactly count tap targets', () {
      const noun = Noun(
        word: 'hundur',
        gender: Gender.masculine,
        imagePath: 'assets/images/letters/words/hundur.webp',
      );
      final round = CorrespondenceRound(
        count: kIcelandicNumbers[2], // 3
        noun: noun,
      );
      expect(round.count.value, 3);
      expect(round.noun, noun);
      expect(round.tapTargets.length, 3);
      // Tap targets carry an index 0..count-1.
      for (var i = 0; i < round.tapTargets.length; i++) {
        expect(round.tapTargets[i].index, i);
      }
    });

    test('C2: count must be 1..5 (D-04 NUM-04)', () {
      const noun = Noun(
        word: 'hundur',
        gender: Gender.masculine,
        imagePath: 'assets/images/letters/words/hundur.webp',
      );
      // 0 → throws.
      expect(
        () => CorrespondenceRound(
          count: kIcelandicNumbers[5], // 6
          noun: noun,
        ),
        throwsA(anything),
      );
    });

    test('C3: equality + hashCode', () {
      const noun = Noun(
        word: 'kýr',
        gender: Gender.feminine,
        imagePath: 'assets/images/letters/words/kyr.webp',
      );
      final a = CorrespondenceRound(count: kIcelandicNumbers[1], noun: noun);
      final b = CorrespondenceRound(count: kIcelandicNumbers[1], noun: noun);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('CorrespondenceRoundGenerator (D-03)', () {
    test('G1: generate() returns count in 1..5', () {
      final gen = CorrespondenceRoundGenerator(seed: 42);
      for (var i = 0; i < 30; i++) {
        final round = gen.generate();
        expect(round.count.value, inInclusiveRange(1, 5));
      }
    });

    test('G2: with seed, generate() is deterministic', () {
      final a = CorrespondenceRoundGenerator(seed: 7).generate();
      final b = CorrespondenceRoundGenerator(seed: 7).generate();
      expect(a, equals(b));
    });

    test('G3: generate() picks from kCorrespondenceNouns', () {
      final gen = CorrespondenceRoundGenerator(seed: 9);
      for (var i = 0; i < 20; i++) {
        final round = gen.generate();
        expect(kCorrespondenceNouns.contains(round.noun), isTrue,
            reason: 'generator must draw from canonical noun set');
      }
    });

    test('G4: across many rounds, counts cover the 1..5 range', () {
      final gen = CorrespondenceRoundGenerator(seed: 1234);
      final seen = <int>{};
      for (var i = 0; i < 200; i++) {
        seen.add(gen.generate().count.value);
      }
      // Expect at least 4 of the 5 to appear given 200 draws (some
      // RNG slack — extremely unlikely to miss more than one).
      expect(seen.length, greaterThanOrEqualTo(4),
          reason: 'count distribution should cover 1..5 across 200 draws');
    });
  });
}
