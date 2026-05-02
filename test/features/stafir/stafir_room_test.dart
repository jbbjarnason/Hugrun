// Plan 04-04 tests for StafirRoom (replaces the Phase 1 placeholder tests).
// Plan 05-03 extends with S1..S7 covering the mode toggle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/stafir/cvc/cvc_activity.dart';
import 'package:hugrun/features/stafir/matching/matching_activity.dart';
import 'package:hugrun/features/stafir/stafir_mode.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/stafir/tracing/tracing_activity.dart';
import 'package:hugrun/features/stafir/widgets/letter_grid.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile.dart';
import 'package:hugrun/features/stafir/widgets/stafir_mode_toggle.dart';

import '../../core/audio/_fakes/fake_audio_player.dart';

class _RecordingEngine extends AudioEngine {
  _RecordingEngine() : super(playerFactory: FakeAudioPlayer.new);
  final List<UtteranceKey> playCalls = <UtteranceKey>[];
  final List<UtteranceKey> stopCalls = <UtteranceKey>[];

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

ProviderScope _wrap({_RecordingEngine? engine}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine ?? _RecordingEngine()),
    ],
    child: const MaterialApp(home: StafirRoom()),
  );
}

void main() {
  testWidgets('StafirRoom renders 32 LetterTile widgets in MMS order', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byType(LetterTile), findsNWidgets(32));
  });

  testWidgets('StafirRoom shows NO AppBar (Phase 12 UI-01: kid-mode '
      'must have zero text titles visible to child)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    // Defense-in-depth: the literal text "Stafir" must not appear
    // anywhere in the kid-facing surface.
    expect(find.text('Stafir'), findsNothing);
  });

  testWidgets('Tapping the "a" tile invokes audioEngine.play(letterA)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final engine = _RecordingEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pump();
    await tester.tap(find.byKey(const Key('letter-tile-0-a')));
    await tester.pump();

    expect(engine.playCalls, contains(UtteranceKey.letterA));
  });

  testWidgets(
    'Tapping a letter that is NOT in the stub manifest does not throw',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final engine = _RecordingEngine();
      await tester.pumpWidget(_wrap(engine: engine));
      await tester.pump();
      // Letter "h" — letterH doesn't exist in Phase 2 stub enum.
      await tester.tap(find.byKey(const Key('letter-tile-9-h')));
      await tester.pump();
      // No exception, and the engine wasn't called for this tile.
      expect(
        engine.playCalls.where((k) => k.name == 'letterH'),
        isEmpty,
      );
    },
  );

  testWidgets('StafirRoom contains zero progress / failure UI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // ============================================================
  //  Plan 05-03 — mode toggle tests S1..S7
  // ============================================================

  testWidgets('S1: default mode is letters — LetterGrid mounted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byType(LetterGrid), findsOneWidget);
    expect(find.byType(MatchingActivity), findsNothing);
  });

  testWidgets('S2: StafirModeToggle is mounted in top-right',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byType(StafirModeToggle), findsOneWidget);
    final toggleRect = tester.getRect(find.byType(StafirModeToggle));
    final scaffoldRect = tester.getRect(find.byType(Scaffold));
    // Within ~32 logical px of the top-right corner of the body.
    expect(toggleRect.top - scaffoldRect.top, lessThan(120));
    expect(scaffoldRect.right - toggleRect.right, lessThan(32));
  });

  testWidgets('S3: programmatic mode swap shows MatchingActivity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    final state = tester.state<StafirRoomState>(find.byType(StafirRoom));
    state.debugSetMode(StafirMode.match);
    await tester.pump();
    await tester.pump();
    expect(find.byType(MatchingActivity), findsOneWidget);
    expect(find.byType(LetterGrid), findsNothing);
  });

  testWidgets('S4: toggle back to letters after match', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    final state = tester.state<StafirRoomState>(find.byType(StafirRoom));
    state.debugSetMode(StafirMode.match);
    await tester.pump();
    await tester.pump();
    expect(find.byType(MatchingActivity), findsOneWidget);
    state.debugSetMode(StafirMode.letters);
    await tester.pump();
    await tester.pump();
    expect(find.byType(LetterGrid), findsOneWidget);
    expect(find.byType(MatchingActivity), findsNothing);
  });

  testWidgets('S4b: programmatic mode swap to cvc shows CvcActivity (Phase 6)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    final state = tester.state<StafirRoomState>(find.byType(StafirRoom));
    state.debugSetMode(StafirMode.cvc);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CvcActivity), findsOneWidget);
    expect(find.byType(LetterGrid), findsNothing);
    expect(find.byType(MatchingActivity), findsNothing);
  });

  testWidgets('S4c: cvc → letters → match cycle preserves room',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    final state = tester.state<StafirRoomState>(find.byType(StafirRoom));
    // letters → match
    state.debugSetMode(StafirMode.match);
    await tester.pump();
    expect(find.byType(MatchingActivity), findsOneWidget);
    // match → cvc
    state.debugSetMode(StafirMode.cvc);
    await tester.pump();
    expect(find.byType(CvcActivity), findsOneWidget);
    // cvc → letters
    state.debugSetMode(StafirMode.letters);
    await tester.pump();
    expect(find.byType(LetterGrid), findsOneWidget);
  });

  testWidgets(
    'S4d (Phase 7): programmatic mode swap to trace shows TracingActivity',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap());
      await tester.pump();
      final state = tester.state<StafirRoomState>(find.byType(StafirRoom));
      state.debugSetMode(StafirMode.trace);
      // Multiple pumps so the FutureProvider for traceData attempts to
      // resolve. In the StafirRoom widget test we don't override
      // traceDataProvider — the real provider hits rootBundle which is
      // not ServicesBinding-mocked here. The TracingActivity widget
      // renders empty (SizedBox.shrink) on loading/error — that's fine
      // because the test asserts on widget TYPE, not subwidgets.
      await tester.pump();
      await tester.pump();
      expect(find.byType(TracingActivity), findsOneWidget);
      expect(find.byType(LetterGrid), findsNothing);
      expect(find.byType(MatchingActivity), findsNothing);
      expect(find.byType(CvcActivity), findsNothing);
    },
  );

  testWidgets(
    'S4e (Phase 7): full 4-mode cycle letters → match → cvc → trace → letters',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap());
      await tester.pump();
      final state = tester.state<StafirRoomState>(find.byType(StafirRoom));

      state.debugSetMode(StafirMode.match);
      await tester.pump();
      expect(find.byType(MatchingActivity), findsOneWidget);

      state.debugSetMode(StafirMode.cvc);
      await tester.pump();
      expect(find.byType(CvcActivity), findsOneWidget);

      state.debugSetMode(StafirMode.trace);
      await tester.pump();
      await tester.pump();
      expect(find.byType(TracingActivity), findsOneWidget);

      state.debugSetMode(StafirMode.letters);
      await tester.pump();
      expect(find.byType(LetterGrid), findsOneWidget);
    },
  );

  testWidgets('S6 (Phase 12): NO AppBar present in any mode — '
      'AppBar removed for kid-mode polish (UI-01)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    final state = tester.state<StafirRoomState>(find.byType(StafirRoom));
    state.debugSetMode(StafirMode.match);
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    state.debugSetMode(StafirMode.cvc);
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('S7: toggle does not capture letter taps in same coordinate',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final engine = _RecordingEngine();
    await tester.pumpWidget(_wrap(engine: engine));
    await tester.pump();
    // Tap a letter that is NOT the toggle area.
    await tester.tap(find.byKey(const Key('letter-tile-0-a')));
    await tester.pump();
    expect(engine.playCalls, contains(UtteranceKey.letterA));
  });

  testWidgets('StafirRoom can be popped without crashing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioEngineProvider.overrideWith((ref) => _RecordingEngine()),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const StafirRoom()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StafirRoom), findsOneWidget);
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(StafirRoom), findsNothing);
  });
}
