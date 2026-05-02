// Plan 05-03 Task 1 tests: StafirMode enum + StafirModeToggle widget.
//
// The toggle is a small icon-only widget that requires a 3-second hold
// to call onToggle. It reuses the Phase 1 ParentGateController state
// machine for hold-timing semantics — same gesture pattern as the parent
// gate, just smaller chrome.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/features/stafir/stafir_mode.dart';
import 'package:hugrun/features/stafir/widgets/stafir_mode_toggle.dart';

Widget _host({
  required StafirMode mode,
  required VoidCallback onToggle,
  Duration holdDuration = const Duration(seconds: 3),
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: StafirModeToggle(
            currentMode: mode,
            onToggle: onToggle,
            holdDuration: holdDuration,
          ),
        ),
      ),
    );

void main() {
  test('M1: StafirMode.values is exactly [letters, match, cvc, trace]',
      () {
    expect(StafirMode.values, <StafirMode>[
      StafirMode.letters,
      StafirMode.match,
      StafirMode.cvc,
      StafirMode.trace,
    ]);
  });

  test(
      'M1b: StafirModeToggleExt.next cycles letters → match → cvc → '
      'trace → letters (Phase 7 D-15 — 4-mode cycle)', () {
    expect(StafirMode.letters.next, StafirMode.match);
    expect(StafirMode.match.next, StafirMode.cvc);
    expect(StafirMode.cvc.next, StafirMode.trace);
    expect(StafirMode.trace.next, StafirMode.letters);
  });

  testWidgets('M2: toggle renders exactly one Icon and zero Text widgets',
      (tester) async {
    await tester.pumpWidget(_host(mode: StafirMode.letters, onToggle: () {}));
    await tester.pump();
    expect(find.byType(Icon), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets(
    'M3 (Phase 12 UI-02): icon is the SAME across all modes — the '
    'toggle represents "tap-and-hold to cycle", not "current mode"',
    (tester) async {
      await tester.pumpWidget(_host(mode: StafirMode.letters, onToggle: () {}));
      await tester.pump();
      final lettersIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      await tester.pumpWidget(_host(mode: StafirMode.match, onToggle: () {}));
      await tester.pump();
      final matchIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      await tester.pumpWidget(_host(mode: StafirMode.cvc, onToggle: () {}));
      await tester.pump();
      final cvcIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      await tester.pumpWidget(_host(mode: StafirMode.trace, onToggle: () {}));
      await tester.pump();
      final traceIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      // All 4 modes share ONE icon — consistent affordance.
      final all = <IconData?>[lettersIcon, matchIcon, cvcIcon, traceIcon];
      expect(all.toSet().length, 1,
          reason: 'all 4 mode icons must be identical — '
              'the toggle is a "cycle" affordance, not a mode badge '
              '(got $all)');
    },
  );

  testWidgets(
    'M3b (Phase 12 UI-02): icon is Icons.swap_horiz across all modes',
    (tester) async {
      for (final m in StafirMode.values) {
        await tester.pumpWidget(_host(mode: m, onToggle: () {}));
        await tester.pump();
        final icon = tester.widget<Icon>(find.byType(Icon)).icon;
        expect(icon, Icons.swap_horiz,
            reason: 'mode $m must use Icons.swap_horiz');
      }
    },
  );

  testWidgets('M4: hold less than 3s does NOT toggle', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(_host(
      mode: StafirMode.letters,
      onToggle: () => callCount++,
    ));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StafirModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 0);
  });

  testWidgets('M5: hold 3s DOES toggle', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(_host(
      mode: StafirMode.letters,
      onToggle: () => callCount++,
    ));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StafirModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 3100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 1);
  });

  testWidgets('M6: after completion, holding again can re-arm', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(_host(
      mode: StafirMode.letters,
      onToggle: () => callCount++,
    ));
    await tester.pump();
    // First completion.
    var gesture = await tester.startGesture(
      tester.getCenter(find.byType(StafirModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 3100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 1);
    // Second completion — re-arms.
    gesture = await tester.startGesture(
      tester.getCenter(find.byType(StafirModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 3100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 2);
  });

  testWidgets('M7: no haptic feedback invoked during hold-to-toggle',
      (tester) async {
    // Spy on SystemChannels.platform and record method names. We pass-through
    // to the original handler so MaterialApp's chrome calls (Title widget,
    // setApplicationSwitcherDescription) keep working — we just record.
    final logged = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      logged.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ));
    var callCount = 0;
    await tester.pumpWidget(_host(
      mode: StafirMode.letters,
      onToggle: () => callCount++,
    ));
    await tester.pump();
    // Reset the log AFTER MaterialApp boot so we only see toggle interactions.
    logged.clear();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StafirModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 3100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 1);
    final hapticCalls = logged
        .where((m) => m.toLowerCase().contains('haptic'))
        .toList();
    expect(hapticCalls, isEmpty);
  });

  testWidgets('M8: small footprint (≤64×64 logical px)', (tester) async {
    await tester.pumpWidget(_host(mode: StafirMode.letters, onToggle: () {}));
    await tester.pump();
    final size = tester.getSize(find.byType(StafirModeToggle));
    expect(size.width, lessThanOrEqualTo(64));
    expect(size.height, lessThanOrEqualTo(64));
  });

  testWidgets('M9: hold ring appears only while holding', (tester) async {
    await tester.pumpWidget(_host(mode: StafirMode.letters, onToggle: () {}));
    await tester.pump();
    expect(
      find.byKey(const Key('stafir-mode-toggle-hold-ring')),
      findsNothing,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StafirModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('stafir-mode-toggle-hold-ring')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('stafir-mode-toggle-hold-ring')),
      findsNothing,
    );
  });

  testWidgets('M10: pointer cancel mid-hold aborts toggle', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(_host(
      mode: StafirMode.letters,
      onToggle: () => callCount++,
    ));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StafirModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.cancel();
    // Wait past where completion would have fired.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(callCount, 0);
  });
}
