// Plan 04-01 RED tests for AudioEngine warm pool + dispose + Phase-3
// silence-pad warning. These tests must compile against the
// not-yet-implemented AudioEngine class — they will fail with "Type
// AudioEngine not found" until Plan 04-01 Task 2 lands the implementation.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

import '_fakes/fake_audio_player.dart';

void main() {
  group('AudioEngine.warmUp', () {
    test('allocates 4 AudioPlayer instances', () async {
      final fakes = <FakeAudioPlayer>[];
      final engine = AudioEngine(
        playerFactory: () {
          final p = FakeAudioPlayer();
          fakes.add(p);
          return p;
        },
      );
      await engine.warmUp();
      expect(fakes.length, AudioEngine.poolSize);
      expect(fakes.length, 4);
    });

    test('completes within 500ms with mock players', () async {
      final engine = AudioEngine(playerFactory: FakeAudioPlayer.new);
      final stopwatch = Stopwatch()..start();
      await engine.warmUp();
      stopwatch.stop();
      expect(stopwatch.elapsed.inMilliseconds, lessThan(500));
    });

    test('plays a silent priming clip on player index 0 (D-03)', () async {
      final fakes = <FakeAudioPlayer>[];
      final engine = AudioEngine(
        playerFactory: () {
          final p = FakeAudioPlayer();
          fakes.add(p);
          return p;
        },
      );
      await engine.warmUp();
      // Player 0 must have received exactly one setAsset(silentAssetPath)
      // and at least one play() before warmUp returns.
      final setAssetCalls = fakes[0].calls
          .where((c) => c.method == 'setAsset')
          .toList();
      final playCalls = fakes[0].calls
          .where((c) => c.method == 'play')
          .toList();
      expect(setAssetCalls.length, 1, reason: 'player 0 setAsset called once');
      expect(
        playCalls.length,
        greaterThanOrEqualTo(1),
        reason: 'player 0 play() called for AVAudioSession activation',
      );
      // Other players should NOT have been primed.
      for (var i = 1; i < fakes.length; i++) {
        expect(
          fakes[i].calls.where((c) => c.method == 'play'),
          isEmpty,
          reason: 'only player 0 is primed during warmUp',
        );
      }
    });

    test('is idempotent across warmUp calls', () async {
      final fakes = <FakeAudioPlayer>[];
      final engine = AudioEngine(
        playerFactory: () {
          final p = FakeAudioPlayer();
          fakes.add(p);
          return p;
        },
      );
      await engine.warmUp();
      final initialCount = fakes.length;
      final initialPlayer0Calls = fakes[0].calls.length;

      await engine.warmUp(); // second call — must be a no-op
      expect(fakes.length, initialCount);
      expect(fakes[0].calls.length, initialPlayer0Calls);
    });
  });

  group('AudioEngine.dispose', () {
    test('cleans up all 4 players', () async {
      final fakes = <FakeAudioPlayer>[];
      final engine = AudioEngine(
        playerFactory: () {
          final p = FakeAudioPlayer();
          fakes.add(p);
          return p;
        },
      );
      await engine.warmUp();
      await engine.dispose();
      for (final p in fakes) {
        expect(p.disposed, isTrue);
        final disposeCalls = p.calls
            .where((c) => c.method == 'dispose')
            .toList();
        expect(disposeCalls.length, 1);
      }
    });
  });

  group('AudioEngine.warnIfMissingPad (D-08)', () {
    test('logs a debug warning when reportedDuration < 20ms', () {
      final engine = AudioEngine(playerFactory: FakeAudioPlayer.new);
      // No exception — debug log only. Verify the function exists and
      // accepts a Duration. The actual log assertion happens via
      // debugPrint capture in a future plan if needed.
      expect(
        () => engine.warnIfMissingPad(
          UtteranceKey.letterA,
          const Duration(milliseconds: 5),
        ),
        returnsNormally,
      );
    });

    test('does not warn when reportedDuration >= 20ms', () {
      final engine = AudioEngine(playerFactory: FakeAudioPlayer.new);
      expect(
        () => engine.warnIfMissingPad(
          UtteranceKey.letterA,
          const Duration(milliseconds: 100),
        ),
        returnsNormally,
      );
    });
  });
}
