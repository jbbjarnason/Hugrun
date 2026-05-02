# Architecture Research

**Domain:** Single-device Flutter app for early childhood literacy + numeracy (Icelandic), offline-only, no accounts, no analytics
**Researched:** 2026-05-02
**Confidence:** HIGH (Riverpod 3.x scoping, Drift migrations, just_audio APIs verified via Context7; project layout from current Flutter community guidance)

---

## Standard Architecture

### System Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                          PRESENTATION LAYER                             │
│  ┌────────────┐  ┌────────────┐  ┌──────────────┐  ┌───────────────┐   │
│  │  HomePage  │  │ StafirRoom │  │  TolurRoom   │  │ ParentSettings│   │
│  │ (2 doors)  │  │ (letters)  │  │  (numbers)   │  │  (gated UI)   │   │
│  └─────┬──────┘  └─────┬──────┘  └──────┬───────┘  └───────┬───────┘   │
│        │               │                │                  │           │
│        ▼               ▼                ▼                  ▼           │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │             SHARED MECHANIC WIDGETS  (lib/mechanics/)          │    │
│  │  ┌──────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐  │    │
│  │  │TapToHear │  │ Tracing │  │Matching │  │   Sequencing    │  │    │
│  │  │ Tile     │  │ Surface │  │  Pair   │  │   Strip         │  │    │
│  │  └──────────┘  └─────────┘  └─────────┘  └─────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
├────────────────────────────────────────────────────────────────────────┤
│                          APPLICATION LAYER                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │   Riverpod Providers (state, controllers, scoped overrides)     │   │
│  │   • Root: childProfile, audioEngine, db, manifest, settings     │   │
│  │   • Room-scoped: currentLesson, currentRoom                     │   │
│  │   • Activity-scoped: tapHistory, tracingPath, matchProgress     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
├────────────────────────────────────────────────────────────────────────┤
│                            DOMAIN LAYER                                 │
│  ┌──────────────┐  ┌─────────────┐  ┌───────────────────────────────┐  │
│  │ Letter,Word, │  │ Utterance   │  │ Mechanic abstractions:        │  │
│  │ Number       │  │ (audio key) │  │ Promptable, Tappable,         │  │
│  │ value types  │  │             │  │ Traceable                     │  │
│  └──────────────┘  └─────────────┘  └───────────────────────────────┘  │
├────────────────────────────────────────────────────────────────────────┤
│                              DATA LAYER                                 │
│  ┌────────────────┐  ┌───────────────┐  ┌──────────────────────────┐   │
│  │  AudioEngine   │  │  ManifestRepo │  │  Drift (SQLite) Database │   │
│  │  (just_audio   │  │  (generated   │  │  • child_profile         │   │
│  │   pool, hot    │  │   Dart map +  │  │  • photo_tags (v2)       │   │
│  │   cache)       │  │   AssetBundle)│  │  • activity_log (v2)     │   │
│  └────────────────┘  └───────────────┘  └──────────────────────────┘   │
├────────────────────────────────────────────────────────────────────────┤
│                          BUILD-TIME PIPELINE                            │
│  Python TTS script → AAC files → ffmpeg-normalize → manifest.yaml      │
│         → build_runner generates lib/gen/audio_manifest.g.dart         │
└────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `App` (root) | Sets up `ProviderScope`, theme, routing, locale | `MaterialApp.router` + `ProviderScope` at `main()` |
| `Router` | Two top-level destinations + parent settings | `go_router` with `StatefulShellRoute` (one branch per room) |
| `RoomScope` | Bridge widget: when a room mounts, exposes room-scoped providers | `ProviderScope(overrides: [...])` wrapping the room subtree |
| Mechanic widgets | Generic, room-agnostic interaction primitives | Stateless/Hooks widgets that accept `Promptable` value objects |
| `AudioEngine` | Owns warm `AudioPlayer` pool, exposes `play(key)` ~10ms call→play | Singleton service behind a `Provider`, initialized in `main()` |
| `ManifestRepo` | Resolves an utterance key → AssetSource path + metadata | Reads generated `audio_manifest.g.dart`; pure in-memory map |
| `Database` (Drift) | Persists child name, settings, future personalization | `DriftDatabase` over `NativeDatabase.createInBackground()` |
| `SettingsController` | Reads/writes child profile, gates parent flow | `AsyncNotifier<ChildProfile>` |
| `AudioManifest` (generated) | Compile-time map: `{utteranceKey: AssetMetadata}` | Generated Dart file from YAML, committed (or generated in CI) |
| `Python TTS pipeline` | Build-time only — never ships | Standalone script; outputs go into `assets/audio/` |

---

## Recommended Project Structure

**Verdict: Feature-first with a shared `mechanics/` layer.** Two rooms is small enough that strict Clean Architecture would be over-engineered, but feature-first prepares cleanly for the Tölur room and personalization. The "four shared mechanics" are the leverage point — they are *not* features, they're a primitives library that rooms compose from.

