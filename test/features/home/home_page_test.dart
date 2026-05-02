// ignore_for_file: scoped_providers_should_specify_dependencies
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/home/home_page.dart';
import 'package:hugrun/features/home/room_button.dart';
import 'package:hugrun/features/parent_settings/parent_settings_screen.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/tolur/tolur_room.dart';

import '../../core/audio/_fakes/fake_audio_player.dart';

class _RecEngine extends AudioEngine {
  _RecEngine() : super(playerFactory: FakeAudioPlayer.new);
  final List<UtteranceKey> playCalls = <UtteranceKey>[];
  @override
  Future<void> warmUp() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> play(UtteranceKey key) async {
    playCalls.add(key);
  }

  @override
  Future<void> stop() async {}
}

/// Pumps HugrunApp wrapped with in-memory Drift + recording engine, runs
/// the body, then unmounts before tear-down so the Drift markAsClosed
/// timer fires inside the fake-async window.
Future<void> _runHomeWithDb(
  WidgetTester tester, {
  required Future<void> Function(_RecEngine engine, AppDatabase db) body,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await ensureDefaultChildProfile(db);
  final engine = _RecEngine();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        audioEngineProvider.overrideWith((ref) => engine),
      ],
      child: const HugrunApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await body(engine, db);
  // Unmount + flush.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
  await db.close();
}

void main() {
  testWidgets('HomePage renders inside HugrunApp', (tester) async {
    await _runHomeWithDb(
      tester,
      body: (engine, db) async {
        expect(find.byType(HomePage), findsOneWidget);
      },
    );
  });

  testWidgets('HomePage renders a Scaffold', (tester) async {
    await _runHomeWithDb(
      tester,
      body: (engine, db) async {
        expect(find.byType(Scaffold), findsWidgets);
      },
    );
  });

  testWidgets('HugrunApp title is "Hugrún" with Icelandic locale', (
    tester,
  ) async {
    await _runHomeWithDb(
      tester,
      body: (engine, db) async {
        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.title, 'Hugrún');
        expect(app.supportedLocales, contains(const Locale('is')));
      },
    );
  });

  testWidgets('HomePage shows two RoomButtons (Stafir, Tölur)', (tester) async {
    await _runHomeWithDb(
      tester,
      body: (engine, db) async {
        final buttons = tester
            .widgetList<RoomButton>(find.byType(RoomButton))
            .toList();
        expect(buttons.length, 2);
        final labels = buttons.map((b) => b.label).toSet();
        expect(labels, containsAll(<String>['Stafir', 'Tölur']));
      },
    );
  });

  testWidgets('Tapping Stafir navigates to StafirRoom', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _runHomeWithDb(
      tester,
      body: (engine, db) async {
        await tester.tap(find.byKey(const Key('home-room-stafir')));
        await tester.pumpAndSettle();
        expect(find.byType(StafirRoom), findsOneWidget);
      },
    );
  });

  testWidgets('Tapping Tölur navigates to TolurRoom', (tester) async {
    await _runHomeWithDb(
      tester,
      body: (engine, db) async {
        await tester.tap(find.byKey(const Key('home-room-tolur')));
        await tester.pumpAndSettle();
        expect(find.byType(TolurRoom), findsOneWidget);
      },
    );
  });

  testWidgets('HomePage contains parent-gate-wrapped settings icon', (
    tester,
  ) async {
    await _runHomeWithDb(
      tester,
      body: (engine, db) async {
        expect(find.byIcon(Icons.settings), findsOneWidget);
      },
    );
  });

  testWidgets(
    'Long-press settings icon for 3s navigates to ParentSettingsScreen',
    (tester) async {
      await _runHomeWithDb(
        tester,
        body: (engine, db) async {
          final settings = find.byIcon(Icons.settings);
          final gesture = await tester.startGesture(
            tester.getCenter(settings),
          );
          await tester.pump(const Duration(seconds: 3, milliseconds: 100));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(find.byType(ParentSettingsScreen), findsOneWidget);
        },
      );
    },
  );

  // Welcome-narration end-to-end through HomePage's addPostFrameCallback
  // is integration-test territory (Plan 04-07 covers it via
  // integration_test/stafir_flow_test.dart). The
  // welcome_narration_controller_test.dart already verifies the
  // dispatch + once-per-session contract at the unit level.
  //
  // The widget-test variant of "HomePage initState fires the welcome"
  // is omitted because the Drift watchSingleOrNull stream + Riverpod
  // StreamProvider + AutomatedTestWidgetsFlutterBinding interaction
  // doesn't surface the in-memory emission inside the widget test's
  // fake-async window. The integration test covers it on a real binding.
}
