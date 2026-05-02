// Tracing celebration audio — D-14 fallback chain.
//
// On round-complete the activity plays a celebration narration. The
// preferred clip is `narrationCelebrationTracing` ("Frábært!" or "Vel
// gert, Hugrún!"). Phase 7 ships the manifest with a placeholder for
// this entry — the actual AAC will land via Phase 3's review pipeline
// in a later commit. Until then, we soft-fall-back to the existing
// `narrationWelcome` clip (which is reviewed and shipping).
//
// The lookup uses runtime introspection on UtteranceKey.values to detect
// whether `narrationCelebrationTracing` exists in the enum. This pattern
// is consistent with `selectWelcomeNarrationKey` in
// lib/features/home/welcome_narration_keys.dart — adding the symbol to
// the enum (no other code change) is all it takes for the celebration
// audio to start firing the new clip.
//
// AudioEngine handles the missing-asset case silently (Phase 4 D-22 +
// D-23 stub fallback): if the celebration key resolves to a symbol that
// kAudioManifest doesn't contain, AudioEngine logs a debug warning and
// returns silently — no exception. So callers can fire-and-forget.

import '../../../core/manifest/utterance_key.dart';

/// Returns the [UtteranceKey] to play on tracing-round completion.
///
/// Lookup order (D-14):
///   1. `narrationCelebrationTracing` — preferred celebration clip.
///   2. `narrationWelcome` — soft fallback (always present in the
///      Phase 2 stub manifest, ensuring the activity always has SOMETHING
///      to play on completion). The "Halló Hugrún" greeting is a
///      pleasant, name-aware narration that gracefully covers gaps.
///
/// Both branches return a non-null UtteranceKey. AudioEngine.play() may
/// still no-op silently if the key isn't present in `kAudioManifest`
/// (Phase 4 D-22 stub fallback), but the caller is unaware of that.
UtteranceKey selectCelebrationKey() {
  final celebration = UtteranceKey.values
      .where((k) => k.name == 'narrationCelebrationTracing')
      .toList();
  if (celebration.isNotEmpty) return celebration.first;
  return UtteranceKey.narrationWelcome;
}
