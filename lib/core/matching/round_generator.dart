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
//   invariant). The duplication is small and the layering boundary is the
//   right call. If the helper changes, both copies will need updating —
//   that is rare and easily caught by tests.
//
// Slug derivation (post-Phase-3):
//   Earlier this helper stripped the `word` PascalCase prefix
//   (`wordHundur` → `hundur`, but `wordA` → `a`, which was wrong — the
//   real audio asset for `wordA` is `api.aac`). The current implementation
//   reads the AudioAsset path from the manifest and extracts the basename
//   (`assets/audio/letters/words/api.aac` → `api`). This produces the
//   correct slug for every `word*` key and is the slug the image lookup
//   in `assets/images/letters/words/<slug>.webp` expects.

import 'dart:math';

import '../alphabet/alphabet.dart';
import '../alphabet/icelandic_letter.dart';
import '../audio/utterance_resolver.dart';
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

/// Returns the actual asset slug for a `word*` UtteranceKey, derived from
/// the manifest path. Mirrors `slugFromWordKey` in the features layer —
/// kept as a private duplicate here for layering reasons (see file header).
///
/// Reads the AudioAsset path from [manifest] and extracts the basename
/// without extension (`assets/audio/letters/words/hundur.aac` → `hundur`).
/// Falls back to enum name when the key isn't in the manifest (defensive).
String _slugFromWordKey(
  UtteranceKey k,
  Map<UtteranceKey, AudioAsset> manifest,
) {
  final asset = manifest[k];
  if (asset == null) return k.name;
  final path = asset.path;
  final lastSlash = path.lastIndexOf('/');
  final filename = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  final dotIdx = filename.lastIndexOf('.');
  return dotIdx >= 0 ? filename.substring(0, dotIdx) : filename;
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
    // 1. Build the eligible (letterKey, wordKey, glyph) target list. Two
    //    sources:
    //      a) kLetterToWord pairings whose wordKey is in the manifest. This
    //         yields the canonical (letter, word) pairings — including
    //         letters whose example word does not begin with the bare letter
    //         glyph (letterEth → wordEth/maður, letterAAcute → wordAAcute/ár,
    //         etc.). These are correct-by-construction.
    //      b) word* manifest entries that have NO entry in kLetterToWord but
    //         whose slug's first character matches a glyph in the alphabet
    //         (legacy path). Phase 3's manifest covers all 32 letters via (a),
    //         so (b) is a safety net that keeps the original Phase 5 contract
    //         working when a test fixture omits the pairing table.
    final pairedTargets = <_Target>[];
    kLetterToWord.forEach((letterKey, wordKey) {
      if (!_manifest.containsKey(wordKey)) return;
      final letter = _letterForKey(letterKey);
      if (letter == null) return;
      pairedTargets.add(_Target(letter: letter, wordKey: wordKey));
    });

    // Add word* manifest entries that don't already appear in pairedTargets.
    // Resolves their letter via the slug-first-char heuristic (Phase 5
    // legacy path; only triggers when the pairing table is bypassed via a
    // test fixture).
    final pairedWordKeys = pairedTargets.map((t) => t.wordKey).toSet();
    for (final k in _manifest.keys) {
      if (!k.name.startsWith('word')) continue;
      if (pairedWordKeys.contains(k)) continue;
      final slug = _slugFromWordKey(k, _manifest);
      if (slug.isEmpty) continue;
      final firstChar = slug.substring(0, 1);
      final letter = kIcelandicAlphabet.firstWhere(
        (l) => l.glyph == firstChar,
        orElse: () => throw StateError(
          'RoundGenerator: no IcelandicLetter for glyph "$firstChar" '
          '(target ${k.name})',
        ),
      );
      pairedTargets.add(_Target(letter: letter, wordKey: k));
    }

    if (pairedTargets.isEmpty) {
      throw StateError(
        'RoundGenerator: manifest has no word* entries — cannot generate '
        'a round (Phase 5 expects ≥1 wordX UtteranceKey).',
      );
    }

    // 2. Pick a target.
    final picked = pairedTargets[_random.nextInt(pairedTargets.length)];
    final targetWordKey = picked.wordKey;
    final correctLetter = picked.letter;
    final targetWordSlug = _slugFromWordKey(targetWordKey, _manifest);
    if (targetWordSlug.isEmpty) {
      throw StateError(
        'RoundGenerator: target slug is empty for ${targetWordKey.name}',
      );
    }

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

/// Internal target row: (correctLetter, wordKey) tuple.
class _Target {
  const _Target({required this.letter, required this.wordKey});
  final IcelandicLetter letter;
  final UtteranceKey wordKey;
}

/// Resolves a `letter*` UtteranceKey to its IcelandicLetter. Hand-mapped
/// alongside `kLetterToWord` so the inverse direction stays explicit.
/// Returns null only for non-`letter*` keys (defensive — the caller filters
/// to letterKey-keyed map entries).
IcelandicLetter? _letterForKey(UtteranceKey k) {
  switch (k) {
    case UtteranceKey.letterA:
      return _byGlyph('a');
    case UtteranceKey.letterAAcute:
      return _byGlyph('á');
    case UtteranceKey.letterAe:
      return _byGlyph('æ');
    case UtteranceKey.letterB:
      return _byGlyph('b');
    case UtteranceKey.letterD:
      return _byGlyph('d');
    case UtteranceKey.letterE:
      return _byGlyph('e');
    case UtteranceKey.letterEAcute:
      return _byGlyph('é');
    case UtteranceKey.letterEth:
      return _byGlyph('ð');
    case UtteranceKey.letterF:
      return _byGlyph('f');
    case UtteranceKey.letterG:
      return _byGlyph('g');
    case UtteranceKey.letterH:
      return _byGlyph('h');
    case UtteranceKey.letterI:
      return _byGlyph('i');
    case UtteranceKey.letterIAcute:
      return _byGlyph('í');
    case UtteranceKey.letterJ:
      return _byGlyph('j');
    case UtteranceKey.letterK:
      return _byGlyph('k');
    case UtteranceKey.letterL:
      return _byGlyph('l');
    case UtteranceKey.letterM:
      return _byGlyph('m');
    case UtteranceKey.letterN:
      return _byGlyph('n');
    case UtteranceKey.letterO:
      return _byGlyph('o');
    case UtteranceKey.letterOAcute:
      return _byGlyph('ó');
    case UtteranceKey.letterOumlaut:
      return _byGlyph('ö');
    case UtteranceKey.letterP:
      return _byGlyph('p');
    case UtteranceKey.letterR:
      return _byGlyph('r');
    case UtteranceKey.letterS:
      return _byGlyph('s');
    case UtteranceKey.letterT:
      return _byGlyph('t');
    case UtteranceKey.letterThorn:
      return _byGlyph('þ');
    case UtteranceKey.letterU:
      return _byGlyph('u');
    case UtteranceKey.letterUAcute:
      return _byGlyph('ú');
    case UtteranceKey.letterV:
      return _byGlyph('v');
    case UtteranceKey.letterX:
      return _byGlyph('x');
    case UtteranceKey.letterY:
      return _byGlyph('y');
    case UtteranceKey.letterYAcute:
      return _byGlyph('ý');
    default:
      return null;
  }
}

IcelandicLetter _byGlyph(String glyph) =>
    kIcelandicAlphabet.firstWhere((l) => l.glyph == glyph);

