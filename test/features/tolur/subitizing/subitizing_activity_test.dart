// Phase 9 Plan 09-02 Workstream B — RED tests for SubitizingActivity
// widget (NUM-05).
//
// Decisions exercised:
//   D-06  Round flashes dots, then asks for matching numeral.
//   D-08  Flash 1.5s default — after that, 5 numeral options shown.
//   D-09  Wrong tap = no-op (silent — same posture as Phase 5 D-07).
//         Correct tap = celebration (mirrors Phase 5/8).
//   NUM-08  No fail state.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/numbers/subitizing_round.dart';
import 'package:hugrun/features/stafir/matching/matching_celebration.dart';
import 'package:hugrun/features/tolur/subitizing/subitizing_activity.dart';
import 'package:hugrun/features/tolur/subitizing/subitizing_providers.dart';

import '../../../../integration_test/test_helpers/fake_audio_engine.dart';

class _StubGenerator implements SubitizingRoundGenerator {
  _StubGenerator(this.queue);
  final List<SubitizingRound> queue;
  int _idx = 0;

  @override
  SubitizingRound generate() {
    final r = queue[_idx % queue.length];
    _idx++;
    return r;
  }
}

ProviderScope _wrap({
  required FakeAudioEngine engine,
  required SubitizingRoundGenerator generator,
}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine),
      subitizingRoundGeneratorProvider.overrideWith((ref) => generator),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SubitizingActivity()),
    ),
  );
}

SubitizingRound _round({
  int count = 3,
  DotArrangement arrangement = DotArrangement.dice,
}) {
  return SubitizingRound(
    count: count,
    arrangement: arrangement,
    dotPositions: List<DotPosition>.generate(
      count,
      (i) => DotPosition(x: 0.2 + i * 0.15, y: 0.5),
    ),
  );
}

void main() {
  testWidgets('SU1: during flash phase, 5 numeral options NOT shown',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    // Flash phase active — numeral options 'sub-option-N' not yet present.
    expect(find.byKey(const Key('sub-option-1')), findsNothing);
    expect(find.byKey(const Key('sub-option-3')), findsNothing);

    // Ensure no Timers leak — pump past celebration.
    await tester.pump(kSubitizingFlashDuration);
    await tester.pump();
    // Now options should appear.
    expect(find.byKey(const Key('sub-option-1')), findsOneWidget);
    expect(find.byKey(const Key('sub-option-3')), findsOneWidget);
    expect(find.byKey(const Key('sub-option-5')), findsOneWidget);
  });

  testWidgets('SU2: after flash, 5 numeral options 1..5 are visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump(kSubitizingFlashDuration);
    await tester.pump();

    for (var v = 1; v <= 5; v++) {
      expect(find.byKey(Key('sub-option-$v')), findsOneWidget);
    }
  });

  testWidgets('SU3: tapping correct numeral shows celebration', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3), _round(count: 2)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump(kSubitizingFlashDuration);
    await tester.pump();

    await tester.tap(find.byKey(const Key('sub-option-3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
    );
  });

  testWidgets('SU4: D-09 — wrong tap is silent (no audio, no celebration)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump(kSubitizingFlashDuration);
    await tester.pump();

    // Tap the wrong numeral.
    await tester.tap(find.byKey(const Key('sub-option-1')));
    await tester.pump();
    expect(engine.playCalls, isEmpty);
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsNothing,
    );
  });

  testWidgets('SU5: NUM-08 — no failure-state UI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump(kSubitizingFlashDuration);
    await tester.pump();

    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('SU6: auto-advance after celebration → next round flashes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3), _round(count: 2)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump(kSubitizingFlashDuration);
    await tester.pump();

    await tester.tap(find.byKey(const Key('sub-option-3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
    );
    await tester.pump(MatchingCelebration.duration);
    await tester.pump();
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsNothing,
    );
    // Round 2 — flash phase active again, options absent.
    expect(find.byKey(const Key('sub-option-1')), findsNothing);
    // After flash, options return.
    await tester.pump(kSubitizingFlashDuration);
    await tester.pump();
    expect(find.byKey(const Key('sub-option-1')), findsOneWidget);
  });
}
