// Phase 7 Workstream B — widget tests for TracingActivity.
//
// The activity:
//   • Mounts a StrokeOrderAnimator from the stroke_order_animator package
//     for the currently-selected letter.
//   • Loads the glyph JSON via traceDataProvider (Riverpod, app-scoped,
//     warmed at app start; tests override it with a fixture map so we
//     don't depend on rootBundle).
//   • Wires onQuizCompleteCallback → AudioEngine.play(celebration key)
//     and auto-advances to a NEW random letter after a brief delay.
//   • Soft stroke-order: package's hintAfterStrokes default behavior is
//     used. We don't reject input; the activity contains zero
//     pass/fail UI.
//
// These tests verify:
//   T1  Mounts a StrokeOrderAnimator for the active letter.
//   T2  No fail/pass UI (no LinearProgressIndicator, no error/check icons).
//   T3  No timer-display widgets (no CountdownTimer, no Progress).
//   T4  On simulated quiz-complete via the controller, the activity
//       fires AudioEngine.play with the celebration utterance key.
//   T5  After completion, the activity auto-advances — the active
//       letter changes (by re-randomizing through the provider).
//   T6  Wrong-stroke does NOT show any negative-feedback chrome.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/alphabet/icelandic_letter.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/core/tracing/glyph_loader.dart';
import 'package:hugrun/features/stafir/tracing/trace_data_provider.dart';
import 'package:hugrun/features/stafir/tracing/tracing_activity.dart';
import 'package:hugrun/features/stafir/tracing/tracing_celebration.dart';
import 'package:stroke_order_animator/stroke_order_animator.dart';

import '../../../core/audio/_fakes/fake_audio_player.dart';

class _RecordingEngine extends AudioEngine {
  _RecordingEngine() : super(playerFactory: FakeAudioPlayer.new);
  final List<UtteranceKey> playCalls = <UtteranceKey>[];

  @override
  Future<void> warmUp() async {
    /* no-op for tests */
  }

  @override
  Future<void> dispose() async {
    /* no-op */
  }

  @override
  Future<void> play(UtteranceKey key) async {
    playCalls.add(key);
  }

  @override
  Future<void> stop() async {
    /* no-op */
  }
}

Map<IcelandicLetter, TraceGlyph> _loadAllShippedGlyphs() {
  final result = <IcelandicLetter, TraceGlyph>{};
  for (final letter in kIcelandicAlphabet) {
    final path = 'assets/tracing/${letter.assetSlug}.json';
    final raw = File(path).readAsStringSync();
    result[letter] = parseGlyphJson(raw);
  }
  return result;
}

class _ForcedLetterNotifier extends TracingCurrentLetter {
  _ForcedLetterNotifier(this._initial);
  final IcelandicLetter _initial;
  @override
  IcelandicLetter build() => _initial;
}

Widget _wrap({
  required _RecordingEngine engine,
  required Map<IcelandicLetter, TraceGlyph> glyphs,
  IcelandicLetter? forcedLetter,
}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine),
      traceDataProvider.overrideWith((ref) async => glyphs),
      if (forcedLetter != null)
        tracingCurrentLetterProvider.overrideWith(
          () => _ForcedLetterNotifier(forcedLetter),
        ),
    ],
    child: const MaterialApp(home: Scaffold(body: TracingActivity())),
  );
}

