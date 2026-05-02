// Pure-Dart slug → phoneme UtteranceKey resolver. Phase 6 D-07.
//
// Maps an IcelandicLetter.assetSlug (e.g. 'a', 'a_acute', 'eth', 'thorn',
// 'o_umlaut') to the corresponding UtteranceKey.phoneme<PascalCase>
// enum value (phonemeA, phonemeAAcute, phonemeEth, phonemeThorn,
// phonemeOumlaut, ...).
//
// Returns null when:
//   - slug is empty, OR
//   - slug is not in the canonical 32-letter alphabet (defensive — should
//     never happen with kIcelandicAlphabet inputs).
//
// The 32 phoneme UtteranceKeys exist in the enum (Phase 6 stub-extension)
// but are intentionally absent from kAudioManifest until the review pass
// (D-21). AudioEngine.play() falls back silently for missing manifest
// entries — the activity is structurally correct but plays no sound for
// unreviewed phonemes.
//
// Pure Dart per Phase 6 D-06; tools/check-domain-purity.sh covers
// lib/core/cvc/.

import '../manifest/utterance_key.dart';

/// Resolves an IcelandicLetter.assetSlug to its phoneme UtteranceKey.
///
/// Pattern: slug → PascalCase → `phoneme<PascalCase>`. The mapping is
/// hand-coded as a switch (rather than reflective enum lookup) so that
/// adding a new letter without updating this resolver fails compilation
/// — the same forward-compatible contract used by example_word_resolver.
UtteranceKey? phonemeKeyForSlug(String slug) {
  switch (slug) {
    case 'a':
      return UtteranceKey.phonemeA;
    case 'a_acute':
      return UtteranceKey.phonemeAAcute;
    case 'b':
      return UtteranceKey.phonemeB;
    case 'd':
      return UtteranceKey.phonemeD;
    case 'eth':
      return UtteranceKey.phonemeEth;
    case 'e':
      return UtteranceKey.phonemeE;
    case 'e_acute':
      return UtteranceKey.phonemeEAcute;
    case 'f':
      return UtteranceKey.phonemeF;
    case 'g':
      return UtteranceKey.phonemeG;
    case 'h':
      return UtteranceKey.phonemeH;
    case 'i':
      return UtteranceKey.phonemeI;
    case 'i_acute':
      return UtteranceKey.phonemeIAcute;
    case 'j':
      return UtteranceKey.phonemeJ;
    case 'k':
      return UtteranceKey.phonemeK;
    case 'l':
      return UtteranceKey.phonemeL;
    case 'm':
      return UtteranceKey.phonemeM;
    case 'n':
      return UtteranceKey.phonemeN;
    case 'o':
      return UtteranceKey.phonemeO;
    case 'o_acute':
      return UtteranceKey.phonemeOAcute;
    case 'p':
      return UtteranceKey.phonemeP;
    case 'r':
      return UtteranceKey.phonemeR;
    case 's':
      return UtteranceKey.phonemeS;
    case 't':
      return UtteranceKey.phonemeT;
    case 'u':
      return UtteranceKey.phonemeU;
    case 'u_acute':
      return UtteranceKey.phonemeUAcute;
    case 'v':
      return UtteranceKey.phonemeV;
    case 'x':
      return UtteranceKey.phonemeX;
    case 'y':
      return UtteranceKey.phonemeY;
    case 'y_acute':
      return UtteranceKey.phonemeYAcute;
    case 'thorn':
      return UtteranceKey.phonemeThorn;
    case 'ae':
      return UtteranceKey.phonemeAe;
    case 'o_umlaut':
      return UtteranceKey.phonemeOumlaut;
    default:
      return null;
  }
}
