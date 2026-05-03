// Letter → (letter-name, optional example-word) resolver. Pure Dart.
//
// Decisions exercised:
//   D-04  cancel-on-retap / cancel-on-other-tap (orchestrated by AudioEngine.play)
//   D-05  letter→word played as a single ConcatenatingAudioSource for gapless
//   D-22  Phase 4 plans against the Phase 2 stub manifest until Phase 3 ships
//   D-23  Letters without paired words: name-only playback (graceful fallback)
//
// Plan 04-02 owns the source of truth for the letter→word pairing table.
// Phase 3 has shipped the full 32-letter manifest; this map covers all 32
// (letter → example word) pairings. The example-word picks for each letter
// follow the canonical list from manifest.yaml (`starts_with` field for
// each `wordX` entry — letterEth → wordEth uses `maður` per the
// notes_for_reviewer there because ð is rare word-initially).

import '../manifest/audio_asset.dart';
import '../manifest/utterance_key.dart';
import '../../gen/audio_manifest.g.dart';

/// Result of resolving a tap to its audio clip queue.
///
/// - [nameKey]: always non-null. The letter-name (or narration / atomic word)
///   to play first.
/// - [wordKey]: optional. If non-null, AudioEngine queues this clip after
///   [nameKey] in a single [ConcatenatingAudioSource] for gapless playback.
class ResolvedUtterance {
  const ResolvedUtterance({required this.nameKey, this.wordKey});
  final UtteranceKey nameKey;
  final UtteranceKey? wordKey;

  @override
  String toString() => 'ResolvedUtterance(name=$nameKey, word=$wordKey)';
}

/// Letter → example-word pairing table. All 32 (letter → word) pairings.
///
/// One special case: letterH → wordHundur (Phase 2 stub key kept as the
/// canonical "h" example word per manifest.yaml notes_for_reviewer —
/// "wordHundur IS wordH"). All other letters pair to their wordX counterpart.
const Map<UtteranceKey, UtteranceKey>
kLetterToWord = <UtteranceKey, UtteranceKey>{
  UtteranceKey.letterA: UtteranceKey.wordA,
  UtteranceKey.letterAAcute: UtteranceKey.wordAAcute,
  UtteranceKey.letterAe: UtteranceKey.wordAe,
  UtteranceKey.letterB: UtteranceKey.wordB,
  UtteranceKey.letterD: UtteranceKey.wordD,
  UtteranceKey.letterE: UtteranceKey.wordE,
  UtteranceKey.letterEAcute: UtteranceKey.wordEAcute,
  UtteranceKey.letterEth: UtteranceKey.wordEth,
  UtteranceKey.letterF: UtteranceKey.wordF,
  UtteranceKey.letterG: UtteranceKey.wordG,
  // Phase 2 stub key kept as canonical "h" example word.
  UtteranceKey.letterH: UtteranceKey.wordHundur,
  UtteranceKey.letterI: UtteranceKey.wordI,
  UtteranceKey.letterIAcute: UtteranceKey.wordIAcute,
  UtteranceKey.letterJ: UtteranceKey.wordJ,
  UtteranceKey.letterK: UtteranceKey.wordK,
  UtteranceKey.letterL: UtteranceKey.wordL,
  UtteranceKey.letterM: UtteranceKey.wordM,
  UtteranceKey.letterN: UtteranceKey.wordN,
  UtteranceKey.letterO: UtteranceKey.wordO,
  UtteranceKey.letterOAcute: UtteranceKey.wordOAcute,
  UtteranceKey.letterOumlaut: UtteranceKey.wordOumlaut,
  UtteranceKey.letterP: UtteranceKey.wordP,
  UtteranceKey.letterR: UtteranceKey.wordR,
  UtteranceKey.letterS: UtteranceKey.wordS,
  UtteranceKey.letterT: UtteranceKey.wordT,
  UtteranceKey.letterThorn: UtteranceKey.wordThorn,
  UtteranceKey.letterU: UtteranceKey.wordU,
  UtteranceKey.letterUAcute: UtteranceKey.wordUAcute,
  UtteranceKey.letterV: UtteranceKey.wordV,
  UtteranceKey.letterX: UtteranceKey.wordX,
  UtteranceKey.letterY: UtteranceKey.wordY,
  UtteranceKey.letterYAcute: UtteranceKey.wordYAcute,
};

/// Pure resolver. Returns null wordKey when:
///   - No pairing exists for [key] in the active pairing table, OR
///   - The pairing target is absent from the active manifest (Phase 2 stub
///     graceful fallback per D-23).
///
/// [manifestOverride] / [pairingOverride] let tests inject a fixture without
/// mutating the production constants.
ResolvedUtterance resolveLetterToClips(
  UtteranceKey key, {
  Map<UtteranceKey, AudioAsset>? manifestOverride,
  Map<UtteranceKey, UtteranceKey>? pairingOverride,
}) {
  final manifest = manifestOverride ?? kAudioManifest;
  final pairings = pairingOverride ?? kLetterToWord;
  final word = pairings[key];
  if (word != null && manifest.containsKey(word)) {
    return ResolvedUtterance(nameKey: key, wordKey: word);
  }
  return ResolvedUtterance(nameKey: key);
}
