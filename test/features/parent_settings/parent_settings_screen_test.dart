// Plan 04-05 tests for ParentSettingsScreen.
// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/features/parent_settings/parent_settings_screen.dart';

ProviderScope _wrap({required AppDatabase db}) {
  // appDatabaseProvider is keepAlive top-level; the riverpod_lint
  // "scoped_providers_should_specify_dependencies" warning doesn't apply
  // to test-time overrides of an app-scoped provider, but the lint still
  // fires here. Suppressed for the file via the
  // `ignore_for_file:` directive at the top.
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: const MaterialApp(home: ParentSettingsScreen()),
  );
}

/// Pumps the widget tree, lets the Drift stream emit, runs the assertion
/// body, then unmounts BEFORE the test finishes so the Drift
/// `markAsClosed` `Timer.zero` fires inside the test's fake-async window.
/// Without this, the no-pending-timers invariant trips at teardown.
Future<void> _runWidgetThenUnmount(
  WidgetTester tester,
  Widget widget, {
  required Future<void> Function() body,
}) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await body();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  testWidgets('AppBar shows "Stillingar"', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await _runWidgetThenUnmount(
      tester,
      _wrap(db: db),
      body: () async {
        expect(find.text('Stillingar'), findsWidgets);
      },
    );
  });

  testWidgets('shows "Nafn barns" label', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await _runWidgetThenUnmount(
      tester,
      _wrap(db: db),
      body: () async {
        expect(find.text('Nafn barns'), findsOneWidget);
      },
    );
  });

  testWidgets('TextField pre-fills with current child name', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await _runWidgetThenUnmount(
      tester,
      _wrap(db: db),
      body: () async {
        final tf = tester.widget<TextField>(find.byType(TextField));
        expect(tf.controller?.text, 'Hugrún');
      },
    );
  });

  testWidgets('tapping Vista with new name calls upsertName', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await _runWidgetThenUnmount(
      tester,
      _wrap(db: db),
      body: () async {
        await tester.enterText(find.byType(TextField), 'Anna');
        await tester.tap(find.byKey(const Key('parent-settings-vista')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // Advance past the saved-confirm 1-second delay before unmount.
        await tester.pump(const Duration(seconds: 2));

        final stored = await db.childProfilesDao.readLatest();
        expect(stored?.name, 'Anna');
      },
    );
  });

  testWidgets('Vista with empty input shows error and does NOT save', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await _runWidgetThenUnmount(
      tester,
      _wrap(db: db),
      body: () async {
        await tester.enterText(find.byType(TextField), '');
        await tester.tap(find.byKey(const Key('parent-settings-vista')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Nafnið má ekki vera tómt'), findsOneWidget);
        final stored = await db.childProfilesDao.readLatest();
        expect(stored?.name, 'Hugrún', reason: 'name was not changed');
      },
    );
  });

  testWidgets('Vista with whitespace-only input is treated as empty', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await _runWidgetThenUnmount(
      tester,
      _wrap(db: db),
      body: () async {
        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.byKey(const Key('parent-settings-vista')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Nafnið má ekki vera tómt'), findsOneWidget);
      },
    );
  });

  testWidgets('Vista with name >32 chars shows error', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await _runWidgetThenUnmount(
      tester,
      _wrap(db: db),
      body: () async {
        await tester.enterText(find.byType(TextField), 'x' * 33);
        await tester.tap(find.byKey(const Key('parent-settings-vista')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.text('Nafn má ekki vera lengra en 32 stafir'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('after successful save, "Vistað ✓" shows briefly', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await _runWidgetThenUnmount(
      tester,
      _wrap(db: db),
      body: () async {
        await tester.enterText(find.byType(TextField), 'Sigga');
        await tester.tap(find.byKey(const Key('parent-settings-vista')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.byKey(const Key('parent-settings-saved-confirm')),
          findsOneWidget,
        );
        expect(find.text('Vistað ✓'), findsOneWidget);
        // Wait past the 1-second visible window.
        await tester.pump(const Duration(seconds: 2));
        // Confirmation should be hidden afterwards.
        expect(
          find.byKey(const Key('parent-settings-saved-confirm')),
          findsNothing,
        );
      },
    );
  });

  group('validateChildName (pure)', () {
    test('null on valid name', () {
      expect(validateChildName('Hugrún'), isNull);
      expect(validateChildName('  Anna  '), isNull); // trimmed
      expect(validateChildName('a'), isNull); // 1 char
      expect(validateChildName('x' * 32), isNull); // exactly 32
    });

    test('error on empty / whitespace', () {
      expect(validateChildName(''), 'Nafnið má ekki vera tómt');
      expect(validateChildName('   '), 'Nafnið má ekki vera tómt');
      expect(validateChildName('\t\n'), 'Nafnið má ekki vera tómt');
    });

    test('error on >32 chars', () {
      expect(
        validateChildName('x' * 33),
        'Nafn má ekki vera lengra en 32 stafir',
      );
    });
  });
}
