// AudioEngine — the heart of the Phase 4 MVP audio loop.
//
// Decisions exercised in this file (all from .planning/phases/04-stafir-tap-to-hear-mvp/04-CONTEXT.md):
//   D-01  Top-level non-autoDispose Riverpod provider owns this engine
//         (see lib/core/audio/audio_engine_provider.dart). Never lives in a
//         widget build, never autoDispose, never per-tap.
//   D-02  Warm pool of 4 AudioPlayer instances allocated at app start.
//   D-03  Warm-up sequence: (1) allocate, (2) activate iOS AVAudioSession by
//         playing a silent priming clip on player 0, (3) ready for play().
//   D-04  play(key) is idempotent + cancellable. Different key while playing
//         → stop current, start new on next pool slot. Same key re-tapped →
//         stop current, replay from beginning. (STAFIR-04, STAFIR-05.)
//   D-05  Clip queue per tap: letter name → example word, gapless via
//         just_audio's ConcatenatingAudioSource on a single pool player.
//   D-08  Cold-start head-clipping: clips arrive pre-padded with silence by
//         Phase 3. AudioEngine logs (does NOT throw) when a clip's
//         reportedDuration is too small to plausibly contain a silence pad.
//   D-22, D-23  Phase 4 builds against Phase 2 stub manifest. Missing clip
//         → debug warning + silent return. No exceptions to caller, no
//         user-visible errors.
//   STAFIR-09  warm pool of >= 2 AudioPlayer instances at app start.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../manifest/audio_asset.dart';
import '../manifest/utterance_key.dart';
import '../../gen/audio_manifest.g.dart';
import 'audio_player_like.dart';
import 'utterance_resolver.dart';

/// App-scoped audio engine.
///
/// Construct with `playerFactory` to inject a test-double; in production the
/// default factory returns [RealAudioPlayer], a thin wrapper around
/// `package:just_audio`'s `AudioPlayer`.
///
/// Lifecycle:
///   `final engine = AudioEngine();`
///   `await engine.warmUp();`     // allocates 4 players, primes player 0
///   `await engine.play(key);`    // [Plan 04-02]
///   `await engine.dispose();`    // tears down the pool
class AudioEngine {
  AudioEngine({
    AudioPlayerLike Function()? playerFactory,
    Map<UtteranceKey, AudioAsset>? manifestOverride,
    Map<UtteranceKey, UtteranceKey>? pairingOverride,
  }) : _playerFactory = playerFactory ?? RealAudioPlayer.new,
       _manifestOverride = manifestOverride,
       _pairingOverride = pairingOverride;

  final AudioPlayerLike Function() _playerFactory;
  final List<AudioPlayerLike> _pool = <AudioPlayerLike>[];

  /// Optional test override for kAudioManifest. Production callers leave
  /// this null and use the real manifest from `lib/gen/audio_manifest.g.dart`.
  final Map<UtteranceKey, AudioAsset>? _manifestOverride;

  /// Optional test override for kLetterToWord. Same pattern as the manifest.
  final Map<UtteranceKey, UtteranceKey>? _pairingOverride;

  Map<UtteranceKey, AudioAsset> get _manifest =>
      _manifestOverride ?? kAudioManifest;

  bool _warmedUp = false;

  /// In-flight warm-up future. When two callers race to warm up (the
  /// keep-alive provider's microtask-scheduled `warmUp()` and an early
  /// `play()` before the first call resolves), the second caller awaits
  /// the same future instead of allocating a duplicate pool. The original
  /// guard (`if (_warmedUp) return`) only fires AFTER the first call has
  /// finished priming, leaving a window where both calls can each allocate
  /// `poolSize` players — pushing `_pool.length` to `2 * poolSize` and
  /// tripping the invariant assertion in `_acquirePlayer`.
  Future<void>? _warmUpFuture;

  /// Number of warm AudioPlayer instances kept ready (D-02).
  static const int poolSize = 4;

  /// Asset path used to prime player 0 during warm-up (D-03). Phase 2's
  /// stub manifest ships silent placeholder clips, so any of them works as
  /// the primer; we use letterA's path because it's the lexically first.
  /// Phase 3 will replace these clips with real audio (still ~50 ms of
  /// leading silence per D-08), at which point the primer is no longer
  /// silent — that is fine; AVAudioSession just needs SOME play call to
  /// activate the session.
  static const String _silentAssetPath = 'assets/audio/letters/names/a.aac';

  /// Read-only access for tests + Plan 04-02.
  @visibleForTesting
  List<AudioPlayerLike> get debugPool => List.unmodifiable(_pool);

  /// True after the first successful `warmUp()`.
  bool get isWarmedUp => _warmedUp;

