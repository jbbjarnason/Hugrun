import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/app/app.dart';

void main() {
  testWidgets('HugrunApp uses Icelandic locale', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('is'));
  });
}
