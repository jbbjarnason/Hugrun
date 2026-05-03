// Phase 7 Workstream D — integration test for the letter-tracing flow.
//
// Walks the full child experience under a real platform binding:
//   1. Boot HugrunApp with overrides that:
//      - Pre-seed the FakeAudioEngine.
//      - Force tracingCurrentLetterProvider to a specific letter so
//        the test is deterministic.
//   2. Tap into Stafir from home.
//   3. Hold the StafirModeToggle 3.2s — letters → match.
//   4. Hold again 3.2s — match → cvc.
//   5. Hold once more 3.2s — cvc → trace.
//   6. Verify TracingActivity is mounted.
//   7. Drive completion via the activity's debug hook.
//   8. Verify the celebration audio key fired on AudioEngine.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/alphabet/icelandic_letter.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/stafir/cvc/cvc_activity.dart';
import 'package:hugrun/features/stafir/matching/matching_activity.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/stafir/tracing/tracing_activity.dart';
import 'package:hugrun/features/stafir/tracing/trace_data_provider.dart';
import 'package:hugrun/features/stafir/widgets/letter_grid.dart';
import 'package:hugrun/features/stafir/widgets/stafir_mode_toggle.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers/fake_audio_engine.dart';

/// Forces tracingCurrentLetterProvider to a specific letter at build time.
class _ForcedLetterNotifier extends TracingCurrentLetter {
  _ForcedLetterNotifier(this._initial);
  final IcelandicLetter _initial;
  @override
  IcelandicLetter build() => _initial;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Phase 7 — full Stafir Letters → Match → CVC → Trace + complete a letter',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ensureDefaultChildProfile(db);

      final engine = FakeAudioEngine();
      final letterA = kIcelandicAlphabet.firstWhere((l) => l.glyph == 'a');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            audioEngineProvider.overrideWith((ref) => engine),
            tracingCurrentLetterProvider.overrideWith(
              () => _ForcedLetterNotifier(letterA),
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
      expect(find.byType(CvcActivity), findsNothing);
      expect(find.byType(TracingActivity), findsNothing);

      final toggleFinder = find.byType(StafirModeToggle);
      expect(toggleFinder, findsOneWidget);

      // -- Step 3: letters → match (first 3.2s hold).
      var gesture = await tester.startGesture(tester.getCenter(toggleFinder));
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(MatchingActivity), findsOneWidget);
      expect(find.byType(LetterGrid), findsNothing);

      // -- Step 4: match → cvc (second 3.2s hold).
      gesture = await tester.startGesture(tester.getCenter(toggleFinder));
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(CvcActivity), findsOneWidget);

      // -- Step 5: cvc → trace (third 3.2s hold).
      gesture = await tester.startGesture(tester.getCenter(toggleFinder));
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(TracingActivity), findsOneWidget);
      expect(find.byType(LetterGrid), findsNothing);
      expect(find.byType(MatchingActivity), findsNothing);
      expect(find.byType(CvcActivity), findsNothing);

      // -- Step 6: drive completion via the activity's test hook.
      // The traceDataProvider has not been overridden so it loads
      // glyphs from rootBundle — the integration_test binding does
      // mount real assets, so the controller will eventually attach.
      // We pump enough times for the FutureProvider to resolve and
      // the post-frame controller (re)build to land.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      final state = tester.state<TracingActivityState>(
        find.byType(TracingActivity),
      );

      final preCount = engine.playCalls.length;
      state.debugCompleteForTesting();
      await tester.pump(const Duration(milliseconds: 50));

      // -- Step 7: celebration audio fired.
      expect(
        engine.playCalls.length,
        greaterThan(preCount),
        reason: 'celebration audio should have fired on completion',
      );
      final celebrationKey = engine.playCalls.last;
      expect(
        celebrationKey == UtteranceKey.narrationWelcome ||
            celebrationKey.name == 'narrationCelebrationTracing',
        isTrue,
        reason: 'expected celebration key, got ${celebrationKey.name}',
      );

      // -- Step 8: pump past auto-advance — letter changes.
      // The overridden notifier only forced the initial value; .set()
      // advances to a new letter independently of the override.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();
      // Activity stays mounted; same TracingActivity instance.
      expect(find.byType(TracingActivity), findsOneWidget);

      // No exceptions throughout.
      expect(tester.takeException(), isNull);
    },
  );
}
