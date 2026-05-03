// Pure-Dart domain model for one CVC starter-word triple. Phase 6 D-05.
//
// A CvcWord describes a 3-letter Icelandic word for the CVC blending
// activity (CVC-01..CVC-03). The blend mechanic is:
//
//   1. Render image of the word at the top of the round.
//   2. Render 3 LetterTiles in a row: c1, v, c2 (display order).
//   3. Child taps each letter — AudioEngine plays the matching phoneme
//      (resolved via phoneme_resolver.dart).
//   4. After all 3 are tapped (any order; D-11 soft order), AudioEngine
//      plays the wordClip — the full blended word audio.
//
// Pure Dart per Phase 6 D-06; tools/check-domain-purity.sh covers
// lib/core/cvc/.

import '../alphabet/icelandic_letter.dart';
import '../manifest/utterance_key.dart';

/// One CVC starter-word triple.
///
/// - [word]: the 3-character Icelandic word (e.g. "kýr", "hús", "gás").
/// - [c1]: first consonant.
/// - [v]: middle vowel.
/// - [c2]: trailing consonant.
/// - [wordClip]: UtteranceKey for the full-blend audio. May resolve to
///   the Phase-3 example_word entry (kýr/wordK) or a Phase-6 new entry
///   under assets/audio/cvc/ (hús/wordHus).
///
/// All three letters are full IcelandicLetter values (not glyph strings)
/// so the activity can render them via LetterTile (Phase 4) without
/// re-resolving — the round generator picks them from kIcelandicAlphabet
/// and the CvcWord just hands the references through.
class CvcWord {
  const CvcWord({
    required this.word,
    required this.c1,
    required this.v,
    required this.c2,
    required this.wordClip,
  });

  final String word;
  final IcelandicLetter c1;
  final IcelandicLetter v;
  final IcelandicLetter c2;
  final UtteranceKey wordClip;

  /// Convenience: [c1, v, c2] in display order. The CVC widget renders
  /// LetterTiles in this order; D-11 soft-order means the child can tap
  /// any of the three first, but the visual layout is still left-to-right.
  List<IcelandicLetter> get letters => <IcelandicLetter>[c1, v, c2];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CvcWord &&
          runtimeType == other.runtimeType &&
          word == other.word &&
          c1 == other.c1 &&
          v == other.v &&
          c2 == other.c2 &&
          wordClip == other.wordClip;

  @override
  int get hashCode => Object.hash(word, c1, v, c2, wordClip);

  @override
  String toString() =>
      'CvcWord($word: ${c1.glyph}-${v.glyph}-${c2.glyph}, '
      'clip=${wordClip.name})';
}
