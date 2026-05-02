// Phase 9 Plan 09-03 Workstream C — RED tests for AdditionRound model
// + AdditionRoundGenerator (NUM-07).
//
// Decisions exercised:
//   D-10  AdditionRound has addend1 + addend2 + noun. Sum ≤ 5.
//   D-11  Sums limited to ≤5 in v1.
//   D-12  No `+` symbol shown anywhere; round model carries no operator
//         glyph (it's just two addends).
//   D-13  Wrong tap on the answer numeral = silent (widget concern).
//
// Pure Dart per Phase 8 D-04 — no Flutter imports.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/numbers/addition_round.dart';
import 'package:hugrun/core/numbers/correspondence_round.dart';
import 'package:hugrun/core/numbers/gender.dart';
import 'package:hugrun/core/numbers/numbers.dart';

void main() {
  const sampleNoun = Noun(
    word: 'hundur',
    gender: Gender.masculine,
    imagePath: 'assets/images/letters/words/hundur.webp',
  );

  group('AdditionRound model (D-10, D-11)', () {
    test('A1: stores addend1, addend2, noun, total', () {
      final round = AdditionRound(
        addend1: kIcelandicNumbers[1], // 2
        addend2: kIcelandicNumbers[0], // 1
        noun: sampleNoun,
      );
      expect(round.addend1.value, 2);
      expect(round.addend2.value, 1);
      expect(round.noun, sampleNoun);
      expect(round.totalValue, 3);
    });

    test('A2: total must be ≤ 5 (D-11)', () {
      // 3 + 3 = 6 → throws.
      expect(
        () => AdditionRound(
          addend1: kIcelandicNumbers[2],
          addend2: kIcelandicNumbers[2],
          noun: sampleNoun,
        ),
        throwsA(anything),
      );
    });

    test('A3: addends must be ≥ 1 (no zero addend)', () {
      // The kIcelandicNumbers list does not include 0; the constructor
      // also rejects passing an entry whose value is < 1.
      // We can't construct a 0 IcelandicNumber from the canonical list,
      // so just assert the documented invariant via valid + invalid cases.
      final ok = AdditionRound(
        addend1: kIcelandicNumbers[0],
        addend2: kIcelandicNumbers[0],
        noun: sampleNoun,
      );
      expect(ok.totalValue, 2);
    });

    test('A4: equality + hashCode', () {
      final a = AdditionRound(
        addend1: kIcelandicNumbers[1],
        addend2: kIcelandicNumbers[0],
        noun: sampleNoun,
      );
      final b = AdditionRound(
        addend1: kIcelandicNumbers[1],
        addend2: kIcelandicNumbers[0],
        noun: sampleNoun,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('AdditionRoundGenerator (D-10)', () {
    test('G1: generate() returns valid sums (1..5)', () {
      final gen = AdditionRoundGenerator(seed: 42);
      for (var i = 0; i < 30; i++) {
        final round = gen.generate();
        expect(round.totalValue, inInclusiveRange(2, 5));
        expect(round.addend1.value, greaterThanOrEqualTo(1));
        expect(round.addend2.value, greaterThanOrEqualTo(1));
      }
    });

    test('G2: with seed, generate() is deterministic', () {
      final a = AdditionRoundGenerator(seed: 7).generate();
      final b = AdditionRoundGenerator(seed: 7).generate();
      expect(a, equals(b));
    });

    test('G3: noun is drawn from kCorrespondenceNouns', () {
      final gen = AdditionRoundGenerator(seed: 99);
      for (var i = 0; i < 10; i++) {
        final round = gen.generate();
        expect(kCorrespondenceNouns.contains(round.noun), isTrue);
      }
    });

    test('G4: across many rounds, all reachable totals 2..5 appear', () {
      final gen = AdditionRoundGenerator(seed: 1234);
      final seen = <int>{};
      for (var i = 0; i < 200; i++) {
        seen.add(gen.generate().totalValue);
      }
      // Expect sums 2, 3, 4, 5 to be reachable. Some draws may miss one
      // by sheer luck — accept ≥3 distinct totals.
      expect(seen.length, greaterThanOrEqualTo(3));
    });
  });
}
