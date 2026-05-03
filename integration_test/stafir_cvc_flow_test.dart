// Plan 06-03 Task C.2 — end-to-end integration test for the Phase 6
// CVC blending flow.
//
// Walks the full child experience under a real platform binding:
//   1. Boot HugrunApp under ProviderScope with FakeAudioEngine + a forced
//      cvcCurrentWord = "hús".
//   2. Tap into Stafir from home.
//   3. Hold the StafirModeToggle 3+s — letters → match.
//   4. Hold again 3+s — match → cvc.
//   5. Verify CvcActivity is mounted with 3 LetterTiles.
//   6. Tap each of the 3 letters in some order (here: c2, c1, v).
//   7. Verify the per-tap phoneme keys fire on AudioEngine.
//   8. Verify the blend (wordHus) fires after the third tap.
//   9. Pump past auto-advance — round resets (still under the cvcCurrentWord
//      override so the same word renders again, but tap state is reset).
//
// Asserts no exceptions, no Timer leaks.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/cvc/cvc_word.dart';
import 'package:hugrun/core/cvc/cvc_words.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/stafir/cvc/cvc_activity.dart';
import 'package:hugrun/features/stafir/cvc/cvc_providers.dart';
import 'package:hugrun/features/stafir/matching/matching_activity.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/stafir/widgets/letter_grid.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile.dart';
import 'package:hugrun/features/stafir/widgets/stafir_mode_toggle.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers/fake_audio_engine.dart';

CvcWord _hus() => kCvcWords.firstWhere((w) => w.word == 'hús');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Phase 6 — full Stafir Letters → Match → CVC → tap-each-letter → blend',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ensureDefaultChildProfile(db);

      final engine = FakeAudioEngine();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            audioEngineProvider.overrideWith((ref) => engine),
            // Force the CVC round to "hús" so the test's tap targets are
            // deterministic.
            cvcCurrentWordProvider.overrideWith((ref) => _hus()),
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
      expect(find.byType(CvcActivity), findsNothing);

      final toggleFinder = find.byType(StafirModeToggle);
      expect(toggleFinder, findsOneWidget);

      // -- Step 3: letters → match (first 3.2s hold).
      var gesture = await tester.startGesture(tester.getCenter(toggleFinder));
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(MatchingActivity), findsOneWidget);
      expect(find.byType(LetterGrid), findsNothing);
      expect(find.byType(CvcActivity), findsNothing);

      // -- Step 4: match → cvc (second 3.2s hold).
      gesture = await tester.startGesture(tester.getCenter(toggleFinder));
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(CvcActivity), findsOneWidget);
      expect(find.byType(MatchingActivity), findsNothing);
      expect(find.byType(LetterGrid), findsNothing);

      // -- Step 5: 3 LetterTiles for hús.
      expect(find.byType(LetterTile), findsNWidgets(3));

      // -- Step 6 + 7: tap c2 ("s") first, then c1 ("h"), then v ("ú").
      final preCount = engine.playCalls.length;

      await tester.tap(find.byKey(const Key('cvc-tile-2-s')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.playCalls.last, UtteranceKey.phonemeS);

      await tester.tap(find.byKey(const Key('cvc-tile-0-h')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.playCalls.last, UtteranceKey.phonemeH);

      // Blend should NOT have fired yet — only 2/3 tapped.
      expect(engine.playCalls.contains(UtteranceKey.wordHus), isFalse);

      await tester.tap(find.byKey(const Key('cvc-tile-1-u_acute')));
      await tester.pump(const Duration(milliseconds: 100));

      // -- Step 8: blend fires.
      expect(
        engine.playCalls.last,
        UtteranceKey.wordHus,
        reason: 'blend should fire as the LAST call after the third tap',
      );

      // The full call sequence between steps 6 and 8: phonemeS, phonemeH,
      // phonemeUAcute, wordHus — 4 entries.
      expect(
        engine.playCalls.length - preCount,
        4,
        reason: 'expected 3 phonemes + 1 blend = 4 new play calls',
      );

      // -- Step 9: pump past auto-advance (~2s) — tile state resets.
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump();
      // The forced cvcCurrentWord override means we still see "hús"; but
      // the activity's internal _tappedPositions was cleared, so re-tapping
      // c2 produces a phoneme without an immediate blend follow-up.
      final blendCount1 = engine.playCalls
          .where((k) => k == UtteranceKey.wordHus)
          .length;
      await tester.tap(find.byKey(const Key('cvc-tile-2-s')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.playCalls.last, UtteranceKey.phonemeS);
      final blendCount2 = engine.playCalls
          .where((k) => k == UtteranceKey.wordHus)
          .length;
      expect(
        blendCount2,
        blendCount1,
        reason:
            'blend should NOT re-fire after auto-advance reset (only '
            '1 of 3 tapped post-reset)',
      );

      // No exceptions throughout.
      expect(tester.takeException(), isNull);
    },
  );
}
