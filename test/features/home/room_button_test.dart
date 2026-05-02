import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/features/home/room_button.dart';

void main() {
  testWidgets('RoomButton renders the provided label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomButton(label: 'Stafir', onTap: () {}),
        ),
      ),
    );
    expect(find.text('Stafir'), findsOneWidget);
  });

  testWidgets('Tapping a RoomButton invokes onTap exactly once', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomButton(label: 'Tölur', onTap: () => taps++),
        ),
      ),
    );
    await tester.tap(find.byType(RoomButton));
    expect(taps, 1);
  });

  testWidgets('RoomButton tap target is at least 88x88 logical px', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RoomButton(label: 'Test', onTap: () {}),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(RoomButton));
    expect(size.width, greaterThanOrEqualTo(88));
    expect(size.height, greaterThanOrEqualTo(88));
  });
}
