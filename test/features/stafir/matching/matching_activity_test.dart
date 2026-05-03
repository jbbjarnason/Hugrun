// Plan 05-02 Task 3 tests: MatchingActivity widget — the heart of Phase 5.
//
// Critical tests:
//   - A4: WRONG TAP IS SILENT (MATCH-02 invariant)
//   - A5: CORRECT TAP plays target word audio + triggers celebration
//   - A6: AUTO-ADVANCE after celebration duration
//
// Wiring: ProviderScope overrides FakeAudioEngine + a seeded RoundGenerator
// with an injected fake manifest (so the test is decoupled from Phase 3's
// production manifest contents).

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/manifest/audio_asset.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/core/matching/photo_override_source.dart';
import 'package:hugrun/core/matching/round_generator.dart';
import 'package:hugrun/features/stafir/matching/matching_activity.dart';
import 'package:hugrun/features/stafir/matching/matching_celebration.dart';
import 'package:hugrun/features/stafir/matching/matching_providers.dart';
import 'package:hugrun/features/stafir/matching/matching_round_image.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile.dart';

import '../../../../integration_test/test_helpers/fake_audio_engine.dart';

const _hundurAsset = AudioAsset(
  path: 'assets/audio/letters/words/hundur.aac',
  approximateDuration: Duration(milliseconds: 300),
);

ProviderScope _wrap({
  required FakeAudioEngine engine,
  required RoundGenerator generator,
  Widget? child,
}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine),
      roundGeneratorProvider.overrideWith((ref) => generator),
      photoOverrideSourceProvider.overrideWith(
        (ref) => const EmptyPhotoOverrideSource(),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child ?? const MatchingActivity())),
  );
}

RoundGenerator _hundurOnlyGenerator(int seed) => RoundGenerator(
  seed: seed,
  manifestOverride: <UtteranceKey, AudioAsset>{
    UtteranceKey.wordHundur: _hundurAsset,
  },
);

