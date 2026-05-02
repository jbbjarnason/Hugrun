---
phase: 04-stafir-tap-to-hear-mvp
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/main.dart
  - lib/core/audio/audio_engine.dart
  - lib/core/audio/audio_engine_provider.dart
  - lib/core/audio/audio_engine_provider.g.dart
  - test/core/audio/audio_engine_test.dart
  - test/core/audio/audio_engine_provider_test.dart
autonomous: true
requirements:
  - STAFIR-09  # warm pool of ≥2 AudioPlayer instances at app start
tags:
  - flutter
  - riverpod
  - just_audio
  - audio
  - phase-4

must_haves:
  truths:
    - "App launches in landscape orientation only (no portrait)"
    - "Status bar and navigation bar are hidden (immersive mode)"
    - "AudioEngine exists as a top-level non-autoDispose Riverpod provider, kept alive for the entire app lifetime"
    - "AudioEngine warms a pool of 4 AudioPlayer instances at app start"
    - "AudioEngine activates iOS AVAudioSession by playing a silent priming clip on player 0"
    - "AudioEngine warm-up completes within 500ms after runApp without blocking the home screen"
    - "AudioEngine logs a debug warning (not an error) if Phase 3 silence-padding is absent on a clip"
  artifacts:
    - path: "lib/main.dart"
      provides: "Orientation lock + immersive mode + ProviderScope"
      contains: "SystemChrome.setPreferredOrientations"
    - path: "lib/core/audio/audio_engine.dart"
      provides: "AudioEngine class with warm pool init, play stub, stop, dispose"
      min_lines: 80
    - path: "lib/core/audio/audio_engine_provider.dart"
      provides: "Riverpod codegen provider with @Riverpod(keepAlive: true)"
      contains: "@Riverpod(keepAlive: true)"
    - path: "test/core/audio/audio_engine_test.dart"
      provides: "Unit tests for warm-pool init, pool size, dispose"
      min_lines: 40
  key_links:
    - from: "lib/main.dart"
      to: "SystemChrome (Flutter framework)"
      via: "setPreferredOrientations + setEnabledSystemUIMode"
      pattern: "SystemChrome\\.set(PreferredOrientations|EnabledSystemUIMode)"
    - from: "lib/core/audio/audio_engine_provider.dart"
      to: "lib/core/audio/audio_engine.dart"
      via: "ref.read(audioEngineProvider) returns AudioEngine"
      pattern: "@Riverpod\\(keepAlive: true\\)"
    - from: "lib/core/audio/audio_engine.dart"
      to: "package:just_audio AudioPlayer"
      via: "List<AudioPlayer> _pool of size 4"
      pattern: "AudioPlayer\\("
---

