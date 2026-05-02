import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/database.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;
  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('schemaAt(1) opens v1 snapshot with child_profiles table', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase.forTesting(connection.executor);
    addTearDown(db.close);

    final result = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='child_profiles'",
        )
        .get();
    expect(result, hasLength(1));
  });

  test('schemaAt(1) round-trips a row through current schema', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase.forTesting(connection.executor);
    addTearDown(db.close);

    await db.childProfilesDao.upsertName(name: 'Hugrún');
    final row = await db.childProfilesDao.readLatest();
    expect(row?.name, 'Hugrún');
  });
}