```
hugrun/
├── pubspec.yaml
├── build.yaml                          # build_runner config (drift, riverpod, asset gen)
├── tools/                              # NEVER imported from lib/
│   ├── tts_pipeline/                   # Python build-time pipeline
│   │   ├── manifest.yaml               # Source of truth: utterance key → text → voice
│   │   ├── pronunciation_overrides.yaml
│   │   ├── generate_audio.py           # YAML → TTS API → raw AAC
│   │   ├── normalize.py                # ffmpeg-normalize wrapper
│   │   ├── emit_dart_manifest.py       # YAML → audio_manifest.g.dart (text template)
│   │   ├── requirements.txt
│   │   └── Makefile                    # `make audio` runs the full pipeline
│   └── verify_assets.dart              # Sanity check: every key in manifest exists on disk
├── assets/
│   ├── audio/
│   │   ├── letters/                    # h.aac, a.aac, æ.aac, ...
│   │   ├── words/                      # hundur.aac, ís.aac, ...
│   │   ├── numbers/                    # einn.aac, tveir.aac, ...
│   │   └── ui/                         # tap_chime.aac, success.aac, ...
│   └── images/
│       ├── letters/
│       ├── words/
│       └── numbers/
├── lib/
│   ├── main.dart                       # ProviderScope, AudioEngine warmup, router
│   ├── app.dart                        # MaterialApp.router, theme, locale
│   │
│   ├── core/                           # Cross-cutting infrastructure
│   │   ├── audio/
│   │   │   ├── audio_engine.dart       # Warm player pool, play(key) API
│   │   │   ├── audio_engine_provider.dart
│   │   │   └── utterance_key.dart      # Typed key (extension type / enum-like)
│   │   ├── manifest/
│   │   │   ├── audio_manifest.dart     # Public API over generated map
│   │   │   └── manifest_provider.dart
│   │   ├── db/
│   │   │   ├── database.dart           # @DriftDatabase definition
│   │   │   ├── tables/
│   │   │   │   ├── child_profile.dart
│   │   │   │   ├── photo_tags.dart     # v2
│   │   │   │   └── activity_log.dart   # v2
│   │   │   ├── database.steps.dart     # Generated by drift schema steps
│   │   │   └── database_provider.dart
│   │   ├── routing/
│   │   │   ├── app_router.dart         # go_router config
│   │   │   └── parent_gate.dart        # 3-second-hold widget
│   │   └── theme/
│   │       └── theme.dart
│   │
│   ├── domain/                         # Pure value types, no Flutter imports
│   │   ├── letter.dart                 # IcelandicLetter enum + metadata
│   │   ├── number.dart
│   │   ├── word.dart                   # Word with linked utterance + image keys
│   │   ├── prompt.dart                 # Promptable: anything with audio + image
│   │   └── icelandic.dart              # Letter ordering, casing rules
│   │
│   ├── mechanics/                      # Reusable interaction primitives (THE leverage)
│   │   ├── tap_to_hear/
│   │   │   ├── tap_tile.dart           # Generic tile: image+label, plays audio on tap
│   │   │   ├── tap_grid.dart           # Layout for N tiles
│   │   │   └── tap_feedback.dart       # Squeeze/glow animation
│   │   ├── tracing/                    # Skeleton present in v1, real impl post-MVP
│   │   │   ├── tracing_surface.dart    # CustomPainter shell
│   │   │   ├── stroke_model.dart       # Sampled points, ideal path, tolerance
│   │   │   └── stroke_evaluator.dart   # (Stub now, real in tracing milestone)
│   │   ├── matching/                   # Stub for post-MVP
│   │   │   └── matching_pair.dart
│   │   └── sequencing/                 # Stub for post-MVP
│   │       └── sequence_strip.dart
│   │
│   ├── features/                       # Feature-first composition layer
│   │   ├── home/
│   │   │   ├── home_page.dart          # Two doors: Stafir / Tölur
│   │   │   └── door_widget.dart
│   │   ├── stafir/                     # Letters room
│   │   │   ├── stafir_room.dart        # Composes mechanics for letters
│   │   │   ├── letter_grid_page.dart   # MVP: tap-to-hear all 32 letters
│   │   │   ├── letter_word_pair.dart
│   │   │   └── stafir_providers.dart   # Room-scoped state
│   │   ├── tolur/                      # Numbers room (post-MVP)
│   │   │   ├── tolur_room.dart
│   │   │   └── tolur_providers.dart
│   │   └── parent_settings/
│   │       ├── parent_settings_page.dart
│   │       ├── child_name_form.dart
│   │       └── settings_controller.dart
│   │
│   ├── gen/                            # Generated, gitignored except audio_manifest
│   │   ├── audio_manifest.g.dart       # From tools/tts_pipeline/manifest.yaml
│   │   └── assets.gen.dart             # (Optional) flutter_gen output for images
│   │
│   └── l10n/                           # Icelandic-only, but ARB-structured
│       ├── app_is.arb                  # All UI strings (parent settings labels, etc.)
│       └── app_localizations.dart      # Generated
│
├── test/
│   ├── unit/
│   │   ├── domain/                     # Letter ordering, casing
│   │   ├── core/audio/                 # AudioEngine.play(key) latency budget
│   │   └── manifest/                   # All keys resolve to existing assets
│   ├── widget/
│   │   ├── mechanics/tap_to_hear_test.dart
│   │   ├── features/stafir_test.dart
│   │   └── features/parent_gate_test.dart
│   └── golden/
│       ├── home_page_test.dart
│       └── letter_grid_test.dart
└── integration_test/
    ├── tap_to_hear_flow_test.dart      # Real device: tap letter → audio plays
    └── parent_gate_flow_test.dart
```

### Structure Rationale

