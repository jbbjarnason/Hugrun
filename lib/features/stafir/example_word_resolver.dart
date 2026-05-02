import '../../core/manifest/utterance_key.dart';

/// Slug → UtteranceKey resolver. Plan 04-04.
///
/// Returns null when the enum doesn't yet have an entry for this letter
/// (Phase 2 stub state — only letterA, letterEth, letterThorn, wordHundur,
/// narrationWelcome are defined). Phase 3's regenerated audio_manifest.g.dart
/// extends UtteranceKey with all 32 letterX + 32 wordY entries; once it does,
/// this function's switch needs extending too — see the manifest swap-in
/// note in `lib/features/stafir/stafir_room.dart`.
///
/// We keep the switch dense + compile-safe: only enum values that exist in
/// the current Phase-2 stub are referenced. Adding a missing letter slug
/// here would fail compilation.
UtteranceKey? letterToUtteranceKey(String slug) {
  switch (slug) {
    case 'a':
      return UtteranceKey.letterA;
    case 'eth':
      return UtteranceKey.letterEth;
    case 'thorn':
      return UtteranceKey.letterThorn;
    default:
      // Phase 3 will fill in the rest. Until then, the StafirRoom tap path
      // returns null here and AudioEngine logs a debug warning.
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

/// Strips the `word` prefix from a `wordX` UtteranceKey to recover the
/// asset slug. Convention enforced by Phase 3's manifest writer:
/// `wordHundur` → `hundur`. For non-`word*` keys, returns the enum name
/// unchanged (defensive).
String slugFromWordKey(UtteranceKey k) {
  final name = k.name;
  if (!name.startsWith('word')) return name;
  // Drop the 'word' prefix, then lowercase the first character (PascalCase
  // → lowercase): wordHundur → Hundur → hundur.
  final remainder = name.substring(4);
  if (remainder.isEmpty) return name;
  return remainder[0].toLowerCase() + remainder.substring(1);
}
