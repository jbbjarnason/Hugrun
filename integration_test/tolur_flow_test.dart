// Phase 8 Plan 08-04 / Phase 9 Plan 09-04 — end-to-end integration test
// for the Tölur flow.
//
// Walks through the full child experience under a real platform binding:
//   1. Boot HugrunApp under ProviderScope with FakeAudioEngine + a stub
//      sequencing generator (deterministic Sort round 1..5).
//   2. Tap into Tölur from home.
//   3. Tap a digit — masculine audio dispatches.
//   4. Hold the TolurModeToggle for 3+s — mode swaps to Activity (Phase 9
//      D-15: 2-mode shape; Activity renders the ActivityRotator).
//   5. Confirm one of the 4 numeracy activities is mounted under the
//      rotator. Drive a sequence round-complete via the public test hook
//      if Sequencing happens to be the rotated activity; otherwise just
//      assert the rotator is present.
//   6. Hold toggle 3+s — back to TapToHear mode.
//
// Asserts no exceptions, no Timer leaks. Drag-and-drop gestures across
// DragTarget are flaky in widget-test mode; the integration_test
// posture (real binding) lets us assert end-to-end while the unit
// widget tests use the debug escape hatches.

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
import 'package:hugrun/core/numbers/sequencing_round.dart';
import 'package:hugrun/features/stafir/matching/matching_celebration.dart';
import 'package:hugrun/features/tolur/activity_rotator.dart';
import 'package:hugrun/features/tolur/sequencing/sequencing_activity.dart';
import 'package:hugrun/features/tolur/sequencing/sequencing_providers.dart';
import 'package:hugrun/features/tolur/tolur_room.dart';
import 'package:hugrun/features/tolur/widgets/number_grid.dart';
import 'package:hugrun/features/tolur/widgets/tolur_mode_toggle.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers/fake_audio_engine.dart';

class _StubGenerator implements SequencingRoundGenerator {
  _StubGenerator(this.queue);
  final List<SequencingRound> queue;
  int _idx = 0;

  @override
  SequencingRound generate() {
    final r = queue[_idx % queue.length];
    _idx++;
    return r;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Phase 8 — full Tölur tap → mode toggle → sequencing → return flow',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ensureDefaultChildProfile(db);

      final engine = FakeAudioEngine();
      final stubGen = _StubGenerator([
        SequencingRound(
          targetSequence: const <int>[1, 2, 3, 4, 5],
          scrambledOrder: const <int>[3, 1, 5, 2, 4],
        ),
        SequencingRound(
          targetSequence: const <int>[2, 3, 4, 5, 6],
          scrambledOrder: const <int>[5, 3, 6, 2, 4],
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            audioEngineProvider.overrideWith((ref) => engine),
            sequencingRoundGeneratorProvider.overrideWith((ref) => stubGen),
          ],
          child: const HugrunApp(),
        ),
      );
      await tester.pumpAndSettle();

      // -- Step 2: tap into Tölur.
      await tester.tap(find.byKey(const Key('home-room-tolur')));
      await tester.pumpAndSettle();
      expect(find.byType(TolurRoom), findsOneWidget);
      expect(find.byType(NumberGrid), findsOneWidget);
      expect(find.byType(SequencingActivity), findsNothing);

      // -- Step 3: tap digit 3 → numberThreeMasc audio.
      final preCount = engine.playCalls.length;
      await tester.tap(find.byKey(const Key('number-tile-2-3')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.playCalls.length, greaterThan(preCount));
      expect(engine.playCalls.last, UtteranceKey.numberThreeMasc,
          reason: 'abstract counting → masculine variant for 1..4');

      // -- Step 4: hold the TolurModeToggle for 3+ seconds.
      final toggleFinder = find.byType(TolurModeToggle);
      expect(toggleFinder, findsOneWidget);
      var gesture =
          await tester.startGesture(tester.getCenter(toggleFinder));
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pumpAndSettle();
      // Phase 9 D-15: Activity mode renders an ActivityRotator that picks
      // one of 4 numeracy activities at random.
      expect(find.byType(ActivityRotator), findsOneWidget);
      expect(find.byType(NumberGrid), findsNothing);

      // -- Step 5: if the rotator chose Sequencing, exercise its debug hook
      // end-to-end. Otherwise just confirm the rotator is mounted (the
      // dedicated activity_rotator_test exercises the rotation invariants
      // deterministically).
      if (find.byType(SequencingActivity).evaluate().isNotEmpty) {
        final state = tester.state<SequencingActivityState>(
          find.byType(SequencingActivity),
        );
        state.debugCompleteRound();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.byKey(const Key('matching-celebration-active')),
          findsOneWidget,
        );

        // -- Auto-advance.
        await tester.pump(MatchingCelebration.duration);
        await tester.pump();
        expect(
          find.byKey(const Key('matching-celebration-active')),
          findsNothing,
        );
      }

      // -- Step 6: toggle back to TapToHear.
      gesture = await tester.startGesture(tester.getCenter(toggleFinder));
      await tester.pump(const Duration(milliseconds: 3200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(NumberGrid), findsOneWidget);
      expect(find.byType(ActivityRotator), findsNothing);

      // No exceptions throughout the flow.
      expect(tester.takeException(), isNull);
    },
  );
}
