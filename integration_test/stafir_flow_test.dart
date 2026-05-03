// Plan 04-07 integration test for the full Stafir tap-to-hear flow.
// Runs under integration_test (real platform binding), exercising:
//   - HomePage launch + welcome narration fires once
//   - Stafir room navigation
//   - 32-letter grid renders
//   - Multiple letter taps dispatch through AudioEngine.play
//   - Cancel-on-retap behavior
//   - Pop back to home does NOT re-fire welcome (D-19 once-per-session)
//
// Uses a FakeAudioEngine + in-memory Drift DB so we don't need device
// audio output to verify dispatch.
//
// Note (D-26): real-platform binding is required for the Drift stream's
// asynchronous emission to fire; the unit-test binding's fake-async
// doesn't surface those reliably.
//
// Note (D-28): tap-to-audio-onset latency is NOT covered here. That's a
// 240fps camera test — see LATENCY-VERIFICATION.md.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers/fake_audio_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 4 MVP smoke — home + welcome + 5 letter taps + return', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    final engine = FakeAudioEngine();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioEngineProvider.overrideWith((ref) => engine),
        ],
        child: const HugrunApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Welcome narration fires once on home mount (D-19).
    expect(engine.playCalls, isNotEmpty, reason: 'welcome narration fires');
    final welcomeCount = engine.playCalls
        .where((k) => k.name.startsWith('narration'))
        .length;
    expect(welcomeCount, 1, reason: 'welcome fires exactly once');

    // 2. Tap Stafir.
    await tester.tap(find.byKey(const Key('home-room-stafir')));
    await tester.pumpAndSettle();
    expect(find.byType(StafirRoom), findsOneWidget);

    // 3. 32 LetterTiles render.
    expect(find.byType(LetterTile), findsNWidgets(32));

    // 4. Tap 5 letters in order — letterA, letterEth, letterThorn (these
    //    have audio in the stub) plus letterH, letterAe (these don't, so
    //    they exercise the graceful-no-op path).
    final lettersToTap = <String>['a', 'eth', 'thorn', 'h', 'ae'];
    final indices = <int>[0, 4, 29, 9, 30];
    for (var i = 0; i < lettersToTap.length; i++) {
      final key = Key('letter-tile-${indices[i]}-${lettersToTap[i]}');
      expect(find.byKey(key), findsOneWidget, reason: 'tile $key exists');
      await tester.tap(find.byKey(key));
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 5. Stub-manifest letters (a, eth, thorn) dispatched. Others (h, ae)
    //    were silent no-ops at the StafirRoom level.
    expect(engine.playCalls, contains(UtteranceKey.letterA));
    expect(engine.playCalls, contains(UtteranceKey.letterEth));
    expect(engine.playCalls, contains(UtteranceKey.letterThorn));

    // 6. No exception was raised.
    expect(tester.takeException(), isNull);

    // 7. Pop back to home; welcome does NOT re-fire (D-19).
    await tester.pageBack();
    await tester.pumpAndSettle();
    final welcomeCountAfterPop = engine.playCalls
        .where((k) => k.name.startsWith('narration'))
        .length;
    expect(
      welcomeCountAfterPop,
      1,
      reason: 'welcome fires only once per session',
    );
  });

  testWidgets('rapid retap on the same letter cancels and re-plays', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    final engine = FakeAudioEngine();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioEngineProvider.overrideWith((ref) => engine),
        ],
        child: const HugrunApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to Stafir.
    await tester.tap(find.byKey(const Key('home-room-stafir')));
    await tester.pumpAndSettle();

    // Tap letter A twice rapidly.
    await tester.tap(find.byKey(const Key('letter-tile-0-a')));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.byKey(const Key('letter-tile-0-a')));
    await tester.pump(const Duration(milliseconds: 100));

    // Both calls dispatched (cancel-on-retap means the engine got two
    // play(letterA) calls — the AudioEngine layer handles the
    // cancellation internally via stop).
    final letterATaps = engine.playCalls
        .where((k) => k == UtteranceKey.letterA)
        .length;
    expect(letterATaps, 2, reason: 'cancel-on-retap dispatches twice');
  });
}
