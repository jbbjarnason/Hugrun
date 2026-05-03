// Pure-Dart value class for the Letter-to-Word Matching round (Phase 5
// Plan 05-01). Decisions:
//   D-03  Round = one target word + 4 letter options (correct + 3 distractors).
//   D-04  Distractors avoid visually-similar pairs — enforced by RoundGenerator,
//         not here; this file only models the value object.
//   D-05  Pure Dart. lib/core/matching/ is in DOMAIN_PATHS and must not import
//         package:flutter (tools/check-domain-purity.sh).
//   D-13  ImageSource has two cases: StockPlaceholder (Phase 5 default,
//         text-on-color) and PhotoOverride (Phase 10 personalization slot).
//
// The class is Freezed for value equality + immutability — same pattern as
// lib/core/alphabet/icelandic_letter.dart. Constructor assertions are wired
// inside the Freezed factory body using Freezed's
// `@Assert(...)` annotations OR a private factory + factory-with-assert
// indirection. Freezed's union mechanism generates `when/map` arms keyed on
// the case factory's name, which means a `_internal` private factory leaks
// into the API as an underscore-prefixed parameter name (illegal Dart). We
// therefore use the simpler single-factory + `@Assert` form for
// MatchingRound, and the union form for ImageSource where it's valid.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../alphabet/icelandic_letter.dart';
import '../manifest/utterance_key.dart';

part 'matching_round.freezed.dart';

/// The image area for a matching round.
///
/// Sealed via Freezed's union types. Two cases:
///   - [ImageSource.stockPlaceholder]: Phase 5 default — a text-on-color tile
///     showing the word slug. Lives until Phase 10 ships custom illustrations
///     or the parent uploads a photo for the matching tag (D-12).
///   - [ImageSource.photoOverride]: Phase 10 personalization slot — selects a
///     parent-uploaded photo by opaque photoId. Routed via the
///     PhotoOverrideSource at ~40% Bernoulli when photos exist (D-13,
///     MATCH-04).
@freezed
sealed class ImageSource with _$ImageSource {
  const factory ImageSource.stockPlaceholder({required String wordSlug}) =
      StockPlaceholder;

  const factory ImageSource.photoOverride({required String photoId}) =
      PhotoOverride;
}

/// One round of the Letter-to-Word Matching activity.
///
/// Invariants (asserted at construction time via Freezed `@Assert`):
///   - `options.length == 4`
///   - `options.toSet().length == 4` (no duplicate letters)
///   - `options.contains(correctLetter)`
///
/// The `targetWordSlug` is the lower-snake form of the word (e.g.
/// `hundur`), derived from `targetWordKey` via the round generator's
/// `_slugFromWordKey`. We store both because:
///   - the key is the manifest lookup contract (audio dispatch),
///   - the slug is the human-readable thing the placeholder/photo uses.
@Freezed()
abstract class MatchingRound with _$MatchingRound {
  @Assert(
    'options.length == 4',
    'MatchingRound: options must contain exactly 4 letters',
  )
  @Assert(
    'options.toSet().length == 4',
    'MatchingRound: options must contain no duplicate letters',
  )
  @Assert(
    'options.contains(correctLetter)',
    'MatchingRound: correctLetter must appear in options',
  )
  factory MatchingRound({
    required UtteranceKey targetWordKey,
    required String targetWordSlug,
    required IcelandicLetter correctLetter,
    required List<IcelandicLetter> options,
    required ImageSource imageSource,
  }) = _MatchingRound;
}
