// Phase 9 Plan 09-04 Workstream D — RED tests for ActivityRotator
// (numeracy activity rotation in Tölur Activity mode).
//
// Decisions exercised:
//   D-15  Tölur has 2 modes: TapToHear and Activity. Activity mode rotates
//         between Sequence, Correspondence, Subitizing, Addition each round.
//   D-16  Random selection between the 4 activity widgets — over many
//         iterations all 4 should appear.
//
// The rotator wraps the 4 activity widgets and switches to a randomly
// selected one whenever its public `debugAdvance()` is called (or on
// post-frame setup). Tests use a deterministic seed.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/features/tolur/activity_rotator.dart';
import 'package:hugrun/features/tolur/addition/addition_activity.dart';
import 'package:hugrun/features/tolur/correspondence/correspondence_activity.dart';
import 'package:hugrun/features/tolur/sequencing/sequencing_activity.dart';
import 'package:hugrun/features/tolur/subitizing/subitizing_activity.dart';

import '../../../integration_test/test_helpers/fake_audio_engine.dart';

ProviderScope _wrap({required FakeAudioEngine engine, required Widget child}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('AR1: ActivityRotator renders one of the 4 numeracy activities',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(
      engine: engine,
      child: const ActivityRotator(seed: 0),
    ));
    await tester.pump();
    await tester.pump();

    final hasOne = (find.byType(SequencingActivity).evaluate().length +
            find.byType(CorrespondenceActivity).evaluate().length +
            find.byType(SubitizingActivity).evaluate().length +
            find.byType(AdditionActivity).evaluate().length) ==
        1;
    expect(hasOne, isTrue,
        reason: 'exactly one of the 4 activities must be rendered');
  });

  testWidgets('AR2: across many seeds, all 4 activities appear (D-15, D-16)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final seenSequencing = <int>{};
    final seenCorrespondence = <int>{};
    final seenSubitizing = <int>{};
    final seenAddition = <int>{};

    for (var seed = 0; seed < 40; seed++) {
      final engine = FakeAudioEngine();
      await tester.pumpWidget(_wrap(
        engine: engine,
        child: ActivityRotator(seed: seed),
      ));
      await tester.pump();
      await tester.pump();
      if (find.byType(SequencingActivity).evaluate().isNotEmpty) {
        seenSequencing.add(seed);
      }
      if (find.byType(CorrespondenceActivity).evaluate().isNotEmpty) {
        seenCorrespondence.add(seed);
      }
      if (find.byType(SubitizingActivity).evaluate().isNotEmpty) {
        seenSubitizing.add(seed);
      }
      if (find.byType(AdditionActivity).evaluate().isNotEmpty) {
        seenAddition.add(seed);
      }
    }

    expect(seenSequencing, isNotEmpty,
        reason: 'Sequencing activity should appear in some seeds');
    expect(seenCorrespondence, isNotEmpty,
        reason: 'Correspondence activity should appear in some seeds');
    expect(seenSubitizing, isNotEmpty,
        reason: 'Subitizing activity should appear in some seeds');
    expect(seenAddition, isNotEmpty,
        reason: 'Addition activity should appear in some seeds');
  });

  testWidgets('AR3: debugAdvance() can switch to a different activity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(
      engine: engine,
      child: const ActivityRotator(seed: 1),
    ));
    await tester.pump();
    await tester.pump();
    final state = tester.state<ActivityRotatorState>(
      find.byType(ActivityRotator),
    );
    final initial = state.debugCurrent;

    // Advance until we land on a different activity (deterministic w/ seed —
    // worst case all 4 distinct activities take 4 advances).
    var attempts = 0;
    while (state.debugCurrent == initial && attempts < 10) {
      state.debugAdvance();
      await tester.pump();
      attempts++;
    }
    expect(state.debugCurrent, isNot(initial),
        reason: 'rotator should be able to land on a different activity');
  });
}