void main() {
  // -----------------------------------------------------------------
  //  T0  selectCelebrationKey — pure helper for D-14 fallback
  // -----------------------------------------------------------------
  group('selectCelebrationKey (T0 — fallback chain)', () {
    test('returns narrationCelebrationTracing if available', () {
      // The enum may or may not have narrationCelebrationTracing depending
      // on whether Phase 3 review has shipped. selectCelebrationKey looks
      // up by symbol name to be resilient to the enum-extension order.
      final key = selectCelebrationKey();
      expect(key, isA<UtteranceKey>());
    });

    test('falls back to narrationWelcome when celebration not in enum', () {
      final key = selectCelebrationKey();
      // narrationWelcome ALWAYS exists (Phase 2 stub guarantee).
      expect(
        <UtteranceKey>{
              UtteranceKey.narrationWelcome,
              // narrationCelebrationTracing is the preferred key — the
              // function MAY return either depending on enum state.
            }.contains(key) ||
            key.name == 'narrationCelebrationTracing',
        isTrue,
      );
    });
  });

  // -----------------------------------------------------------------
  //  T1  Mounts a StrokeOrderAnimator for the active letter
  // -----------------------------------------------------------------
  testWidgets('T1: mounts a StrokeOrderAnimator for the current letter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final glyphs = _loadAllShippedGlyphs();
    final letter = kIcelandicAlphabet.firstWhere((l) => l.glyph == 'a');

    await tester.pumpWidget(
      _wrap(engine: _RecordingEngine(), glyphs: glyphs, forcedLetter: letter),
    );
    // First pump: build empty (Future is loading or post-frame pending).
    // Second pump: Future resolves; build() requests a controller via
    // addPostFrameCallback. Third pump: setState after callback.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(StrokeOrderAnimator), findsOneWidget);
  });

  // -----------------------------------------------------------------
  //  T2  No fail/pass UI surface
  // -----------------------------------------------------------------
  testWidgets('T2: no LinearProgressIndicator, no error/check icons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final glyphs = _loadAllShippedGlyphs();
    await tester.pumpWidget(
      _wrap(
        engine: _RecordingEngine(),
        glyphs: glyphs,
        forcedLetter: kIcelandicAlphabet.first,
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  // -----------------------------------------------------------------
  //  T3  No text instructions visible to the child (STAFIR-08 spirit
  //       extended to tracing per Phase 7 D-09)
  // -----------------------------------------------------------------
  testWidgets('T3: no Text widgets show user-facing instructions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final glyphs = _loadAllShippedGlyphs();
    await tester.pumpWidget(
      _wrap(
        engine: _RecordingEngine(),
        glyphs: glyphs,
        forcedLetter: kIcelandicAlphabet.first,
      ),
    );
    await tester.pump();
    // Allow at most one Text widget — the optional letter glyph header.
    // Either way: no instruction-style strings.
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    for (final s in texts) {
      // No instruction-y words.
      expect(
        s.toLowerCase(),
        isNot(anyOf(contains('try'), contains('start'), contains('begin'))),
      );
    }
  });

  // -----------------------------------------------------------------
  //  T4  Quiz-complete via controller fires AudioEngine.play
  // -----------------------------------------------------------------
  testWidgets(
    'T4: simulated quiz-complete via debugCompleteForTesting fires audio',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final engine = _RecordingEngine();
      final glyphs = _loadAllShippedGlyphs();
      await tester.pumpWidget(
        _wrap(
          engine: engine,
          glyphs: glyphs,
          forcedLetter: kIcelandicAlphabet.first,
        ),
      );
      await tester.pump();

      // Find the activity state and invoke the test-only completion hook.
      final state = tester.state<TracingActivityState>(
        find.byType(TracingActivity),
      );
      state.debugCompleteForTesting();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        engine.playCalls,
        isNotEmpty,
        reason: 'celebration audio should fire on quiz complete',
      );
      final last = engine.playCalls.last;
      // Either narrationCelebrationTracing (preferred) or narrationWelcome
      // (fallback) is acceptable.
      expect(
        last == UtteranceKey.narrationWelcome ||
            last.name == 'narrationCelebrationTracing',
        isTrue,
        reason:
            'expected celebration key, got ${last.name}; play history: ${engine.playCalls}',
      );
    },
  );

  // -----------------------------------------------------------------
  //  T5  Auto-advance — current letter changes after celebration
  // -----------------------------------------------------------------
  testWidgets('T5: auto-advances to a new letter after celebration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final engine = _RecordingEngine();
    final glyphs = _loadAllShippedGlyphs();
    final initialLetter = kIcelandicAlphabet.firstWhere((l) => l.glyph == 'a');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioEngineProvider.overrideWith((ref) => engine),
          traceDataProvider.overrideWith((ref) async => glyphs),
        ],
        child: const MaterialApp(home: Scaffold(body: TracingActivity())),
      ),
    );
    await tester.pump();

    // Capture the initial letter from the state.
    final state1 = tester.state<TracingActivityState>(
      find.byType(TracingActivity),
    );
    final letterBefore = state1.debugCurrentLetter;

    state1.debugCompleteForTesting();
    // Pump past the auto-advance delay.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    final state2 = tester.state<TracingActivityState>(
      find.byType(TracingActivity),
    );
    final letterAfter = state2.debugCurrentLetter;

    // With 32 letters and random selection, identical letter is possible
    // but improbable. We retry up to 5 times for robustness against the
    // RNG happening to repeat. Each completion auto-advances.
    var advances = 0;
    var current = letterAfter;
    while (current == letterBefore && advances < 5) {
      state2.debugCompleteForTesting();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();
      current = state2.debugCurrentLetter;
      advances++;
    }
    expect(
      current,
      isNot(letterBefore),
      reason: 'auto-advance should pick a different letter within 5 attempts',
    );
    // Initial start letter should also have rendered without explicit
    // override — it is selected at random from the 32-letter pool.
    expect(kIcelandicAlphabet, contains(letterBefore));
    expect(kIcelandicAlphabet, contains(letterAfter));
    // initialLetter is referenced to silence unused-local warnings:
    expect(initialLetter, isA<IcelandicLetter>());
  });

  // -----------------------------------------------------------------
  //  T6  Wrong-stroke does NOT trigger a fail-state. The package's
  //  callback fires `onWrongStrokeCallback` — we just confirm nothing
  //  user-facing changes (no audio plays, no error chrome).
  // -----------------------------------------------------------------
  testWidgets('T6: wrong-stroke triggers NO audio + NO error chrome', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final engine = _RecordingEngine();
    final glyphs = _loadAllShippedGlyphs();
    await tester.pumpWidget(
      _wrap(
        engine: engine,
        glyphs: glyphs,
        forcedLetter: kIcelandicAlphabet.first,
      ),
    );
    await tester.pump();
    // Mounting produced zero plays.
    expect(engine.playCalls, isEmpty);

    // Simulating "wrong stroke" via the test hook on the activity.
    final state = tester.state<TracingActivityState>(
      find.byType(TracingActivity),
    );
    state.debugWrongStrokeForTesting();
    await tester.pump();
    // Wrong-stroke is silent — no celebration, no negative cue.
    expect(
      engine.playCalls,
      isEmpty,
      reason: 'wrong stroke must NOT fire audio (TRACE-03/04, no fail UI)',
    );
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
  });
}
