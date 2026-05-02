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
/// Phase 2 stub entries (D-08):
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
///
/// Phase 6 stub-extension entries (D-01..D-07; CVC-01..CVC-03):
/// - `phoneme*` (32 entries) — phoneme audio set, distinct from letter
///   names. `assets/audio/letters/phonemes/{slug}.aac`. Awaiting
///   reviewer pass; until reviewed, `kAudioManifest` does NOT contain
///   these keys and `AudioEngine.play()` falls back silently per D-21.
/// - [wordHus], [wordHar], [wordGas] — 3 additional CVC starter words
///   (the other 5 reuse existing word* keys per D-04).
///   Same review-pass posture as phoneme entries.
enum UtteranceKey {
  // Phase 2 stub keys (D-22 backward compat).
  letterA,
  letterEth,
  letterThorn,
  wordHundur,
  narrationWelcome,

  // Phase 6 phoneme set (D-01, CVC-02). 32 entries — one per Icelandic
  // letter. Naming follows IcelandicLetter.assetSlug → PascalCase.
  phonemeA,
  phonemeAAcute,
  phonemeB,
  phonemeD,
  phonemeEth,
  phonemeE,
  phonemeEAcute,
  phonemeF,
  phonemeG,
  phonemeH,
  phonemeI,
  phonemeIAcute,
  phonemeJ,
  phonemeK,
  phonemeL,
  phonemeM,
  phonemeN,
  phonemeO,
  phonemeOAcute,
  phonemeP,
  phonemeR,
  phonemeS,
  phonemeT,
  phonemeU,
  phonemeUAcute,
  phonemeV,
  phonemeX,
  phonemeY,
  phonemeYAcute,
  phonemeThorn,
  phonemeAe,
  phonemeOumlaut,

  // Phase 6 CVC starter-word references (D-04).
  //
  // The 8-word CVC starter set is: kýr, sól, hús, rós, bók, mús, hár, gás.
  // 5 of those 8 happen to be the Phase-3 example_word for their letter
  // (kýr/wordK, sól/wordS, mús/wordM, rós/wordR, bók/wordB). Those 5 keys
  // exist in manifest.yaml as `kind: example_word` entries; Phase 6 adds
  // the enum identifiers so `CvcWord.wordClip` can reference them. They
  // remain absent from the Phase 2 `kAudioManifest` stub (D-21 silent
  // fallback) until the review pass regenerates lib/gen/audio_manifest.g.dart.
  //
  // The remaining 3 (hús, hár, gás) are new in Phase 6 and live under
  // `assets/audio/cvc/` rather than `assets/audio/letters/words/` — see
  // manifest.yaml for the asset-path mapping.
  wordK,
  wordS,
  wordM,
  wordR,
  wordB,
  wordHus,
  wordHar,
  wordGas,
}
