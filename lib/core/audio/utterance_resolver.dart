// Letter → (letter-name, optional example-word) resolver. Pure Dart.
//
// Decisions exercised:
//   D-04  cancel-on-retap / cancel-on-other-tap (orchestrated by AudioEngine.play)
//   D-05  letter→word played as a single ConcatenatingAudioSource for gapless
//   D-22  Phase 4 plans against the Phase 2 stub manifest until Phase 3 ships
//   D-23  Letters without paired words: name-only playback (graceful fallback)
//
// Plan 04-02 owns the source of truth for the letter→word pairing table.
// Phase 2 stub state ships with kLetterToWord empty (the stub doesn't have
// the letter↔word pairings — Phase 3 will populate this).

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

/// Letter → example-word pairing table. Phase 2 stub: empty (no pairings).
///
/// Phase 3 manifest writer will populate this with the 32 (letterX → wordY)
/// pairings once the live audio is reviewed and approved. The shape is
/// stable; only values change. Resolver does NOT hardcode any pairing —
/// it reads this map at call time.
const Map<UtteranceKey, UtteranceKey> kLetterToWord = <UtteranceKey, UtteranceKey>{
  // Phase 2 stub state: no useful pairings yet.
  // Phase 3 will populate (e.g. UtteranceKey.letterH → UtteranceKey.wordHundur)
  // once that letterH symbol exists in the enum.
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
