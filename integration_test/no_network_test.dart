import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';
import 'package:hugrun/features/tolur/tolur_room.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers/no_network_http_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = NoNetworkHttpOverrides();
  });
  tearDown(() {
    HttpOverrides.global = null;
  });

  test('NoNetworkHttpOverrides throws on HttpClient construction', () {
    expect(HttpClient.new, throwsStateError);
  });

  testWidgets('Full Phase 1 play session attempts no network', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    await tester.pumpAndSettle();

    // Tap each room and back out — exercises Plan 01-03 paths.
    // Phase 12 UI-01 removed the AppBar from kid surfaces so we pop
    // programmatically via Navigator.of(...) rather than tester.pageBack().
    await tester.tap(find.byKey(const Key('home-room-stafir')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(StafirRoom))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-room-tolur')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(TolurRoom))).pop();
    await tester.pumpAndSettle();

    // Long-press settings icon.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.settings)),
    );
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    // If anything tried to hit the network, the override would have thrown.
    expect(true, isTrue);
  });
}
