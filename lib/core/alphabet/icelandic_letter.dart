// Pure-Dart domain model. Phase 1 D-08 + Phase 2 D-13 require
// `lib/core/alphabet/` to stay Flutter-free; tools/check-domain-purity.sh
// enforces this on CI.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'icelandic_letter.freezed.dart';

/// One letter of the canonical 32-letter Icelandic alphabet.
///
/// - [glyph]: the Unicode display character (e.g. 'a', 'á', 'ð', 'þ', 'æ', 'ö').
///   This is what is rendered in the Stafir grid and what `kIcelandicAlphabet`
///   iteration order is keyed on.
/// - [name]: the Icelandic spoken letter name (e.g. 'a', 'á', 'eð', 'þoddn',
///   'eff'). Used as a human-readable label and as the audio-key lookup hint;
///   the audio manifest itself keys on [UtteranceKey] not on [name].
///   Phase 3's TTS pipeline owns the final pronunciation review.
/// - [assetSlug]: ASCII-safe filename slug per CONTEXT D-03 (e.g. 'a',
///   'a_acute', 'eth', 'thorn', 'ae', 'o_umlaut'). Used to construct asset
///   paths under `assets/audio/letters/names/<slug>.aac`. Lowercase ASCII,
///   `^[a-z][a-z0-9_]*$`, unique across the alphabet.
@freezed
abstract class IcelandicLetter with _$IcelandicLetter {
  const factory IcelandicLetter({
    required String glyph,
    required String name,
    required String assetSlug,
  }) = _IcelandicLetter;
}
