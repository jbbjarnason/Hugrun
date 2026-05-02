// Phase 10 D-06 — Pure-Dart lexicon. No package:flutter imports.

import 'gender.dart';

/// One curated noun in the personalization lexicon.
///
/// - [word]: the Icelandic noun in nominative singular, all lowercase
///   (e.g. `'hundur'`, `'kýr'`, `'epli'`). The matching join key when
///   parent-uploaded photos are reconciled with stock images
///   (`photo_tags.lexicon_word` column).
/// - [gender]: grammatical gender. Used by future numeracy phases for
///   gender-correct number agreement (Phase 9 D-15); not yet used by the
///   matching activity.
/// - [defaultImagePath]: the stock asset path used when no parent photo
///   exists for this word. Should follow `assets/images/letters/words/<slug>.webp`
///   convention (Phase 2 D-06 / D-10). The slug is ASCII-safe and lowercase
///   per Phase 2 conventions; Icelandic special letters in the [word] are
///   transliterated in the slug (eg `kýr` → `kyr.webp`, `kötur` → `kottur.webp`).
///
/// Pure value class — `==` and `hashCode` are derived field-by-field via the
/// const constructor + [==] override below.
class LexiconEntry {
  const LexiconEntry({
    required this.word,
    required this.gender,
    required this.defaultImagePath,
  });

  final String word;
  final Gender gender;
  final String defaultImagePath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LexiconEntry &&
          other.word == word &&
          other.gender == gender &&
          other.defaultImagePath == defaultImagePath);

  @override
  int get hashCode => Object.hash(word, gender, defaultImagePath);

  @override
  String toString() =>
      'LexiconEntry(word: $word, gender: $gender, '
      'defaultImagePath: $defaultImagePath)';
}
