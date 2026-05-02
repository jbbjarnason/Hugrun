// Canonical 32-letter Icelandic alphabet in MMS (Menntamálastofnun) school
// order. Source: PITFALLS #2, RESEARCH SUMMARY Finding 3, CONTEXT D-02.
// No C, Q, W, or Z. ASCII-safe slugs per CONTEXT D-03.
//
// Pure Dart — see Phase 1 D-08 / Phase 2 D-13 (no package:flutter imports).
import 'icelandic_letter.dart';

/// The canonical 32-letter Icelandic alphabet in MMS (Menntamálastofnun)
/// school order. Phase 4 renders this as the Stafir grid; Phase 3 keys the
/// generated audio manifest off these slugs; Phase 6 keys phonemes off them.
///
/// Order: a á b d ð e é f g h i í j k l m n o ó p r s t u ú v x y ý þ æ ö
///
/// **Do not change order without updating PITFALLS #2.** Drift here means the
/// shipped app teaches a different alphabet than Hugrún sees in school.
const List<IcelandicLetter> kIcelandicAlphabet = <IcelandicLetter>[
  // Row 1: a á b d ð e é f
  IcelandicLetter(glyph: 'a', name: 'a', assetSlug: 'a'),
  IcelandicLetter(glyph: 'á', name: 'á', assetSlug: 'a_acute'),
  IcelandicLetter(glyph: 'b', name: 'bé', assetSlug: 'b'),
  IcelandicLetter(glyph: 'd', name: 'dé', assetSlug: 'd'),
  IcelandicLetter(glyph: 'ð', name: 'eð', assetSlug: 'eth'),
  IcelandicLetter(glyph: 'e', name: 'e', assetSlug: 'e'),
  IcelandicLetter(glyph: 'é', name: 'é', assetSlug: 'e_acute'),
  IcelandicLetter(glyph: 'f', name: 'eff', assetSlug: 'f'),
  // Row 2: g h i í j k l m
  IcelandicLetter(glyph: 'g', name: 'gé', assetSlug: 'g'),
  IcelandicLetter(glyph: 'h', name: 'há', assetSlug: 'h'),
  IcelandicLetter(glyph: 'i', name: 'i', assetSlug: 'i'),
  IcelandicLetter(glyph: 'í', name: 'í', assetSlug: 'i_acute'),
  IcelandicLetter(glyph: 'j', name: 'joð', assetSlug: 'j'),
  IcelandicLetter(glyph: 'k', name: 'ká', assetSlug: 'k'),
  IcelandicLetter(glyph: 'l', name: 'ell', assetSlug: 'l'),
  IcelandicLetter(glyph: 'm', name: 'emm', assetSlug: 'm'),
  // Row 3: n o ó p r s t u
  IcelandicLetter(glyph: 'n', name: 'enn', assetSlug: 'n'),
  IcelandicLetter(glyph: 'o', name: 'o', assetSlug: 'o'),
  IcelandicLetter(glyph: 'ó', name: 'ó', assetSlug: 'o_acute'),
  IcelandicLetter(glyph: 'p', name: 'pé', assetSlug: 'p'),
  IcelandicLetter(glyph: 'r', name: 'err', assetSlug: 'r'),
  IcelandicLetter(glyph: 's', name: 'ess', assetSlug: 's'),
  IcelandicLetter(glyph: 't', name: 'té', assetSlug: 't'),
  IcelandicLetter(glyph: 'u', name: 'u', assetSlug: 'u'),
  // Row 4: ú v x y ý þ æ ö
  IcelandicLetter(glyph: 'ú', name: 'ú', assetSlug: 'u_acute'),
  IcelandicLetter(glyph: 'v', name: 'vaff', assetSlug: 'v'),
  IcelandicLetter(glyph: 'x', name: 'ex', assetSlug: 'x'),
  IcelandicLetter(glyph: 'y', name: 'ufsilon-y', assetSlug: 'y'),
  IcelandicLetter(glyph: 'ý', name: 'ufsilon-ý', assetSlug: 'y_acute'),
  IcelandicLetter(glyph: 'þ', name: 'þorn', assetSlug: 'thorn'),
  IcelandicLetter(glyph: 'æ', name: 'æ', assetSlug: 'ae'),
  IcelandicLetter(glyph: 'ö', name: 'ö', assetSlug: 'o_umlaut'),
];
