// Pure-Dart round generator for the Letter-to-Word Matching activity
// (Phase 5 Plan 05-01). Produces a [MatchingRound] from a manifest +
// alphabet + photo-override source.
//
// Decisions exercised:
//   D-03   Round = one target word + 4 letter options (correct + 3 distractors).
//   D-04   Distractors must avoid visually-similar pairs (a/á, e/é, i/í,
//          o/ó, u/ú, y/ý) — see [kSimilarPairs].
//   D-05   Pure Dart. No package:flutter imports allowed under
//          lib/core/matching/ (tools/check-domain-purity.sh).
//   D-06   Round count = infinite. Caller invokes generate() each time.
//   D-13   Photo override hook with ~40% Bernoulli when overrides exist
//          (MATCH-04). Phase 5 ships [EmptyPhotoOverrideSource] as the
//          default; Phase 10 swaps the Riverpod binding.
//
// Layering note (intentional duplication):
//   This file deliberately re-implements `_slugFromWordKey` rather than
//   importing it from `lib/features/stafir/example_word_resolver.dart`.
//   Reason: lib/core/ may NOT depend on lib/features/ (per project layering
//   invariant). The duplication is small (a 4-line helper) and the
//   layering boundary is the right call. If the helper changes, both
//   copies will need updating — that is rare and easily caught by tests.

import 'dart:math';

import '../alphabet/alphabet.dart';
import '../alphabet/icelandic_letter.dart';
import '../manifest/audio_asset.dart';
import '../manifest/utterance_key.dart';
import '../../gen/audio_manifest.g.dart';
import 'matching_round.dart';
import 'photo_override_source.dart';

/// Visually-similar letter pairs that must not co-occur in a round (D-04).
/// Each inner set has size 2; outer set is iterated by [_formsSimilarPair].
///
/// The 6 pairs cover the 6 acute-accent vowel duos in Icelandic:
///   a/á, e/é, i/í, o/ó, u/ú, y/ý
/// The unmarked-vs-acute distinction is hard for a 5-year-old to
/// disambiguate visually; keeping both in the same round would test
/// recognition of the diacritic, not the letter-sound mapping the activity
/// is teaching.
const Set<Set<String>> kSimilarPairs = <Set<String>>{
  <String>{'a', 'á'},
  <String>{'e', 'é'},
  <String>{'i', 'í'},
  <String>{'o', 'ó'},
  <String>{'u', 'ú'},
  <String>{'y', 'ý'},
};

/// Returns true iff `{glyphA, glyphB}` is one of [kSimilarPairs].
bool _formsSimilarPair(String glyphA, String glyphB) {
  if (glyphA == glyphB) return false;
  final pair = <String>{glyphA, glyphB};
  for (final p in kSimilarPairs) {
    if (p.length == pair.length && p.containsAll(pair)) return true;
  }
  return false;
}

/// Strips the `word` prefix from a `wordX` UtteranceKey to recover the
/// asset slug. Same convention as Phase 4's example_word_resolver — kept
/// as a private duplicate here for layering reasons (see file header).
String _slugFromWordKey(UtteranceKey k) {
  final name = k.name;
  if (!name.startsWith('word')) return name;
  final remainder = name.substring(4);
  if (remainder.isEmpty) return name;
  return remainder[0].toLowerCase() + remainder.substring(1);
}

/// Generates [MatchingRound] instances from a manifest + alphabet pool.
///
/// Construction parameters:
///   - [seed]: optional `Random` seed for deterministic output (tests).
///     When null, uses a system-seeded Random (production).
///   - [manifestOverride]: optional manifest map. Defaults to
///     `kAudioManifest`. Tests pass a stripped-down map so the test
///     fixture is decoupled from Phase 3's manifest contents.
///   - [photoSource]: photo override source. Defaults to
///     [EmptyPhotoOverrideSource]; Phase 10 swaps this via the
///     `photoOverrideSourceProvider` Riverpod binding.
///   - [photoFrequency]: Bernoulli probability of routing to a photo
///     when overrides exist. Default 0.40 per D-13.
class RoundGenerator {
  RoundGenerator({
    int? seed,
    Map<UtteranceKey, AudioAsset>? manifestOverride,
    PhotoOverrideSource photoSource = const EmptyPhotoOverrideSource(),
    double photoFrequency = 0.40,
  }) : _random = seed != null ? Random(seed) : Random(),
       _manifest = manifestOverride ?? kAudioManifest,
       _photoSource = photoSource,
       _photoFrequency = photoFrequency;

