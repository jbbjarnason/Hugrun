// Plan 04-05 RED tests for ParentSettingsScreen.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/features/parent_settings/parent_settings_screen.dart';

ProviderScope _wrap({required AppDatabase db}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: const MaterialApp(home: ParentSettingsScreen()),
  );
}

void main() {
  testWidgets('AppBar shows "Stillingar"', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();
    expect(find.text('Stillingar'), findsWidgets);
  });

  testWidgets('shows "Nafn barns" label', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();
    expect(find.text('Nafn barns'), findsOneWidget);
  });

  testWidgets('TextField pre-fills with current child name', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.controller?.text, 'Hugrún');
  });

  testWidgets('tapping Vista with new name calls upsertName', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();

    // Replace text by clearing and entering new name.
    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.tap(find.byKey(const Key('parent-settings-vista')));
    await tester.pump();
    await tester.pumpAndSettle();

    final stored = await db.childProfilesDao.readLatest();
    expect(stored?.name, 'Anna');
  });

  testWidgets('Vista with empty input shows error and does NOT save', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byKey(const Key('parent-settings-vista')));
    await tester.pumpAndSettle();

    expect(find.text('Nafnið má ekki vera tómt'), findsOneWidget);
    final stored = await db.childProfilesDao.readLatest();
    expect(stored?.name, 'Hugrún', reason: 'name was not changed');
  });

  testWidgets('Vista with whitespace-only input is treated as empty', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byKey(const Key('parent-settings-vista')));
    await tester.pumpAndSettle();

    expect(find.text('Nafnið má ekki vera tómt'), findsOneWidget);
  });

  testWidgets('Vista with name >32 chars shows error', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'x' * 33);
    await tester.tap(find.byKey(const Key('parent-settings-vista')));
    await tester.pumpAndSettle();

    expect(find.text('Nafn má ekki vera lengra en 32 stafir'), findsOneWidget);
  });

  testWidgets('after successful save, "Vistað ✓" shows briefly', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sigga');
    await tester.tap(find.byKey(const Key('parent-settings-vista')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('parent-settings-saved-confirm')), findsOneWidget);
    expect(find.text('Vistað ✓'), findsOneWidget);
    // Wait past the 1-second visible window.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    // Confirmation should be hidden afterwards.
    expect(
      find.byKey(const Key('parent-settings-saved-confirm')),
      findsNothing,
    );
  });
}
