import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';
import 'package:hugrun/features/home/home_page.dart';
import 'package:hugrun/features/home/room_button.dart';
import 'package:hugrun/features/parent_settings/parent_settings_screen.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/tolur/tolur_room.dart';

void main() {
  testWidgets('HomePage renders inside HugrunApp', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('HomePage renders a Scaffold', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('HugrunApp title is "Hugrún" with Icelandic locale', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Hugrún');
    expect(app.supportedLocales, contains(const Locale('is')));
  });

  testWidgets('HomePage shows two RoomButtons (Stafir, Tölur)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    final buttons = tester
        .widgetList<RoomButton>(find.byType(RoomButton))
        .toList();
    expect(buttons.length, 2);
    final labels = buttons.map((b) => b.label).toSet();
    expect(labels, containsAll(<String>['Stafir', 'Tölur']));
  });

  testWidgets('Tapping Stafir navigates to StafirRoom', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    await tester.tap(find.byKey(const Key('home-room-stafir')));
    await tester.pumpAndSettle();
    expect(find.byType(StafirRoom), findsOneWidget);
  });

  testWidgets('Tapping Tölur navigates to TolurRoom', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    await tester.tap(find.byKey(const Key('home-room-tolur')));
    await tester.pumpAndSettle();
    expect(find.byType(TolurRoom), findsOneWidget);
  });

  testWidgets('HomePage contains parent-gate-wrapped settings icon', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets(
    'Long-press settings icon for 3s navigates to ParentSettingsScreen',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
      final settings = find.byIcon(Icons.settings);
      final gesture = await tester.startGesture(tester.getCenter(settings));
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(ParentSettingsScreen), findsOneWidget);
    },
  );
}
