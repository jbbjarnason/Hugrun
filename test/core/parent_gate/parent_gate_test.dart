import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/parent_gate/parent_gate.dart';
import 'package:hugrun/core/parent_gate/parent_gate_controller.dart';

void main() {
  group('ParentGateController (pure Dart state machine)', () {
    test('starts idle: not holding, not completed', () {
      final c = ParentGateController(
        duration: const Duration(milliseconds: 100),
        onCompleted: () {},
      );
      expect(c.isHolding, isFalse);
      expect(c.isCompleted, isFalse);
      c.dispose();
    });

    test('onPressStart sets isHolding=true', () {
      final c = ParentGateController(
        duration: const Duration(milliseconds: 100),
        onCompleted: () {},
      );
      c.onPressStart();
      expect(c.isHolding, isTrue);
      c.dispose();
    });

    test('release before duration does not call onCompleted', () async {
      var fired = false;
      final c = ParentGateController(
        duration: const Duration(milliseconds: 50),
        onCompleted: () => fired = true,
      );
      c.onPressStart();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      c.onPressEnd();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fired, isFalse);
      expect(c.isHolding, isFalse);
      c.dispose();
    });

    test('hold for full duration calls onCompleted exactly once', () async {
      var fireCount = 0;
      final c = ParentGateController(
        duration: const Duration(milliseconds: 30),
        onCompleted: () => fireCount++,
      );
      c.onPressStart();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fireCount, 1);
      expect(c.isCompleted, isTrue);
      c.dispose();
    });

    test('onPressStart after onPressEnd restarts the timer', () async {
      var fired = false;
      final c = ParentGateController(
        duration: const Duration(milliseconds: 30),
        onCompleted: () => fired = true,
      );
      c.onPressStart();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      c.onPressEnd();
      c.onPressStart();
      await Future<void>.delayed(const Duration(milliseconds: 15));
      // 25ms in, but only 15ms of the second hold has elapsed — should not fire.
      expect(fired, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(fired, isTrue);
      c.dispose();
    });
  });

  group('ParentGate widget', () {
    testWidgets('long hold for holdDuration calls onCompleted', (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentGate(
              holdDuration: const Duration(milliseconds: 100),
              onCompleted: () => completed = true,
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Text('press'),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('press')),
      );
      await tester.pump(const Duration(milliseconds: 110));
      await gesture.up();
      await tester.pump();
      expect(completed, isTrue);
    });

    testWidgets('short hold does NOT call onCompleted', (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentGate(
              holdDuration: const Duration(milliseconds: 100),
              onCompleted: () => completed = true,
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Text('press'),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('press')),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(completed, isFalse);
    });

    testWidgets('ring widget appears during hold', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentGate(
              holdDuration: const Duration(milliseconds: 100),
              onCompleted: () {},
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Text('press'),
              ),
            ),
          ),
        ),
      );
      // Initially no ring.
      expect(find.byKey(const Key('parent-gate-ring')), findsNothing);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('press')),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.byKey(const Key('parent-gate-ring')), findsOneWidget);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('ring disappears on release before completion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentGate(
              holdDuration: const Duration(milliseconds: 100),
              onCompleted: () {},
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Text('press'),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('press')),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.byKey(const Key('parent-gate-ring')), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(find.byKey(const Key('parent-gate-ring')), findsNothing);
    });
  });
}
