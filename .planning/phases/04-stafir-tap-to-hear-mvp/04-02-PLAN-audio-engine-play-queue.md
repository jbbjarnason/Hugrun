---
phase: 04-stafir-tap-to-hear-mvp
plan: 02
type: execute
wave: 2
depends_on:
  - 04-01
files_modified:
  - lib/core/audio/audio_engine.dart
  - lib/core/audio/utterance_resolver.dart
  - test/core/audio/audio_engine_play_test.dart
  - test/core/audio/utterance_resolver_test.dart
autonomous: true
requirements:
  - STAFIR-02  # tap plays letter name (audio plumbing — latency QA in 04-07)
  - STAFIR-03  # letter name then example word
  - STAFIR-04  # re-tap cancels and restarts
  - STAFIR-05  # different letter cancels current and starts new
  - STAFIR-09  # uses the warm pool from 04-01
tags:
  - flutter
  - just_audio
  - audio
  - phase-4

must_haves:
  truths:
    - "AudioEngine.play(UtteranceKey) plays the letter name immediately"
    - "When the key is a letter (e.g. UtteranceKey.letterA), play queues the matching example word clip after the letter name with no audible gap"
    - "Calling play(X) while X is already playing cancels and restarts X from the letter name"
    - "Calling play(Y) while X is playing cancels X and starts Y immediately"
    - "If a UtteranceKey has no matching example word in the manifest, play plays only the letter name and logs a debug warning (graceful fallback for the Phase 2 stub manifest)"
    - "AudioEngine.stop halts any current playback without throwing"
    - "play() never instantiates a new AudioPlayer — it only round-robins through the warm pool from Plan 01"
    - "play() returns immediately (does not await playback completion)"
  artifacts:
    - path: "lib/core/audio/audio_engine.dart"
      provides: "play(UtteranceKey) + stop() + cancel-on-new-tap semantics"
      min_lines: 150
    - path: "lib/core/audio/utterance_resolver.dart"
      provides: "letterKey -> (nameKey, optional wordKey) resolver. Pure function. Maps UtteranceKey.letterA -> (letterA, wordHundur if A's example word existed) etc."
      min_lines: 30
    - path: "test/core/audio/audio_engine_play_test.dart"
      provides: "Behavior tests for play queue, cancel-on-retap, cancel-on-other-tap, missing-clip fallback"
      min_lines: 80
  key_links:
    - from: "lib/core/audio/audio_engine.dart"
      to: "lib/core/audio/utterance_resolver.dart"
      via: "resolveLetterToClips(key) -> ResolvedUtterance"
      pattern: "resolveLetterToClips"
    - from: "lib/core/audio/audio_engine.dart"
      to: "lib/gen/audio_manifest.g.dart"
      via: "kAudioManifest[key] lookup; missing key triggers warning + skip"
      pattern: "kAudioManifest\\[.+\\]"
    - from: "lib/core/audio/audio_engine.dart"
      to: "package:just_audio ConcatenatingAudioSource"
      via: "Queue letter name + word as a single ConcatenatingAudioSource on one player for gapless playback"
      pattern: "ConcatenatingAudioSource"
---

<objective>
Make AudioEngine actually play audio. Plan 01 left `play()` as `UnimplementedError`. This plan implements the full play queue:

1. Resolve UtteranceKey → (letterName clip, optional exampleWord clip).
2. Queue them as a `ConcatenatingAudioSource` on one warm player from the Plan-01 pool — gapless playback.
3. If `play()` is called again (same key OR different key) while playback is active, cancel the current player and start the new request on the next pool slot. No audio overlap, ever (STAFIR-04, STAFIR-05).
4. Gracefully tolerate missing clips (Phase 2 stub manifest only has letterA, letterEth, letterThorn, wordHundur, narrationWelcome; the rest of the 32 letters return null from `kAudioManifest[key]` until Phase 3 lands the real manifest). On miss → debug warning, no error to user, no exception to caller.

Purpose: This is the audio side of the MVP loop. After this plan, `ref.read(audioEngineProvider).play(UtteranceKey.letterA)` plays "a → hundur" with no gap, no overlap, and no per-tap player creation. PITFALLS #4 + #7 + #8 are honored by construction.

Output: A fully working AudioEngine.play(). Plan 03 + 04 will wire it to LetterTile + StafirRoom.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/ROADMAP.md

@.planning/phases/04-stafir-tap-to-hear-mvp/04-CONTEXT.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-01-SUMMARY.md

@.planning/research/SUMMARY.md
@.planning/research/PITFALLS.md

@lib/core/audio/audio_engine.dart
@lib/core/audio/audio_player_like.dart
@lib/core/manifest/utterance_key.dart
@lib/gen/audio_manifest.g.dart
@lib/core/alphabet/alphabet.dart

<interfaces>
<!-- Carry-forward from Plan 01 + Phase 2. -->

