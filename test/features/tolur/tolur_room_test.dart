import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/features/tolur/tolur_room.dart';

void main() {
  testWidgets('TolurRoom Scaffold has AppBar with title "Tölur"', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TolurRoom()));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title, isA<Text>());
    expect((appBar.title as Text).data, 'Tölur');
  });

  testWidgets('TolurRoom can be popped without crashing', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const TolurRoom()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TolurRoom), findsOneWidget);
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(TolurRoom), findsNothing);
  });
}
