// Phase 8 Plan 08-04 Workstream D — RED tests for TolurMode + TolurModeToggle.
//
// Mirror of Phase 5/6's StafirModeToggle test (M1..M10 reused as TM1..TM10).
// 3-second hold → onToggle. Reuses Phase 1's ParentGateController.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/features/tolur/tolur_mode.dart';
import 'package:hugrun/features/tolur/widgets/tolur_mode_toggle.dart';

Widget _host({
  required TolurMode mode,
  required VoidCallback onToggle,
  Duration holdDuration = const Duration(seconds: 3),
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: TolurModeToggle(
        currentMode: mode,
        onToggle: onToggle,
        holdDuration: holdDuration,
      ),
    ),
  ),
);

void main() {
  test(
    'TM1: TolurMode.values is exactly [tapToHear, activity] (Phase 9 D-15)',
    () {
      expect(TolurMode.values, <TolurMode>[
        TolurMode.tapToHear,
        TolurMode.activity,
      ]);
    },
  );

  test(
    'TM1b: TolurModeToggleExt.next cycles tapToHear → activity → tapToHear',
    () {
      expect(TolurMode.tapToHear.next, TolurMode.activity);
      expect(TolurMode.activity.next, TolurMode.tapToHear);
    },
  );

  testWidgets('TM2: toggle renders exactly one Icon and zero Text widgets', (
    tester,
  ) async {
    await tester.pumpWidget(_host(mode: TolurMode.tapToHear, onToggle: () {}));
    await tester.pump();
    expect(find.byType(Icon), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('TM3 (Phase 12 UI-02): icon is the SAME across modes — '
      'consistent "cycle" affordance, not a mode badge', (tester) async {
    await tester.pumpWidget(_host(mode: TolurMode.tapToHear, onToggle: () {}));
    await tester.pump();
    final tthIcon = tester.widget<Icon>(find.byType(Icon)).icon;

    await tester.pumpWidget(_host(mode: TolurMode.activity, onToggle: () {}));
    await tester.pump();
    final actIcon = tester.widget<Icon>(find.byType(Icon)).icon;

    expect(
      tthIcon,
      actIcon,
      reason: 'both modes must use the same toggle icon',
    );
  });

  testWidgets('TM3b (Phase 12 UI-02): icon is Icons.swap_horiz across modes — '
      'matches StafirModeToggle (M3b)', (tester) async {
    for (final m in TolurMode.values) {
      await tester.pumpWidget(_host(mode: m, onToggle: () {}));
      await tester.pump();
      final icon = tester.widget<Icon>(find.byType(Icon)).icon;
      expect(
        icon,
        Icons.swap_horiz,
        reason: 'mode $m must use Icons.swap_horiz',
      );
    }
  });

  testWidgets('TM4: hold less than 3s does NOT toggle', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(
      _host(mode: TolurMode.tapToHear, onToggle: () => callCount++),
    );
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TolurModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 0);
  });

  testWidgets('TM5: hold 3s DOES toggle', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(
      _host(mode: TolurMode.tapToHear, onToggle: () => callCount++),
    );
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TolurModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 3100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 1);
  });

  testWidgets('TM6: pointer cancel mid-hold aborts toggle', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(
      _host(mode: TolurMode.tapToHear, onToggle: () => callCount++),
    );
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TolurModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(callCount, 0);
  });

  testWidgets('TM7: small footprint (≤64×64 logical px)', (tester) async {
    await tester.pumpWidget(_host(mode: TolurMode.tapToHear, onToggle: () {}));
    await tester.pump();
    final size = tester.getSize(find.byType(TolurModeToggle));
    expect(size.width, lessThanOrEqualTo(64));
    expect(size.height, lessThanOrEqualTo(64));
  });

  testWidgets('TM8: hold ring appears only while holding', (tester) async {
    await tester.pumpWidget(_host(mode: TolurMode.tapToHear, onToggle: () {}));
    await tester.pump();
    expect(find.byKey(const Key('tolur-mode-toggle-hold-ring')), findsNothing);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TolurModeToggle)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('tolur-mode-toggle-hold-ring')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('tolur-mode-toggle-hold-ring')), findsNothing);
  });
}
