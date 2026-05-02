import '../../core/manifest/utterance_key.dart';

/// Canonical child name. The pre-baked "Halló Hugrún" narration matches
/// this exact string. D-18.
const String kCanonicalChildName = 'Hugrún';

/// Pure: name → UtteranceKey selection logic (D-18).
///
/// Returns null only when no narration variant is available for the
/// input AND the canonical-fallback is also absent (i.e. completely
/// empty manifest — should never happen in practice).
///
/// Phase 2 stub state: narrationWelcomeGeneric is NOT in the enum yet.
/// The function uses runtime `UtteranceKey.values.where(...)` to detect
/// the symbol's presence, so when Phase 3 extends the enum, the same
/// code at runtime starts returning the new key with no edit needed.
UtteranceKey? selectWelcomeNarrationKey(String? name) {
  if (name == kCanonicalChildName) {
    return UtteranceKey.narrationWelcome;
  }
  // Look for the generic variant by name (defensive against Phase 2 stub).
  final generic = UtteranceKey.values
      .where((k) => k.name == 'narrationWelcomeGeneric')
      .toList();
  if (generic.isNotEmpty) return generic.first;
  // Stub fallback: re-use the canonical narration. Logs as a debug
  // warning at the call site (controller). Acceptable for stub-only
  // state — Hugrún's clip plays even when the name doesn't match.
  return UtteranceKey.narrationWelcome;
}
