// Canonical 8-word CVC starter list. Phase 6 D-04, D-06; CVC-01.
//
// Word selection from .planning/research/FEATURES.md (Icelandic primary
// curriculum) and Phase 6 CONTEXT D-04: kýr, sól, hús, rós, bók, mús,
// hár, gás. All are 3-letter consonant-vowel-consonant words with clear
// child-friendly imagery.
//
// 5 of the 8 (kýr/sól/mús/rós/bók) reuse the Phase-3 example_word audio
// for their leading letter — the example_word for the letter k IS "kýr",
// for s IS "sól", etc. The remaining 3 (hús/hár/gás) ship as new audio
// entries under assets/audio/cvc/.
//
// Pure Dart per Phase 6 D-06.

import '../alphabet/alphabet.dart';
import '../alphabet/icelandic_letter.dart';
import '../manifest/utterance_key.dart';
import 'cvc_word.dart';

/// Lookup helper — returns the canonical IcelandicLetter from
/// kIcelandicAlphabet for the given Unicode glyph. Compile-time const
/// would require pre-indexing; runtime lookup is O(32) which is
/// trivial and only happens at app start when the const list is
/// dereferenced via an accessor.
IcelandicLetter _letter(String glyph) =>
    kIcelandicAlphabet.firstWhere(
      (l) => l.glyph == glyph,
      orElse: () => throw StateError(
        'kCvcWords: no IcelandicLetter for glyph "$glyph"',
      ),
    );

/// The 8 canonical CVC starter words (CVC-01).
///
/// Order: kýr, sól, hús, rós, bók, mús, hár, gás. Round generator
/// (a future enhancement) may shuffle; the activity widget treats this
/// as an unordered pool.
///
/// Note: not `const` because IcelandicLetter lookups via firstWhere
/// run at first access. Trivial cost, never re-runs (`final` once the
/// list is materialized).
final List<CvcWord> kCvcWords = <CvcWord>[
  CvcWord(
    word: 'kýr',
    c1: _letter('k'),
    v: _letter('ý'),
    c2: _letter('r'),
    wordClip: UtteranceKey.wordK,
  ),
  CvcWord(
    word: 'sól',
    c1: _letter('s'),
    v: _letter('ó'),
    c2: _letter('l'),
    wordClip: UtteranceKey.wordS,
  ),
  CvcWord(
    word: 'hús',
    c1: _letter('h'),
    v: _letter('ú'),
    c2: _letter('s'),
    wordClip: UtteranceKey.wordHus,
  ),
  CvcWord(
    word: 'rós',
    c1: _letter('r'),
    v: _letter('ó'),
    c2: _letter('s'),
    wordClip: UtteranceKey.wordR,
  ),
  CvcWord(
    word: 'bók',
    c1: _letter('b'),
    v: _letter('ó'),
    c2: _letter('k'),
    wordClip: UtteranceKey.wordB,
  ),
  CvcWord(
    word: 'mús',
    c1: _letter('m'),
    v: _letter('ú'),
    c2: _letter('s'),
    wordClip: UtteranceKey.wordM,
  ),
  CvcWord(
    word: 'hár',
    c1: _letter('h'),
    v: _letter('á'),
    c2: _letter('r'),
    wordClip: UtteranceKey.wordHar,
  ),
  CvcWord(
    word: 'gás',
    c1: _letter('g'),
    v: _letter('á'),
    c2: _letter('s'),
    wordClip: UtteranceKey.wordGas,
  ),
];
