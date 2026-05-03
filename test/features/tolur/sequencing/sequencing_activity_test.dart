// Phase 8 Plan 08-03 Workstream C — RED tests for SequencingActivity widget.
//
// Decisions exercised:
//   D-09  SequencingActivity is the new Tölur surface (mode = sequence)
//         rendering 5 draggable numerals.
//   D-12  Drag-and-drop accepts only the correct numeral; wrong drops
//         snap back. NO audio penalty on wrong drops.
//   D-13  Round complete = celebration overlay + auto-advance.
//   D-14  No fail state. No score. No timer.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/numbers/sequencing_round.dart';
import 'package:hugrun/features/stafir/matching/matching_celebration.dart';
import 'package:hugrun/features/tolur/sequencing/sequencing_activity.dart';
import 'package:hugrun/features/tolur/sequencing/sequencing_providers.dart';

import '../../../../integration_test/test_helpers/fake_audio_engine.dart';

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

ProviderScope _wrap({
  required FakeAudioEngine engine,
  required SequencingRoundGenerator generator,
  Widget? child,
}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine),
      sequencingRoundGeneratorProvider.overrideWith((ref) => generator),
    ],
    child: MaterialApp(
      home: Scaffold(body: child ?? const SequencingActivity()),
    ),
  );
}

SequencingRound _sortRound() => SequencingRound(
  targetSequence: const <int>[1, 2, 3, 4, 5],
  // Pre-determined scramble so dragging works deterministically.
  scrambledOrder: const <int>[3, 1, 5, 2, 4],
);

SequencingRound _fillMissingRound() => SequencingRound(
  targetSequence: const <int>[1, 2, 3, 4, 5],
  scrambledOrder: const <int>[1, 2, 4, 5],
  missingPosition: 2, // missing value = 3
);

void main() {
  testWidgets('Q1: SequencingActivity renders 5 numerals (Sort variant)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_sortRound()]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    // Each numeral 1..5 should be visible (in either source or target slots).
    for (var v = 1; v <= 5; v++) {
      expect(
        find.text('$v'),
        findsAtLeastNWidgets(1),
        reason: 'numeral $v should render',
      );
    }
  });

  testWidgets('Q2: FillMissing variant renders 4 candidates + 1 empty slot', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_fillMissingRound()]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    // The missing value (3) is in the candidate row; targets 1, 2, 4, 5
    // appear in the target row already filled. So '3' appears once
    // (candidate) and 1,2,4,5 appear once each (target slot).
    expect(find.text('3'), findsAtLeastNWidgets(1));
    expect(find.text('1'), findsAtLeastNWidgets(1));
    expect(find.text('5'), findsAtLeastNWidgets(1));
  });

  testWidgets('Q3: round-complete invariant — when all targets are filled '
      'correctly, celebration appears', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_sortRound(), _sortRound()]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();
    // Drive completion via the public test hook (debug-only escape hatch
    // — drag-and-drop is exercised in the integration test, where a real
    // gesture stream is reliable; widget-test gestures across DragTarget
    // are flaky enough that the activity exposes a debugCompleteRound for
    // unit-level assertions).
    final state = tester.state<SequencingActivityState>(
      find.byType(SequencingActivity),
    );
    state.debugCompleteRound();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
      reason: 'completion should show celebration overlay',
    );
  });

  testWidgets('Q4: NO audio plays when round starts (no auto-narration)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_sortRound()]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();
    expect(engine.playCalls, isEmpty);
  });

  testWidgets(
    'Q5: D-12 — wrong drops do NOT trigger audio (silent snap-back)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final engine = FakeAudioEngine();
      final gen = _StubGenerator([_sortRound()]);
      await tester.pumpWidget(_wrap(engine: engine, generator: gen));
      await tester.pump();
      await tester.pump();
      // Use the same test hook to drive a wrong drop — the activity's
      // public API exposes debugRejectDrop so the widget-test can assert
      // the silent invariant without a flaky DragTarget gesture.
      final state = tester.state<SequencingActivityState>(
        find.byType(SequencingActivity),
      );
      state.debugRejectDrop();
      await tester.pump();
      expect(
        engine.playCalls,
        isEmpty,
        reason: 'D-12: wrong drops MUST NOT fire audio',
      );
      expect(
        engine.stopCallCount,
        0,
        reason: 'D-12: wrong drops MUST NOT call stop()',
      );
    },
  );

  testWidgets(
    'Q6: NUM-08 — no fail-state UI (no error/cancel icons; no score)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final engine = FakeAudioEngine();
      final gen = _StubGenerator([_sortRound()]);
      await tester.pumpWidget(_wrap(engine: engine, generator: gen));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    },
  );

  testWidgets('Q7: round auto-advances after celebration duration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_sortRound(), _sortRound()]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();
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
    // Pump past celebration → new round, celebration gone.
    await tester.pump(MatchingCelebration.duration);
    await tester.pump();
    expect(find.byKey(const Key('matching-celebration-active')), findsNothing);
  });
}
