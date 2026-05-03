// CorrespondenceRound — pure-Dart value class for one-to-one correspondence
// rounds (Phase 9 Plan 09-01; NUM-04).
//
// Decisions exercised:
//   D-01  Round model: count (IcelandicNumber, value 1..5) + noun (Noun) +
//         tap targets (one per object).
//   D-02  Picture-object counting uses GENDER of the depicted noun.
//         numberAudioKey(value, noun.gender) resolves the right audio.
//   D-03  Round generator picks random count 1..5, random noun.
//   D-04  Last number narrated equals the count (NUM-04).
//   D-05  Tapping a previously-tapped object is a no-op (widget concern,
//         not the model's).
//
// Pure Dart per Phase 8 D-04 — no Flutter imports. Lives under
// lib/core/numbers/, which is in tools/check-domain-purity.sh's allow-list.
//
// Lexicon note (Phase 10): Phase 9 ships a hardcoded built-in noun set
// (kCorrespondenceNouns) drawn from the Phase 4 example_word manifest.
// Phase 10 introduces the full lexicon (~200 nouns) — at that point this
// hardcoded set is replaced by the lexicon binding (Riverpod swap, no
// code change in CorrespondenceActivity).

import 'dart:math';

import 'gender.dart';
import 'icelandic_number.dart';
import 'numbers.dart';

/// One pictured noun used in a correspondence round.
///
/// `word` is the Icelandic noun string (e.g. "hundur"); `gender` selects the
/// audio variant for picture-object counting; `imagePath` is the Flutter
/// asset path for the rendered illustration. Phase 9 reuses Phase 4/5
/// example-word slugs (no new assets).
class Noun {
  const Noun({
    required this.word,
    required this.gender,
    required this.imagePath,
  });

  final String word;
  final Gender gender;
  final String imagePath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Noun &&
          runtimeType == other.runtimeType &&
          word == other.word &&
          gender == other.gender &&
          imagePath == other.imagePath;

  @override
  int get hashCode => Object.hash(word, gender, imagePath);

  @override
  String toString() => 'Noun(word=$word, gender=$gender, imagePath=$imagePath)';
}

/// Built-in noun set for Phase 9 — drawn from the Phase 4/5 example-word
/// manifest. Mix of masculine, feminine, and neuter for gender coverage
/// (NUM-03 — picture-object counting uses depicted noun's gender).
///
/// Phase 10 introduces the full ~200-noun lexicon and replaces this
/// constant with a lexicon-backed Riverpod binding.
const List<Noun> kCorrespondenceNouns = <Noun>[
  // Masculine
  Noun(
    word: 'hundur',
    gender: Gender.masculine,
    imagePath: 'assets/images/letters/words/hundur.webp',
  ),
  Noun(
    word: 'fiskur',
    gender: Gender.masculine,
    imagePath: 'assets/images/letters/words/fiskur.webp',
  ),
  Noun(
    word: 'lampi',
    gender: Gender.masculine,
    imagePath: 'assets/images/letters/words/lampi.webp',
  ),
  // Feminine
  Noun(
    word: 'kýr',
    gender: Gender.feminine,
    imagePath: 'assets/images/letters/words/kyr.webp',
  ),
  Noun(
    word: 'sól',
    gender: Gender.feminine,
    imagePath: 'assets/images/letters/words/sol.webp',
  ),
  Noun(
    word: 'rós',
    gender: Gender.feminine,
    imagePath: 'assets/images/letters/words/ros.webp',
  ),
  // Neuter
  Noun(
    word: 'hús',
    gender: Gender.neuter,
    imagePath: 'assets/images/letters/words/hus.webp',
  ),
  Noun(
    word: 'epli',
    gender: Gender.neuter,
    imagePath: 'assets/images/letters/words/epli.webp',
  ),
];

/// One tap target in a correspondence round — one of `count` copies of the
/// noun's image. Carries an index 0..count-1 so the widget can wire taps
/// without reaching into the round's internal state.
class TapTarget {
  const TapTarget({required this.index});

  /// 0-based position in the round's tapTargets list.
  final int index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TapTarget &&
          runtimeType == other.runtimeType &&
          index == other.index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'TapTarget(index=$index)';
}

/// One round of the One-to-One Correspondence activity.
///
/// Asserting factory enforces NUM-04 invariants:
///   - count.value in 1..5
///   - tapTargets.length == count.value
class CorrespondenceRound {
  const CorrespondenceRound._({
    required this.count,
    required this.noun,
    required this.tapTargets,
  });

  /// Asserting factory — used by the generator and by tests.
  factory CorrespondenceRound({
    required IcelandicNumber count,
    required Noun noun,
  }) {
    if (count.value < 1 || count.value > 5) {
      throw RangeError.range(
        count.value,
        1,
        5,
        'count.value',
        'CorrespondenceRound: count must be in 1..5 per NUM-04',
      );
    }
    final targets = List<TapTarget>.unmodifiable(<TapTarget>[
      for (var i = 0; i < count.value; i++) TapTarget(index: i),
    ]);
    return CorrespondenceRound._(count: count, noun: noun, tapTargets: targets);
  }

  /// IcelandicNumber for the count (1..5).
  final IcelandicNumber count;

  /// The pictured noun. count copies of [Noun.imagePath] are rendered.
  final Noun noun;

  /// `count.value` tap targets, indexed 0..count-1.
  final List<TapTarget> tapTargets;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CorrespondenceRound &&
          runtimeType == other.runtimeType &&
          count == other.count &&
          noun == other.noun &&
          _listEq(tapTargets, other.tapTargets);

  @override
  int get hashCode => Object.hash(count, noun, Object.hashAll(tapTargets));

  @override
  String toString() =>
      'CorrespondenceRound(count=$count, noun=$noun, '
      'tapTargets=${tapTargets.length})';

  static bool _listEq(List<TapTarget> a, List<TapTarget> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Generates [CorrespondenceRound]s. Deterministic when constructed with
/// a seed via [seed].
class CorrespondenceRoundGenerator {
  CorrespondenceRoundGenerator({int? seed})
    : _rng = seed != null ? Random(seed) : Random();

  final Random _rng;

  /// Roll a new round.
  ///
  /// Picks random count 1..5 and random noun from [kCorrespondenceNouns].
  CorrespondenceRound generate() {
    final value = 1 + _rng.nextInt(5); // 1..5
    final number = kIcelandicNumbers[value - 1];
    final noun =
        kCorrespondenceNouns[_rng.nextInt(kCorrespondenceNouns.length)];
    return CorrespondenceRound(count: number, noun: noun);
  }
}