From Plan 01 lib/core/audio/audio_engine.dart:
```dart
class AudioEngine {
  AudioEngine({AudioPlayerLike Function()? playerFactory});
  Future<void> warmUp();
  Future<void> dispose();
  Future<void> play(UtteranceKey key); // throws UnimplementedError; THIS PLAN implements
  Future<void> stop();                  // throws UnimplementedError; THIS PLAN implements
  // private: List<AudioPlayerLike> _pool of size 4
  // private: _acquirePlayer() round-robin helper
}
```

From Phase 2:
```dart
enum UtteranceKey { letterA, letterEth, letterThorn, wordHundur, narrationWelcome }
const Map<UtteranceKey, AudioAsset> kAudioManifest;
```

Phase 2 stub manifest entries that EXIST:
- letterA → assets/audio/letters/names/a.aac
- letterEth → assets/audio/letters/names/eth.aac
- letterThorn → assets/audio/letters/names/thorn.aac
- wordHundur → assets/audio/letters/words/hundur.aac
- narrationWelcome → assets/audio/narration/welcome_hugrun.aac

Phase 2 stub manifest letter↔word pairing convention (D-23):
- letterA has no example word in stub — plays letter name only
- letterEth has no example word in stub — plays letter name only
- letterThorn has no example word in stub — plays letter name only
  (We have wordHundur in the stub but no letterH yet — that's because Phase 2's
  stub set was chosen to exercise the diacritic slug map, not the letter→word
  pairing. Plan 02 must NOT assume any letterX exists or any wordX exists.)

When Phase 3 manifest swap-in happens, the same UtteranceKey enum will gain
~64 more entries (32 letterX + 32 wordX) and the resolver still works because
it asks the manifest, doesn't pre-bake the pairing.

Letter → example word pairing (Plan 02 owns the source of truth):
A list of (letterKey, exampleWordKey) tuples lives at the top of utterance_resolver.dart.
Today it has only 1 useful entry (h → hundur, but letterH doesn't exist in stub
so the entry is dormant). When Phase 3 lands, this list grows to 32 entries.

just_audio API:
```dart
class ConcatenatingAudioSource implements AudioSource {
  ConcatenatingAudioSource({required List<AudioSource> children});
}
class AudioSource {
  static AudioSource asset(String path);
}
```
</interfaces>

