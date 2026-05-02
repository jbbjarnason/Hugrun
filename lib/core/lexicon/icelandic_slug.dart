// Phase 11 fix-pass — Icelandic word → ASCII slug transliteration.
//
// Per Phase 2 D-03 / lexicon.dart header: special Icelandic letters in slugs
// are transliterated to ASCII so file names stay portable and predictable
// across the asset bundle. The starter lexicon (lib/core/lexicon/lexicon.dart)
// already follows these rules — this file extracts the transliteration rule
// into a reusable pure function so callers (CVC activity, matching activity)
// can derive `assets/images/letters/words/<slug>.webp` from any Icelandic
// word string at runtime without re-encoding the table.
//
// Pure Dart per check-domain-purity.sh — lib/core/lexicon/ is on the
// allow-list and must not import package:flutter.
//
// Transliteration table (Phase 2 D-03):
//   á → a    é → e    í → i    ó → o    ú → u    ý → y
//   ð → d    þ → th   æ → ae   ö → o
//
// Casing: input is lowercased first; the slug is always lowercase ASCII.
// Non-Icelandic characters that survive the table (e.g. spaces, hyphens) are
// left as-is — callers should pass clean noun strings (the starter lexicon
// is the source of truth for word-form choice).

/// Converts an Icelandic word like `'kýr'`, `'hús'`, or `'köttur'` to its
/// ASCII slug form (`'kyr'`, `'hus'`, `'kottur'`) used in asset filenames
/// at `assets/images/letters/words/<slug>.webp`.
///
/// Examples:
/// ```dart
/// icelandicWordToSlug('kýr');     // 'kyr'
/// icelandicWordToSlug('hús');     // 'hus'
/// icelandicWordToSlug('köttur');  // 'kottur'
/// icelandicWordToSlug('brauð');   // 'braud'
/// icelandicWordToSlug('þorn');    // 'thorn'
/// icelandicWordToSlug('mjólk');   // 'mjolk'
/// ```
String icelandicWordToSlug(String word) {
  final lower = word.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    switch (ch) {
      case 'á':
        buf.write('a');
      case 'é':
        buf.write('e');
      case 'í':
        buf.write('i');
      case 'ó':
        buf.write('o');
      case 'ú':
        buf.write('u');
      case 'ý':
        buf.write('y');
      case 'ð':
        buf.write('d');
      case 'þ':
        buf.write('th');
      case 'æ':
        buf.write('ae');
      case 'ö':
        buf.write('o');
      default:
        buf.write(ch);
    }
  }
  return buf.toString();
}
