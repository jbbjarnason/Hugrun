// Plan 04-04 tests for StafirRoom (replaces the Phase 1 placeholder tests).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile.dart';

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

  testWidgets('StafirRoom AppBar still shows "Stafir"', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pump();
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title, isA<Text>());
    expect((appBar.title! as Text).data, 'Stafir');
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
