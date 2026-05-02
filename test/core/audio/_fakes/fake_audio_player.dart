// Test-double for [AudioPlayerLike]. Records every method call as a list of
// (method, args) entries so tests can assert on the exact call sequence.
//
// Used by:
//   test/core/audio/audio_engine_test.dart           (Plan 04-01)
//   test/core/audio/audio_engine_play_test.dart      (Plan 04-02)
//   test/core/audio/audio_engine_provider_test.dart  (Plan 04-01)
//
// The fake never touches platform channels — safe to use under
// `flutter_test`'s AutomatedTestWidgetsFlutterBinding.

import 'dart:async';

import 'package:hugrun/core/audio/audio_player_like.dart';

class FakeAudioPlayerCall {
  const FakeAudioPlayerCall(this.method, [this.args = const <Object?>[]]);
  final String method;
  final List<Object?> args;

  @override
  String toString() => '$method(${args.join(', ')})';
}

class FakeAudioPlayer implements AudioPlayerLike {
  FakeAudioPlayer({
    this.reportedDuration = const Duration(milliseconds: 100),
    this.throwOnPlay = false,
  });

  /// Duration reported by [setAsset]. Tests can override to simulate
  /// missing-silence-pad clips (< 20 ms) per D-08.
  final Duration reportedDuration;

  /// If true, [play] throws — used by Plan 06 tests to verify
  /// WelcomeNarrationController's exception swallowing.
  final bool throwOnPlay;

  final List<FakeAudioPlayerCall> calls = <FakeAudioPlayerCall>[];

  final StreamController<dynamic> _stateCtl =
      StreamController<dynamic>.broadcast();

  bool disposed = false;

  @override
  Future<Duration?> setAsset(String path) async {
    calls.add(FakeAudioPlayerCall('setAsset', <Object?>[path]));
    return reportedDuration;
  }

  @override
  Future<void> setAudioSource(Object source) async {
    calls.add(FakeAudioPlayerCall('setAudioSource', <Object?>[source]));
  }

  @override
  Future<void> play() async {
    calls.add(const FakeAudioPlayerCall('play'));
    if (throwOnPlay) {
      throw StateError('FakeAudioPlayer.throwOnPlay');
    }
  }

  @override
  Future<void> pause() async {
    calls.add(const FakeAudioPlayerCall('pause'));
  }

  @override
  Future<void> stop() async {
    calls.add(const FakeAudioPlayerCall('stop'));
  }

  @override
  Future<void> dispose() async {
    calls.add(const FakeAudioPlayerCall('dispose'));
    disposed = true;
    await _stateCtl.close();
  }

  @override
  Stream<dynamic> get playerStateStream => _stateCtl.stream;
}
