// Pure-Dart domain enum for the audio manifest contract. Phase 1 D-08 +
// Phase 2 D-13 require lib/core/manifest/ to stay Flutter-free; the audio
// layer (Phase 4) imports this enum and the generated kAudioManifest map
// without reaching into Flutter widgets.

/// The set of audio utterances Phase 2 ships as a manifest stub.
///
/// Phase 3's Python TTS pipeline regenerates `lib/gen/audio_manifest.g.dart`
/// against this enum (paths + durations change; the enum identifiers
/// MUST stay stable across regenerations). The hand-written stub used in
/// Phase 2 is exhaustive at compile time — adding a new entry without a
/// matching `kAudioManifest` mapping is a compile-time error in
/// `getAudioAsset` and a test failure in `audio_manifest_test.dart`.
///
/// Entries (D-08):
/// - [letterA]: the letter "a" name (`assets/audio/letters/names/a.aac`).
///   Simplest case in the D-03 slug map.
/// - [letterEth]: the letter "ð" name (`.../names/eth.aac`). Exercises the
///   diacritic→ASCII slug mapping for `ð`.
/// - [letterThorn]: the letter "þ" name (`.../names/thorn.aac`). Exercises
///   the diacritic→ASCII slug mapping for `þ`.
/// - [wordHundur]: example word "hundur" / "dog" (`.../words/hundur.aac`).
///   Phase 4 plays this when the child taps the letter `h`.
/// - [narrationWelcome]: the open-app greeting voice clip
///   (`.../narration/welcome_hugrun.aac`). Phase 4 plays this on first
///   home-screen render for PERS-03 (welcome-the-child personalization).
enum UtteranceKey {
  letterA,
  letterEth,
  letterThorn,
  wordHundur,
  narrationWelcome,
}
