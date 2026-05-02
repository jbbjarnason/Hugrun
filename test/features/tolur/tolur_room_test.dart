// Phase 8 Plan 08-02 Workstream B — RED tests for TolurRoom (tap-to-hear).
//
// Decisions:
//   D-01  10 NumberTiles for digits 1..10 in a grid (2 rows × 5 cols
//         landscape; defensive 5×2 portrait).
//   D-02  Tap any digit → AudioEngine.play(masculine variant for 1..4 /
//         invariant for 5..10) per D-08 (abstract counting, NUM-03).
//   D-03  Synchronous visual feedback (mirrors STAFIR-06).
//
// Phase 1 placeholder tests (AppBar title, pop) preserved — TolurRoom is a
// Scaffold with AppBar in Phase 8 too, so they stay green.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/tolur/sequencing/sequencing_activity.dart';
import 'package:hugrun/features/tolur/tolur_mode.dart';
import 'package:hugrun/features/tolur/tolur_room.dart';
import 'package:hugrun/features/tolur/widgets/number_grid.dart';
import 'package:hugrun/features/tolur/widgets/number_tile.dart';
import 'package:hugrun/features/tolur/widgets/tolur_mode_toggle.dart';

import '../../../integration_test/test_helpers/fake_audio_engine.dart';

ProviderScope _wrap({required FakeAudioEngine engine, Widget? child}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine),
    ],
    child: MaterialApp(home: child ?? const TolurRoom()),
  );
}

void main() {
  // -- Phase 1 baseline (still required) ------------------------------------

  testWidgets('TolurRoom Scaffold has AppBar with title "Tölur"',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title, isA<Text>());
    expect((appBar.title as Text).data, 'Tölur');
  });

  testWidgets('TolurRoom can be popped without crashing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioEngineProvider.overrideWith((ref) => engine)],
        child: MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const TolurRoom()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TolurRoom), findsOneWidget);
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(TolurRoom), findsNothing);
  });

  // -- Phase 8 ---------------------------------------------------------------

  testWidgets('T1: TolurRoom renders exactly 10 NumberTile widgets (NUM-01)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();
    expect(find.byType(NumberTile), findsNWidgets(10));
  });

  testWidgets('T2: digit glyphs 1..10 are all rendered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();
    for (var i = 1; i <= 10; i++) {
      expect(find.text('$i'), findsOneWidget,
          reason: 'digit $i should render once in the grid');
    }
  });

  testWidgets('T3: tapping digit 1 fires numberOneMasc (D-08 — abstract = M)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('number-tile-0-1')));
    await tester.pump();
    expect(engine.playCalls, <UtteranceKey>[UtteranceKey.numberOneMasc]);
  });

  testWidgets('T4: tapping digit 4 fires numberFourMasc (1-4 are gendered)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('number-tile-3-4')));
    await tester.pump();
    expect(engine.playCalls, <UtteranceKey>[UtteranceKey.numberFourMasc]);
  });

  testWidgets('T5: tapping digit 7 fires numberSeven (5..10 invariant)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('number-tile-6-7')));
    await tester.pump();
    expect(engine.playCalls, <UtteranceKey>[UtteranceKey.numberSeven]);
  });

  testWidgets('T6: tapping all 10 in order produces 10 distinct play calls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();

    for (var i = 1; i <= 10; i++) {
      await tester.tap(find.byKey(Key('number-tile-${i - 1}-$i')));
      await tester.pump();
    }
    expect(engine.playCalls, <UtteranceKey>[
      UtteranceKey.numberOneMasc,
      UtteranceKey.numberTwoMasc,
      UtteranceKey.numberThreeMasc,
      UtteranceKey.numberFourMasc,
      UtteranceKey.numberFive,
      UtteranceKey.numberSix,
      UtteranceKey.numberSeven,
      UtteranceKey.numberEight,
      UtteranceKey.numberNine,
      UtteranceKey.numberTen,
    ]);
  });

  testWidgets('TR1: TolurRoom hosts a TolurModeToggle widget', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();
    expect(find.byType(TolurModeToggle), findsOneWidget);
  });

  testWidgets('TR2: TolurRoom defaults to TapToHear mode (NumberGrid visible)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();
    expect(find.byType(NumberGrid), findsOneWidget);
    expect(find.byType(SequencingActivity), findsNothing);
  });

  testWidgets('TR3: setting mode=sequence swaps body to SequencingActivity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();

    final state = tester.state<TolurRoomState>(find.byType(TolurRoom));
    state.debugSetMode(TolurMode.sequence);
    await tester.pump();
    await tester.pump();
    expect(find.byType(NumberGrid), findsNothing);
    expect(find.byType(SequencingActivity), findsOneWidget);
  });

  testWidgets('T7: NUM-08 — no fail UI / no score / no extra digit text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    // Exactly 10 digit-bearing Text widgets — one per tile glyph. Anything
    // more would be a score/streak/timer leak.
    final allDigits = tester.widgetList<Text>(find.byType(Text)).where((t) {
      final s = t.data ?? '';
      return RegExp(r'\d').hasMatch(s);
    }).toList();
    expect(allDigits.length, 10,
        reason: 'expected 10 digit glyphs (1..10); '
            'extra digit-bearing Text would be a score/streak/timer leak');
  });
}