  /// Allocates the pool and primes player 0 to activate the iOS
  /// AVAudioSession. Idempotent — calling twice is a no-op (D-03).
  ///
  /// Budget: < 500 ms after `runApp`. The audio_engine_provider schedules
  /// this via `Future.microtask` so the home screen renders before the
  /// pool finishes initializing.
  Future<void> warmUp() {
    if (_warmedUp) return Future<void>.value();
    // De-duplicate concurrent callers: the second caller awaits the same
    // in-flight future, never allocating a second pool.
    return _warmUpFuture ??= _doWarmUp();
  }

  Future<void> _doWarmUp() async {
    // 1. Allocate the pool.
    for (var i = 0; i < poolSize; i++) {
      _pool.add(_playerFactory());
    }

    // 2. Activate iOS AVAudioSession via a silent priming play on player 0.
    //    `setAsset` returns the clip duration; we pass it to the silence-pad
    //    health check (D-08). pause() immediately so we don't actually emit
    //    audio at app start — the goal is to give the session something to
    //    initialize against, not to play sound.
    try {
      final reportedDuration = await _pool[0].setAsset(_silentAssetPath);
      await _pool[0].play();
      await _pool[0].pause();
      if (reportedDuration != null) {
        warnIfMissingPad(UtteranceKey.letterA, reportedDuration);
      }
    } catch (e) {
      // Don't fail warm-up because of an asset hiccup — log + continue. A
      // missing primer clip means the session may activate on the first
      // real play() call instead, with a tiny extra latency. Better than
      // a hard crash on app start.
      debugPrint('[AudioEngine] warmUp priming failed: $e');
    }

    // 3. Plan 04-02 may extend this with cache-on-tap pre-load. For now
    //    the pool is ready and player 0 has activated the audio session.
    _warmedUp = true;
  }

  /// Acquires the next player from the pool in round-robin order.
  ///
  /// Plan 04-02 uses this internally to dispatch playback while preserving
  /// the cancel-on-retap contract (D-04, D-05): the previous player is
  /// stopped first, then the next pool slot picks up the new audio source.
  /// Exposed via `@visibleForTesting` so Plan 04-02 tests can inspect
  /// rotation behavior without making the whole pool public.
  @visibleForTesting
  AudioPlayerLike acquirePlayerForTesting() => _acquirePlayer();

  /// Round-robin index. The pool size is fixed at [poolSize]; we wrap modulo
  /// [poolSize]. Initial value `0` so the first acquire returns player 0.
  /// Plan 04-01 only uses player 0 (for AVAudioSession priming); Plan 04-02
  /// will rotate as letters are tapped.
  int _nextPoolIndex = 0;

  /// Internal pool acquire — guarded by an assertion that the pool hasn't
  /// drifted from [poolSize] (catches a future bug that mutates [_pool]).
  AudioPlayerLike _acquirePlayer() {
    assert(
      _pool.length == poolSize,
      'pool size invariant — must be $poolSize, was ${_pool.length}',
    );
    final p = _pool[_nextPoolIndex];
    _nextPoolIndex = (_nextPoolIndex + 1) % poolSize;
    return p;
  }

  /// Debug-only: dump pool occupancy. Plan 04-02 may extend this to track
  /// which slot is currently active.
  @visibleForTesting
  String debugPoolSummary() =>
      'AudioEngine pool=${_pool.length}/$poolSize next=$_nextPoolIndex warmedUp=$_warmedUp';

  /// Releases all players. Called from the Riverpod provider's `onDispose`.
  Future<void> dispose() async {
    for (final p in _pool) {
      await p.dispose();
    }
    _pool.clear();
    _warmedUp = false;
    _warmUpFuture = null;
  }

  /// Active playback slot. Conceptually a `(player, key)` pair: when a
  /// new tap arrives we stop [_activePlayer] then acquire a fresh slot.
  /// Both fields are nulled-out together; tests assert via
  /// [debugActiveKey].
  ///
  /// Invariant: `_activePlayer == null  IFF  _activeKey == null`.
  /// Invariant: `_activePlayer != null` only between dispatch and the
  /// next stop()/play() call. The previous tap's player may still be
  /// playing audio briefly after we stop() it because just_audio drains
  /// asynchronously — that's fine, the system mixer handles the overlap.
  AudioPlayerLike? _activePlayer;
  UtteranceKey? _activeKey;

  @visibleForTesting
  UtteranceKey? get debugActiveKey => _activeKey;

