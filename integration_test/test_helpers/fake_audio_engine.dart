// Reusable test-double for AudioEngine. Records every play()/stop()
// call so integration_test scenarios can assert on the expected
// dispatch sequence.
//
// No actual audio playback — extends the real AudioEngine and overrides
// the four methods Phase 4 calls. Lifecycle methods (warmUp, dispose)
// are no-ops to avoid platform-channel reach-through.

import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

import '../../test/core/audio/_fakes/fake_audio_player.dart';

class FakeAudioEngine extends AudioEngine {
  FakeAudioEngine() : super(playerFactory: FakeAudioPlayer.new);

  /// All play(key) calls in order.
  final List<UtteranceKey> playCalls = <UtteranceKey>[];

  /// All stop() invocations.
  int stopCallCount = 0;

  @override
  Future<void> warmUp() async {
    /* no-op for tests */
  }

  @override
  Future<void> dispose() async {
    /* no-op */
  }

  @override
  Future<void> play(UtteranceKey key) async {
    playCalls.add(key);
  }

  @override
  Future<void> stop() async {
    stopCallCount += 1;
  }
}
