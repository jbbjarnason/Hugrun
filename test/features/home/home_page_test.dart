import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';
import 'package:hugrun/features/home/home_page.dart';

void main() {
  testWidgets('HomePage renders inside HugrunApp', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('HomePage renders a Scaffold', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('HugrunApp title is "Hugrún" with Icelandic locale', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Hugrún');
    expect(app.supportedLocales, contains(const Locale('is')));
  });
}
