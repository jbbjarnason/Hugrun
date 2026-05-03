// Plan 05-03 Task 3 — end-to-end integration test for the Phase 5
// Letter-to-Word Matching flow.
//
// Walks through the full child experience under a real platform binding:
//   1. Boot HugrunApp under ProviderScope with FakeAudioEngine + seeded
//      RoundGenerator (manifest = wordHundur only).
//   2. Tap into Stafir from home.
//   3. Tap a letter — letter audio dispatches.
//   4. Hold the StafirModeToggle for 3+s — mode swaps to Match.
//   5. Tap a wrong letter — NO new audio (MATCH-02 silence).
//   6. Tap the correct letter ('h') — wordHundur audio fires + celebration.
//   7. Pump past celebration duration — auto-advance to a new round.
//   8. Hold toggle 3+s — back to Letters mode.
//
// Asserts no exceptions, no Timer leaks.

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
import 'package:hugrun/core/manifest/audio_asset.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/core/matching/photo_override_source.dart';
import 'package:hugrun/core/matching/round_generator.dart';
import 'package:hugrun/features/stafir/matching/matching_activity.dart';
import 'package:hugrun/features/stafir/matching/matching_celebration.dart';
import 'package:hugrun/features/stafir/matching/matching_providers.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/stafir/widgets/letter_grid.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile.dart';
import 'package:hugrun/features/stafir/widgets/stafir_mode_toggle.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers/fake_audio_engine.dart';

const _hundurAsset = AudioAsset(
  path: 'assets/audio/letters/words/hundur.aac',
  approximateDuration: Duration(milliseconds: 300),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Phase 5 — full Stafir Letters → Match → tap silent / correct / advance flow',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ensureDefaultChildProfile(db);

      final engine = FakeAudioEngine();
      final seededGenerator = RoundGenerator(
        seed: 42,
        manifestOverride: const <UtteranceKey, AudioAsset>{
          UtteranceKey.wordHundur: _hundurAsset,
        },
        photoSource: const EmptyPhotoOverrideSource(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            audioEngineProvider.overrideWith((ref) => engine),
            roundGeneratorProvider.overrideWith((ref) => seededGenerator),
            photoOverrideSourceProvider.overrideWith(
              (ref) => const EmptyPhotoOverrideSource(),
            ),
          ],
          child: const HugrunApp(),
        ),
      );
      await tester.pumpAndSettle();

      // -- Step 2: tap into Stafir.
      await tester.tap(find.byKey(const Key('home-room-stafir')));
      await tester.pumpAndSettle();
      expect(find.byType(StafirRoom), findsOneWidget);
      expect(find.byType(LetterGrid), findsOneWidget);
      expect(find.byType(MatchingActivity), findsNothing);

      // -- Step 3: tap a letter that has audio (a → letterA).
      final preCount = engine.playCalls.length;
      await tester.tap(find.byKey(const Key('letter-tile-0-a')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        engine.playCalls.length,
        greaterThan(preCount),
        reason: 'letter audio should dispatch',
      );
      final postLetterCount = engine.playCalls.length;

      // -- Step 4: hold the StafirModeToggle for 3+ seconds.
      final toggleFinder = find.byType(StafirModeToggle);
      expect(toggleFinder, findsOneWidget);
      var gesture = await tester.startGesture(tester.getCenter(toggleFinder));
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(MatchingActivity), findsOneWidget);
      expect(find.byType(LetterGrid), findsNothing);

      // -- Step 5: tap a WRONG letter — must be silent (MATCH-02).
      await tester.pump();
      final tiles = tester
          .widgetList<LetterTile>(find.byType(LetterTile))
          .toList();
      expect(tiles, hasLength(4));
      final wrongTile = tiles.firstWhere((t) => t.letter.glyph != 'h');
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is LetterTile && w.letter == wrongTile.letter,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        engine.playCalls.length,
        postLetterCount,
        reason: 'wrong tap MUST NOT fire new audio (MATCH-02)',
      );

      // -- Step 6: tap CORRECT letter — wordHundur audio + celebration.
      final correctTile = tiles.firstWhere((t) => t.letter.glyph == 'h');
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is LetterTile && w.letter == correctTile.letter,
        ),
      );
      await tester.pump();
      expect(engine.playCalls.last, UtteranceKey.wordHundur);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const Key('matching-celebration-active')),
        findsOneWidget,
      );

      // -- Step 7: pump past celebration → auto-advance.
      await tester.pump(MatchingCelebration.duration);
      await tester.pump();
      expect(
        find.byKey(const Key('matching-celebration-active')),
        findsNothing,
      );
      // 4 LetterTile widgets still present — new round.
      expect(find.byType(LetterTile), findsNWidgets(4));

      // -- Step 8: toggle hold again to return to Letters.
      gesture = await tester.startGesture(tester.getCenter(toggleFinder));
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(LetterGrid), findsOneWidget);
      expect(find.byType(MatchingActivity), findsNothing);

      // No exceptions throughout the flow.
      expect(tester.takeException(), isNull);
    },
  );
}
