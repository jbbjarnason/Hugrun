// Pure-Dart contract for what AudioEngine needs from an AudioPlayer.
//
// Phase 4 D-26: unit tests must NOT depend on `package:just_audio`'s native
// channels (those require integration_test). The AudioEngine accepts any
// implementation of [AudioPlayerLike] via its `playerFactory` constructor
// parameter; the production implementation wraps `package:just_audio`'s
// `AudioPlayer` (see [RealAudioPlayer] in `audio_engine.dart`), and tests
// inject a [FakeAudioPlayer] that records every call.
//
// The interface is intentionally minimal — only the methods Phase 4 plans
// 01-02 use. Adding a method requires extending FakeAudioPlayer in lockstep.

/// Test-injectable surface for an audio player.
abstract class AudioPlayerLike {
  /// Sets the player's source from an asset path. Returns the loaded clip's
  /// duration when known. May complete with `null` if metadata is absent.
  Future<Duration?> setAsset(String path);

  /// Sets the player's source from an arbitrary AudioSource (e.g.
  /// `ConcatenatingAudioSource`). Typed `Object` here so this interface can
  /// stay free of `package:just_audio` types — Plan 02 wires the real
  /// `ja.AudioSource` through.
  Future<void> setAudioSource(Object source);

  /// Sets a playlist of audio sources for gapless playback (D-05). Each
  /// element is treated by the production [RealAudioPlayer] as a
  /// `ja.AudioSource`. Typed as `List<Object>` to keep this interface free
  /// of `package:just_audio` types.
  ///
  /// Replaces the deprecated `ConcatenatingAudioSource` path; just_audio
  /// 0.10.x ships a built-in `setAudioSources(List<AudioSource>)` that
  /// handles the playlist internally.
  Future<void> setAudioSources(List<Object> sources);

  /// Begins playback (fire-and-forget — caller does NOT await completion).
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback and resets position. Used by AudioEngine for the
  /// cancel-on-retap / cancel-on-other-tap behavior (D-04).
  Future<void> stop();

  /// Disposes platform resources. Called from AudioEngine.dispose().
  Future<void> dispose();

  /// Player state stream — Plan 02 may listen to detect playback completion.
  /// Typed `dynamic` so the interface stays just_audio-agnostic.
  Stream<dynamic> get playerStateStream;
}
