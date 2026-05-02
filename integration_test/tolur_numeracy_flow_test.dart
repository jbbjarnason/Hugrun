// Phase 9 Plan 09-04 Workstream E — end-to-end integration test for the
// Tölur numeracy flow.
//
// Walks through:
//   1. Boot HugrunApp under ProviderScope (FakeAudioEngine).
//   2. Tap into Tölur from home.
//   3. Drive TolurRoom into Activity mode via debugSetMode.
//   4. ActivityRotator mounts; advance through it 6 times and verify
//      that at least 3 distinct activity types appear (rotation works).
//   5. Hold toggle 3+s — back to TapToHear.
//
// Asserts no exceptions, no Timer leaks. The unit-level rotator test
// exercises the deterministic-seed rotation logic in isolation; this
// integration test confirms it actually composes inside TolurRoom.

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
import 'package:hugrun/features/tolur/activity_rotator.dart';
import 'package:hugrun/features/tolur/tolur_mode.dart';
import 'package:hugrun/features/tolur/tolur_room.dart';
import 'package:hugrun/features/tolur/widgets/number_grid.dart';
import 'package:hugrun/features/tolur/widgets/tolur_mode_toggle.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers/fake_audio_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Phase 9 — Tölur numeracy: tap-to-hear → activity → rotation → return',
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

      // -- Step 3: switch to activity mode via debug hook (3-second hold
      // is exercised in tolur_flow_test; here we focus on the rotation).
      final tolurState =
          tester.state<TolurRoomState>(find.byType(TolurRoom));
      tolurState.debugSetMode(TolurMode.activity);
      await tester.pump();
      await tester.pump();
      expect(find.byType(ActivityRotator), findsOneWidget);
      expect(find.byType(NumberGrid), findsNothing);

      // -- Step 4: rotate ≥6 times and confirm at least 3 distinct
      // activities show up (NUM-04, NUM-05, NUM-07 + Phase 8's NUM-06 are
      // the 4 candidates; rotator picks uniformly).
      final rotatorState = tester.state<ActivityRotatorState>(
        find.byType(ActivityRotator),
      );
      final seen = <TolurActivity>{rotatorState.debugCurrent};
      for (var i = 0; i < 20 && seen.length < 3; i++) {
        rotatorState.debugAdvance();
        // Pump two frames so the new activity has a chance to mount its
        // postFrameCallback round generator.
        await tester.pump();
        await tester.pump();
        seen.add(rotatorState.debugCurrent);
      }
      expect(seen.length, greaterThanOrEqualTo(3),
          reason: 'rotator must reach ≥3 distinct activity types');

      // -- Step 5: toggle back to TapToHear via the toggle widget (3s hold).
      final toggleFinder = find.byType(TolurModeToggle);
      final gesture = await tester.startGesture(
        tester.getCenter(toggleFinder),
      );
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
