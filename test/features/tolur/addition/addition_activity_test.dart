// Phase 9 Plan 09-03 Workstream C — RED tests for AdditionActivity widget
// (NUM-07).
//
// Decisions exercised:
//   D-10  Round narrates addition; renders objects in two groups, asks for
//         the total; child taps answer numeral.
//   D-12  NO `+` symbol anywhere in the widget tree. Critical invariant —
//         tested explicitly via find.text.
//   D-13  Wrong tap = silent. Correct tap = celebration.
//   NUM-08  No fail state.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/numbers/addition_round.dart';
import 'package:hugrun/core/numbers/correspondence_round.dart';
import 'package:hugrun/core/numbers/gender.dart';
import 'package:hugrun/core/numbers/numbers.dart';
import 'package:hugrun/features/stafir/matching/matching_celebration.dart';
import 'package:hugrun/features/tolur/addition/addition_activity.dart';
import 'package:hugrun/features/tolur/addition/addition_providers.dart';

import '../../../../integration_test/test_helpers/fake_audio_engine.dart';

class _StubGenerator implements AdditionRoundGenerator {
  _StubGenerator(this.queue);
  final List<AdditionRound> queue;
  int _idx = 0;

  @override
  AdditionRound generate() {
    final r = queue[_idx % queue.length];
    _idx++;
    return r;
  }
}

ProviderScope _wrap({
  required FakeAudioEngine engine,
  required AdditionRoundGenerator generator,
}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine),
      additionRoundGeneratorProvider.overrideWith((ref) => generator),
    ],
    child: const MaterialApp(
      home: Scaffold(body: AdditionActivity()),
    ),
  );
}

AdditionRound _round({int a1 = 2, int a2 = 1, String word = 'hundur'}) {
  return AdditionRound(
    addend1: kIcelandicNumbers[a1 - 1],
    addend2: kIcelandicNumbers[a2 - 1],
    noun: Noun(
      word: word,
      gender: Gender.masculine,
      imagePath: 'assets/images/letters/words/$word.webp',
    ),
  );
}

void main() {
  testWidgets('AD1: NO `+` symbol anywhere in the widget tree (D-12)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(a1: 2, a2: 1)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    expect(find.text('+'), findsNothing,
        reason: 'D-12: no `+` symbol allowed');
    expect(find.text('plus'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing,
        reason: 'D-12: no add icon allowed');
  });

  testWidgets('AD2: renders addend1 + addend2 noun copies (5 total for 2+3)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(a1: 2, a2: 3)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    // Each addend renders distinct keyed widgets.
    for (var i = 0; i < 2; i++) {
      expect(find.byKey(Key('add-group1-$i')), findsOneWidget);
    }
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('add-group2-$i')), findsOneWidget);
    }
  });

  testWidgets('AD3: 5 numeral options (1..5) shown as answer choices',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(a1: 2, a2: 1)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    for (var v = 1; v <= 5; v++) {
      expect(find.byKey(Key('add-option-$v')), findsOneWidget);
    }
  });

  testWidgets('AD4: tapping correct total → celebration', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(a1: 2, a2: 1), _round(a1: 1, a2: 1)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    // 2 + 1 = 3 → tap "3".
    await tester.tap(find.byKey(const Key('add-option-3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
    );
  });

  testWidgets('AD5: D-13 — wrong tap is silent (no celebration)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(a1: 2, a2: 1)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    // 2 + 1 = 3, but tap "5".
    await tester.tap(find.byKey(const Key('add-option-5')));
    await tester.pump();

    expect(engine.playCalls, isEmpty);
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsNothing,
    );
  });

  testWidgets('AD6: NUM-08 — no failure-state UI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([_round(a1: 2, a2: 1)]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('AD7: auto-advance to next round after celebration',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _StubGenerator([
      _round(a1: 1, a2: 1), // 2
      _round(a1: 2, a2: 2), // 4
    ]);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('add-option-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
    );
    await tester.pump(MatchingCelebration.duration);
    await tester.pump();

    // Round 2: 2+2=4. Group keys reflect new addend counts.
    expect(find.byKey(const Key('add-group1-0')), findsOneWidget);
    expect(find.byKey(const Key('add-group1-1')), findsOneWidget);
    expect(find.byKey(const Key('add-group2-0')), findsOneWidget);
    expect(find.byKey(const Key('add-group2-1')), findsOneWidget);
  });
}
