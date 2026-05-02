import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'dao/child_profiles_dao.dart';
import 'database.steps.dart';
import 'tables/child_profiles.dart';

part 'database.g.dart';

/// AppDatabase — Hugrún's local Drift database.
///
/// `schemaVersion = 1` (D-04). Migration strategy uses `stepByStep` so future
/// versions can layer migrations without rewriting v1 (D-04). A snapshot of the
/// v1 schema is committed at `drift_schemas/v1.json` (D-05).
@DriftDatabase(tables: [ChildProfiles], daos: [ChildProfilesDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    // Generated `stepByStep` from drift_dev `schema steps` — empty at v1
    // but the framework is wired so Phase 10's v1→v2 step lands cleanly.
    onUpgrade: stepByStep(),
  );
}

/// Real-platform connection. Uses `drift_flutter` to set up `path_provider`
/// + sqlite3 bundling. Per D-06, `drift_flutter` pulls `sqlite3_flutter_libs`
/// transitively; we do NOT add `sqlite3_flutter_libs` as a direct dep.
QueryExecutor _openConnection() {
  return driftDatabase(name: 'hugrun');
}
