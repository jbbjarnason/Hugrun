// Plan 04-06 RED tests for WelcomeNarrationController.
// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/home/welcome_narration_controller.dart';

import '../../core/audio/_fakes/fake_audio_player.dart';

class _RecEngine extends AudioEngine {
  _RecEngine() : super(playerFactory: FakeAudioPlayer.new);
  final List<UtteranceKey> playCalls = <UtteranceKey>[];
  bool throwOnPlay = false;

  @override
  Future<void> warmUp() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> play(UtteranceKey key) async {
    if (throwOnPlay) throw StateError('boom');
    playCalls.add(key);
  }

  @override
  Future<void> stop() async {}
}

ProviderContainer _makeContainer({
  required AppDatabase db,
  required _RecEngine engine,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      audioEngineProvider.overrideWith((ref) => engine),
    ],
  );
}

void main() {
  test(
    'maybeFireOnce with name "Hugrún" calls audioEngine.play(narrationWelcome)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ensureDefaultChildProfile(db);

      final engine = _RecEngine();
      final container = _makeContainer(db: db, engine: engine);
      addTearDown(container.dispose);

      // Read controller; let stream provider settle.
      final ctl = container.read(welcomeNarrationControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await ctl.maybeFireOnce();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.playCalls, contains(UtteranceKey.narrationWelcome));
    },
  );

  test(
    'maybeFireOnce called twice fires only once (D-19)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ensureDefaultChildProfile(db);

      final engine = _RecEngine();
      final container = _makeContainer(db: db, engine: engine);
      addTearDown(container.dispose);

      final ctl = container.read(welcomeNarrationControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await ctl.maybeFireOnce();
      await ctl.maybeFireOnce();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.playCalls.length, 1);
    },
  );

  test(
    'name change after first fire does NOT trigger second fire (D-21)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ensureDefaultChildProfile(db);

      final engine = _RecEngine();
      final container = _makeContainer(db: db, engine: engine);
      addTearDown(container.dispose);

      final ctl = container.read(welcomeNarrationControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await ctl.maybeFireOnce();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Now change the name.
      await db.childProfilesDao.upsertName(name: 'Anna');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await ctl.maybeFireOnce();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.playCalls.length, 1);
    },
  );

  test('maybeFireOnce when AudioEngine.play throws does not propagate', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    final engine = _RecEngine()..throwOnPlay = true;
    final container = _makeContainer(db: db, engine: engine);
    addTearDown(container.dispose);

    final ctl = container.read(welcomeNarrationControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Should NOT throw.
    await ctl.maybeFireOnce();
    // No assertion needed — absence of exception IS the assertion.
  });
}