void main() {
  testWidgets('A1: layout — 1 image, 4 LetterTiles, 1 (hidden) celebration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    // Pump once to let post-frame callback schedule first round.
    await tester.pump();
    await tester.pump();

    expect(find.byType(MatchingRoundImage), findsOneWidget);
    expect(find.byType(LetterTile), findsNWidgets(4));
    // Celebration is mounted but hidden.
    expect(find.byType(MatchingCelebration), findsOneWidget);
    expect(find.byKey(const Key('matching-celebration-active')), findsNothing);
  });

  testWidgets('A2: each LetterTile receives kIcelandicAlphabet index', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    final tiles = tester
        .widgetList<LetterTile>(find.byType(LetterTile))
        .toList();
    for (final t in tiles) {
      final expectedIndex = kIcelandicAlphabet.indexOf(t.letter);
      expect(
        t.letterIndex,
        expectedIndex,
        reason: 'tile for ${t.letter.glyph} should have index $expectedIndex',
      );
    }
  });

  testWidgets('A3: no audio plays on mount', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();
    expect(engine.playCalls, isEmpty);
  });

  testWidgets('A4 (CRITICAL — MATCH-02): wrong tap is completely silent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    // Find the first LetterTile whose letter glyph is NOT 'h'.
    final tiles = tester
        .widgetList<LetterTile>(find.byType(LetterTile))
        .toList();
    final wrongTile = tiles.firstWhere((t) => t.letter.glyph != 'h');
    final wrongFinder = find.byWidgetPredicate(
      (w) => w is LetterTile && w.letter == wrongTile.letter,
    );

    await tester.tap(wrongFinder);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      engine.playCalls,
      isEmpty,
      reason: 'wrong tap MUST NOT trigger audio (MATCH-02)',
    );
    expect(
      engine.stopCallCount,
      0,
      reason: 'wrong tap MUST NOT trigger stop()',
    );
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsNothing,
      reason: 'wrong tap MUST NOT show celebration',
    );

    // Tap a second wrong letter — same invariants hold.
    final secondWrongTile = tiles.firstWhere(
      (t) => t.letter.glyph != 'h' && t.letter != wrongTile.letter,
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is LetterTile && w.letter == secondWrongTile.letter,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.playCalls, isEmpty);
    expect(engine.stopCallCount, 0);
    expect(find.byKey(const Key('matching-celebration-active')), findsNothing);
  });

  testWidgets('A5: correct tap fires audio + celebration', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    final tiles = tester
        .widgetList<LetterTile>(find.byType(LetterTile))
        .toList();
    final correctTile = tiles.firstWhere((t) => t.letter.glyph == 'h');
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is LetterTile && w.letter == correctTile.letter,
      ),
    );
    await tester.pump();

    expect(engine.playCalls, <UtteranceKey>[UtteranceKey.wordHundur]);
    // Pump 100ms; celebration should be active.
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
    );
    // Stop the lingering auto-advance Timer to avoid leak warnings.
    await tester.pump(MatchingCelebration.duration);
    await tester.pump();
  });

  testWidgets('A6: auto-advance generates a new round after duration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    // Use only wordHundur — round will repeat but the celebration overlay
    // resets to invisible after auto-advance.
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    final tiles = tester
        .widgetList<LetterTile>(find.byType(LetterTile))
        .toList();
    final correctTile = tiles.firstWhere((t) => t.letter.glyph == 'h');
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is LetterTile && w.letter == correctTile.letter,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('matching-celebration-active')),
      findsOneWidget,
    );

    // Pump the auto-advance timer.
    await tester.pump(MatchingCelebration.duration);
    await tester.pump();
    // Celebration is now hidden again — auto-advance fired.
    expect(find.byKey(const Key('matching-celebration-active')), findsNothing);
    // 4 tiles still rendered for the new round.
    expect(find.byType(LetterTile), findsNWidgets(4));
  });

  testWidgets('A7: 5 wrong taps — no fail UI ever appears', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    final tiles = tester
        .widgetList<LetterTile>(find.byType(LetterTile))
        .toList();
    final wrongs = tiles.where((t) => t.letter.glyph != 'h').toList();
    for (var i = 0; i < 5; i++) {
      final t = wrongs[i % wrongs.length];
      await tester.tap(
        find.byWidgetPredicate((w) => w is LetterTile && w.letter == t.letter),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.text('wrong'), findsNothing);
    expect(find.text('nope'), findsNothing);
    expect(find.text('try'), findsNothing);
  });

  testWidgets('A8: no score / streak / timer / digits visible', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(RegExp(r'\d')),
      ),
      findsNothing,
    );
    // No keys including the forbidden words.
    for (final forbidden in <String>['score', 'streak', 'timer', 'count']) {
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              ((w.key! as ValueKey<String>).value).toLowerCase().contains(
                forbidden,
              ),
        ),
        findsNothing,
        reason: 'no widget key should contain "$forbidden"',
      );
    }
  });

  testWidgets('A9: rapid wrong then correct — only correct dispatches audio', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    final tiles = tester
        .widgetList<LetterTile>(find.byType(LetterTile))
        .toList();
    final wrong = tiles.firstWhere((t) => t.letter.glyph != 'h');
    final correct = tiles.firstWhere((t) => t.letter.glyph == 'h');

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is LetterTile && w.letter == wrong.letter,
      ),
    );
    // No pump in between — same frame.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is LetterTile && w.letter == correct.letter,
      ),
    );
    await tester.pump();
    expect(engine.playCalls, <UtteranceKey>[UtteranceKey.wordHundur]);
    // Drain auto-advance.
    await tester.pump(MatchingCelebration.duration);
    await tester.pump();
  });

  testWidgets('A10: exactly 4 LetterTile widgets (no duplicate tile class)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LetterTile).evaluate().length, 4);
  });

  testWidgets('A11: pending auto-advance Timer is safe across unmount', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final gen = _hundurOnlyGenerator(42);
    await tester.pumpWidget(_wrap(engine: engine, generator: gen));
    await tester.pump();
    await tester.pump();

    final tiles = tester
        .widgetList<LetterTile>(find.byType(LetterTile))
        .toList();
    final correct = tiles.firstWhere((t) => t.letter.glyph == 'h');
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is LetterTile && w.letter == correct.letter,
      ),
    );
    await tester.pump();

    // Replace the entire app with a different widget (unmounts the
    // MatchingActivity AND its parent ProviderScope).
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    // Pump past the auto-advance timer's deadline.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
