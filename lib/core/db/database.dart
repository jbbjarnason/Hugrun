import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'dao/child_profiles_dao.dart';
import 'database.steps.dart';
import 'tables/activity_log.dart';
import 'tables/child_profiles.dart';
import 'tables/photo_tags.dart';

part 'database.g.dart';

/// AppDatabase — Hugrún's local Drift database.
///
/// `schemaVersion = 2` (Phase 10 D-01). v1 had only `child_profiles`; v2 adds
/// `photo_tags` (parent-uploaded photo overrides for matching/numeracy) and
/// `activity_log` (forward-compat for v2 parent-companion screen). The v1→v2
/// migration is non-destructive — `child_profiles` is left untouched (D-04).
///
/// Schema snapshots committed at `drift_schemas/drift_schema_v1.json` and
/// `drift_schemas/drift_schema_v2.json`.
@DriftDatabase(
  tables: [ChildProfiles, PhotoTags, ActivityLog],
  daos: [ChildProfilesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    // `stepByStep` from drift_dev `schema steps`. The v1→v2 step adds
    // photo_tags + activity_log without touching child_profiles (D-04).
    onUpgrade: stepByStep(
      from1To2: (Migrator m, Schema2 schema) async {
        await m.createTable(schema.photoTags);
        await m.createTable(schema.activityLog);
      },
    ),
  );
}

/// Real-platform connection. Uses `drift_flutter` to set up `path_provider`
/// + sqlite3 bundling. Per Phase 1 D-06, `drift_flutter` pulls
/// `sqlite3_flutter_libs` transitively; we do NOT add `sqlite3_flutter_libs`
/// as a direct dep.
QueryExecutor _openConnection() {
  return driftDatabase(name: 'hugrun');
}
