// Plan 04-05 RED tests for childNameProvider.
// Uses an in-memory Drift database via NativeDatabase.memory().

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/features/parent_settings/child_name_provider.dart';

void main() {
  test(
    'childNameProvider emits "Hugrún" after ensureDefaultChildProfile',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ensureDefaultChildProfile(db);

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // Read the stream and await first non-loading value.
      final firstValue = await container
          .read(childNameProvider.future)
          .timeout(const Duration(seconds: 2));
      expect(firstValue, 'Hugrún');
    },
  );

  test('childNameProvider streams updated value when DAO upsertName fires', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ensureDefaultChildProfile(db);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // Subscribe and capture emissions.
    final emissions = <String?>[];
    final sub = container.listen<AsyncValue<String?>>(
      childNameProvider,
      (_, value) {
        if (value is AsyncData<String?>) {
          emissions.add(value.value);
        }
      },
      fireImmediately: true,
    );
    // Wait for the initial 'Hugrún'.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(emissions.last, 'Hugrún');

    await db.childProfilesDao.upsertName(name: 'Anna');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(emissions.contains('Anna'), isTrue);

    sub.close();
  });

  test('childNameProvider emits null when child_profiles table is empty', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // No bootstrap — table is empty.

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final firstValue = await container
        .read(childNameProvider.future)
        .timeout(const Duration(seconds: 2));
    expect(firstValue, isNull);
  });
}
