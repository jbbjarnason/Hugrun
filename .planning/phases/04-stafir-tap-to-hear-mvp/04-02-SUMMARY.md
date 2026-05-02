---
phase: 04
plan: 02
subsystem: audio
tags: [flutter, just_audio, audio, phase-4]
key-files:
  created:
    - lib/core/audio/utterance_resolver.dart
    - test/core/audio/audio_engine_play_test.dart
    - test/core/audio/utterance_resolver_test.dart
  modified:
    - lib/core/audio/audio_engine.dart
    - lib/core/audio/audio_player_like.dart
    - test/core/audio/_fakes/fake_audio_player.dart
decisions: [D-04, D-05, D-22, D-23]
---

# Phase 4 Plan 02: AudioEngine play queue — Summary

Fills in `play()` and `stop()` from Plan 04-01's stub, with cancel-on-retap,
gapless letter→word playlist via just_audio's `setAudioSources`, and Phase 2
stub-manifest fallback.

## play queue contract (D-04, D-05)

```
play(letterKey):
  1. If !warmedUp: await warmUp() (defensive against onTapDown race)
  2. If activePlayer != null: stop the previous player (cancel-on-retap)
  3. Resolve letterKey -> ResolvedUtterance(name, optional word)
  4. If name asset missing in manifest: log warning + return (silent no-op)
  5. Acquire next pool slot via _acquirePlayer (round-robin)
  6. If word asset present: setAudioSources([nameAsset, wordAsset]) for gapless
     Else: setAsset(nameAsset.path) (single-clip path)
  7. unawaited(player.play()) — fire-and-forget
```

`stop()` halts active player; no-op if idle.

## Tests added (13)

| File | Count | Coverage |
|------|-------|----------|
| utterance_resolver_test.dart | 5 | letter→clip resolution, manifest override, missing-pairing fallback |
| audio_engine_play_test.dart | 8 | dispatch, pool stays at 4, cancel-on-retap, cancel-on-other-tap, missing-clip fallback, returns synchronously, paired-word setAudioSources, stop semantics |

## Decisions exercised

- **D-04:** `play(key)` is idempotent + cancellable. Different key → stop current + dispatch on next pool slot. Same key re-tapped → stop current + replay.
- **D-05:** Letter name + example word queued via `setAudioSources(List<AudioSource>)` (replaced deprecated `ConcatenatingAudioSource`).
- **D-22, D-23:** Phase 2 stub fallback path verified — missing manifest entries log a debug warning and return silently. No exception, no user-visible error.

## Requirements

- **STAFIR-02..05:** audio plumbing for tap-to-hear. (Latency QA in 04-07.)
- **STAFIR-09:** uses the warm pool from 04-01 (verified by test that pool size stays 4).

## Atomic commits

| Commit | Subject |
|--------|---------|
| 66433a2 | test(04-02): add failing tests for play queue + cancel semantics + missing-clip fallback |
| 03483ba | feat(04-02): implement play queue with gapless playlist + cancel-on-new-tap |
| 96e49fa | refactor(04-02): tighten AudioEngine playback state + document invariants |

## Deviations

**[Rule 1 - Bug] Replaced deprecated `ConcatenatingAudioSource` with `setAudioSources`.**
The plan called for `ja.ConcatenatingAudioSource(children: [...])`. Compiling against just_audio 0.10.5 produced `deprecated_member_use` warnings for `ConcatenatingAudioSource`. Switched to the new `player.setAudioSources(List<AudioSource>)` API. Functionally equivalent (gapless playlist).

**[Rule 1 - Bug] Phase 3 untracked files captured in commit `03483ba`.**
Same issue as Plan 04-01 — Phase 3's mid-flight changes to assets/ + .planning/phases/03/ were untracked at commit time and got bundled with my AudioEngine GREEN commit. Files are correct; commit history is messy.

Self-check: utterance_resolver + AudioEngine.play + AudioEngine.stop all landed; 24 audio tests pass; flutter analyze clean.