<reference_decisions>
- D-04: `play(key)` is idempotent + cancellable. Different key while playing → stop current, start new on next pool slot. Same key re-tapped → stop current, replay from beginning of letter name (STAFIR-04).
- D-05: Clip queue per tap is letter name → example word, queued sequentially on the same player via `ConcatenatingAudioSource` for gapless playback.
- D-06: Visual feedback fires synchronously in onTapDown — Plan 03 owns this. AudioEngine fire-and-forget; this plan's `play()` returns the moment scheduling is done, NOT after audio finishes.
- D-22, D-23: Phase 4 may run against Phase 2 stub manifest. AudioEngine MUST handle missing clips gracefully (log + skip).
- D-24: Unit tests: warm-up (Plan 01), play queue, cancel-on-new-tap, name provider (Plan 05).
</reference_decisions>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — write failing tests for play queue, cancel semantics, and missing-clip fallback</name>
  <files>
    test/core/audio/audio_engine_play_test.dart,
    test/core/audio/utterance_resolver_test.dart
  </files>
  <behavior>
    test/core/audio/utterance_resolver_test.dart:
    - "resolveLetterToClips(letterA) returns ResolvedUtterance with nameKey=letterA and wordKey=null when stub manifest is in effect"
    - "resolveLetterToClips(narrationWelcome) returns ResolvedUtterance with nameKey=narrationWelcome and wordKey=null (narrations are atomic)"
    - "resolveLetterToClips(wordHundur) returns ResolvedUtterance with nameKey=wordHundur and wordKey=null (words played alone are atomic)"
    - "resolveLetterToClips returns wordKey only when the letter→word pairing table includes the letter AND that wordKey is present in kAudioManifest" — test with a fixture pairing table override

    test/core/audio/audio_engine_play_test.dart (uses FakeAudioPlayer from Plan 01):
    - "play(letterA) acquires a player from the pool and calls setAudioSource with a ConcatenatingAudioSource (or an AudioSource — accept either; assert the player.setAudioSource OR setAsset call recorded)"
    - "play(letterA) does not instantiate a new AudioPlayer — pool size remains 4 throughout"
    - "play(letterA) followed by play(letterA) cancels the first and starts a second; the first player got .stop() called, the second got setAudioSource() called"
    - "play(letterA) followed by play(letterEth) cancels the first and starts the second on a different pool slot"
    - "play(UtteranceKey not in kAudioManifest) — simulate by passing a key whose manifest entry is removed via test override — emits a debug warning and does NOT throw"
    - "play() returns synchronously-ish — the returned Future completes within ~10ms in unit tests (the actual playback is fire-and-forget on the player)"
    - "stop() calls .stop on every player in the pool that is currently active; tests verify the active player got stopped, idle players were not touched"
    - "stop() called when nothing is playing is a no-op (does not throw)"

    Use a `TestAudioManifest` fixture or override pattern so the resolver's view of `kAudioManifest` can be mocked per-test (since the real manifest is `const`, route through a function `currentManifest()` that defaults to `kAudioManifest` but is overridable in tests).
  </behavior>
  <action>
    Write all the failing tests above. Tests should fail because:
    - `utterance_resolver.dart` doesn't exist yet
    - `AudioEngine.play()` still throws UnimplementedError
    - `AudioEngine.stop()` still throws UnimplementedError

    Run `flutter test test/core/audio/` and confirm RED.

    Atomic commit: `test(04-02): add failing tests for play queue + cancel semantics + missing-clip fallback`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test test/core/audio/ 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    - 12+ new failing tests in audio_engine_play_test.dart + utterance_resolver_test.dart
    - Plan 01 tests still pass
    - Pre-Phase-4 84 tests still pass
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — implement utterance_resolver + AudioEngine.play queue + cancel + missing-clip fallback</name>
  <files>
    lib/core/audio/audio_engine.dart,
    lib/core/audio/utterance_resolver.dart
  </files>
  <action>
    1. `lib/core/audio/utterance_resolver.dart`:
       ```dart
       import '../manifest/audio_asset.dart';
       import '../manifest/utterance_key.dart';
       import '../../gen/audio_manifest.g.dart';

       class ResolvedUtterance {
         const ResolvedUtterance({required this.nameKey, this.wordKey});
         final UtteranceKey nameKey;
         final UtteranceKey? wordKey; // null = name only (narration, missing pairing)
       }

       /// Letter → example word pairing. Phase 2 stub has no useful pairings;
       /// Phase 3 will deliver the full 32-entry table. Resolver does NOT
       /// hardcode the pairing — it reads this map. Empty entries are fine.
       const Map&lt;UtteranceKey, UtteranceKey&gt; kLetterToWord = &lt;UtteranceKey, UtteranceKey&gt;{
         // Phase 2 stub: no pairings yet. letterA has no wordX, etc.
         // Phase 3 will populate (letterA → wordApi, letterB → wordBoltinn, ...).
       };

       /// Pure resolver. Returns null wordKey if no pairing OR pairing target
       /// is absent from the active manifest (Phase 2 stub graceful-fallback).
       ResolvedUtterance resolveLetterToClips(
         UtteranceKey key, {
         Map&lt;UtteranceKey, AudioAsset&gt;? manifestOverride,
         Map&lt;UtteranceKey, UtteranceKey&gt;? pairingOverride,
       }) {
         final manifest = manifestOverride ?? kAudioManifest;
         final pairings = pairingOverride ?? kLetterToWord;
         final word = pairings[key];
         if (word != null && manifest.containsKey(word)) {
           return ResolvedUtterance(nameKey: key, wordKey: word);
         }
         return ResolvedUtterance(nameKey: key, wordKey: null);
       }
       ```

    2. `lib/core/audio/audio_engine.dart` — fill in play() and stop():
       ```dart
       int _nextPoolIndex = 0;
       AudioPlayerLike? _activePlayer;
       UtteranceKey? _activeKey;

       AudioPlayerLike _acquirePlayer() {
         final p = _pool[_nextPoolIndex];
         _nextPoolIndex = (_nextPoolIndex + 1) % poolSize;
         return p;
       }

       Future&lt;void&gt; play(UtteranceKey key) async {
         if (!_warmedUp) {
           debugPrint('[AudioEngine] play() called before warmUp completed; queueing.');
           // Don't throw — Plan 03's onTapDown handler may fire before warmUp finishes.
           // Best-effort: warm-up first, then play.
           await warmUp();
         }
         // 1. Cancel current playback (D-04, STAFIR-04, STAFIR-05).
         await _activePlayer?.stop();
         _activePlayer = null;
         _activeKey = null;

         // 2. Resolve clips.
         final resolved = resolveLetterToClips(key);
         final nameAsset = kAudioManifest[resolved.nameKey];
         if (nameAsset == null) {
           debugPrint('[AudioEngine] WARNING: no asset for $key (Phase 2 stub manifest fallback). Visual feedback only.');
           return;
         }

         // 3. Acquire next player and dispatch.
         final player = _acquirePlayer();
         _activePlayer = player;
         _activeKey = key;

         // Build queue: name [+ word if pairing present].
         final wordAsset = resolved.wordKey != null ? kAudioManifest[resolved.wordKey] : null;
         try {
           if (wordAsset == null) {
             await player.setAsset(nameAsset.path);
           } else {
             await player.setAudioSource(
               ja.ConcatenatingAudioSource(children: [
                 ja.AudioSource.asset(nameAsset.path),
                 ja.AudioSource.asset(wordAsset.path),
               ]),
             );
           }
           // Fire-and-forget. play() returns; audio plays asynchronously.
           // ignore: unawaited_futures
           player.play();
         } catch (e) {
           debugPrint('[AudioEngine] play($key) error: $e');
           _activePlayer = null;
           _activeKey = null;
         }
       }

       Future&lt;void&gt; stop() async {
         await _activePlayer?.stop();
         _activePlayer = null;
         _activeKey = null;
       }
       ```

    Note: production code uses `package:just_audio` types directly (`ja.ConcatenatingAudioSource`). Tests inject `FakeAudioPlayer` via the constructor's `playerFactory`. Fakes don't need to actually parse the AudioSource — they just record the call. To keep `setAudioSource` testable without coupling fakes to just_audio types, accept `Object` in the AudioPlayerLike signature (already done in Plan 01).

    For the "missing clip" test path, expose a hook on AudioEngine for tests to override the manifest used. Either:
    - Constructor parameter: `AudioEngine({Map<UtteranceKey, AudioAsset>? manifestOverride})` — preferred.
    - Or read via a `currentManifest()` function that's pluggable.

    Choose the constructor-injection path (matches the existing playerFactory pattern).

    Run `flutter test`; all tests must pass.

    Atomic commit: `feat(04-02): implement play queue with ConcatenatingAudioSource + cancel-on-new-tap (D-04, D-05, STAFIR-02..05)`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test 2>&amp;1 | tail -10</automated>
  </verify>
  <done>
    - All Task 1 tests green
    - Pre-existing tests still green
    - `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: REFACTOR — extract play state machine + comment STAFIR-04/05 invariants</name>
  <files>
    lib/core/audio/audio_engine.dart
  </files>
  <action>
    With tests green, polish:

    - Extract a private `_PlaybackSlot` value type or method that bundles `(player, key)` so the active-playback state is one field instead of two.
    - Add a dartdoc to `play()` listing the STAFIR-04 + STAFIR-05 + D-04 + D-05 invariants it preserves.
    - Verify `flutter analyze` is silent on `unawaited_futures`. If `// ignore: unawaited_futures` is needed for the fire-and-forget call, document why inline.
    - Add a debug invariant: `assert(_pool.length == poolSize)` at the start of `_acquirePlayer()` to catch any future bug that mutates the pool.

    No behavior change. Tests must remain green.

    Atomic commit: `refactor(04-02): tighten AudioEngine playback state + document invariants`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - All tests green
    - `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| process → audio HW | just_audio routes audio to system mixer |
| process → filesystem | bundled .aac assets read |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-05 | T (tampering) | UtteranceKey enum drift | mitigate | enum is closed in `lib/core/manifest/utterance_key.dart`; missing manifest entry returns null + debug warning, never crashes |
| T-04-06 | D (denial of service) | runaway pool growth | mitigate | pool size fixed at 4 (D-02); `_acquirePlayer()` round-robins; no path adds players |
| T-04-07 | I (info disclosure) | debugPrint of UtteranceKey names | accept | UtteranceKey names are non-sensitive (e.g. `letterA`); no PII; `debugPrint` no-op in release builds |
| T-04-08 | T (tampering) | unawaited Future drops | mitigate | fire-and-forget `player.play()` documented + `// ignore: unawaited_futures` annotated; failure path logs error and clears active state |
</threat_model>

<verification>
- `flutter test` — all green, ≥ 95 tests
- `flutter analyze` — 0 issues
- `dart format --set-exit-if-changed .` — clean
- `flutter build apk --debug` — succeeds

Manual smoke: in a test app screen, `ref.read(audioEngineProvider).play(UtteranceKey.letterA)` plays the placeholder a.aac. (Real-device audio verification deferred to Plan 04 / 04-07.)
</verification>

<success_criteria>
- AudioEngine.play(key) implemented per D-04 + D-05 + STAFIR-02..05
- Cancel-on-new-tap and cancel-on-retap both observable via FakeAudioPlayer call recordings
- Missing-clip fallback works without exception (Phase 2 stub safety net per D-23)
- 12+ new tests, all green
- 3 atomic commits (RED → GREEN → REFACTOR)
</success_criteria>

<output>
Create `.planning/phases/04-stafir-tap-to-hear-mvp/04-02-SUMMARY.md` with:
- play queue contract (D-04, D-05) summary
- Test count delta
- Decisions exercised: D-04, D-05, D-22, D-23 fallback path
- Requirements satisfied (audio plumbing for STAFIR-02..05; latency QA in 04-07)
- Atomic commits + SHAs
- Any deviations
</output>
