// Phase 10 D-05 / D-07 — Curated starter lexicon for parent photo tagging.
//
// Pure Dart. No package:flutter imports. Enforced by
// tools/check-domain-purity.sh (lib/core/lexicon/ added in Plan 10-02).
//
// Scope:
//   * 30 common kid-relevant nouns covering pets, food, household objects,
//     body parts, vehicles, weather, family-adjacent items.
//   * Each entry gets the canonical default image path under
//     `assets/images/letters/words/<slug>.webp` so the matching activity
//     keeps rendering when no parent photo is uploaded for that word.
//   * Slug rules: lowercase ASCII, special Icelandic letters transliterated
//     (á→a, ð→d, é→e, í→i, ó→o, ú→u, ý→y, þ→th, æ→ae, ö→o). Phase 2 D-03
//     convention.
//
// Future expansion (CONTEXT D-07):
//   * Full ~200-entry set is a polish pass.
//   * Audio integration (LexiconEntry.audioKey field referencing UtteranceKey)
//     is deferred until Phase 3's TTS pipeline ships full noun coverage.
//
// PRIVACY: this list is shipped baked-in. Free-text lexicon entries are
// deferred to v2 (PERS-V2-01) — they would require runtime TTS, which
// PROJECT.md explicitly excludes.

import 'gender.dart';
import 'lexicon_entry.dart';

/// Starter lexicon (30 entries). The matching activity falls back to
/// `defaultImagePath` when the parent has not tagged a photo for the word.
const List<LexiconEntry> kStarterLexicon = <LexiconEntry>[
  // Animals / pets (8)
  LexiconEntry(
    word: 'hundur',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/hundur.webp',
  ),
  LexiconEntry(
    word: 'köttur',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/kottur.webp',
  ),
  LexiconEntry(
    word: 'kýr',
    gender: Gender.feminine,
    defaultImagePath: 'assets/images/letters/words/kyr.webp',
  ),
  LexiconEntry(
    word: 'hestur',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/hestur.webp',
  ),
  LexiconEntry(
    word: 'fugl',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/fugl.webp',
  ),
  LexiconEntry(
    word: 'fiskur',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/fiskur.webp',
  ),
  LexiconEntry(
    word: 'mús',
    gender: Gender.feminine,
    defaultImagePath: 'assets/images/letters/words/mus.webp',
  ),
  LexiconEntry(
    word: 'kanína',
    gender: Gender.feminine,
    defaultImagePath: 'assets/images/letters/words/kanina.webp',
  ),

  // Food (5)
  LexiconEntry(
    word: 'epli',
    gender: Gender.neuter,
    defaultImagePath: 'assets/images/letters/words/epli.webp',
  ),
  LexiconEntry(
    word: 'banani',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/banani.webp',
  ),
  LexiconEntry(
    word: 'brauð',
    gender: Gender.neuter,
    defaultImagePath: 'assets/images/letters/words/braud.webp',
  ),
  LexiconEntry(
    word: 'mjólk',
    gender: Gender.feminine,
    defaultImagePath: 'assets/images/letters/words/mjolk.webp',
  ),
  LexiconEntry(
    word: 'vatn',
    gender: Gender.neuter,
    defaultImagePath: 'assets/images/letters/words/vatn.webp',
  ),

  // Outdoors / nature (4)
  LexiconEntry(
    word: 'sól',
    gender: Gender.feminine,
    defaultImagePath: 'assets/images/letters/words/sol.webp',
  ),
  LexiconEntry(
    word: 'máni',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/mani.webp',
  ),
  LexiconEntry(
    word: 'tré',
    gender: Gender.neuter,
    defaultImagePath: 'assets/images/letters/words/tre.webp',
  ),
  LexiconEntry(
    word: 'blóm',
    gender: Gender.neuter,
    defaultImagePath: 'assets/images/letters/words/blom.webp',
  ),

  // Toys / household (8)
  LexiconEntry(
    word: 'bók',
    gender: Gender.feminine,
    defaultImagePath: 'assets/images/letters/words/bok.webp',
  ),
  LexiconEntry(
    word: 'bíll',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/bill.webp',
  ),
  LexiconEntry(
    word: 'hús',
    gender: Gender.neuter,
    defaultImagePath: 'assets/images/letters/words/hus.webp',
  ),
  LexiconEntry(
    word: 'bolti',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/bolti.webp',
  ),
  LexiconEntry(
    word: 'dúkka',
    gender: Gender.feminine,
    defaultImagePath: 'assets/images/letters/words/dukka.webp',
  ),
  LexiconEntry(
    word: 'koddi',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/koddi.webp',
  ),
  LexiconEntry(
    word: 'teppi',
    gender: Gender.neuter,
    defaultImagePath: 'assets/images/letters/words/teppi.webp',
  ),
  LexiconEntry(
    word: 'stóll',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/stoll.webp',
  ),

  // Clothing (4)
  LexiconEntry(
    word: 'hattur',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/hattur.webp',
  ),
  LexiconEntry(
    word: 'peysa',
    gender: Gender.feminine,
    defaultImagePath: 'assets/images/letters/words/peysa.webp',
  ),
  LexiconEntry(
    word: 'sokkar',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/sokkar.webp',
  ),
  LexiconEntry(
    word: 'skór',
    gender: Gender.masculine,
    defaultImagePath: 'assets/images/letters/words/skor.webp',
  ),

  // Body (1)
  LexiconEntry(
    word: 'auga',
    gender: Gender.neuter,
    defaultImagePath: 'assets/images/letters/words/auga.webp',
  ),
];

/// Returns the [LexiconEntry] with [word] (case-sensitive, exact match), or
/// `null` if no match.
LexiconEntry? lookupLexiconEntry(String word) {
  for (final entry in kStarterLexicon) {
    if (entry.word == word) return entry;
  }
  return null;
}
