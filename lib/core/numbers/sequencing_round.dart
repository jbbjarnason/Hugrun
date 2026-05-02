// SequencingRound — pure-Dart value class for one Tölur sequencing round.
// Phase 8 Plan 08-03 D-09..D-11; NUM-06.
//
// Two variants per D-11:
//   - **Sort:** all 5 numerals shown scrambled; child drags into ascending
//     order. [scrambledOrder] is a permutation of [targetSequence];
//     [missingPosition] is null.
//   - **FillMissing:** 4 of the 5 numerals shown in scrambled order;
//     one position empty. Child drags the missing numeral into the gap.
//     [missingPosition] points to the index in [targetSequence] of the
//     missing value; [scrambledOrder] holds the other 4 in arbitrary order.
//
// Defensive constructor (S4..S6): targetSequence MUST be 5 contiguous
// ascending integers in 1..10. Bug guards. The generator constructs valid
// rounds; ad-hoc test fixtures occasionally reach for the constructor
// directly so the asserts are useful.
//
// Pure Dart per Phase 8 D-04.

import 'dart:math';

class SequencingRound {
  const SequencingRound._({
    required this.targetSequence,
    required this.scrambledOrder,
    required this.missingPosition,
  });

  /// Asserting factory — used by the generator and by tests.
  factory SequencingRound({
    required List<int> targetSequence,
    required List<int> scrambledOrder,
    int? missingPosition,
  }) {
    if (targetSequence.length != 5) {
      throw ArgumentError('targetSequence must have exactly 5 entries '
          '(got ${targetSequence.length})');
    }
    for (final v in targetSequence) {
      if (v < 1 || v > 10) {
        throw RangeError.range(
            v, 1, 10, 'targetSequence value', 'must be in 1..10');
      }
    }
    for (var i = 1; i < targetSequence.length; i++) {
      if (targetSequence[i] != targetSequence[i - 1] + 1) {
        throw ArgumentError('targetSequence must be contiguous ascending '
            'integers (got $targetSequence at index $i)');
      }
    }
    if (missingPosition != null) {
      if (missingPosition < 0 ||
          missingPosition >= targetSequence.length) {
        throw RangeError.range(missingPosition, 0,
            targetSequence.length - 1, 'missingPosition');
      }
      if (scrambledOrder.length != targetSequence.length - 1) {
        throw ArgumentError(
            'FillMissing variant: scrambledOrder must have ${targetSequence.length - 1} '
            'entries (got ${scrambledOrder.length})');
      }
    } else {
      if (scrambledOrder.length != targetSequence.length) {
        throw ArgumentError(
            'Sort variant: scrambledOrder must have ${targetSequence.length} '
            'entries (got ${scrambledOrder.length})');
      }
    }
    return SequencingRound._(
      targetSequence: List<int>.unmodifiable(targetSequence),
      scrambledOrder: List<int>.unmodifiable(scrambledOrder),
      missingPosition: missingPosition,
    );
  }

  /// The correct ascending order, e.g. [3, 4, 5, 6, 7].
  final List<int> targetSequence;

  /// The numerals presented to the child, in scrambled order.
  /// - Sort variant: 5 entries, permutation of [targetSequence].
  /// - FillMissing: 4 entries, target minus the missing value.
  final List<int> scrambledOrder;

  /// Index in [targetSequence] of the missing slot. `null` for Sort variant.
  final int? missingPosition;

  bool get isSort => missingPosition == null;
  bool get isFillMissing => missingPosition != null;

  /// The numeral that was removed in FillMissing variant. Throws if called
  /// on a Sort round.
  int get missingValue {
    final pos = missingPosition;
    if (pos == null) {
      throw StateError('missingValue: not a FillMissing round');
    }
    return targetSequence[pos];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SequencingRound &&
          runtimeType == other.runtimeType &&
          _listEq(targetSequence, other.targetSequence) &&
          _listEq(scrambledOrder, other.scrambledOrder) &&
          missingPosition == other.missingPosition;

  @override
  int get hashCode => Object.hash(
      Object.hashAll(targetSequence),
      Object.hashAll(scrambledOrder),
      missingPosition);

  @override
  String toString() => 'SequencingRound(target=$targetSequence, '
      'scrambled=$scrambledOrder, missing=$missingPosition)';

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Generates [SequencingRound]s. Deterministic when constructed with a
/// seeded Random via [seed].
class SequencingRoundGenerator {
  SequencingRoundGenerator({int? seed}) : _rng = Random(seed);

  final Random _rng;

  /// Roll a new round.
  ///
  /// Picks a random starting numeral in 1..6 (so the run 1..5, 2..6, ...,
  /// 6..10 stays inside 1..10), then ~50/50 between Sort and FillMissing
  /// variants and shuffles accordingly.
  SequencingRound generate() {
    final start = 1 + _rng.nextInt(6); // 1..6
    final target = <int>[for (var i = 0; i < 5; i++) start + i];
    final isFillMissing = _rng.nextBool();
    if (isFillMissing) {
      final missingPos = _rng.nextInt(5);
      final missingVal = target[missingPos];
      final remaining = <int>[...target]..remove(missingVal);
      remaining.shuffle(_rng);
      return SequencingRound(
        targetSequence: target,
        scrambledOrder: remaining,
        missingPosition: missingPos,
      );
    }
    final scrambled = <int>[...target]..shuffle(_rng);
    return SequencingRound(
      targetSequence: target,
      scrambledOrder: scrambled,
    );
  }
}