<objective>
Lay the AudioEngine foundation that every later Phase 4 plan builds on. This plan does NOT play any letter audio yet — it ships the orientation lock (D-15, D-16), the AudioEngine class skeleton with a 4-player warm pool (D-02, D-03, STAFIR-09), and the top-level non-autoDispose Riverpod provider that owns it (D-01, PITFALLS #7, #8). Plan 02 fills in the play queue.

Purpose: Get the architectural primitives right at MVP. PITFALLS #7 + #8 say AudioPlayer must NEVER live in widget build, NEVER autoDispose, NEVER be created per-tap. This plan establishes that contract so Plans 02–06 can call `ref.read(audioEngineProvider).play(key)` without re-deriving lifecycle rules.

Output: Locked landscape orientation, immersive UI chrome, app-scoped AudioEngine warmed at start, ready for Plan 02 to add the play queue on top.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/ROADMAP.md
@.planning/STATE.md

@.planning/phases/04-stafir-tap-to-hear-mvp/04-CONTEXT.md
@.planning/phases/01-skeleton-drift-schema/01-SUMMARY.md
@.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-SUMMARY.md

@.planning/research/SUMMARY.md
@.planning/research/PITFALLS.md

@lib/main.dart
@lib/app/app.dart
@lib/core/db/database_provider.dart
@lib/core/manifest/utterance_key.dart
@lib/core/manifest/audio_asset.dart
@lib/gen/audio_manifest.g.dart
@pubspec.yaml

<interfaces>
<!-- Existing types this plan uses. Extracted so the executor doesn't need to re-grep. -->

From lib/core/manifest/utterance_key.dart:
```dart
enum UtteranceKey {
  letterA,
  letterEth,
  letterThorn,
  wordHundur,
  narrationWelcome,
}
```

From lib/core/manifest/audio_asset.dart:
```dart
class AudioAsset {
  const AudioAsset({required this.path, required this.approximateDuration});
  final String path;
  final Duration approximateDuration;
  // operator==, hashCode, toString
}
```

From lib/gen/audio_manifest.g.dart:
```dart
const Map<UtteranceKey, AudioAsset> kAudioManifest = <UtteranceKey, AudioAsset>{ ... };
AudioAsset getAudioAsset(UtteranceKey key) => kAudioManifest[key]!;
```

From lib/core/db/database_provider.dart (the canonical pattern this plan mirrors for AudioEngine):
```dart
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
```

just_audio API surface this plan uses:
```dart
class AudioPlayer {
  AudioPlayer();
  Future<Duration?> setAsset(String path);
  Future<void> setAudioSource(AudioSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
  Stream<PlayerState> get playerStateStream;
}
```

audio_session API surface this plan uses:
```dart
class AudioSession {
  static Future<AudioSession> get instance;
  Future<void> configure(AudioSessionConfiguration config);
}
class AudioSessionConfiguration {
  static const speech = AudioSessionConfiguration(...);
}
```
</interfaces>

<reference_decisions>
- D-01: AudioEngine at `lib/core/audio/audio_engine.dart`, owned by top-level non-autoDispose `@Riverpod(keepAlive: true)` provider in `lib/core/audio/audio_engine_provider.dart`. NEVER lives in widget build, NEVER autoDispose, NEVER per-tap.
- D-02: Pool of **4 AudioPlayer instances** allocated at app start.
- D-03: Warm-up sequence: (1) allocate 4 players, (2) activate iOS AVAudioSession by playing silent clip on player 0, (3) pre-load next-likely clips. Budget: <500ms after runApp. Done in async-init provider so home screen doesn't wait.
- D-08: Cold-start head-clipping fix lives in Phase 3 (silence-pad clips). AudioEngine logs a debug warning if a clip's leading silence is absent but still plays.
- D-15: Lock to landscape via `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])`.
- D-16: Hide status + navigation bar via `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive)`.
</reference_decisions>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — write failing tests for orientation lock + AudioEngine warm-pool init</name>
  <files>
    test/core/audio/audio_engine_test.dart,
    test/core/audio/audio_engine_provider_test.dart,
    test/skeleton/main_orientation_test.dart
  </files>
  <behavior>
    test/core/audio/audio_engine_test.dart (unit tests, no Flutter widget tree):
    - "AudioEngine.warmUp allocates 4 AudioPlayer instances" — assert internal pool length == 4 after warmUp completes
    - "AudioEngine.warmUp completes within 500ms (with mock players)" — uses `FakeAudioPlayer` injected via constructor; assert elapsed < Duration(milliseconds: 500)
    - "AudioEngine.warmUp plays a silent priming clip on player index 0" — fake player records its setAsset + play calls; assert player[0] received exactly one setAsset(silentAssetPath) and one play() before warmUp returns
    - "AudioEngine.dispose cleans up all 4 players" — assert each fake player.dispose() called exactly once
    - "AudioEngine logs a debug warning when a clip lacks silence padding" — inject a fake player that reports duration < 20ms head silence; assert AudioEngine.warnIfMissingPad fires (use a test logger sink — see below)
    - "AudioEngine is idempotent across warmUp calls" — second warmUp is a no-op (assert pool unchanged, no extra setAsset calls)

    test/core/audio/audio_engine_provider_test.dart (Riverpod integration):
    - "audioEngineProvider returns the same AudioEngine across reads (keepAlive)" — `container.read(audioEngineProvider) == container.read(audioEngineProvider)`; rebuild a dependent provider and confirm engine instance unchanged
    - "audioEngineProvider is NOT autoDispose" — assert `provider is! AutoDisposeProvider` (use the codegen-emitted symbol)
    - "audioEngineProvider disposes the engine on container dispose" — track dispose call via a marker AudioEngine subclass passed via override

    test/skeleton/main_orientation_test.dart (no Flutter widget; just imports lib/main.dart helpers):
    - "configureSystemChrome calls setPreferredOrientations with [landscapeLeft, landscapeRight] only" — replace SystemChannels.platform sender with a recorder; assert the args
    - "configureSystemChrome calls setEnabledSystemUIMode with SystemUiMode.immersive" — assert the channel call

    Use `FakeAudioPlayer` (test-double) from a new file `test/core/audio/_fakes/fake_audio_player.dart`. It implements an `AudioPlayerLike` interface (defined in audio_engine.dart for testability per D-26). Records every method call as a list of `(method, args)` tuples.
  </behavior>
  <action>
    Create `lib/core/audio/audio_player_like.dart` with an abstract interface that mirrors the just_audio AudioPlayer surface this phase needs:
    ```dart
    abstract class AudioPlayerLike {
      Future<Duration?> setAsset(String path);
      Future<void> setAudioSource(Object source); // ConcatenatingAudioSource in Plan 02
      Future<void> play();
      Future<void> pause();
      Future<void> stop();
      Future<void> dispose();
      Stream<dynamic> get playerStateStream;
    }
    ```
    This interface lets unit tests inject FakeAudioPlayer without touching just_audio's actual native channels (which would require integration_test).

    Create `test/core/audio/_fakes/fake_audio_player.dart` implementing AudioPlayerLike. Track every call.

    Create the three test files above. Use minimal `ProviderContainer` setups for the provider tests. Tests MUST fail when run because the production code does not exist yet.

    DO NOT touch lib/ source code in this task — RED is failing tests only. Run `flutter test` and confirm the new tests fail with "Type AudioEngine not found" or "Method warmUp not found" — that is the RED signal.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test test/core/audio/ test/skeleton/main_orientation_test.dart 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    - test/core/audio/_fakes/fake_audio_player.dart exists with AudioPlayerLike implementation that records calls
    - test/core/audio/audio_engine_test.dart, test/core/audio/audio_engine_provider_test.dart, test/skeleton/main_orientation_test.dart all FAIL with compilation errors referencing AudioEngine / configureSystemChrome
    - Pre-existing 84 tests still pass
    - Atomic commit: `test(04-01): add failing tests for AudioEngine warm pool + orientation lock`
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — implement AudioEngine + provider + orientation lock</name>
  <files>
    lib/core/audio/audio_engine.dart,
    lib/core/audio/audio_engine_provider.dart,
    lib/core/audio/audio_engine_provider.g.dart,
    lib/core/audio/audio_player_like.dart,
    lib/main.dart
  </files>
  <action>
    Implement the minimum code to turn Task 1's tests GREEN.

    1. `lib/core/audio/audio_player_like.dart` — already created in Task 1 if you put the interface there; if not, move it now.

    2. `lib/core/audio/audio_engine.dart`:
       ```dart
       class AudioEngine {
         AudioEngine({AudioPlayerLike Function()? playerFactory})
           : _playerFactory = playerFactory ?? (() => RealAudioPlayer());

         final AudioPlayerLike Function() _playerFactory;
         final List<AudioPlayerLike> _pool = [];
         bool _warmedUp = false;
         static const int poolSize = 4;
         static const String _silentAssetPath = 'assets/audio/letters/names/a.aac'; // Phase 2 placeholder; ALL Phase-2 stubs are silent so any works as a primer

         Future<void> warmUp() async {
           if (_warmedUp) return;
           // 1. allocate 4 players
           for (var i = 0; i < poolSize; i++) {
             _pool.add(_playerFactory());
           }
           // 2. activate iOS AVAudioSession via silent priming on player 0 (D-03)
           await _pool[0].setAsset(_silentAssetPath);
           await _pool[0].play();
           await _pool[0].pause();
           // 3. pre-load next-likely (Phase 4: first 3 letter-name keys actually present in the manifest stub).
           //    Phase 2 stub manifest has letterA / letterEth / letterThorn — pre-load those onto players 1..3.
           //    Plan 02 will replace this with a smarter cache-on-tap strategy.
           _warmedUp = true;
         }

         Future<void> dispose() async {
           for (final p in _pool) { await p.dispose(); }
           _pool.clear();
           _warmedUp = false;
         }

         // Plan 02 fills these in. Leave stubs that throw UnimplementedError + are not used yet.
         Future<void> play(UtteranceKey key) async {
           throw UnimplementedError('Plan 04-02 implements play queue');
         }
         Future<void> stop() async {
           throw UnimplementedError('Plan 04-02 implements stop');
         }

         /// Phase 3 silence-pad health check (D-08). Logs a warning if the clip
         /// reports < 20 ms duration (which is a strong signal the silence pad
         /// is absent OR the asset is the Phase 2 placeholder).
         void warnIfMissingPad(UtteranceKey key, Duration reportedDuration) {
           if (reportedDuration.inMilliseconds < 20) {
             debugPrint('[AudioEngine] WARNING: clip $key reported ${reportedDuration.inMilliseconds}ms — silence pad may be missing.');
           }
         }
       }

       class RealAudioPlayer implements AudioPlayerLike {
         RealAudioPlayer() : _player = ja.AudioPlayer();
         final ja.AudioPlayer _player;
         @override Future&lt;Duration?&gt; setAsset(String path) =&gt; _player.setAsset(path);
         @override Future&lt;void&gt; setAudioSource(Object source) =&gt; _player.setAudioSource(source as ja.AudioSource);
         // ... wrap each method
       }
       ```
       (`ja.` is `package:just_audio/just_audio.dart` aliased.)

    3. `lib/core/audio/audio_engine_provider.dart`:
       ```dart
       import 'package:riverpod_annotation/riverpod_annotation.dart';
       import 'audio_engine.dart';
       part 'audio_engine_provider.g.dart';

       /// App-scoped singleton. Per PITFALLS #7 + #8: never autoDispose, never per-tap, never in build.
       /// Mirrors the appDatabaseProvider pattern from Phase 1 D-02.
       @Riverpod(keepAlive: true)
       AudioEngine audioEngine(Ref ref) {
         final engine = AudioEngine();
         // Schedule warm-up on the next event-loop tick so the home screen
         // can render immediately while the pool initializes.
         Future.microtask(() => engine.warmUp());
         ref.onDispose(() => engine.dispose());
         return engine;
       }
       ```
       Run `dart run build_runner build --delete-conflicting-outputs` to generate `audio_engine_provider.g.dart`. Commit the generated file (project gitignores most `.g.dart` but commits `audio_manifest.g.dart`; check `.gitignore` — Phase 1's appDatabaseProvider.g.dart is gitignored, so this one is too. Confirm by running `git check-ignore lib/core/audio/audio_engine_provider.g.dart`).

    4. `lib/main.dart` — add orientation lock + immersive mode BEFORE runApp:
       ```dart
       import 'package:flutter/services.dart';
       // ... existing imports

       /// Lock landscape + hide system chrome (D-15, D-16). Extracted so unit tests can verify.
       Future&lt;void&gt; configureSystemChrome() async {
         await SystemChrome.setPreferredOrientations(&lt;DeviceOrientation&gt;[
           DeviceOrientation.landscapeLeft,
           DeviceOrientation.landscapeRight,
         ]);
         await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
       }

       void main() async {
         if (kDebugMode) {
           MarionetteBinding.ensureInitialized();
         } else {
           WidgetsFlutterBinding.ensureInitialized();
         }
         await configureSystemChrome();
         runApp(const ProviderScope(child: HugrunApp()));
       }
       ```
       NOTE: `MarionetteBinding.ensureInitialized()` already initializes binding; we then call `configureSystemChrome()` which uses `SystemChrome` (which requires a binding). The await order is correct.

    Run `flutter test` until ALL Task 1 tests pass.

    Commit two atomic GREEN commits if the diff naturally splits, or one if it's tightly coupled:
    1. `feat(04-01): orient app to landscape + immersive (D-15, D-16)` — main.dart only
    2. `feat(04-01): scaffold AudioEngine + warm pool + Riverpod keepAlive provider (D-01..D-03, D-08, STAFIR-09)` — audio/ module + tests pass
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test 2>&amp;1 | tail -10</automated>
  </verify>
  <done>
    - All Task 1 tests pass
    - Pre-existing 84 tests still pass (total ≥ 90+)
    - `flutter analyze` clean
    - `dart format --set-exit-if-changed .` clean
    - `flutter build apk --debug` succeeds
    - Atomic commits per above
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: REFACTOR — extract pool helpers + finalize logging</name>
  <files>
    lib/core/audio/audio_engine.dart
  </files>
  <action>
    With tests green, polish the AudioEngine:

    - Extract a private `_acquirePlayer()` method that returns the next free player from the pool (round-robin). Plan 02 will use this; expose it now so Plan 02 doesn't need to refactor.
    - Extract `_logPoolState()` for debug-print of pool occupancy.
    - Document each public method with dartdoc comments referencing the relevant Decision IDs (D-01, D-02, etc.).
    - If any internal field can be `final` after warmUp, mark it `late final`.

    DO NOT change behavior. All tests must remain green. If a refactor opportunity is purely cosmetic (rename, doc) and adds no clarity, skip it.

    If the diff is empty (no real refactor needed), commit a no-op refactor pass with message
    `refactor(04-01): document audio_engine internals + flag pool helpers for plan 04-02` and add only doc-comment lines.

    Atomic commit: `refactor(04-01): extract pool acquisition helper + audio_engine docs`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - All tests still green
    - `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| process → filesystem | AudioEngine reads .aac assets from app bundle (read-only, no user input crosses) |
| process → audio HW | just_audio routes audio to system mixer (no user input crosses) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-01 | T (tampering) | bundled .aac assets | accept | Bundled inside the signed app binary; tampering equates to a re-sign attack and is out of scope for an offline kids' app |
| T-04-02 | I (info disclosure) | AudioEngine logs | mitigate | `debugPrint` only, gated on `kDebugMode`; no PII (no child name, no DB rows) flows into logs |
| T-04-03 | D (denial of service) | warmUp blocking startup | mitigate | warmUp scheduled via `Future.microtask` so the home screen renders before pool init completes; 500 ms budget validated by unit test |
| T-04-04 | E (elevation) | AudioPlayer instantiated in widget build | mitigate | `@Riverpod(keepAlive: true)` enforces app-scope; lint rule `riverpod_lint` flags any `AudioPlayer()` constructor outside this file (verified by `flutter analyze`) |

No PII, no network, no user input cross any boundary in this plan.
</threat_model>

<verification>
- `flutter test` — all green, ≥ 90 tests
- `flutter analyze` — 0 issues
- `dart format --set-exit-if-changed .` — clean
- `flutter build apk --debug` — succeeds
- `flutter build ios --no-codesign --debug` — succeeds
- `bash tools/check-domain-purity.sh` — passes (lib/core/audio is a Flutter+Dart layer, NOT pure-Dart domain — does NOT need to be in DOMAIN_PATHS)
- `git check-ignore lib/core/audio/audio_engine_provider.g.dart` — confirm gitignored (or commit per existing pattern)

After Plan 01: AudioEngine instance is reachable via `ref.read(audioEngineProvider)`. Calling `.play()` throws UnimplementedError — that's correct for now; Plan 02 fills it in.
</verification>

<success_criteria>
- AudioEngine class exists with 4-player warm pool, app-scoped via keepAlive Riverpod provider
- main.dart locks landscape + immersive mode before runApp
- Test suite grew by ≥10 tests; all green
- 3 atomic commits (RED → GREEN → REFACTOR)
- No regression in pre-existing 84 tests
</success_criteria>

<output>
Create `.planning/phases/04-stafir-tap-to-hear-mvp/04-01-SUMMARY.md` capturing:
- Tests added (count + descriptions)
- AudioEngine public API surface (warmUp, dispose, play [stub], stop [stub])
- Decisions exercised: D-01, D-02, D-03, D-08, D-15, D-16
- Requirements partially satisfied: STAFIR-09 (warm pool exists; play queue lands in 04-02)
- Atomic commits and SHAs
- Any deviations from this plan with rationale
</output>
