// Plan 04-06 tests for WelcomeNarrationController.
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
import 'package:hugrun/features/parent_settings/child_name_provider.dart';

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

/// Eagerly subscribes to [childNameProvider] so its stream emits before
/// the controller awaits `childNameProvider.future`. Without this, the
/// stream provider gets disposed in loading state because the only
/// listener (the controller's await) is sync-disposed when
/// container.dispose runs.
Future<void> _primeChildName(ProviderContainer container) async {
  final emissions = <String?>[];
  final sub = container.listen<AsyncValue<String?>>(
    childNameProvider,
    (prev, next) {
      if (next is AsyncData<String?>) emissions.add(next.value);
    },
    fireImmediately: true,
  );
  // Wait for at least one emission.
  for (var i = 0; i < 20 && emissions.isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  sub.close();
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

      await _primeChildName(container);

      final ctl = container.read(welcomeNarrationControllerProvider.notifier);
      await ctl.maybeFireOnce();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.playCalls, contains(UtteranceKey.narrationWelcome));
    },
  );

  test('maybeFireOnce called twice fires only once (D-19)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    final engine = _RecEngine();
    final container = _makeContainer(db: db, engine: engine);
    addTearDown(container.dispose);

    await _primeChildName(container);

    final ctl = container.read(welcomeNarrationControllerProvider.notifier);
    await ctl.maybeFireOnce();
    await ctl.maybeFireOnce();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.playCalls.length, 1);
  });

  test(
    'name change after first fire does NOT trigger second fire (D-21)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ensureDefaultChildProfile(db);

      final engine = _RecEngine();
      final container = _makeContainer(db: db, engine: engine);
      addTearDown(container.dispose);

      await _primeChildName(container);

      final ctl = container.read(welcomeNarrationControllerProvider.notifier);
      await ctl.maybeFireOnce();
      await Future<void>.delayed(const Duration(milliseconds: 50));
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

    await _primeChildName(container);

    final ctl = container.read(welcomeNarrationControllerProvider.notifier);
    await ctl.maybeFireOnce();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Absence of exception IS the assertion.
  });
}
