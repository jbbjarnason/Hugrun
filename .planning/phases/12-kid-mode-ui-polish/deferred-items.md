# Deferred Items — Phase 12 (Kid-Mode UI Polish)

Items discovered during Phase 12 execution that are **out of scope**
for Phase 12 (which owns `lib/features/`, widget code, and home-screen
icons). Listed here so the verifier / next phase can pick them up.

## Pre-existing failure: `audio_manifest_test.dart` D-21 stub gate

**Test:** `test/core/manifest/audio_manifest_test.dart` —
"kAudioManifest Phase 6 phoneme + new word keys are NOT in the
Phase 2 stub manifest (D-21)"

**Status:** failing on `main` BEFORE Phase 12 started. Phase 13
(audio manifest regeneration) is committing concurrently and has
populated `lib/gen/audio_manifest.g.dart` with phoneme entries that
this test asserts are absent. Verified by `git stash` round-trip
prior to landing Phase 12 changes — failure pre-dates Phase 12.

**Owner:** Phase 13. The D-21 gate test was written assuming
Phase 6 phoneme keys would be **absent** until the native-speaker
review pass; Phase 13 takes the technical-review-only soft gate
(`technically_reviewed: true`) and regenerates the manifest with
all entries. The test needs to be updated as part of Phase 13's
final commit.

**Phase 12 stance:** untouched. Out of scope per Phase 12's
"DO NOT touch `tools/tts/` or `lib/gen/audio_manifest.g.dart`"
constraint.
