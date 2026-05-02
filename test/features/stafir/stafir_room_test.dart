import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/features/stafir/stafir_room.dart';

void main() {
  testWidgets('StafirRoom Scaffold has AppBar with title "Stafir"', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StafirRoom()));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title, isA<Text>());
    expect((appBar.title as Text).data, 'Stafir');
  });

  testWidgets('StafirRoom can be popped without crashing', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: SizedBox()),
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
