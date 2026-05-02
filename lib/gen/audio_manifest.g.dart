// GENERATED FILE -- DO NOT EDIT MANUALLY
// Hand-written stub for Phase 2; Phase 3 Python pipeline will regenerate this.
//
// Source of truth: 02-CONTEXT.md D-08 (5 UtteranceKey entries) + D-09
// (placeholder AAC files, 100 ms silent clips at 48 kHz mono 96 kbps AAC-LC,
// or copy-fixture stand-ins when ffmpeg is unavailable).
//
// Contract: kAudioManifest is exhaustive at compile time. Adding a new
// UtteranceKey without a matching kAudioManifest entry surfaces as a runtime
// throw via getAudioAsset() and a test failure in audio_manifest_test.dart.
// Phase 3 owns regeneration; do not edit by hand once the pipeline ships.

import 'package:hugrun/core/manifest/audio_asset.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

/// All audio assets referenced by Phase 2's manifest stub. Paths are
/// project-relative and conform to D-06 (lowercase ASCII alphanumerics + . _
/// - / only). Durations are placeholders — Phase 3 measures real clips and
/// rewrites this file with actual values.
const Map<UtteranceKey, AudioAsset> kAudioManifest = <UtteranceKey, AudioAsset>{
  UtteranceKey.letterA: AudioAsset(
    path: 'assets/audio/letters/names/a.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
  UtteranceKey.letterEth: AudioAsset(
    path: 'assets/audio/letters/names/eth.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
  UtteranceKey.letterThorn: AudioAsset(
    path: 'assets/audio/letters/names/thorn.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
  UtteranceKey.wordHundur: AudioAsset(
    path: 'assets/audio/letters/words/hundur.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
  UtteranceKey.narrationWelcome: AudioAsset(
    path: 'assets/audio/narration/welcome_hugrun.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
};

/// Type-safe lookup. Throws if the key is absent — manifest is exhaustive at
/// compile time, so a missing entry is a programmer error, not a runtime
/// fallback condition (D-08).
AudioAsset getAudioAsset(UtteranceKey key) => kAudioManifest[key]!;
