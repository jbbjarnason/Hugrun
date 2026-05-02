import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('ensureDefaultChildProfile inserts "Hugrún" on empty db', () async {
    await ensureDefaultChildProfile(db);
    final row = await db.childProfilesDao.readLatest();
    expect(row?.name, 'Hugrún');
    expect(await db.childProfilesDao.count(), 1);
  });

  test(
    'ensureDefaultChildProfile is idempotent (re-run does not duplicate)',
    () async {
      await ensureDefaultChildProfile(db);
      await ensureDefaultChildProfile(db);
      expect(await db.childProfilesDao.count(), 1);
    },
  );

  test(
    'ensureDefaultChildProfile does not overwrite existing custom name',
    () async {
      await db.childProfilesDao.upsertName(name: 'Other');
      await ensureDefaultChildProfile(db);
      expect((await db.childProfilesDao.readLatest())!.name, 'Other');
    },
  );
}
