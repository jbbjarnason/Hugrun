// AdditionRound — pure-Dart value class for addition rounds (Phase 9
// Plan 09-03; NUM-07).
//
// Decisions exercised:
//   D-10  Round narrates "[addend1] [noun-plural] koma. [addend2] [noun]
//         kemur til viðbótar." then asks for the total. Child taps the
//         answer numeral.
//   D-11  Sums limited to ≤5 in v1 (research). Constructor enforces.
//   D-12  No `+` symbol. The model carries no operator glyph; the widget
//         must NOT render one.
//   D-13  Wrong tap = silent. Correct tap = celebration + auto-advance.
//
// Pure Dart per Phase 8 D-04 — no Flutter imports.

import 'dart:math';

import 'correspondence_round.dart' show Noun, kCorrespondenceNouns;
import 'icelandic_number.dart';
import 'numbers.dart';

/// One round of the Addition activity.
///
/// Asserting factory enforces:
///   - addend1.value ≥ 1
///   - addend2.value ≥ 1
///   - addend1 + addend2 ≤ 5  (D-11)
///   - addend1 + addend2 ≥ 2  (must be a real addition, not 0+x)
class AdditionRound {
  const AdditionRound._({
    required this.addend1,
    required this.addend2,
    required this.noun,
  });

  /// Asserting factory — used by the generator and by tests.
  factory AdditionRound({
    required IcelandicNumber addend1,
    required IcelandicNumber addend2,
    required Noun noun,
  }) {
    if (addend1.value < 1) {
      throw RangeError.value(
        addend1.value,
        'addend1.value',
        'AdditionRound: addend1 must be ≥ 1',
      );
    }
    if (addend2.value < 1) {
      throw RangeError.value(
        addend2.value,
        'addend2.value',
        'AdditionRound: addend2 must be ≥ 1',
      );
    }
    final total = addend1.value + addend2.value;
    if (total > 5) {
      throw RangeError.range(
        total,
        2,
        5,
        'addend1+addend2',
        'AdditionRound: sum must be ≤ 5 (D-11)',
      );
    }
    return AdditionRound._(addend1: addend1, addend2: addend2, noun: noun);
  }

  final IcelandicNumber addend1;
  final IcelandicNumber addend2;
  final Noun noun;

  /// Computed total. Always 2..5 by construction.
  int get totalValue => addend1.value + addend2.value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdditionRound &&
          runtimeType == other.runtimeType &&
          addend1 == other.addend1 &&
          addend2 == other.addend2 &&
          noun == other.noun;

  @override
  int get hashCode => Object.hash(addend1, addend2, noun);

  @override
  String toString() =>
      'AdditionRound(addend1=$addend1, addend2=$addend2, '
      'total=$totalValue, noun=${noun.word})';
}

/// Generates [AdditionRound]s. Deterministic when constructed with a seed.
class AdditionRoundGenerator {
  AdditionRoundGenerator({int? seed})
    : _rng = seed != null ? Random(seed) : Random();

  final Random _rng;

  /// Roll a new round.
  ///
  /// Picks a random total in 2..5, splits into (addend1, addend2) where
  /// both addends are ≥1, then picks a random noun from
  /// [kCorrespondenceNouns].
  AdditionRound generate() {
    final total = 2 + _rng.nextInt(4); // 2..5
    final addend1Value = 1 + _rng.nextInt(total - 1); // 1..total-1
    final addend2Value = total - addend1Value;
    final noun =
        kCorrespondenceNouns[_rng.nextInt(kCorrespondenceNouns.length)];
    return AdditionRound(
      addend1: kIcelandicNumbers[addend1Value - 1],
      addend2: kIcelandicNumbers[addend2Value - 1],
      noun: noun,
    );
  }
}
