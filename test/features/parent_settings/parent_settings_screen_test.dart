import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/features/parent_settings/parent_settings_screen.dart';

void main() {
  testWidgets('ParentSettingsScreen shows "Stillingar" text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentSettingsScreen()));
    expect(find.text('Stillingar'), findsWidgets);
  });

  testWidgets('ParentSettingsScreen has an AppBar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentSettingsScreen()));
    expect(find.byType(AppBar), findsOneWidget);
  });
}
