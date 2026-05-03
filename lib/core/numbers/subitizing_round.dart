// SubitizingRound — pure-Dart value class for subitizing rounds (Phase 9
// Plan 09-02; NUM-05).
//
// Decisions exercised:
//   D-06  Round flashes 1..5 dots in varied arrangements: dice (canonical
//         for 1..6), line (left-to-right), random scatter, finger pattern
//         (mimicking hand-counting).
//   D-07  Arrangements rotate to prevent visual memorization. The
//         generator round-robins through DotArrangement.values.
//   D-08  Flash duration default 1.5 seconds (research range 1-3s);
//         tunable via [kSubitizingFlashDuration].
//   D-09  No fail state. Wrong tap on the numeral options = no-op
//         (handled by widget per Phase 5 D-07 silent-no-op pattern).
//
// Pure Dart per Phase 8 D-04 — no Flutter imports. Lives under
// lib/core/numbers/, in tools/check-domain-purity.sh's allow-list.

import 'dart:math';

/// The four arrangement patterns for the dot flash (D-06, D-07).
enum DotArrangement {
  /// Canonical dice/domino arrangement (research: instantly recognizable
  /// for 1..6, child intuits the pattern).
  dice,

  /// Left-to-right linear arrangement.
  line,

  /// Random scatter — exposes the kid to non-canonical arrangements.
  random,

  /// Finger arrangement — five spots clustered like a hand, used for
  /// finger-counting analog.
  finger,
}

/// Default flash duration for the subitizing prompt (D-08, research 1-3s).
const Duration kSubitizingFlashDuration = Duration(milliseconds: 1500);

/// Normalized 2D coordinate of a dot inside the flash area.
/// Both [x] and [y] are in `[0..1]`; the widget multiplies by the rendered
/// area's pixel dimensions to position dots.
class DotPosition {
  const DotPosition({required this.x, required this.y});

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DotPosition &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'DotPosition(x=$x, y=$y)';
}

/// One round of the Subitizing activity.
class SubitizingRound {
  const SubitizingRound._({
    required this.count,
    required this.arrangement,
    required this.dotPositions,
  });

  /// Asserting factory.
  factory SubitizingRound({
    required int count,
    required DotArrangement arrangement,
    required List<DotPosition> dotPositions,
  }) {
    if (count < 1 || count > 5) {
      throw RangeError.range(
        count,
        1,
        5,
        'count',
        'SubitizingRound: count must be in 1..5 per NUM-05',
      );
    }
    if (dotPositions.length != count) {
      throw ArgumentError(
        'SubitizingRound: dotPositions.length must equal count '
        '(got ${dotPositions.length} dots for count=$count)',
      );
    }
    for (final p in dotPositions) {
      if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
        throw RangeError('SubitizingRound: dotPosition out of [0..1]: $p');
      }
    }
    return SubitizingRound._(
      count: count,
      arrangement: arrangement,
      dotPositions: List<DotPosition>.unmodifiable(dotPositions),
    );
  }

  /// 1..5.
  final int count;

  final DotArrangement arrangement;

  /// `count` normalized dot positions inside the flash area.
  final List<DotPosition> dotPositions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubitizingRound &&
          runtimeType == other.runtimeType &&
          count == other.count &&
          arrangement == other.arrangement &&
          _listEq(dotPositions, other.dotPositions);

  @override
  int get hashCode =>
      Object.hash(count, arrangement, Object.hashAll(dotPositions));

  @override
  String toString() =>
      'SubitizingRound(count=$count, '
      'arrangement=$arrangement, dots=${dotPositions.length})';

  static bool _listEq(List<DotPosition> a, List<DotPosition> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Generates [SubitizingRound]s. Deterministic when constructed with a seed.
class SubitizingRoundGenerator {
  SubitizingRoundGenerator({int? seed})
    : _rng = seed != null ? Random(seed) : Random();

  final Random _rng;
  int _arrangementIndex = 0;

  /// Roll a new round. Picks count 1..5 randomly, rotates through
  /// DotArrangement.values to ensure variety (D-07), generates positions
  /// per arrangement.
  SubitizingRound generate() {
    final count = 1 + _rng.nextInt(5); // 1..5
    final arrangement =
        DotArrangement.values[_arrangementIndex % DotArrangement.values.length];
    _arrangementIndex++;
    final positions = _positionsFor(count, arrangement);
    return SubitizingRound(
      count: count,
      arrangement: arrangement,
      dotPositions: positions,
    );
  }

  List<DotPosition> _positionsFor(int count, DotArrangement arr) {
    switch (arr) {
      case DotArrangement.dice:
        return _dicePositions(count);
      case DotArrangement.line:
        return _linePositions(count);
      case DotArrangement.random:
        return _randomPositions(count);
      case DotArrangement.finger:
        return _fingerPositions(count);
    }
  }

  /// Canonical dice / domino patterns for 1..5.
  List<DotPosition> _dicePositions(int count) {
    switch (count) {
      case 1:
        return const <DotPosition>[DotPosition(x: 0.5, y: 0.5)];
      case 2:
        return const <DotPosition>[
          DotPosition(x: 0.25, y: 0.25),
          DotPosition(x: 0.75, y: 0.75),
        ];
      case 3:
        return const <DotPosition>[
          DotPosition(x: 0.25, y: 0.25),
          DotPosition(x: 0.5, y: 0.5),
          DotPosition(x: 0.75, y: 0.75),
        ];
      case 4:
        return const <DotPosition>[
          DotPosition(x: 0.25, y: 0.25),
          DotPosition(x: 0.75, y: 0.25),
          DotPosition(x: 0.25, y: 0.75),
          DotPosition(x: 0.75, y: 0.75),
        ];
      case 5:
        return const <DotPosition>[
          DotPosition(x: 0.25, y: 0.25),
          DotPosition(x: 0.75, y: 0.25),
          DotPosition(x: 0.5, y: 0.5),
          DotPosition(x: 0.25, y: 0.75),
          DotPosition(x: 0.75, y: 0.75),
        ];
      default:
        throw RangeError.value(count, 'count');
    }
  }

  /// Horizontal line at y=0.5.
  List<DotPosition> _linePositions(int count) {
    final dots = <DotPosition>[];
    final spacing = 1.0 / (count + 1);
    for (var i = 1; i <= count; i++) {
      dots.add(DotPosition(x: i * spacing, y: 0.5));
    }
    return dots;
  }

  /// Random scatter inside [0.1..0.9] to keep dots away from edges.
  List<DotPosition> _randomPositions(int count) {
    final dots = <DotPosition>[];
    for (var i = 0; i < count; i++) {
      final x = 0.1 + _rng.nextDouble() * 0.8;
      final y = 0.1 + _rng.nextDouble() * 0.8;
      dots.add(DotPosition(x: x, y: y));
    }
    return dots;
  }

  /// "Finger" arrangement — analogous to dots on a raised hand.
  List<DotPosition> _fingerPositions(int count) {
    // 5 fixed slots evenly spaced along y=0.4 (representing finger tips
    // above a palm). Truncate to first `count` slots.
    const slots = <DotPosition>[
      DotPosition(x: 0.15, y: 0.4),
      DotPosition(x: 0.325, y: 0.3),
      DotPosition(x: 0.5, y: 0.25),
      DotPosition(x: 0.675, y: 0.3),
      DotPosition(x: 0.85, y: 0.4),
    ];
    return slots.sublist(0, count);
  }
}
