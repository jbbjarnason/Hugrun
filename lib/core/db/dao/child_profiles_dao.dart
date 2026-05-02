import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/child_profiles.dart';

part 'child_profiles_dao.g.dart';

/// Data-access object for [ChildProfiles].
///
/// Singleton semantics enforced at the DAO layer — there is at most one row.
/// `upsertName` updates the existing row in-place, or inserts if empty.
@DriftAccessor(tables: [ChildProfiles])
class ChildProfilesDao extends DatabaseAccessor<AppDatabase>
    with _$ChildProfilesDaoMixin {
  ChildProfilesDao(super.db);

  /// Returns the count of profiles. Used by bootstrap to detect "first run."
  Future<int> count() async {
    final query = selectOnly(childProfiles)
      ..addColumns([childProfiles.id.count()]);
    return query.map((row) => row.read(childProfiles.id.count())!).getSingle();
  }

  /// Returns the latest profile (singleton), or null if empty.
  Future<ChildProfile?> readLatest() {
    return (select(childProfiles)
          ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Reactive variant for Phase 4 / parent_settings UI.
  Stream<ChildProfile?> watchLatest() {
    return (select(childProfiles)
          ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Upsert child name — singleton semantics: if a row exists, update the
  /// latest in-place; otherwise insert. Maintains `count() == 1`.
  Future<void> upsertName({required String name}) async {
    final existing = await readLatest();
    if (existing == null) {
      await into(childProfiles).insert(
        ChildProfilesCompanion.insert(name: name, createdAt: DateTime.now()),
      );
    } else {
      await (update(childProfiles)..where((t) => t.id.equals(existing.id)))
          .write(ChildProfilesCompanion(name: Value(name)));
    }
  }
}
