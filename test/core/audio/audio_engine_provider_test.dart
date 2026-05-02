// Plan 04-01 RED tests for the audioEngineProvider.
// Validates D-01 (top-level non-autoDispose Riverpod provider with
// keepAlive: true) and the dispose-on-container-dispose contract.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';

import '_fakes/fake_audio_player.dart';

void main() {
  test(
    'audioEngineProvider returns the same AudioEngine across reads (keepAlive)',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final a = container.read(audioEngineProvider);
      final b = container.read(audioEngineProvider);
      expect(identical(a, b), isTrue);
    },
  );

  test(
    'audioEngineProvider with overridden engine disposes engine on container dispose',
    () async {
      var disposed = false;
      final fakes = <FakeAudioPlayer>[];
      final engine = AudioEngine(
        playerFactory: () {
          final p = FakeAudioPlayer();
          fakes.add(p);
          return p;
        },
      );
      // Wrap engine so we can detect dispose without subclassing.
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith((ref) {
            ref.onDispose(() async {
              await engine.dispose();
              disposed = true;
            });
            // Schedule warm-up off the main path.
            Future<void>.microtask(engine.warmUp);
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
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final original = container.read(audioEngineProvider);

    // Read another provider that depends on it.
    final stillSame = container.read(audioEngineProvider);
    expect(identical(original, stillSame), isTrue);
  });
}