- **`mechanics/` is its own top-level folder, not nested under `features/`:** The four mechanics are *primitives*, used by both rooms. Putting them inside `features/stafir/` would create cross-feature imports (anti-pattern). Putting them in `core/` would conflate infrastructure with UI. They get their own peer.
- **`features/` is feature-first:** Each room is a feature; parent settings is a feature; home is a feature. Rooms compose mechanics + room-specific layout/wiring. Easy to delete or replace a room.
- **`domain/` has zero Flutter imports:** Pure Dart value types. Allows fast unit tests, possible future code reuse (e.g., parent-companion app).
- **`tools/` is sibling to `lib/`, not inside it:** Python build pipeline never ships. Keeping it next to (not inside) `lib/` makes that boundary unmistakable. Pubspec doesn't bundle `tools/`.
- **`gen/` is partially gitignored:** `audio_manifest.g.dart` SHOULD be committed (it's the contract between Python pipeline and Flutter app — committing makes builds reproducible without Python). Other `*.g.dart` files (drift, riverpod) are conventionally gitignored.
- **`l10n/` exists even though only Icelandic:** ARB structure costs ~30 minutes of setup and zero ongoing maintenance. Hardcoding strings is the kind of decision that's painful to undo. Use ARB for *parent-facing UI* (settings labels). Child-facing content is voice, not text — no localization layer needed there.

---

## Architectural Patterns

### Pattern 1: Generated Audio Manifest (compile-time map)

**What:** A Python script reads `manifest.yaml`, generates AAC files, and emits `lib/gen/audio_manifest.g.dart` containing a `const Map<String, AudioAsset>` (or sealed/enum variants for type safety). The Flutter app imports this generated file and looks up assets by key in O(1) at runtime.

**When to use:** Always — the alternative (loading JSON at startup, parsing into a map) adds 30-100ms to cold start and gives no compile-time safety. A generated `const` map is faster, type-safe, and tree-shakeable.

**Trade-offs:**
- **Pro:** Zero runtime parse cost. Compile error if a feature references a missing utterance key. IDE autocomplete on keys.
- **Pro:** The committed `.g.dart` decouples Flutter builds from Python — a teammate without Python installed can still `flutter run`.
- **Con:** Manifest changes require regenerating the Dart file. Mitigation: `Makefile` target + git pre-commit hook.

**Example:**
```dart
// lib/gen/audio_manifest.g.dart  (generated; DO NOT EDIT)
import '../core/audio/utterance_key.dart';

const Map<UtteranceKey, AudioAsset> audioManifest = {
  UtteranceKey.letterH: AudioAsset(
    path: 'assets/audio/letters/h.aac',
    durationMs: 410,
    voice: 'tiro_dilja_v2',
    text: 'Há',
  ),
  UtteranceKey.wordHundur: AudioAsset(
    path: 'assets/audio/words/hundur.aac',
    durationMs: 720,
    voice: 'tiro_dilja_v2',
    text: 'hundur',
  ),
  // ... ~300 more
};
```

```python
# tools/tts_pipeline/emit_dart_manifest.py (excerpt)
def emit(manifest: list[Utterance], out_path: Path):
    lines = ['// GENERATED — DO NOT EDIT', "import '../core/audio/utterance_key.dart';"]
    lines.append('const Map<UtteranceKey, AudioAsset> audioManifest = {')
    for u in manifest:
        lines.append(f"  UtteranceKey.{u.key}: AudioAsset(")
        lines.append(f"    path: '{u.path}',")
        lines.append(f"    durationMs: {u.duration_ms},")
        lines.append(f"    voice: '{u.voice}',")
        lines.append(f"    text: {dart_str(u.text)},")
        lines.append('  ),')
    lines.append('};')
    out_path.write_text('\n'.join(lines))
```

### Pattern 2: Warm Player Pool for ~50ms Tap-to-Audio

**What:** Instead of creating an `AudioPlayer` per tap (~150-300ms cold start on Android), pre-allocate a small pool (e.g., 4 players) at app launch. Each `play(key)` call grabs a free player, calls `setAsset(path)` if needed, and `play()`. Crucially: pre-load the most-likely-next assets into idle players during the previous frame.

**When to use:** Whenever tap-to-audio latency budget is < 100ms. Verified on the just_audio README: `setUrl`/`setAsset` is the slow path; `play()` on an already-loaded source is ~10-30ms. Flame's `AudioPool` pattern documents this approach for game audio. Critically, set up `AudioPlayer.preload = true` (default) and avoid disposing/recreating.

**Trade-offs:**
- **Pro:** Sub-50ms tap-to-audio is achievable on the hot path (assets already loaded into a player).
- **Pro:** No memory pressure — 4 players × ~1MB each is negligible.
- **Con:** State management is non-trivial (which player has which asset?). Solution: encapsulate in `AudioEngine`.
- **Alternative considered:** `flutter_soloud` is officially recommended by Flutter docs for low-latency game audio (FFI-direct, no platform channel hop). For 200-400 short AAC clips and 50ms target, `just_audio` with a warm pool is sufficient and was specified by the user in PROJECT.md. Defer SoLoud unless latency measurements during phase 1 prove just_audio insufficient.

**Example:**
```dart
class AudioEngine {
  final List<_PooledPlayer> _pool;
  final Map<UtteranceKey, _PooledPlayer> _hot; // key → pre-loaded player
  AudioEngine._(this._pool) : _hot = {};

  static Future<AudioEngine> warmup({int poolSize = 4}) async {
    final pool = await Future.wait(
      List.generate(poolSize, (_) async => _PooledPlayer(AudioPlayer())),
    );
    return AudioEngine._(pool);
  }

  /// Pre-load assets that are likely to play next (e.g., all 32 letters on
  /// entering Stafir room). Called from `RoomScope` mount.
  Future<void> warmCache(Iterable<UtteranceKey> keys) async {
    // Round-robin assign to pool slots; LRU eviction when pool is full.
  }

  /// Hot-path: must be < 30ms wall-clock.
  void play(UtteranceKey key) {
    final hot = _hot[key];
    if (hot != null) {
      hot.player.seek(Duration.zero);
      hot.player.play(); // fire-and-forget; do NOT await
      return;
    }
    // Cold path: grab any free player, setAsset + play
    _coldPlay(key);
  }
}
```

### Pattern 3: Riverpod Provider Hierarchy with Scoped Overrides

**What:** Three concentric scopes:
1. **App-scoped (root `ProviderScope`)** — singletons that live for the whole app lifetime.
2. **Room-scoped (`ProviderScope` wrapping each room)** — state that resets when leaving the room (current letter, recent activity within the room).
3. **Activity-scoped (`ProviderScope` inside an activity widget)** — ephemeral state (current tracing stroke, current matching attempt). Disposed automatically on widget unmount.

Riverpod 3.x supports this via `ProviderScope(overrides: [...])`. Scoped providers must declare `dependencies` so the linter validates the scope hierarchy.

**When to use:** Whenever state lifetimes differ. App-scoped audio engine should NOT be re-created on room change. Room-scoped "letters seen this session" should reset between rooms. Activity-scoped "current stroke" should reset when leaving an activity.

**Trade-offs:**
- **Pro:** Automatic disposal — no manual lifecycle code. Predictable scoping.
- **Pro:** Test isolation — override providers in `ProviderScope` for widget tests.
- **Con:** Riverpod scoping has a learning curve; the `dependencies:` annotation requirement on scoped providers is easy to forget.

**Example provider tree:**
```dart
// === ROOT (app-scoped) ===
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final audioEngineProvider = Provider<AudioEngine>((ref) {
  throw UnimplementedError(); // overridden in main() with awaited warmup
});

final manifestProvider = Provider<AudioManifest>((ref) {
  return const AudioManifest(audioManifest); // pure const map
});

@riverpod
class ChildProfileController extends _$ChildProfileController {
  @override
  Future<ChildProfile> build() => ref.read(databaseProvider).childProfile.read();
  Future<void> setName(String name) async { /* ... */ }
}

// === ROOM-SCOPED (Stafir) ===
@Riverpod(dependencies: [])
class CurrentLetter extends _$CurrentLetter {
  @override
  IcelandicLetter? build() => null;
  void select(IcelandicLetter l) => state = l;
}

// In stafir_room.dart:
class StafirRoom extends ConsumerWidget {
  Widget build(context, ref) {
    return ProviderScope(
      overrides: [
        // Pre-warm room audio while the room mounts
        _stafirAudioWarmup.overrideWith((ref) async {
          final engine = ref.read(audioEngineProvider);
          await engine.warmCache(IcelandicLetter.values.map((l) => l.utteranceKey));
        }),
      ],
      child: const _StafirRoomBody(),
    );
  }
}
```

### Pattern 4: Drift with Stepwise Migrations (Schema Evolution Built-in)

**What:** Use Drift's `stepByStep` migration generator from day one, even when the v1 schema has only one table. Each schema bump (`schemaVersion: N → N+1`) gets its own migration step. Drift's `drift_dev schema steps` command generates a `database.steps.dart` file that's verified against actual schema snapshots.

**When to use:** Always for any persistent schema. The cost of doing this on day one is ~10 minutes; the cost of retrofitting after shipping is rewriting all of v1's user data.

**Trade-offs:**
- **Pro:** Future schema changes can't break v1 user data — every migration step is tested against the schema snapshot it migrates from.
- **Pro:** Drift's compile-time SQL checking catches typos that would crash at runtime.
- **Con:** Drift requires `build_runner`. Acceptable since `riverpod_generator` already brings build_runner.

### Pattern 5: Parent Gate via Long-Press, Not Math Question

**What:** A 3-second hold gesture, not a "what's 7×8" challenge. Implementation: `GestureDetector(onLongPress: ...)` configured with `delay: Duration(seconds: 3)`. Visual feedback during hold (a slowly filling ring) so the gesture is discoverable but a 5-year-old won't accidentally complete it.

**When to use:** This is the user-specified pattern. The alternative (math question) is recommended by Apple's child app guidelines but adds friction the user has explicitly rejected. 3-second hold is a known compromise.

**Trade-offs:**
- **Pro:** Discoverable for adults (visible affordance), invisible to a 5-year-old.
- **Con:** A motivated 5-year-old *could* hold for 3 seconds. Mitigation: settings screen has no destructive actions in v1 (just enter child name). If destructive options ship later, escalate gate complexity then, not now.

---

## Data Flow

### The Hot Path: Tap → Audio (target < 50ms perceived)

This is the single most important data flow in the app. Optimize ruthlessly.

```
[Finger touches glass]
    ↓ (~16ms — Flutter input event arrival)
[GestureDetector.onTapDown fires]                  ← visual feedback STARTS HERE
    ↓ (~0ms — synchronous)
[TapTile triggers AnimationController.forward()]   ← squeeze/glow animation
    ↓ (~0ms — synchronous, fire-and-forget)
[ref.read(audioEngineProvider).play(letter.utteranceKey)]
    ↓ (~5-15ms — pool lookup, seek-to-zero, play() platform call)
[just_audio dispatches to AVAudioPlayer / MediaPlayer]
    ↓ (~10-25ms — platform audio engine pre-warmed)
[Sound emerges from speaker]                       ← audio feedback HERE
                                                   ← total: ~30-55ms perceived
```

**Critical rules for the hot path:**
1. `play()` must NOT be `await`ed in the tap handler — fire-and-forget. The animation must start before the audio call returns.
2. Asset must be pre-loaded — cold-loading an asset costs 100-300ms and blows the budget.
3. No `setState` between tap and play — use Riverpod or just trigger animation imperatively.
4. NEVER hit Drift on the tap path. Activity logging (v2) must be deferred (`Future.microtask` or write-batch on screen exit).

### Asset Pipeline Flow (build-time)

```
[manifest.yaml: utterance keys + text + voice]
    ↓ (Python: tools/tts_pipeline/generate_audio.py)
[Tiro TTS API / ElevenLabs API → raw .wav per utterance]
    ↓ (Python: normalize.py wrapping ffmpeg-normalize)
[Loudness-normalized .wav (-16 LUFS) → .aac (encoded)]
    ↓ (write to assets/audio/{category}/{key}.aac)
[All AAC files on disk + manifest.yaml]
    ↓ (Python: emit_dart_manifest.py)
[lib/gen/audio_manifest.g.dart written]
    ↓ (committed to git — see Pattern 1 trade-off)
[flutter run — pubspec.yaml bundles assets/audio/**]
    ↓ (runtime startup)
[AudioEngine.warmup() → optionally pre-load most-played keys]
```

### State Management Flow (Riverpod)

```
[Drift Database] ───stream──→ [DatabaseProvider] ──→ [ChildProfileController]
                                                              ↓ ref.watch
                                              [ParentSettingsPage rebuilds]
                                                              ↓ user edits
                                              [Controller.setName(text)]
                                                              ↓ writes
                                                       [Drift Database]
                                                              ↓ stream
                                              [ChildProfileController]
                                                              ↓ rebuild
                                              [Voice rendering uses new name]
```

### Key Data Flows

1. **Tap → Audio (HOT, < 50ms):** TapTile gesture → AudioEngine.play() → just_audio. No DB, no provider rebuild on the tap itself; only the animation state changes.
2. **App launch warmup:** `main()` → `AudioEngine.warmup()` (allocates pool) → opens Drift DB in background isolate → loads child profile → renders home page. Target < 1.5s on a mid-range Android tablet.
3. **Room entry warmup:** Navigate to Stafir → `StafirRoom` mounts → triggers `engine.warmCache(allLetterKeys)` in parallel with grid build. By the time the user taps, all 32 letter audios are in the pool's hot cache.
4. **Settings update:** Parent enters name → `ChildProfileController.setName()` → Drift write → Drift stream → all consumers re-render.

---

## Suggested Build Order

This order resolves dependencies correctly and lets each milestone validate the next.

| Step | What | Why first / depends on |
|------|------|------------------------|
| **0. Skeleton** | `flutter create`, pubspec, build.yaml, ProviderScope, MaterialApp.router with two empty pages | Bootstrap |
| **1. Manifest contract** | Hand-write a tiny `audio_manifest.g.dart` with 2-3 letters; commit. Drop 2-3 hand-recorded `.aac` placeholders into `assets/audio/letters/` | **Unblocks audio engine work without waiting for Python pipeline.** This is the critical path decoupling. |
| **2. AudioEngine** | Warm pool, `play(key)`, `warmCache(keys)`. Unit test with stubbed manifest. | Depends on step 1's contract (just the type, not real assets) |
| **3. TapToHearTile mechanic** | Generic widget, takes a `Promptable`, plays audio + animates on tap | Depends on AudioEngine |
| **4. Stafir room (MVP)** | Compose 32 TapToHearTiles in a grid. Use placeholder audio for letters not yet generated. | Depends on TapToHearTile + manifest having all 32 keys (audio can lag) |
| **5. Python TTS pipeline** | Build out `tools/tts_pipeline/` properly. Generate all 32 letters + ~32 example words. Emit real `audio_manifest.g.dart`. | **Can be done in parallel with steps 2-4** — that's the whole point of the manifest contract decoupling. Just needs to be done before MVP ships. |
| **6. Drift schema v1** | Single `child_profile` table. Migration scaffolding in place. | Independent of audio path |
| **7. Parent gate + settings** | 3s-hold widget + child name form persisting to Drift | Depends on Drift |
| **8. Personalization wiring** | Inject child name into voice-overs via manifest post-processing or per-utterance text substitution | Depends on settings + TTS pipeline (for re-rendering name-bearing utterances) |
| **9. Tracing skeleton** | `tracing/` folder with `StrokeModel` types committed but `TracingSurface` is a stub. **Just enough to ensure types are stable** so future work doesn't refactor mechanics/. | Architecture stability for post-MVP |
| **10. Tölur room** | Mirrors Stafir; reuses TapToHearTile. New utterance keys for numbers. | Depends on TapToHearTile being battle-tested in Stafir |
| **11. Tracing real impl** | CustomPainter, sampled at 60Hz, tolerance check | Post-MVP |
| **12. Matching / sequencing** | New mechanics; new room compositions | Post-MVP |

**The critical path insight:** Step 1 (the hand-written manifest with 2 placeholder audios) is the single highest-leverage unblock. It lets the audio engine, mechanic, and room work proceed *in parallel* with the Python pipeline. Without it, Flutter work blocks on TTS API access.

---

## Drift Schema Sketch

### v1 (MVP)

```dart
// lib/core/db/tables/child_profile.dart
class ChildProfile extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get name => text().withLength(min: 1, max: 32)();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
  // Singleton pattern: id always = 1. No multi-child support per PROJECT.md.
}

// lib/core/db/database.dart
@DriftDatabase(tables: [ChildProfile])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: stepByStep(/* empty in v1 */),
  );
}

LazyDatabase _open() => LazyDatabase(() async {
  // Background isolate per Drift recommendation for cross-platform
  return NativeDatabase.createInBackground(await _dbFile());
});
```

### v2 (Personalization)

```dart
// New tables added without modifying ChildProfile (additive migration)
class PhotoTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tag => text()();              // Icelandic word: "hundur", "köttur"
  TextColumn get filePath => text()();         // app_documents_dir relative path
  DateTimeColumn get addedAt => dateTime()();
}

class ActivityLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get room => text()();             // 'stafir' | 'tolur'
  TextColumn get utteranceKey => text()();
  DateTimeColumn get tappedAt => dateTime()();
  // For "recently played" / personalization heuristics. No analytics export.
}

// schemaVersion: 2
// stepByStep migration: from1To2: (m, schema) async {
//   await m.createTable(schema.photoTags);
//   await m.createTable(schema.activityLog);
// }
```

**Schema rules:**
- Never modify v1 columns post-launch — only add new tables/columns.
- Activity log writes MUST be off the tap hot path (write-batch on screen exit, or microtask).
- Photo file bytes never live in the DB — only paths to the app's documents dir.

---

## Riverpod Provider Tree Sketch

```
ProviderScope (root, in main.dart)
  ├── databaseProvider                    [app-scoped, singleton]
  ├── audioEngineProvider                 [app-scoped, singleton, awaited at startup]
  ├── manifestProvider                    [app-scoped, const]
  ├── childProfileProvider                [app-scoped, AsyncNotifier on Drift stream]
  └── routerProvider                      [app-scoped, go_router config]
  │
  ├──→ HomePage (no extra scope)
  │
  ├──→ ProviderScope (Stafir room)        [room-scoped, dependencies declared]
  │       ├── currentLetterProvider       [room-scoped, autoDispose]
  │       ├── stafirSessionProvider       [room-scoped, autoDispose]
  │       └──→ LetterGridPage
  │              └──→ TapToHearTile (×32)
  │                     └── (uses root audioEngineProvider directly)
  │
  ├──→ ProviderScope (Tolur room)         [room-scoped, post-MVP]
  │       └── currentNumberProvider
  │
  └──→ ProviderScope (ParentSettings)     [route-scoped]
          └── settingsControllerProvider  [reads/writes childProfileProvider]
```

**Scoping rules:**
- Anything used by mechanics (`audioEngineProvider`) is root-scoped. Mechanics never override these — they just `ref.watch`/`ref.read`.
- Anything specific to "what's happening in this room right now" is room-scoped + `autoDispose`.
- Anything specific to "what's happening in this widget interaction" is activity-scoped or just `useState` in a HookWidget.

---

## Asset Manifest Format Proposal

### Source: `tools/tts_pipeline/manifest.yaml`

```yaml
# Hugrún audio manifest — single source of truth.
# Generated assets and Dart code derive from this file.

defaults:
  voice: tiro_dilja_v2
  output_format: aac
  loudness_target_lufs: -16

utterances:
  # === LETTERS ===
  - key: letterA
    text: "A"
    category: letters
    file: letters/a.aac

  - key: letterAE
    text: "Æ"
    category: letters
    file: letters/ae.aac
    pronunciation: "aɪ"  # IPA override; ssml_override also supported

  # ... all 32 letters

  # === EXAMPLE WORDS ===
  - key: wordHundur
    text: "hundur"
    category: words
    file: words/hundur.aac
    linked_letter: letterH       # for letter→word audio chains

  # === NUMBERS (post-MVP) ===
  - key: numberEinn
    text: "einn"
    category: numbers
    file: numbers/einn.aac

  # === UI SOUNDS ===
  - key: uiTapChime
    text: null                   # synthesized non-speech, hand-authored
    category: ui
    file: ui/tap_chime.aac
    skip_tts: true
```

### Generated: `lib/gen/audio_manifest.g.dart`

```dart
// GENERATED FROM tools/tts_pipeline/manifest.yaml — DO NOT EDIT
// Run: make audio (or python tools/tts_pipeline/emit_dart_manifest.py)

import '../core/audio/utterance_key.dart';
import '../core/audio/audio_asset.dart';

const Map<UtteranceKey, AudioAsset> audioManifest = {
  UtteranceKey.letterA: AudioAsset(
    path: 'assets/audio/letters/a.aac',
    text: 'A',
    voice: 'tiro_dilja_v2',
    durationMs: 380,
  ),
  UtteranceKey.letterAE: AudioAsset(
    path: 'assets/audio/letters/ae.aac',
    text: 'Æ',
    voice: 'tiro_dilja_v2',
    durationMs: 420,
  ),
  // ... continues for every utterance
};
```

### Companion: `lib/core/audio/utterance_key.dart`

```dart
// Hand-written; the Python emitter generates ALL utterance keys but checks
// against this enum at build time to prevent drift between manifest and code.
enum UtteranceKey {
  letterA, letterAA, letterB, /* ... */ letterOE,
  wordHundur, wordIs, /* ... */
  numberEinn, /* ... */
  uiTapChime, uiSuccess,
}
```

**Verification step (CI / pre-commit):**
1. `python tools/verify_manifest.py` — every key in YAML matches an `UtteranceKey` enum value, every linked file exists on disk.
2. `dart run tools/verify_assets.dart` — every `audioManifest` entry's `path` resolves under `assets/`.

---

## Routing Decision

**Verdict: `go_router` with simple top-level routes.** Not `StatefulShellRoute` (overkill for 2 destinations with no preserved state per branch). Not raw `Navigator 2.0` (the API is hostile and offers no benefit here).

```dart
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/stafir', builder: (_, __) => const StafirRoom()),
    GoRoute(path: '/tolur', builder: (_, __) => const TolurRoom()),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const ParentSettingsPage(),
      // Reachable only via parent gate from HomePage; no direct URL surface.
    ),
  ],
);
```

**Rationale:**
- Two rooms + home + settings = 4 routes. `StatefulShellRoute` shines for tab bars where each tab preserves scroll/state on switch. We *want* rooms to fully reset on exit (engagement reset, audio cache freed). So a simple route stack is correct.
- `go_router` over Navigator 1.0 stacked pages: future-proofs deep linking (parent could open settings via system-level shortcut), and is the documented community standard.
- No web platform support needed — but `go_router` doesn't penalize us for that.

---

## Localization Architecture

**Verdict: ARB-based for parent UI, no localization layer for child content.**

- **Parent UI strings** (settings labels, "Enter your child's name") → `lib/l10n/app_is.arb` + generated `AppLocalizations`.
- **Child content** is voice-only by design (`Out of scope: text instructions anywhere` per PROJECT.md). There is no string layer for child content. The "string" of letter H is the audio file `letters/h.aac`, looked up by `UtteranceKey.letterH`.

**Why ARB even for single language:**
- 30 minutes of upfront cost.
- Forces clean separation between code and copy — easier to review parent-facing wording with a non-developer.
- If "localization beyond Icelandic" ever moves out of Out of Scope (e.g., Faroese, which shares many letters), the foundation is in place.
- Tooling (Android Studio / VSCode) gives ARB key autocomplete and lints for missing translations.

**What ARB does NOT do:**
- Does not localize child voice content. That's a TTS pipeline concern, not a string concern.
- Does not localize letter ordering or grammar rules. Those live in `domain/icelandic.dart` as pure Dart code.

---

## Testing Structure

| Test type | Scope | What to cover | Tools |
|-----------|-------|---------------|-------|
| **Unit** | Pure Dart, no Flutter | Letter ordering, casing rules, manifest integrity, AudioEngine state machine (with mock player) | `test`, `mocktail` |
| **Widget** | Single widget in isolation | TapToHearTile fires audio on tap; ParentGate completes after 3s hold but not before; LetterGrid renders all 32 | `flutter_test`, `ProviderScope` overrides |
| **Golden** | Visual regression | HomePage layout, LetterGrid layout (5×7), ParentSettingsPage. Screen the 50% holding state of the parent gate. | `flutter_test` `matchesGoldenFile`, optional `golden_toolkit` for multi-device |
| **Integration** | Real device, full app | Tap-to-hear flow on a real iPad/Android tablet — audio actually plays, latency measured. Parent gate completion. | `integration_test`, `flutter drive` |
| **Latency** | Real device, instrumented | Tap timestamp → audio start timestamp must be < 100ms p95 | Custom test harness using `Stopwatch` + `AudioPlayer.playerStateStream` |

**Critical: do NOT use golden tests for tap-to-hear timing.** Golden tests check pixels, not timing. Tap-to-audio latency is an integration test on real hardware. Goldens are for layout regressions only.

**Provider override pattern in tests:**
```dart
testWidgets('TapToHearTile plays audio on tap', (tester) async {
  final fakeEngine = FakeAudioEngine();
  await tester.pumpWidget(ProviderScope(
    overrides: [audioEngineProvider.overrideWithValue(fakeEngine)],
    child: const MaterialApp(home: TapToHearTile(prompt: testLetterH)),
  ));
  await tester.tap(find.byType(TapToHearTile));
  expect(fakeEngine.played, [UtteranceKey.letterH]);
});
```

---

## Tracing Component: Forward-Compatible Data Model (Post-MVP)

Even though tracing is deferred, commit the types now so mechanics/ folder is stable:

```dart
// lib/mechanics/tracing/stroke_model.dart  (commit in MVP, even if unused)

class IdealStroke {
  final List<Offset> path;          // Sampled control points along ideal stroke
  final int order;                   // For multi-stroke letters (1st, 2nd, ...)
  final double tolerance;            // Generous: 30-50px on a 1024px tile
}

class TraceAttempt {
  final List<TimedPoint> samples;    // Pointer events sampled at 60Hz
  final DateTime startedAt;
}

class TimedPoint {
  final Offset position;
  final Duration sinceStart;
}

abstract class StrokeEvaluator {
  /// Returns 0.0 (totally off) to 1.0 (perfect). MVP: hardcoded 1.0 — generous.
  /// Post-MVP: Fréchet distance or similar against IdealStroke.path.
  double evaluate(TraceAttempt attempt, IdealStroke ideal);
}
```

**Why commit stubs now:** The shape of `TraceAttempt`, `IdealStroke`, and the evaluator interface won't change much when implementation lands. Locking the types in MVP prevents a refactor cascade later. Implementation is the deferred work; the data model is cheap and stable.

---

## Build-Time Pipeline Integration

### Make-driven (recommended)

```makefile
# Makefile (project root)
.PHONY: audio audio-clean dart-gen verify

audio:
	cd tools/tts_pipeline && python generate_audio.py
	cd tools/tts_pipeline && python normalize.py
	cd tools/tts_pipeline && python emit_dart_manifest.py ../../lib/gen/audio_manifest.g.dart

dart-gen:
	dart run build_runner build --delete-conflicting-outputs

verify:
	dart run tools/verify_assets.dart
	flutter analyze
	flutter test

build: audio dart-gen verify
	flutter build apk
	flutter build ipa
```

### Pre-commit hook

```bash
# .git/hooks/pre-commit (or via lefthook/pre-commit)
# Block commit if manifest.yaml changed but audio_manifest.g.dart didn't
if git diff --cached --name-only | grep -q "tools/tts_pipeline/manifest.yaml"; then
  if ! git diff --cached --name-only | grep -q "lib/gen/audio_manifest.g.dart"; then
    echo "ERROR: manifest.yaml changed but audio_manifest.g.dart not regenerated"
    echo "Run: make audio"
    exit 1
  fi
fi
```

### CI

- **Don't** run the TTS pipeline in CI (TTS API costs money / hits quotas).
- **Do** verify `audio_manifest.g.dart` is in sync with `manifest.yaml` (a hash-diff check).
- **Do** run `flutter test` and integration tests on emulators.

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| **1 child (Hugrún)** | This is the design point. Singleton child profile, single Drift DB, all assets bundled. Nothing else needed. |
| **Public release** (10s of children, still single-device) | Schema change: `child_profile.id` becomes a real auto-increment for multi-child support. Even then: still no cloud, no accounts. Settings UI gains "switch child." |
| **Public release with cloud** (out of scope per PROJECT.md) | Would require: account layer, sync engine, server backend, photo upload pipeline, GDPR/COPPA review. Explicitly Out of Scope — a parent-companion review app is the most likely future, not multi-device sync. |

### Scaling Priorities (within current scope)

1. **First bottleneck:** Asset bundle size — at 200-400 AAC files × ~25KB each = 5-10MB. Acceptable. If asset count grows past ~1000, consider on-disk loading from `getApplicationSupportDirectory()` for non-essential assets.
2. **Second bottleneck:** Drift cold start on low-end Android — `NativeDatabase.createInBackground()` mitigates by running queries off the UI thread.
3. **Third bottleneck:** Audio engine memory if pool grows — mitigation is LRU eviction in `_hot` cache; pool itself stays at 4 players.

---

## Anti-Patterns

### Anti-Pattern 1: Creating an `AudioPlayer` per tap

**What people do:** `final p = AudioPlayer(); await p.setAsset(...); await p.play();` on every tap.
**Why it's wrong:** Cold start of an `AudioPlayer` instance is 100-300ms on Android. Blows the 50ms budget by 6×.
**Do this instead:** Warm pool pattern (Pattern 2). Create players once at app start; reuse them.

### Anti-Pattern 2: Loading audio asset map from JSON at startup

**What people do:** Ship `assets/audio_manifest.json`, parse it in `main()` into a `Map<String, AudioAsset>`.
**Why it's wrong:** Adds 30-100ms to cold start (JSON decode + asset bundle read). No compile-time safety on keys. Tree-shaking can't remove unused entries.
**Do this instead:** Generated `const` Dart map (Pattern 1). Zero runtime cost, full type safety, tree-shakeable.

### Anti-Pattern 3: Putting `mechanics/` inside `features/stafir/`

**What people do:** Build TapToHearTile inside the first feature that needs it; later when Tölur needs it too, either copy-paste or create cross-feature imports.
**Why it's wrong:** Cross-feature imports defeat the point of feature-first organization. Copy-paste guarantees drift between rooms.
**Do this instead:** `mechanics/` is a peer of `features/`, not a child. Designed up-front to be reusable.

### Anti-Pattern 4: Using BLoC or Provider alongside Riverpod

**What people do:** Old tutorials show `provider`, ChangeNotifier, BLoC. Mixing libraries in a Flutter app is common.
**Why it's wrong:** PROJECT.md specifies Riverpod. Mixing causes provider lookup confusion, double-rebuilds, and test flake.
**Do this instead:** Riverpod 3.x with `riverpod_generator`. One state library.

### Anti-Pattern 5: Drift queries on the tap path

**What people do:** "Let me log every tap so I can build a 'recent letters' feature." Calls into Drift from `onTap`.
**Why it's wrong:** SQLite write on a UI thread can cost 10-50ms; even on a background isolate, the await adds latency. Every ms counts on the tap path.
**Do this instead:** Tap handler triggers audio + animation only. Activity logging (v2) goes through a write-batched controller that flushes on screen unmount or after a `Future.microtask` delay.

### Anti-Pattern 6: Math-question parent gate

**What people do:** "What is 7 × 8?" challenge before settings.
**Why it's wrong:** Adds friction for tired parents. PROJECT.md implicitly rejected this by specifying 3-second hold.
**Do this instead:** 3-second hold with a slowly-filling visual ring. Discoverable for adults, invisible to a 5-year-old, no math required.

### Anti-Pattern 7: Hardcoding the child's name as a string concat into utterance text

**What people do:** `play("Vel gert, ${childName}!")` — but the audio is pre-baked, so this either means string substitution into a placeholder audio (impossible without splicing) or runtime TTS (rejected per PROJECT.md).
**Why it's wrong:** Pre-baked audio means name personalization requires re-rendering name-bearing utterances when the name changes.
**Do this instead:** Two-tier strategy — (a) at parent settings save, the TTS pipeline regenerates name-bearing utterances offline (post-MVP, requires bundled TTS or background generation); (b) MVP simpler approach: skip name in voice-overs in v1, ship name personalization as a v2 feature with proper pipeline support. PROJECT.md flags this as deferred — honor that.

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Tiro TTS API (`tts.tiro.is`) | Build-time only, Python script | Free, Icelandic government-funded. No runtime calls. Cache responses locally. |
| ElevenLabs API | Build-time only, Python script (parallel A/B) | Commercial — verify kids-app licensing before relying on it. No runtime calls. |
| ffmpeg (`ffmpeg-normalize`) | Build-time CLI invocation | Loudness normalization to -16 LUFS so no clip is louder than another. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Python pipeline ↔ Flutter app | Generated `audio_manifest.g.dart` + AAC files in `assets/` | Single source of truth: `manifest.yaml`. Generated file is committed. |
| `lib/mechanics/` ↔ `lib/features/` | Direct import (mechanics → consumed by features) | Mechanics never import from features. Lint rule recommended. |
| `lib/domain/` ↔ everywhere | Direct import (others → domain) | Domain never imports anything Flutter. Pure Dart. |
| `lib/core/db/` ↔ `lib/features/` | Via Riverpod providers | Features never `import 'package:drift/...'` directly. Always go through provider + controller. |
| `lib/core/audio/` ↔ `lib/mechanics/tap_to_hear/` | Via `audioEngineProvider` | Mechanics get `AudioEngine` via Riverpod, not constructor. Enables test override. |

---

## Sources

- [Riverpod docs (Context7) — scoping and ProviderScope override](https://github.com/rrousselgit/riverpod) (HIGH confidence)
- [Drift migrations (Context7) — stepByStep migration strategy](https://drift.simonbinder.eu/migrations) (HIGH confidence)
- [Drift isolates — DriftIsolate background isolate setup](https://drift.simonbinder.eu/isolates/) (HIGH confidence)
- [just_audio README (Context7) — AudioPlayer, setAudioSource, playlist API](https://github.com/ryanheise/just_audio) (HIGH confidence)
- [Flame AudioPool — pre-allocated player pool pattern for game audio](https://docs.flame-engine.org/latest/bridge_packages/flame_audio/audio_pool.html) (HIGH confidence)
- [flutter_soloud — alternative low-latency audio plugin recommended for games](https://docs.flutter.dev/cookbook/audio/soloud) (HIGH confidence — kept as fallback option)
- [go_router (Context7) — basic and ShellRoute usage](https://pub.dev/packages/go_router) (HIGH confidence)
- [Code With Andrea — Flutter Project Structure: Feature-first or Layer-first?](https://codewithandrea.com/articles/flutter-project-structure/) (MEDIUM — community guidance)
- [Code With Andrea — Flutter App Architecture with Riverpod](https://codewithandrea.com/articles/flutter-app-architecture-riverpod-introduction/) (MEDIUM — community guidance)
- [FlutterGen — flutter_gen for assets/code generation](https://pub.dev/packages/flutter_gen) (HIGH confidence)
- [Flutter Internationalization — ARB and intl approach](https://docs.flutter.dev/ui/internationalization) (HIGH confidence — official docs)
- [Flutter app architecture guide — MVVM, Repositories, Services](https://docs.flutter.dev/app-architecture/guide) (HIGH confidence — official docs)
- [Flutter widget testing cookbook](https://docs.flutter.dev/cookbook/testing/widget/introduction) (HIGH confidence)
- [Integration testing — flutter_test + integration_test](https://docs.flutter.dev/testing/integration-tests) (HIGH confidence)

---
*Architecture research for: single-device Flutter literacy + numeracy app, Icelandic, offline-only, ages 5*
*Researched: 2026-05-02*
