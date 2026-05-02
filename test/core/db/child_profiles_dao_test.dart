// Alias drift imports — `drift/drift.dart` exports an `isNotNull` operator
// (column predicate builder) that clashes with `matcher`'s `isNotNull` matcher.
import 'package:drift/drift.dart' show InvalidDataException;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('count() is 0 on fresh db', () async {
    expect(await db.childProfilesDao.count(), 0);
  });

  test('upsertName then readLatest returns inserted row', () async {
    await db.childProfilesDao.upsertName(name: 'Test');
    final row = await db.childProfilesDao.readLatest();
    expect(row, isNotNull);
    expect(row!.name, 'Test');
  });

  test('upsertName twice keeps singleton (count == 1, latest wins)', () async {
    await db.childProfilesDao.upsertName(name: 'New');
    await db.childProfilesDao.upsertName(name: 'Newer');
    expect(await db.childProfilesDao.count(), 1);
    expect((await db.childProfilesDao.readLatest())!.name, 'Newer');
  });

  test('name length constraint enforces 1..32', () async {
    expect(
      () async => db.childProfilesDao.upsertName(name: ''),
      throwsA(isA<InvalidDataException>()),
    );
    expect(
      () async => db.childProfilesDao.upsertName(name: 'x' * 33),
      throwsA(isA<InvalidDataException>()),
    );
  });

  test('watchLatest emits inserted then updated', () async {
    final emissions = <String?>[];
    final sub = db.childProfilesDao.watchLatest().listen(
      (row) => emissions.add(row?.name),
    );
    await db.childProfilesDao.upsertName(name: 'A');
    await db.childProfilesDao.upsertName(name: 'B');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(
      emissions.where((n) => n == 'A' || n == 'B'),
      containsAll(['A', 'B']),
    );
  });
}
