// AudioEngine — the heart of the Phase 4 MVP audio loop.
//
// Decisions exercised in this file (all from .planning/phases/04-stafir-tap-to-hear-mvp/04-CONTEXT.md):
//   D-01  Top-level non-autoDispose Riverpod provider owns this engine
//         (see lib/core/audio/audio_engine_provider.dart). Never lives in a
//         widget build, never autoDispose, never per-tap.
//   D-02  Warm pool of 4 AudioPlayer instances allocated at app start.
//   D-03  Warm-up sequence: (1) allocate, (2) activate iOS AVAudioSession by
//         playing a silent priming clip on player 0, (3) ready for play().
//   D-08  Cold-start head-clipping: clips arrive pre-padded with silence by
//         Phase 3. AudioEngine logs (does NOT throw) when a clip's
//         reportedDuration is too small to plausibly contain a silence pad.
//   STAFIR-09  warm pool of >= 2 AudioPlayer instances at app start.
//
// Plan 04-02 fills in `play()` and `stop()`; this file ships those as
// `UnimplementedError` stubs so Plan 04-01 can land independently.

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../manifest/utterance_key.dart';
import 'audio_player_like.dart';

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
  AudioEngine({AudioPlayerLike Function()? playerFactory})
    : _playerFactory = playerFactory ?? RealAudioPlayer.new;

  final AudioPlayerLike Function() _playerFactory;
  final List<AudioPlayerLike> _pool = <AudioPlayerLike>[];

  bool _warmedUp = false;

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
  Future<void> warmUp() async {
    if (_warmedUp) return;

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
  /// Plan 04-02 uses this internally; exposed via `@visibleForTesting`
  /// so tests in Plan 04-02 can inspect rotation behavior.
  @visibleForTesting
  AudioPlayerLike acquirePlayerForTesting() => _acquirePlayer();

  int _nextPoolIndex = 0;
  AudioPlayerLike _acquirePlayer() {
    assert(
      _pool.length == poolSize,
      'pool size invariant — must be $poolSize, was ${_pool.length}',
    );
    final p = _pool[_nextPoolIndex];
    _nextPoolIndex = (_nextPoolIndex + 1) % poolSize;
    return p;
  }

  /// Releases all players. Called from the Riverpod provider's `onDispose`.
  Future<void> dispose() async {
    for (final p in _pool) {
      await p.dispose();
    }
    _pool.clear();
    _warmedUp = false;
  }

  /// Plays the audio for [key].
  ///
  /// Plan 04-02 fills this in with the full play queue (letter name +
  /// example word, gapless via `ConcatenatingAudioSource`, cancel-on-retap
  /// per D-04 + D-05). Plan 04-01 ships the stub.
  Future<void> play(UtteranceKey key) async {
    throw UnimplementedError('Plan 04-02 implements play queue');
  }

  /// Stops any in-flight playback.
  ///
  /// Plan 04-02 fills this in. Plan 04-01 ships the stub.
  Future<void> stop() async {
    throw UnimplementedError('Plan 04-02 implements stop');
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
