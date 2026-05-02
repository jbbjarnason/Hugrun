---
phase: 04
plan: 01
subsystem: audio + skeleton
tags: [flutter, riverpod, just_audio, audio, phase-4]
key-files:
  created:
    - lib/core/audio/audio_engine.dart
    - lib/core/audio/audio_engine_provider.dart
    - lib/core/audio/audio_player_like.dart
    - test/core/audio/_fakes/fake_audio_player.dart
    - test/core/audio/audio_engine_test.dart
    - test/core/audio/audio_engine_provider_test.dart
    - test/skeleton/main_orientation_test.dart
  modified:
    - lib/main.dart
decisions: [D-01, D-02, D-03, D-08, D-15, D-16]
---

# Phase 4 Plan 01: Orientation lock + AudioEngine warm pool — Summary

Foundation for the MVP audio loop: orientation lock + immersive UI + the
top-level non-autoDispose AudioEngine warm pool.

## Tests added (12)

| File | Count | Coverage |
|------|-------|----------|
| audio_engine_test.dart | 7 | warm pool size, idempotency, dispose cleanup, AVAudioSession priming, silence-pad warning |
| audio_engine_provider_test.dart | 3 | keepAlive identity, dispose-on-container-dispose, survives provider rebuilds |
| main_orientation_test.dart | 2 | SystemChrome.setPreferredOrientations + setEnabledSystemUIMode |

## AudioEngine API

```dart
class AudioEngine {
  AudioEngine({
    AudioPlayerLike Function()? playerFactory,
    Map<UtteranceKey, AudioAsset>? manifestOverride,    // Plan 04-02
    Map<UtteranceKey, UtteranceKey>? pairingOverride,   // Plan 04-02
  });
  static const int poolSize = 4;
  bool get isWarmedUp;
  Future<void> warmUp();   // idempotent; allocates 4 players, primes player 0
  Future<void> dispose();  // releases pool
  Future<void> play(UtteranceKey key);  // Plan 04-02 (stub here throws)
  Future<void> stop();                  // Plan 04-02 (stub here throws)
  void warnIfMissingPad(UtteranceKey, Duration);
}
```

## Decisions exercised

- **D-01:** AudioEngine owned by `@Riverpod(keepAlive: true)` provider in `audio_engine_provider.dart`. Mirrors `appDatabaseProvider` pattern.
- **D-02:** Pool of 4 AudioPlayer instances allocated at app start.
- **D-03:** Warm-up sequence: allocate → prime player 0 with silent clip → activate iOS AVAudioSession.
- **D-08:** `warnIfMissingPad` debug-logs when reportedDuration < 20 ms (Phase 3 silence-pad health check).
- **D-15:** `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])` before runApp.
- **D-16:** `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive)`.

## Requirements

- **STAFIR-09:** warm pool exists ✓ (play queue lands in 04-02)

## Atomic commits

| Commit | Subject |
|--------|---------|
| 758d08c | test(04-01): add failing tests for AudioEngine warm pool + orientation lock |
| 33b6f30 | feat(04-01): orient app to landscape + immersive (D-15, D-16) |
| a596906 | (Phase 3 commit that bundled my AudioEngine work — see Deviations) |
| 9a9f465 | refactor(04-01): document audio_engine internals + flag pool helpers for plan 04-02 |

## Deviations

**[Rule 3 - Blocking issue] Phase 3 parallel commit absorbed Plan 04-01 GREEN files.**

Phase 3 was running in parallel and committed its work (`a596906 feat(03-07)`) at the same time I was committing my AudioEngine GREEN. The commit captured:
- My Phase 4 files: audio_engine.dart, audio_engine_provider.dart (intended)
- Phase 3's: 65 baked AAC clips, 03-02 SUMMARY (NOT mine to commit)

The end-state is correct (all files tracked at HEAD; tests pass), but the Plan 04-01 GREEN feat is attributed to commit message `feat(03-07): bake 65 Steinn AAC clips`. The Plan 04-01 work itself is materially complete — the AudioEngine class with the 4-player warm pool, the keepAlive provider, and the orientation/immersive lock all landed. Just sub-optimal commit history.

Self-check: AudioEngine + provider + main.dart edits are all live at HEAD as expected; 165 tests pass.
