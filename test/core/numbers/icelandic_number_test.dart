// Phase 8 Plan 08-01 Workstream A — RED tests for the IcelandicNumber model
// + kIcelandicNumbers + numberAudioKey resolver.
//
// Pure-Dart per Phase 8 D-04 (lib/core/numbers/ flutter-free; check-domain-
// purity.sh extended).
//
// REQUIREMENTS-01:
//   NUM-01: Tölur shows digits 1–10 with tap-to-hear matching Stafir's mechanic
//   NUM-02: 1–4 have gendered audio variants (M/F/N); 5–10 have a single form
//   NUM-03: abstract counting uses masculine; pictured uses object's gender
//
// Decisions exercised:
//   D-07  IcelandicNumber model: int value, masculine/feminine?/neuter?,
//         invariant. invariant == masculine for 1–4 abstract; sole key for 5+.
//   D-08  numberAudioKey(value, gender) resolver. abstract = masculine.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/core/numbers/gender.dart';
import 'package:hugrun/core/numbers/icelandic_number.dart';
import 'package:hugrun/core/numbers/number_audio_resolver.dart';
import 'package:hugrun/core/numbers/numbers.dart';

void main() {
  group('IcelandicNumber model (D-07)', () {
    test('N1: holds value + masculine + feminine + neuter + invariant', () {
      const n = IcelandicNumber(
        value: 1,
        masculine: UtteranceKey.numberOneMasc,
        feminine: UtteranceKey.numberOneFem,
        neuter: UtteranceKey.numberOneNeut,
        invariant: UtteranceKey.numberOneMasc,
      );
      expect(n.value, 1);
      expect(n.masculine, UtteranceKey.numberOneMasc);
      expect(n.feminine, UtteranceKey.numberOneFem);
      expect(n.neuter, UtteranceKey.numberOneNeut);
      expect(n.invariant, UtteranceKey.numberOneMasc);
    });

    test('N2: 5+ entries have null feminine + null neuter', () {
      const n = IcelandicNumber(
        value: 5,
        invariant: UtteranceKey.numberFive,
      );
      expect(n.feminine, isNull);
      expect(n.neuter, isNull);
      // For 5+, masculine isn't a separate variant; invariant doubles as the
      // only key. We allow masculine to be null OR equal to invariant; the
      // canonical pattern is null (non-applicable).
      expect(n.masculine, isNull);
    });

    test('N3: equality + hashCode by value', () {
      const a = IcelandicNumber(
        value: 3,
        masculine: UtteranceKey.numberThreeMasc,
        feminine: UtteranceKey.numberThreeFem,
        neuter: UtteranceKey.numberThreeNeut,
        invariant: UtteranceKey.numberThreeMasc,
      );
      const b = IcelandicNumber(
        value: 3,
        masculine: UtteranceKey.numberThreeMasc,
        feminine: UtteranceKey.numberThreeFem,
        neuter: UtteranceKey.numberThreeNeut,
        invariant: UtteranceKey.numberThreeMasc,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('kIcelandicNumbers (D-07)', () {
    test('K1: exactly 10 entries, value 1..10 in order', () {
      expect(kIcelandicNumbers.length, 10);
      for (var i = 0; i < 10; i++) {
        expect(kIcelandicNumbers[i].value, i + 1,
            reason: 'kIcelandicNumbers[$i].value should be ${i + 1}');
      }
    });

    test('K2: 1..4 have non-null masculine + feminine + neuter', () {
      for (var i = 0; i < 4; i++) {
        final n = kIcelandicNumbers[i];
        expect(n.masculine, isNotNull,
            reason: 'value=${n.value} missing masculine');
        expect(n.feminine, isNotNull,
            reason: 'value=${n.value} missing feminine');
        expect(n.neuter, isNotNull,
            reason: 'value=${n.value} missing neuter');
      }
    });

    test('K3: 5..10 have null feminine + null neuter (NUM-02)', () {
      for (var i = 4; i < 10; i++) {
        final n = kIcelandicNumbers[i];
        expect(n.feminine, isNull,
            reason: 'value=${n.value} should not have feminine variant');
        expect(n.neuter, isNull,
            reason: 'value=${n.value} should not have neuter variant');
      }
    });

    test('K4: invariant is non-null for every entry', () {
      for (final n in kIcelandicNumbers) {
        expect(n.invariant, isNotNull,
            reason: 'value=${n.value} missing invariant');
      }
    });

    test('K5: 1..4 invariant equals masculine (abstract = masculine D-08)', () {
      for (var i = 0; i < 4; i++) {
        final n = kIcelandicNumbers[i];
        expect(n.invariant, n.masculine,
            reason: 'value=${n.value}: abstract counting uses masculine');
      }
    });

    test('K6: every UtteranceKey reference is a real enum entry', () {
      for (final n in kIcelandicNumbers) {
        expect(UtteranceKey.values, contains(n.invariant));
        if (n.masculine != null) {
          expect(UtteranceKey.values, contains(n.masculine));
        }
        if (n.feminine != null) {
          expect(UtteranceKey.values, contains(n.feminine));
        }
        if (n.neuter != null) {
          expect(UtteranceKey.values, contains(n.neuter));
        }
      }
    });

    test('K7: each gendered variant key is unique across the list', () {
      final allKeys = <UtteranceKey>{};
      for (final n in kIcelandicNumbers) {
        for (final k in <UtteranceKey?>[
          n.masculine,
          n.feminine,
          n.neuter,
          n.invariant,
        ]) {
          if (k == null) continue;
          // The same masculine key reappears as invariant for 1..4 — that's
          // OK. We just check no two DIFFERENT slots accidentally share a key
          // outside the masculine == invariant pairing.
          allKeys.add(k);
        }
      }
      // 12 gendered (1..4 × 3) + 6 invariant for 5..10 = 18. The 4 masculine
      // keys are reused as invariant for 1..4 (D-08), so total distinct = 18.
      expect(allKeys.length, 18,
          reason: 'expected 18 distinct UtteranceKeys across all variants');
    });
  });

  group('numberAudioKey resolver (D-08)', () {
    test('R1: 1..4 with masculine returns the masculine key', () {
      expect(numberAudioKey(1, Gender.masculine),
          UtteranceKey.numberOneMasc);
      expect(numberAudioKey(2, Gender.masculine),
          UtteranceKey.numberTwoMasc);
      expect(numberAudioKey(3, Gender.masculine),
          UtteranceKey.numberThreeMasc);
      expect(numberAudioKey(4, Gender.masculine),
          UtteranceKey.numberFourMasc);
    });

    test('R2: 1..4 with feminine returns the feminine key', () {
      expect(numberAudioKey(1, Gender.feminine), UtteranceKey.numberOneFem);
      expect(numberAudioKey(2, Gender.feminine), UtteranceKey.numberTwoFem);
      expect(numberAudioKey(3, Gender.feminine),
          UtteranceKey.numberThreeFem);
      expect(numberAudioKey(4, Gender.feminine),
          UtteranceKey.numberFourFem);
    });

    test('R3: 1..4 with neuter returns the neuter key', () {
      expect(numberAudioKey(1, Gender.neuter), UtteranceKey.numberOneNeut);
      expect(numberAudioKey(2, Gender.neuter), UtteranceKey.numberTwoNeut);
      expect(numberAudioKey(3, Gender.neuter),
          UtteranceKey.numberThreeNeut);
      expect(numberAudioKey(4, Gender.neuter),
          UtteranceKey.numberFourNeut);
    });

    test('R4: 5..10 returns the invariant regardless of gender (NUM-02)', () {
      const expected = <int, UtteranceKey>{
        5: UtteranceKey.numberFive,
        6: UtteranceKey.numberSix,
        7: UtteranceKey.numberSeven,
        8: UtteranceKey.numberEight,
        9: UtteranceKey.numberNine,
        10: UtteranceKey.numberTen,
      };
      for (final entry in expected.entries) {
        for (final g in Gender.values) {
          expect(numberAudioKey(entry.key, g), entry.value,
              reason:
                  'value=${entry.key} gender=$g should resolve to ${entry.value}');
        }
      }
    });

    test('R5: throws (or asserts) on out-of-range values', () {
      expect(() => numberAudioKey(0, Gender.masculine), throwsA(anything));
      expect(() => numberAudioKey(11, Gender.masculine), throwsA(anything));
      expect(() => numberAudioKey(-1, Gender.masculine), throwsA(anything));
    });
  });
}
