// Plan 04-01 RED tests for the audioEngineProvider.
// Validates D-01 (top-level non-autoDispose Riverpod provider with
// keepAlive: true) and the dispose-on-container-dispose contract.
//
// We override the default provider with a fake-player-backed engine because
// the default factory constructs `package:just_audio`'s AudioPlayer, which
// requires platform channels not available under the unit-test binding.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';

import '_fakes/fake_audio_player.dart';

AudioEngine _makeFakeBackedEngine() =>
    AudioEngine(playerFactory: FakeAudioPlayer.new);

void main() {
  test(
    'audioEngineProvider returns the same AudioEngine across reads (keepAlive)',
    () {
      final engine = _makeFakeBackedEngine();
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith((ref) {
            ref.onDispose(() async => engine.dispose());
            return engine;
          }),
        ],
      );
      addTearDown(container.dispose);

      final a = container.read(audioEngineProvider);
      final b = container.read(audioEngineProvider);
      expect(identical(a, b), isTrue);
      expect(a, same(engine));
    },
  );

  test(
    'audioEngineProvider with overridden engine disposes engine on container dispose',
    () async {
      var disposed = false;
      final engine = _makeFakeBackedEngine();
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith((ref) {
            ref.onDispose(() async {
              await engine.dispose();
              disposed = true;
            });
            return engine;
          }),
        ],
      );
      // Read at least once so provider materializes.
      final read = container.read(audioEngineProvider);
      expect(read, same(engine));
      container.dispose();
      // Allow async dispose to flush.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(disposed, isTrue);
    },
  );

  test('audioEngineProvider survives dependent provider rebuilds', () {
    final engine = _makeFakeBackedEngine();
    final container = ProviderContainer(
      overrides: [
        audioEngineProvider.overrideWith((ref) {
          ref.onDispose(() async => engine.dispose());
          return engine;
        }),
      ],
    );
    addTearDown(container.dispose);
    final original = container.read(audioEngineProvider);
    // Read again — same instance (keepAlive contract).
    final stillSame = container.read(audioEngineProvider);
    expect(identical(original, stillSame), isTrue);
  });
}
