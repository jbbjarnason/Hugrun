// Phase 8 Plan 08-03 Workstream C — RED tests for SequencingRound model
// + SequencingRoundGenerator.
//
// Decisions:
//   D-09  SequencingActivity is the new Tölur surface (mode = sequence).
//   D-10  Round has 5 numerals; one optionally missing; others scrambled.
//   D-11  Two variants: SortVariant (all 5 scrambled) and FillMissing
//         (one position empty, child drags candidate into the gap).
//   D-12  Drag-and-drop accepts only the correct numeral; wrong drops
//         snap back silently (no audio penalty).
//   D-13  Round complete = celebration animation; auto-advance.
//   D-14  No fail state. No score.
//
// Pure Dart per Phase 8 D-04.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/numbers/sequencing_round.dart';

void main() {
  group('SequencingRound model (D-10, D-11)', () {
    test('S1: SortVariant — all 5 numerals scrambled, no missing slot', () {
      const round = SequencingRound(
        targetSequence: <int>[1, 2, 3, 4, 5],
        scrambledOrder: <int>[3, 1, 4, 5, 2],
        missingPosition: null,
      );
      expect(round.targetSequence, <int>[1, 2, 3, 4, 5]);
      expect(round.scrambledOrder, <int>[3, 1, 4, 5, 2]);
      expect(round.missingPosition, isNull);
      expect(round.isSort, isTrue);
      expect(round.isFillMissing, isFalse);
    });

    test('S2: FillMissing — one position null/missing in render', () {
      const round = SequencingRound(
        targetSequence: <int>[1, 2, 3, 4, 5],
        scrambledOrder: <int>[1, 2, 4, 5],
        missingPosition: 2, // index 2 of targetSequence is missing → "3"
      );
      expect(round.missingPosition, 2);
      expect(round.missingValue, 3);
      expect(round.isSort, isFalse);
      expect(round.isFillMissing, isTrue);
    });

    test('S3: equality + hashCode', () {
      const a = SequencingRound(
        targetSequence: <int>[2, 3, 4, 5, 6],
        scrambledOrder: <int>[6, 4, 2, 5, 3],
        missingPosition: null,
      );
      const b = SequencingRound(
        targetSequence: <int>[2, 3, 4, 5, 6],
        scrambledOrder: <int>[6, 4, 2, 5, 3],
        missingPosition: null,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('S4: targetSequence MUST contain consecutive ascending integers', () {
      // Defensive constructor: rounds always express a contiguous run of
      // numerals from the kIcelandicNumbers domain (1..10). Non-contiguous
      // sequences are not in scope.
      expect(
        () => SequencingRound(
          targetSequence: const <int>[1, 3, 5, 7, 9],
          scrambledOrder: const <int>[1, 3, 5, 7, 9],
          missingPosition: null,
        ),
        throwsA(anything),
      );
    });

    test('S5: targetSequence length must be 5', () {
      expect(
        () => SequencingRound(
          targetSequence: const <int>[1, 2, 3, 4],
          scrambledOrder: const <int>[1, 2, 3, 4],
          missingPosition: null,
        ),
        throwsA(anything),
      );
    });

    test('S6: targetSequence values must be in 1..10', () {
      expect(
        () => SequencingRound(
          targetSequence: const <int>[7, 8, 9, 10, 11],
          scrambledOrder: const <int>[7, 8, 9, 10, 11],
          missingPosition: null,
        ),
        throwsA(anything),
      );
    });
  });

  group('SequencingRoundGenerator (D-10, D-11)', () {
    test('G1: generate() returns a 5-numeral round in 1..10 range', () {
      final gen = SequencingRoundGenerator(seed: 42);
      final round = gen.generate();
      expect(round.targetSequence.length, 5);
      for (final v in round.targetSequence) {
        expect(v, inInclusiveRange(1, 10));
      }
      // Contiguous ascending.
      for (var i = 1; i < round.targetSequence.length; i++) {
        expect(round.targetSequence[i],
            round.targetSequence[i - 1] + 1);
      }
    });

    test('G2: with seed, generate() is deterministic', () {
      final a = SequencingRoundGenerator(seed: 7).generate();
      final b = SequencingRoundGenerator(seed: 7).generate();
      expect(a, equals(b));
    });

    test('G3: scrambledOrder is a permutation of targetSequence (Sort) or '
        'targetSequence-minus-one (FillMissing)', () {
      // Sample a handful of seeds and verify the invariant.
      for (final seed in <int>[1, 2, 3, 4, 5, 11, 99, 1000]) {
        final round = SequencingRoundGenerator(seed: seed).generate();
        if (round.isSort) {
          expect(round.scrambledOrder.toSet(),
              round.targetSequence.toSet(),
              reason: 'Sort: scrambled must be permutation of target');
          expect(round.scrambledOrder.length, 5);
        } else {
          // FillMissing: scrambledOrder has 4 entries (target minus the
          // missing value), in some order.
          expect(round.scrambledOrder.length, 4);
          final expectedSet = {...round.targetSequence}..remove(
              round.missingValue);
          expect(round.scrambledOrder.toSet(), expectedSet);
        }
      }
    });

    test('G4: across many rounds both variants appear (D-11)', () {
      // 50 rounds with varying seed should yield both variants.
      var sortSeen = 0;
      var fillSeen = 0;
      for (var s = 0; s < 50; s++) {
        final r = SequencingRoundGenerator(seed: s).generate();
        if (r.isSort) {
          sortSeen++;
        } else {
          fillSeen++;
        }
      }
      expect(sortSeen, greaterThan(0), reason: 'Sort variant never produced');
      expect(fillSeen, greaterThan(0),
          reason: 'FillMissing variant never produced');
    });

    test('G5: generate() returned scrambled order is NOT identical to target '
        '(at least most of the time)', () {
      // With 5! = 120 perms, the chance of "scrambled" matching target by
      // accident is 1/120. Across 100 generations we'd expect ~0.83 hits;
      // assert <10 to give plenty of slack while still catching a bug
      // (e.g. forgetting to shuffle).
      var identical = 0;
      for (var s = 0; s < 100; s++) {
        final r = SequencingRoundGenerator(seed: s).generate();
        if (r.isSort && r.scrambledOrder.toString() ==
            r.targetSequence.toString()) {
          identical++;
        }
      }
      expect(identical, lessThan(10),
          reason: 'scrambledOrder seems unshuffled across 100 rounds');
    });
  });
}