  /// Plays the audio for [key].
  ///
  /// Invariants (D-04, D-05, STAFIR-02..05):
  /// - Idempotent: calling twice with the same key cancels the in-flight
  ///   playback and restarts from the beginning of the letter name.
  /// - Cancellable: calling with a different key cancels the current player
  ///   and dispatches the new key to the next round-robin pool slot.
  /// - Fire-and-forget: returns as soon as scheduling is done. The actual
  ///   playback happens asynchronously on the player.
  /// - Graceful: missing manifest entry → debug warning + silent return.
  ///   No exception escapes (Phase 2 stub fallback per D-22 + D-23).
  Future<void> play(UtteranceKey key) async {
    // Defensive: if onTapDown fires before warmUp() completes, run warmUp
    // first. This is rare in practice (the provider schedules warm-up via
    // unawaited microtask at app start, and onTapDown happens after first
    // user interaction) but the safety net costs nothing.
    if (!_warmedUp) {
      debugPrint(
        '[AudioEngine] play() called before warmUp completed; warming up now.',
      );
      await warmUp();
    }

    // 1. Cancel any in-flight playback (D-04, STAFIR-04, STAFIR-05).
    final previousPlayer = _activePlayer;
    _activePlayer = null;
    _activeKey = null;
    if (previousPlayer != null) {
      try {
        await previousPlayer.stop();
      } catch (e) {
        // Cancellation should never throw; if it does, log + continue so
        // the new tap still dispatches.
        debugPrint('[AudioEngine] cancel-on-retap stop() failed: $e');
      }
    }

    // 2. Resolve clips against the active manifest + pairing table.
    final resolved = resolveLetterToClips(
      key,
      manifestOverride: _manifestOverride,
      pairingOverride: _pairingOverride,
    );
    final nameAsset = _manifest[resolved.nameKey];
    if (nameAsset == null) {
      // Phase 2 stub fallback: letter has no audio yet. LetterTile already
      // animated synchronously on tap-down; we just stay silent. Log so
      // it's visible during development.
      debugPrint(
        '[AudioEngine] no clip for ${key.name} '
        '(Phase 2 stub manifest fallback). Visual feedback only.',
      );
      return;
    }

    // 3. Acquire next pool player + dispatch.
    final player = _acquirePlayer();
    _activePlayer = player;
    _activeKey = key;

    final wordAsset = resolved.wordKey != null
        ? _manifest[resolved.wordKey]
        : null;
    try {
      if (wordAsset == null) {
        // Single clip — just setAsset.
        final reportedDuration = await player.setAsset(nameAsset.path);
        if (reportedDuration != null) {
          warnIfMissingPad(resolved.nameKey, reportedDuration);
        }
      } else {
        // letter name + example word as a setAudioSources playlist for
        // gapless playback (D-05). Replaces the deprecated
        // `ConcatenatingAudioSource` path; just_audio 0.10.x natively
        // handles the playlist via setAudioSources.
        await player.setAudioSources(<Object>[
          ja.AudioSource.asset(nameAsset.path),
          ja.AudioSource.asset(wordAsset.path),
        ]);
      }
      // Fire-and-forget. play() returns; audio plays asynchronously.
      // The unawaited future is intentional — the visual feedback already
      // fired in onTapDown (LetterTile, Plan 04-03), and the cancel path
      // for the next tap will handle the in-flight player via
      // _activePlayer.stop().
      unawaited(player.play());
    } catch (e) {
      debugPrint('[AudioEngine] play(${key.name}) error: $e');
      _activePlayer = null;
      _activeKey = null;
    }
  }

  /// Stops any in-flight playback. No-op if nothing is playing.
  Future<void> stop() async {
    final p = _activePlayer;
    _activePlayer = null;
    _activeKey = null;
    if (p == null) return;
    try {
      await p.stop();
    } catch (e) {
      debugPrint('[AudioEngine] stop() failed: $e');
    }
  }

  /// Phase 3 silence-pad health check (D-08).
  ///
  /// Logs a debug warning when [reportedDuration] is short enough that the
  /// clip plausibly lacks the 20–50 ms leading silence that masks Android's
  /// first-play head-clipping. Does NOT throw — the clip still plays; the
  /// warning is for developer attention during the Phase 3 review pass.
  void warnIfMissingPad(UtteranceKey key, Duration reportedDuration) {
    if (reportedDuration.inMilliseconds < 20) {
      debugPrint(
        '[AudioEngine] WARNING: clip ${key.name} reported '
        '${reportedDuration.inMilliseconds}ms — silence pad may be missing.',
      );
    }
  }
}

/// Production [AudioPlayerLike] backed by `package:just_audio`'s [ja.AudioPlayer].
///
/// Lives in this file so the production audio surface and the
/// engine-internal pool are in one place. Tests construct AudioEngine with
/// a different factory and never touch this class.
class RealAudioPlayer implements AudioPlayerLike {
  RealAudioPlayer() : _player = ja.AudioPlayer();

  final ja.AudioPlayer _player;

  @override
  Future<Duration?> setAsset(String path) => _player.setAsset(path);

  @override
  Future<void> setAudioSource(Object source) =>
      _player.setAudioSource(source as ja.AudioSource);

  @override
  Future<void> setAudioSources(List<Object> sources) =>
      _player.setAudioSources(sources.cast<ja.AudioSource>());

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Stream<dynamic> get playerStateStream => _player.playerStateStream;
}
