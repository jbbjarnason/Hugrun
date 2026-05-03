import '../../core/manifest/utterance_key.dart';
import '../../gen/audio_manifest.g.dart';

/// Slug → UtteranceKey resolver.
///
/// Maps an [IcelandicLetter.assetSlug] (e.g. `a`, `a_acute`, `eth`, `thorn`,
/// `o_umlaut`) to the corresponding `UtteranceKey.letter<PascalCase>` enum
/// value. The 32-case switch is hand-coded (not reflective) so adding a new
/// letter slug without extending this resolver fails compilation — same
/// forward-compatible contract as `phonemeKeyForSlug` (Phase 6 D-07).
///
/// Returns null only for unknown slugs; the canonical 32-letter alphabet
/// is fully covered.
UtteranceKey? letterToUtteranceKey(String slug) {
  switch (slug) {
    case 'a':
      return UtteranceKey.letterA;
    case 'a_acute':
      return UtteranceKey.letterAAcute;
    case 'b':
      return UtteranceKey.letterB;
    case 'd':
      return UtteranceKey.letterD;
    case 'eth':
      return UtteranceKey.letterEth;
    case 'e':
      return UtteranceKey.letterE;
    case 'e_acute':
      return UtteranceKey.letterEAcute;
    case 'f':
      return UtteranceKey.letterF;
    case 'g':
      return UtteranceKey.letterG;
    case 'h':
      return UtteranceKey.letterH;
    case 'i':
      return UtteranceKey.letterI;
    case 'i_acute':
      return UtteranceKey.letterIAcute;
    case 'j':
      return UtteranceKey.letterJ;
    case 'k':
      return UtteranceKey.letterK;
    case 'l':
      return UtteranceKey.letterL;
    case 'm':
      return UtteranceKey.letterM;
    case 'n':
      return UtteranceKey.letterN;
    case 'o':
      return UtteranceKey.letterO;
    case 'o_acute':
      return UtteranceKey.letterOAcute;
    case 'p':
      return UtteranceKey.letterP;
    case 'r':
      return UtteranceKey.letterR;
    case 's':
      return UtteranceKey.letterS;
    case 't':
      return UtteranceKey.letterT;
    case 'u':
      return UtteranceKey.letterU;
    case 'u_acute':
      return UtteranceKey.letterUAcute;
    case 'v':
      return UtteranceKey.letterV;
    case 'x':
      return UtteranceKey.letterX;
    case 'y':
      return UtteranceKey.letterY;
    case 'y_acute':
      return UtteranceKey.letterYAcute;
    case 'thorn':
      return UtteranceKey.letterThorn;
    case 'ae':
      return UtteranceKey.letterAe;
    case 'o_umlaut':
      return UtteranceKey.letterOumlaut;
    default:
      return null;
  }
}

/// Project-relative path to the example-word image asset for the given
/// word slug. Phase 4 ships placeholder text-on-color tiles when the
/// image asset doesn't exist (the image probe via `rootBundle.load`
/// catches the absence at runtime).
String exampleWordImagePath(String wordSlug) =>
    'assets/images/letters/words/$wordSlug.webp';

/// Display text for the placeholder tile when no image exists. Phase 4
/// ships this as the literal slug ('hundur'); a polish pass or Phase 10
/// personalization may replace with illustrations.
String exampleWordPlaceholderText(String wordSlug) => wordSlug;

/// Returns the actual asset slug for a `word*` UtteranceKey, derived from
/// the manifest path (`assets/audio/letters/words/<slug>.aac` → `<slug>`).
///
/// This replaces the older PascalCase-strip heuristic (`wordHundur` →
/// `hundur`) which was correct for `wordHundur` only by coincidence —
/// `wordA` strips to `a`, but the real audio is `api.aac` and the actual
/// slug is `api`. Reading from the manifest path is the only correct
/// derivation for arbitrary `word*` keys.
///
/// For non-`word*` keys or word keys missing from the manifest, falls
/// back to the enum name unchanged (defensive — callers only pass
/// confirmed `word*` keys in practice).
String slugFromWordKey(UtteranceKey k) {
  final asset = kAudioManifest[k];
  if (asset != null) {
    return _slugFromAssetPath(asset.path);
  }
  // Fallback: enum name unchanged. Documented as defensive behavior.
  return k.name;
}

/// Extracts the basename without extension from an asset path.
/// `assets/audio/letters/words/hundur.aac` → `hundur`.
String _slugFromAssetPath(String path) {
  final lastSlash = path.lastIndexOf('/');
  final filename = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  final dotIdx = filename.lastIndexOf('.');
  return dotIdx >= 0 ? filename.substring(0, dotIdx) : filename;
}

