// Phase 9 Plan 09-02 Workstream B — RED tests for SubitizingRound model
// + SubitizingRoundGenerator (NUM-05).
//
// Decisions exercised:
//   D-06  Round flashes 1..5 dots in varied arrangements (dice, line,
//         random, finger).
//   D-07  Arrangements rotate to prevent visual memorization.
//   D-08  Flash duration 1.5s default (research range 1-3s); tunable const.
//   D-09  No fail state. Wrong tap = no-op (widget concern).
//
// Pure Dart per Phase 8 D-04 — no Flutter imports.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/numbers/subitizing_round.dart';

void main() {
  group('DotArrangement enum (D-06, D-07)', () {
    test('A1: ships exactly 4 arrangements (dice, line, random, finger)', () {
      expect(DotArrangement.values.length, 4);
      expect(DotArrangement.values, containsAll(<DotArrangement>[
        DotArrangement.dice,
        DotArrangement.line,
        DotArrangement.random,
        DotArrangement.finger,
      ]));
    });
  });

  group('SubitizingRound model (D-06)', () {
    test('S1: stores count, arrangement, dot positions', () {
      final round = SubitizingRound(
        count: 3,
        arrangement: DotArrangement.dice,
        dotPositions: const <DotPosition>[
          DotPosition(x: 0.2, y: 0.2),
          DotPosition(x: 0.5, y: 0.5),
          DotPosition(x: 0.8, y: 0.8),
        ],
      );
      expect(round.count, 3);
      expect(round.arrangement, DotArrangement.dice);
      expect(round.dotPositions.length, 3);
    });

    test('S2: count must be 1..5 (NUM-05)', () {
      expect(
        () => SubitizingRound(
          count: 6,
          arrangement: DotArrangement.dice,
          dotPositions: const <DotPosition>[],
        ),
        throwsA(anything),
      );
      expect(
        () => SubitizingRound(
          count: 0,
          arrangement: DotArrangement.dice,
          dotPositions: const <DotPosition>[],
        ),
        throwsA(anything),
      );
    });

    test('S3: dotPositions length must equal count', () {
      expect(
        () => SubitizingRound(
          count: 3,
          arrangement: DotArrangement.dice,
          dotPositions: const <DotPosition>[
            DotPosition(x: 0.5, y: 0.5),
          ], // 1 dot for count=3 — invalid
        ),
        throwsA(anything),
      );
    });

    test('S4: equality + hashCode', () {
      final a = SubitizingRound(
        count: 2,
        arrangement: DotArrangement.line,
        dotPositions: const <DotPosition>[
          DotPosition(x: 0.3, y: 0.5),
          DotPosition(x: 0.7, y: 0.5),
        ],
      );
      final b = SubitizingRound(
        count: 2,
        arrangement: DotArrangement.line,
        dotPositions: const <DotPosition>[
          DotPosition(x: 0.3, y: 0.5),
          DotPosition(x: 0.7, y: 0.5),
        ],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('S5: dotPositions are within [0..1]', () {
      // Defensive: layouts use normalized coords; out-of-range = bug.
      expect(
        () => SubitizingRound(
          count: 1,
          arrangement: DotArrangement.random,
          dotPositions: const <DotPosition>[
            DotPosition(x: 1.5, y: 0.5),
          ],
        ),
        throwsA(anything),
      );
    });
  });

  group('kSubitizingFlashDuration', () {
    test('F1: default flash duration is 1.5 seconds (D-08)', () {
      expect(kSubitizingFlashDuration, const Duration(milliseconds: 1500));
    });
  });

  group('SubitizingRoundGenerator (D-06, D-07)', () {
    test('G1: generate() returns count in 1..5', () {
      final gen = SubitizingRoundGenerator(seed: 42);
      for (var i = 0; i < 30; i++) {
        final round = gen.generate();
        expect(round.count, inInclusiveRange(1, 5));
      }
    });

    test('G2: generate() dotPositions length matches count', () {
      final gen = SubitizingRoundGenerator(seed: 7);
      for (var i = 0; i < 20; i++) {
        final round = gen.generate();
        expect(round.dotPositions.length, round.count);
      }
    });

    test('G3: generate() arrangements rotate (all 4 appear across many '
        'rounds) (D-07)', () {
      final gen = SubitizingRoundGenerator(seed: 11);
      final seen = <DotArrangement>{};
      for (var i = 0; i < 100; i++) {
        seen.add(gen.generate().arrangement);
      }
      // All 4 should appear in 100 rounds (deterministic seed makes this
      // robust as long as the implementation actually rotates).
      expect(seen, containsAll(DotArrangement.values));
    });

    test('G4: with seed, generate() is deterministic', () {
      final a = SubitizingRoundGenerator(seed: 99).generate();
      final b = SubitizingRoundGenerator(seed: 99).generate();
      expect(a, equals(b));
    });

    test('G5: dot positions are always in [0..1]', () {
      final gen = SubitizingRoundGenerator(seed: 31);
      for (var i = 0; i < 50; i++) {
        for (final p in gen.generate().dotPositions) {
          expect(p.x, inInclusiveRange(0.0, 1.0));
          expect(p.y, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });
}
