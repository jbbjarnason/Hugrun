// Phase 9 Plan 09-01 Workstream A — RED tests for CorrespondenceActivity
// widget (NUM-04).
//
// Decisions exercised:
//   D-01  Activity renders N copies of the noun image as tappable targets.
//   D-02  Picture-object counting uses GENDER of the depicted noun.
//   D-04  Tapping each in sequence fires correct numeral audio in counting
//         order; last narrated number equals count.
//   D-05  Re-tapping a counted target is a no-op.
//   D-13  Round complete = celebration + auto-advance (mirrors Phase 5).
//   NUM-08  No fail state — wrong actions silent.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/core/numbers/correspondence_round.dart';
import 'package:hugrun/core/numbers/gender.dart';
import 'package:hugrun/core/numbers/numbers.dart';
import 'package:hugrun/features/stafir/matching/matching_celebration.dart';
import 'package:hugrun/features/tolur/correspondence/correspondence_activity.dart';
import 'package:hugrun/features/tolur/correspondence/correspondence_providers.dart';

import '../../../../integration_test/test_helpers/fake_audio_engine.dart';

class _StubGenerator implements CorrespondenceRoundGenerator {
  _StubGenerator(this.queue);
  final List<CorrespondenceRound> queue;
  int _idx = 0;

  @override
  CorrespondenceRound generate() {
    final r = queue[_idx % queue.length];
    _idx++;
    return r;
  }
}

ProviderScope _wrap({
  required FakeAudioEngine engine,
  required CorrespondenceRoundGenerator generator,
}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine),
      correspondenceRoundGeneratorProvider.overrideWith((ref) => generator),
    ],
    child: const MaterialApp(home: Scaffold(body: CorrespondenceActivity())),
  );
}

CorrespondenceRound _round({
  required int count,
  Gender gender = Gender.masculine,
  String word = 'hundur',
}) {
  return CorrespondenceRound(
    count: kIcelandicNumbers[count - 1],
    noun: Noun(
      word: word,
      gender: gender,
      imagePath: 'assets/images/letters/words/$word.webp',
    ),
  );
}

void main() {
  testWidgets('CR1: renders exactly N tap targets when count is 3', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    // Each tap target gets a stable key 'corr-target-<i>'.
    expect(find.byKey(const Key('corr-target-0')), findsOneWidget);
    expect(find.byKey(const Key('corr-target-1')), findsOneWidget);
    expect(find.byKey(const Key('corr-target-2')), findsOneWidget);
    expect(find.byKey(const Key('corr-target-3')), findsNothing);
  });

  testWidgets('CR2: tapping target i fires numeral audio in counting order '
      '(masculine noun)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3, gender: Gender.masculine)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('corr-target-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('corr-target-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('corr-target-2')));
    await tester.pump();

    // Counting order: 1, 2, 3 — masculine variants since noun is masculine.
    expect(engine.playCalls, <UtteranceKey>[
      UtteranceKey.numberOneMasc,
      UtteranceKey.numberTwoMasc,
      UtteranceKey.numberThreeMasc,
    ]);
  });

  testWidgets(
    'CR3: feminine noun → numeral audio uses feminine variants for 1..4',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final engine = FakeAudioEngine();
      final gen = _StubGenerator([
        _round(count: 2, gender: Gender.feminine, word: 'kyr'),
      ]);
      await tester.pumpWidget(_wrap(engine: engine, generator: gen));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('corr-target-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('corr-target-1')));
      await tester.pump();

      expect(engine.playCalls, <UtteranceKey>[
        UtteranceKey.numberOneFem,
        UtteranceKey.numberTwoFem,
      ]);
    },
  );

  testWidgets('CR4: re-tapping a counted target is a no-op (D-05)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('corr-target-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('corr-target-0'))); // again
    await tester.pump();

    // Only one audio call — second tap on the same target was a no-op.
    expect(engine.playCalls, <UtteranceKey>[UtteranceKey.numberOneMasc]);
  });

  testWidgets('CR5: completing all targets shows celebration (D-13)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 2), _round(count: 3)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('corr-target-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('corr-target-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
      reason: 'completion should show celebration overlay',
    );
  });

  testWidgets('CR6: NUM-08 — no failure-state UI (no error/cancel icons)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 3)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('CR7: auto-advance after celebration', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(count: 1), _round(count: 2)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('corr-target-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
    );

    await tester.pump(MatchingCelebration.duration);
    await tester.pump();
    expect(find.byKey(const Key('matching-celebration-active')), findsNothing);
    // Round 2 has 2 targets.
    expect(find.byKey(const Key('corr-target-1')), findsOneWidget);
  });
}
