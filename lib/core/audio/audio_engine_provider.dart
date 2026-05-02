// App-scoped Riverpod provider for [AudioEngine] (D-01).
//
// Mirrors the appDatabaseProvider pattern in lib/core/db/database_provider.dart:
// `@Riverpod(keepAlive: true)` so the engine survives navigation, ProviderScope
// rebuilds, and (critically) is never re-created per tap.
//
// PITFALLS #7 (Riverpod scope): never autoDispose, never per-tap, never
// inside a widget build.
// PITFALLS #8 (no AudioPlayer in widget build): all AudioPlayer creation
// flows through this provider's call chain.

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'audio_engine.dart';

part 'audio_engine_provider.g.dart';

/// Returns the app-scoped [AudioEngine].
///
/// Schedules `warmUp()` on the next event-loop microtask so the home screen
/// can render immediately while the pool initializes. The engine itself is
/// returned synchronously; callers that need to wait for warm-up complete
/// can call `await engine.warmUp()` (idempotent — second call is a no-op).
///
/// Disposes the engine when the container is disposed.
@Riverpod(keepAlive: true)
AudioEngine audioEngine(Ref ref) {
  final engine = AudioEngine();
  // Fire warm-up off the main path. We deliberately don't await the future:
  // - The home screen should not block on AudioEngine warm-up.
  // - `play()` calls before warm-up completes will trigger the engine's
  //   own warm-up await (Plan 04-02 — onTapDown can race the warm-up).
  unawaited(engine.warmUp());
  ref.onDispose(() {
    // Don't await in onDispose — Riverpod doesn't await async disposers in
    // this version. Best-effort.
    unawaited(engine.dispose());
  });
  return engine;
}
