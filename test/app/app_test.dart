// ignore_for_file: scoped_providers_should_specify_dependencies
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

import '../core/audio/_fakes/fake_audio_player.dart';

class _NoopEngine extends AudioEngine {
  _NoopEngine() : super(playerFactory: FakeAudioPlayer.new);
  @override
  Future<void> warmUp() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> play(UtteranceKey key) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('HugrunApp uses Icelandic locale', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioEngineProvider.overrideWith((ref) => _NoopEngine()),
        ],
        child: const HugrunApp(),
      ),
    );
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('is'));
    // Tear down inside fake-async window.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