  final Random _random;
  final Map<UtteranceKey, AudioAsset> _manifest;
  final PhotoOverrideSource _photoSource;
  final double _photoFrequency;

  /// Generates one [MatchingRound]. Idempotent in the sense that two
  /// constructions with the same seed produce the same first-N sequence
  /// (G6).
  ///
  /// Throws [StateError] when:
  ///   - the manifest contains zero `word*` entries (G11), or
  ///   - the derived correct letter has no entry in `kIcelandicAlphabet`
  ///     (defensive — should not happen with the canonical alphabet).
  MatchingRound generate() {
    // 1. Filter to word* manifest entries.
    final wordKeys = _manifest.keys
        .where((k) => k.name.startsWith('word'))
        .toList();
    if (wordKeys.isEmpty) {
      throw StateError(
        'RoundGenerator: manifest has no word* entries — cannot generate '
        'a round (Phase 5 expects ≥1 wordX UtteranceKey).',
      );
    }

    // 2. Pick a target.
    final targetWordKey = wordKeys[_random.nextInt(wordKeys.length)];
    final targetWordSlug = _slugFromWordKey(targetWordKey);

    // 3. Resolve correct letter from slug[0].
    if (targetWordSlug.isEmpty) {
      throw StateError(
        'RoundGenerator: target slug is empty for ${targetWordKey.name}',
      );
    }
    final firstChar = targetWordSlug.substring(0, 1);
    final correctLetter = kIcelandicAlphabet.firstWhere(
      (l) => l.glyph == firstChar,
      orElse: () => throw StateError(
        'RoundGenerator: no IcelandicLetter for glyph "$firstChar" '
        '(target ${targetWordKey.name})',
      ),
    );

    // 4. Build distractor pool: alphabet minus correct minus its similar
    //    counterparts.
    final distractorPool =
        kIcelandicAlphabet
            .where(
              (l) =>
                  l != correctLetter &&
                  !_formsSimilarPair(correctLetter.glyph, l.glyph),
            )
            .toList()
          ..shuffle(_random);

    // 5. Greedy pick of 3 distractors, skipping any that forms a similar
    //    pair with an already-selected distractor.
    final distractors = <IcelandicLetter>[];
    for (final candidate in distractorPool) {
      if (distractors.length == 3) break;
      final formsPair = distractors.any(
        (d) => _formsSimilarPair(d.glyph, candidate.glyph),
      );
      if (!formsPair) distractors.add(candidate);
    }
    if (distractors.length < 3) {
      // Defensive — alphabet is large enough that this should never trip.
      throw StateError(
        'RoundGenerator: could not select 3 distinct non-similar '
        'distractors for ${correctLetter.glyph}',
      );
    }

    // 6. Combined options shuffled into random position.
    final options = <IcelandicLetter>[correctLetter, ...distractors]
      ..shuffle(_random);

    // 7. Image source: photo override Bernoulli vs stock placeholder.
    final overrides = _photoSource.photosForWordSlug(targetWordSlug);
    final ImageSource imageSource;
    if (overrides.isNotEmpty && _random.nextDouble() < _photoFrequency) {
      final photoId = overrides[_random.nextInt(overrides.length)];
      imageSource = ImageSource.photoOverride(photoId: photoId);
    } else {
      imageSource = ImageSource.stockPlaceholder(wordSlug: targetWordSlug);
    }

    return MatchingRound(
      targetWordKey: targetWordKey,
      targetWordSlug: targetWordSlug,
      correctLetter: correctLetter,
      options: options,
      imageSource: imageSource,
    );
  }
}
