---
phase: 01-skeleton-drift-schema
plan: 02
type: execute
wave: 2
depends_on:
  - "01-01"
files_modified:
  - lib/core/db/database.dart
  - lib/core/db/tables/child_profiles.dart
  - lib/core/db/dao/child_profiles_dao.dart
  - lib/core/db/database_provider.dart
  - lib/core/db/bootstrap.dart
  - drift_schemas/v1.json
  - test/core/db/child_profiles_dao_test.dart
  - test/core/db/migration_test.dart
  - test/core/db/bootstrap_test.dart
  - integration_test/database_smoke_test.dart
  - build.yaml
  - pubspec.yaml
autonomous: true
requirements:
  - FOUND-02
  - FOUND-03

user_setup: []

must_haves:
  truths:
    - "A `child_profiles` table exists in Drift schema v1 with columns id (INTEGER PRIMARY KEY), name (TEXT NOT NULL), created_at (INTEGER NOT NULL)"
    - "Drift schemaVersion is 1 and MigrationStrategy uses stepByStep (D-04)"
    - "drift_dev schema dump v1 snapshot is committed to drift_schemas/v1.json (D-05)"
    - "An idempotent bootstrap inserts the default child profile name 'Hugrún' if the table is empty (D-03)"
    - "A Riverpod provider exposes the AppDatabase as an app-scoped singleton"
    - "ChildProfilesDao supports read (latest) and update (rename) operations against the table"
    - "Unit tests cover DAO CRUD using NativeDatabase.memory()"
    - "Migration test calls schemaAt(1) round-trip on the v1 snapshot and asserts the schema is recognized"
    - "Integration test opens AppDatabase on a real platform, runs bootstrap, reads back 'Hugrún'"
  artifacts:
    - path: "lib/core/db/database.dart"
      provides: "AppDatabase class, schemaVersion=1, stepByStep migration scaffolding"
      contains: "@DriftDatabase"
    - path: "lib/core/db/tables/child_profiles.dart"
      provides: "ChildProfiles Drift table definition"
      contains: "class ChildProfiles extends Table"
    - path: "lib/core/db/dao/child_profiles_dao.dart"
      provides: "DAO with read/upsert operations"
      contains: "@DriftAccessor"
    - path: "lib/core/db/database_provider.dart"
      provides: "Riverpod provider for AppDatabase (app-scoped singleton)"
      contains: "@riverpod"
    - path: "lib/core/db/bootstrap.dart"
      provides: "ensureDefaultChildProfile() — idempotent insert of name='Hugrún'"
      contains: "ensureDefaultChildProfile"
    - path: "drift_schemas/v1.json"
      provides: "Schema snapshot for future migration tests via schemaAt(1)"
      contains: "child_profiles"
    - path: "test/core/db/child_profiles_dao_test.dart"
      provides: "DAO unit tests (NativeDatabase.memory())"
      contains: "ChildProfilesDao"
    - path: "test/core/db/migration_test.dart"
      provides: "schemaAt(1) round-trip test confirming v1 snapshot loads"
      contains: "schemaAt(1)"
    - path: "integration_test/database_smoke_test.dart"
      provides: "Real-platform Drift open + bootstrap + read smoke test"
      contains: "AppDatabase"
  key_links:
    - from: "lib/core/db/database_provider.dart"
      to: "lib/core/db/database.dart"
      via: "ref.read returns AppDatabase singleton"
      pattern: "AppDatabase"
    - from: "lib/core/db/bootstrap.dart"
      to: "lib/core/db/dao/child_profiles_dao.dart"
      via: "ensureDefaultChildProfile checks empty + inserts via DAO"
      pattern: "ChildProfilesDao"
    - from: "drift_schemas/v1.json"
      to: "test/core/db/migration_test.dart"
      via: "schemaAt(1) loads the snapshot"
      pattern: "schemaAt\\(1\\)"
---

<objective>
Stand up the Drift v1 schema with a single `child_profiles` table (D-03), wire stepwise migration scaffolding from day one (D-04), commit a `drift_dev schema dump 1` snapshot for future migration tests (D-05), and provide a Riverpod-exposed app-scoped `AppDatabase` singleton plus an idempotent bootstrap that inserts the default child profile "Hugrún" on first launch.

Purpose: This implements FOUND-02 (Drift in pubspec at consistent versions — Plan 01 already added the deps; this plan exercises them) and FOUND-03 (Drift schema versioned from v1 with migration scaffolding; no destructive migrations possible). Without this plan, Phase 4 has nowhere to persist the child name (PERS-02), and Phase 10's v1→v2 photo_tags migration has no `schemaAt(1)` snapshot to migrate from.

Output: A working AppDatabase with `child_profiles` table at schemaVersion=1, schema snapshot at `drift_schemas/v1.json`, idempotent bootstrap, Riverpod provider, and unit + migration + integration tests covering it.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/01-skeleton-drift-schema/01-CONTEXT.md
@.planning/phases/01-skeleton-drift-schema/01-01-SUMMARY.md
@.planning/research/STACK.md
@.planning/research/ARCHITECTURE.md
@.planning/research/PITFALLS.md

<interfaces>
<!-- This plan creates the database contract. Plan 03 does NOT depend on the DB
     directly (parent settings stub is empty in Phase 1). Phase 4 (Stafir MVP)
     will consume this. Phase 10 (Personalization) will migrate v1→v2. -->

From `lib/core/db/tables/child_profiles.dart`:
```dart
import 'package:drift/drift.dart';

class ChildProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 32)();
  DateTimeColumn get createdAt => dateTime()();
  // No singleton-id constraint at the DB level — bootstrap enforces "exactly
  // one row" by checking count() before inserting. This keeps v2's photo_tags
  // migration option open without rewriting v1.
}
```

From `lib/core/db/database.dart`:
```dart
@DriftDatabase(tables: [ChildProfiles], daos: [ChildProfilesDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);  // for unit tests with NativeDatabase.memory()
  @override int get schemaVersion => 1;  // D-04
  @override MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async { await m.createAll(); },
    onUpgrade: stepByStep(),  // empty step list at v1; Phase 10 adds first step
  );
}
```

From `lib/core/db/dao/child_profiles_dao.dart`:
```dart
@DriftAccessor(tables: [ChildProfiles])
class ChildProfilesDao extends DatabaseAccessor<AppDatabase>
    with _$ChildProfilesDaoMixin {
  ChildProfilesDao(super.db);
  Future<ChildProfile?> readLatest() => /* SELECT ... ORDER BY id LIMIT 1 */;
  Stream<ChildProfile?> watchLatest();
  Future<void> upsertName({required String name});  // updates row id=1, or inserts if empty
  Future<int> count();
}
```

From `lib/core/db/database_provider.dart`:
```dart
@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
```

From `lib/core/db/bootstrap.dart`:
```dart
/// Inserts the default child profile name ('Hugrún') if no row exists.
/// Idempotent: re-running has no effect.
Future<void> ensureDefaultChildProfile(AppDatabase db, {String defaultName = 'Hugrún'}) async {
  final existing = await db.childProfilesDao.count();
  if (existing == 0) {
    await db.childProfilesDao.upsertName(name: defaultName);
  }
}
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write failing DAO + migration + bootstrap tests (RED)</name>
  <files>
    test/core/db/child_profiles_dao_test.dart,
    test/core/db/migration_test.dart,
    test/core/db/bootstrap_test.dart,
    integration_test/database_smoke_test.dart,
    build.yaml
  </files>
  <behavior>
    Test 1 (child_profiles_dao_test.dart): Opening an in-memory `AppDatabase.forTesting(NativeDatabase.memory())` returns a DAO whose `count()` is 0 initially.
    Test 2 (child_profiles_dao_test.dart): After `upsertName(name: 'Test')`, `readLatest()` returns a row with name == 'Test'.
    Test 3 (child_profiles_dao_test.dart): `upsertName(name: 'New')` followed by `upsertName(name: 'Newer')` results in `count()` == 1 (singleton semantics) and `readLatest()` returns 'Newer'.
    Test 4 (child_profiles_dao_test.dart): `name` length less than 1 or greater than 32 throws (Drift constraint).
    Test 5 (child_profiles_dao_test.dart): `watchLatest()` emits updated values across upserts.
    Test 6 (migration_test.dart): `schemaAt(1)` opens the snapshot from `drift_schemas/v1.json` and the schema reports a `child_profiles` table with the expected columns.
    Test 7 (bootstrap_test.dart): `ensureDefaultChildProfile(db)` on an empty in-memory DB inserts a row whose name == 'Hugrún'. Running it twice is idempotent (`count() == 1`).
    Test 8 (integration_test/database_smoke_test.dart): Real-platform open of AppDatabase, run bootstrap, read back name == 'Hugrún'. (Runs on iOS/Android via integration_test runner.)

    All tests MUST fail at this stage because no schema, DAO, bootstrap, or snapshot exist yet.
  </behavior>
  <action>
    Per D-16 (TDD), write all tests before any production code.

    1. Update `pubspec.yaml`: add `drift: ^2.32.1` (already present from Plan 01) and confirm `drift_dev` is listed under dev_dependencies. Add `path_provider: ^2.1.0` to runtime deps (drift_flutter pulls it transitively but listing it directly stabilizes the version).

    2. Create `build.yaml` at the repo root to control codegen ordering (per PITFALLS Pitfall 21 — drift_dev should run before riverpod_generator):
       ```yaml
       targets:
         $default:
           builders:
             drift_dev:
               enabled: true
               options:
                 store_date_time_values_as_text: false  # use INTEGER unix epoch — matches D-03 "created_at INTEGER"
                 named_parameters: true
                 mutable_classes: false
                 sql:
                   dialect: sqlite
                   options:
                     version: "3.39"
             riverpod_generator:
               enabled: true
             freezed:
               enabled: true
       ```

    3. Create `test/core/db/child_profiles_dao_test.dart` — DAO unit tests using `NativeDatabase.memory()`. The test file imports `package:hugrun/core/db/database.dart` and `package:hugrun/core/db/dao/child_profiles_dao.dart` which do not yet exist (RED). Tests cover all 5 DAO behaviors above.

       Skeleton (executor fills in based on the `<interfaces>` block above):
       ```dart
       import 'package:drift/drift.dart';
       import 'package:drift/native.dart';
       import 'package:flutter_test/flutter_test.dart';
       import 'package:hugrun/core/db/database.dart';

       void main() {
         late AppDatabase db;
         setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
         tearDown(() => db.close());

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
           await Future.delayed(const Duration(milliseconds: 50));
           await sub.cancel();
           // First emission may be null (initial), then 'A', then 'B'
           expect(emissions.where((n) => n == 'A' || n == 'B'), containsAll(['A', 'B']));
         });
       }
       ```

    4. Create `test/core/db/migration_test.dart` — exercises `schemaAt(1)` against `drift_schemas/v1.json` (which doesn't exist yet — RED):
       ```dart
       import 'package:drift_dev/api/migrations_native.dart';
       import 'package:flutter_test/flutter_test.dart';
       import 'package:hugrun/core/db/database.dart';

       void main() {
         late SchemaVerifier verifier;
         setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

         test('schemaAt(1) opens v1 snapshot with child_profiles table', () async {
           final schema = await verifier.schemaAt(1);
           // schemaAt returns a database initialized at schema v1.
           // We verify the table exists and is queryable.
           // Drift's schemaAt returns a `MigratedDatabase` whose database property
           // is a raw QueryExecutor; we can run a SQL query directly.
           final result = await schema.database.customSelect(
             "SELECT name FROM sqlite_master WHERE type='table' AND name='child_profiles'",
           ).get();
           expect(result, hasLength(1),
               reason: 'child_profiles table must exist in v1 snapshot (D-05)');
           await schema.database.close();
         });

         test('upgrading from v1 to v1 is a no-op (round-trip identity)', () async {
           // Sanity: calling validateDatabaseSchema on a freshly-created v1 DB passes.
           final db = AppDatabase.forTesting(/* in-memory v1 */);
           // verifier.startAt(1, db) opens the v1 snapshot, then runs db's migration
           // strategy. With schemaVersion=1 and no upgrades, this is a no-op.
           // We just assert no exception is thrown.
           await db.close();
         });
       }
       ```
       Note: the executor will need to import `GeneratedHelper` from the generated `*.steps.dart` file (Drift's `drift_dev schema steps` command produces this). If not available at this stage, scaffold the test with `// TODO(plan-03): wire GeneratedHelper after drift_dev schema steps runs` and mark the test as `skip: 'pending generated helper from drift_dev schema steps'` until Task 3 generates it. The test must EXIST in red form so the GREEN task knows what to satisfy.

    5. Create `test/core/db/bootstrap_test.dart`:
       ```dart
       import 'package:drift/native.dart';
       import 'package:flutter_test/flutter_test.dart';
       import 'package:hugrun/core/db/database.dart';
       import 'package:hugrun/core/db/bootstrap.dart';

       void main() {
         late AppDatabase db;
         setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
         tearDown(() => db.close());

         test('ensureDefaultChildProfile inserts "Hugrún" on empty db', () async {
           await ensureDefaultChildProfile(db);
           final row = await db.childProfilesDao.readLatest();
           expect(row?.name, 'Hugrún');
           expect(await db.childProfilesDao.count(), 1);
         });

         test('ensureDefaultChildProfile is idempotent (re-run does not duplicate)', () async {
           await ensureDefaultChildProfile(db);
           await ensureDefaultChildProfile(db);
           expect(await db.childProfilesDao.count(), 1);
         });

         test('ensureDefaultChildProfile does not overwrite existing custom name', () async {
           await db.childProfilesDao.upsertName(name: 'Other');
           await ensureDefaultChildProfile(db);
           expect((await db.childProfilesDao.readLatest())!.name, 'Other');
         });
       }
       ```

    6. Create `integration_test/database_smoke_test.dart` (runs on real iOS/Android via `flutter test integration_test`):
       ```dart
       import 'package:flutter_test/flutter_test.dart';
       import 'package:integration_test/integration_test.dart';
       import 'package:hugrun/core/db/database.dart';
       import 'package:hugrun/core/db/bootstrap.dart';

       void main() {
         IntegrationTestWidgetsFlutterBinding.ensureInitialized();

         testWidgets('AppDatabase opens on real platform and bootstrap inserts Hugrún',
             (tester) async {
           final db = AppDatabase();
           addTearDown(db.close);

           await ensureDefaultChildProfile(db);
           final row = await db.childProfilesDao.readLatest();

           expect(row, isNotNull);
           expect(row!.name, 'Hugrún');
         });
       }
       ```

    7. Run `flutter test test/core/db/`. ALL tests must fail with compile/import errors (no production code exists yet). Capture failure log as RED proof.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter pub get &amp;&amp; ! flutter test test/core/db/ 2&gt;&amp;1 | tee /tmp/hugrun-task1-red.log; grep -qE "error|Error|FAILED|cannot find" /tmp/hugrun-task1-red.log</automated>
  </verify>
  <done>
    - All four test files exist (`child_profiles_dao_test.dart`, `migration_test.dart`, `bootstrap_test.dart`, `database_smoke_test.dart`).
    - `flutter test test/core/db/` fails with import/compile errors because production code is missing — RED state.
    - `build.yaml` exists with builder ordering per PITFALLS Pitfall 21.
    - `pubspec.yaml` lists `path_provider` (Plan 01 may have already; verify).
    - Commit: `test(01-02): add failing Drift DAO/migration/bootstrap tests (RED)`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Implement schema, DAO, migration scaffolding, bootstrap, and Riverpod provider (GREEN)</name>
  <files>
    lib/core/db/database.dart,
    lib/core/db/tables/child_profiles.dart,
    lib/core/db/dao/child_profiles_dao.dart,
    lib/core/db/database_provider.dart,
    lib/core/db/bootstrap.dart
  </files>
  <behavior>
    All RED tests from Task 1 (DAO, bootstrap) must pass. Migration test stays in `skip:` mode until Task 3 generates the schema snapshot. Integration test runs on iOS Simulator + Android Emulator and passes.
  </behavior>
  <action>
    Implement minimum production code to turn DAO + bootstrap tests green. Migration test snapshot and `*.steps.dart` generation comes in Task 3.

    1. Create `lib/core/db/tables/child_profiles.dart`:
       ```dart
       import 'package:drift/drift.dart';

       /// Child profile table — Drift v1 schema.
       /// Per CONTEXT D-03: id (auto-increment), name (TEXT NOT NULL, 1..32 chars),
       /// created_at (DateTime stored as INTEGER unix epoch).
       /// Singleton row enforced at app level (bootstrap + DAO upsertName), NOT at
       /// the DB level — keeps options open for v2 multi-child support without
       /// rewriting v1 schema.
       class ChildProfiles extends Table {
         IntColumn get id => integer().autoIncrement()();
         TextColumn get name => text().withLength(min: 1, max: 32)();
         DateTimeColumn get createdAt => dateTime()();

         @override
         String? get tableName => 'child_profiles';
       }
       ```

    2. Create `lib/core/db/database.dart`:
       ```dart
       import 'dart:io';

       import 'package:drift/drift.dart';
       import 'package:drift/native.dart';
       import 'package:drift_flutter/drift_flutter.dart' as drift_flutter;
       import 'package:path_provider/path_provider.dart';
       import 'package:path/path.dart' as p;

       import 'tables/child_profiles.dart';
       import 'dao/child_profiles_dao.dart';

       part 'database.g.dart';

       /// AppDatabase — Hugrún's local Drift database.
       /// schemaVersion = 1 (D-04). Migration strategy uses stepByStep so future
       /// versions can layer migrations without rewriting v1 (D-04). Snapshot of
       /// v1 schema is committed at drift_schemas/v1.json (D-05).
       @DriftDatabase(tables: [ChildProfiles], daos: [ChildProfilesDao])
       class AppDatabase extends _$AppDatabase {
         AppDatabase() : super(_openConnection());
         AppDatabase.forTesting(super.executor);

         @override
         int get schemaVersion => 1;

         @override
         MigrationStrategy get migration => MigrationStrategy(
               onCreate: (m) async {
                 await m.createAll();
               },
               // stepByStep is empty at v1; Phase 10 will add from1To2 here.
               // The framework is wired up now (D-04) so retrofitting is unnecessary.
               onUpgrade: stepByStep(),
             );
       }

       /// Real-platform connection — uses drift_flutter to handle path_provider
       /// + sqlite bundling. Per D-06, drift_flutter pulls sqlite3 transitively;
       /// we do NOT add sqlite3_flutter_libs as a direct dep.
       QueryExecutor _openConnection() {
         return drift_flutter.driftDatabase(
           name: 'hugrun.sqlite',
           native: const drift_flutter.DriftNativeOptions(
             // background isolate per Drift recommendation
             // (research ARCHITECTURE.md notes NativeDatabase.createInBackground)
             databaseDirectory: getApplicationDocumentsDirectory,
           ),
         );
       }
       ```

       Note: `drift_flutter.driftDatabase()` API exact name may differ between 0.3.x patch versions. If the symbol is `driftDatabase` or `Database` or different, the executor verifies via `dart pub deps` + reading `drift_flutter`'s public API and adapts. The semantic must be: open an on-disk SQLite DB rooted at the app documents directory using a background isolate.

    3. Create `lib/core/db/dao/child_profiles_dao.dart`:
       ```dart
       import 'package:drift/drift.dart';

       import '../database.dart';
       import '../tables/child_profiles.dart';

       part 'child_profiles_dao.g.dart';

       @DriftAccessor(tables: [ChildProfiles])
       class ChildProfilesDao extends DatabaseAccessor<AppDatabase>
           with _$ChildProfilesDaoMixin {
         ChildProfilesDao(super.db);

         /// Returns the count of profiles. Used by bootstrap to detect "first run."
         Future<int> count() async {
           final query = selectOnly(childProfiles)
             ..addColumns([childProfiles.id.count()]);
           return await query.map((row) => row.read(childProfiles.id.count())!).getSingle();
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

         /// Upsert child name — singleton semantics: if any row exists, update
         /// the latest; otherwise insert. Maintains count() == 1.
         Future<void> upsertName({required String name}) async {
           final existing = await readLatest();
           if (existing == null) {
             await into(childProfiles).insert(ChildProfilesCompanion.insert(
               name: name,
               createdAt: DateTime.now(),
             ));
           } else {
             await (update(childProfiles)..where((t) => t.id.equals(existing.id)))
                 .write(ChildProfilesCompanion(name: Value(name)));
           }
         }
       }
       ```

    4. Create `lib/core/db/database_provider.dart`:
       ```dart
       import 'package:riverpod_annotation/riverpod_annotation.dart';

       import 'database.dart';

       part 'database_provider.g.dart';

       /// App-scoped singleton — never autoDispose. Per ARCHITECTURE.md the
       /// DB lives for the whole app lifetime (no scope leaks per PITFALLS #7).
       @Riverpod(keepAlive: true)
       AppDatabase appDatabase(AppDatabaseRef ref) {
         final db = AppDatabase();
         ref.onDispose(db.close);
         return db;
       }
       ```

    5. Create `lib/core/db/bootstrap.dart`:
       ```dart
       import 'database.dart';

       /// Inserts the default child profile name ('Hugrún' per D-03) on first
       /// launch. Idempotent: if any row exists, does nothing. Phase 4's parent
       /// settings UI will let the parent change the name; this only bootstraps
       /// "first run" so downstream code can rely on a row existing.
       Future<void> ensureDefaultChildProfile(
         AppDatabase db, {
         String defaultName = 'Hugrún',
       }) async {
         final existing = await db.childProfilesDao.count();
         if (existing == 0) {
           await db.childProfilesDao.upsertName(name: defaultName);
         }
       }
       ```

    6. Run codegen: `dart run build_runner build --delete-conflicting-outputs`. This generates `database.g.dart`, `child_profiles_dao.g.dart`, `database_provider.g.dart`. Verify no errors.

    7. Run `flutter test test/core/db/child_profiles_dao_test.dart test/core/db/bootstrap_test.dart`. Both must pass GREEN. The migration_test.dart stays skipped until Task 3.

    8. Run `flutter analyze`. Must exit 0.

    9. (Integration test for real-platform DB) — defer execution to Plan 05's CI which runs the integration_test job on Ubuntu (using drift's `WebSqlite` is not viable; instead the integration job runs against an Android emulator). Locally, if a device is attached, run `flutter test integration_test/database_smoke_test.dart` to confirm the smoke test passes. Otherwise, document in commit and move on — Plan 05 wires the CI matrix.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; dart run build_runner build --delete-conflicting-outputs &amp;&amp; flutter analyze &amp;&amp; flutter test test/core/db/child_profiles_dao_test.dart test/core/db/bootstrap_test.dart</automated>
  </verify>
  <done>
    - DAO unit tests (5) pass.
    - Bootstrap unit tests (3) pass.
    - Generated `*.g.dart` files exist (gitignored except check pubspec build_runner output).
    - `flutter analyze` exits 0.
    - migration_test.dart still skipped (Task 3 turns it on).
    - Commit: `feat(01-02): add Drift v1 schema + DAO + bootstrap + Riverpod provider (GREEN)`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Generate v1 schema snapshot, wire schemaAt(1) migration test, run integration smoke (REFACTOR + extra GREEN)</name>
  <files>
    drift_schemas/v1.json,
    test/core/db/migration_test.dart,
    test/core/db/generated/schema.dart,
    test/core/db/generated/schema_v1.dart
  </files>
  <behavior>
    The previously-skipped migration_test.dart now runs and passes. `drift_schemas/v1.json` exists and matches the runtime schema. Integration smoke test passes on at least one platform (locally if device attached; otherwise leaves it for Plan 05 CI).
    All Task 1+2 tests remain green.
  </behavior>
  <action>
    Generate the schema snapshot (D-05) and wire it into the migration test.

    1. Run `dart run drift_dev schema dump lib/core/db/database.dart drift_schemas/v1.json`. This creates the JSON snapshot of v1.

    2. Verify `drift_schemas/v1.json` was created and contains a `child_profiles` entry. If the file is empty or missing, the schema dump command might use a different argument order — try `dart run drift_dev schema dump --output=drift_schemas/ lib/core/db/database.dart` or consult `drift_dev schema --help`. Goal: produce a JSON file at `drift_schemas/v1.json` that captures the v1 schema.

    3. Run `dart run drift_dev schema steps drift_schemas/ lib/core/db/database.steps.dart`. This generates a Dart file describing migration steps from v1 onward. With only v1 it'll be near-empty but the framework is in place (D-04). Update `database.dart` to import the generated steps file:
       ```dart
       part 'database.steps.dart';
       ```
       And update the `MigrationStrategy.onUpgrade` to use the generated steps:
       ```dart
       onUpgrade: stepByStep(),  // empty for now; auto-includes from1To2 etc when added
       ```

    4. Run `dart run drift_dev schema generate drift_schemas/ test/core/db/generated/`. This generates `test/core/db/generated/schema_v1.dart` (and per-version DBs for round-trip testing). Required for `schemaAt(1)` to find a typed v1 schema.

    5. Update `test/core/db/migration_test.dart` to remove the `skip:` flag and use the generated `GeneratedHelper`:
       ```dart
       import 'package:drift_dev/api/migrations_native.dart';
       import 'package:flutter_test/flutter_test.dart';
       import 'package:hugrun/core/db/database.dart';
       import 'generated/schema.dart';  // generated by drift_dev schema generate

       void main() {
         late SchemaVerifier verifier;
         setUpAll(() {
           verifier = SchemaVerifier(GeneratedHelper());
         });

         test('schemaAt(1) opens v1 snapshot with child_profiles table', () async {
           final connection = await verifier.startAt(1);
           // Open the v1 schema-only DB (no app code).
           final db = AppDatabase.forTesting(connection);
           addTearDown(db.close);

           // Confirm the table exists.
           final result = await db.customSelect(
             "SELECT name FROM sqlite_master WHERE type='table' AND name='child_profiles'",
           ).get();
           expect(result, hasLength(1));
         });

         test('schemaAt(1) round-trips a row through current schema', () async {
           final connection = await verifier.startAt(1);
           final db = AppDatabase.forTesting(connection);
           addTearDown(db.close);

           await db.childProfilesDao.upsertName(name: 'Hugrún');
           final row = await db.childProfilesDao.readLatest();
           expect(row?.name, 'Hugrún');
         });
       }
       ```

    6. Run `flutter test test/core/db/`. ALL tests must pass — DAO, bootstrap, AND migration. Total expected: 10+ tests green.

    7. Run `flutter analyze`. Must exit 0.

    8. If a local device/simulator is attached, run `flutter test integration_test/database_smoke_test.dart -d <device>`. Capture pass/fail in commit. Otherwise leave for Plan 05 CI.

    9. Add a `Makefile` target (or just a shell snippet in commit message) for future schema dumps so Phase 10 doesn't have to rediscover the command:
       ```
       schema-dump:
         dart run drift_dev schema dump lib/core/db/database.dart drift_schemas/v$$(grep schemaVersion lib/core/db/database.dart | grep -oE '[0-9]+').json
         dart run drift_dev schema steps drift_schemas/ lib/core/db/database.steps.dart
         dart run drift_dev schema generate drift_schemas/ test/core/db/generated/
       ```
       (Optional — if executor adds a Makefile, document under `tools/`. If not, document in 01-02-SUMMARY.md.)
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; test -f drift_schemas/v1.json &amp;&amp; flutter test test/core/db/ &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - `drift_schemas/v1.json` exists and contains the `child_profiles` table description.
    - `lib/core/db/database.steps.dart` exists (empty stepByStep at v1; ready for v2).
    - `test/core/db/generated/schema.dart` and `schema_v1.dart` exist.
    - `migration_test.dart` is no longer skipped; both schemaAt(1) tests pass.
    - All ~10 DB-related tests pass under `flutter test test/core/db/`.
    - `flutter analyze` exits 0.
    - Phase 10 will be able to add a v2 step + corresponding from1To2 migration test using `schemaAt(1)`.
    - Commit: `chore(01-02): commit drift v1 schema snapshot + wire schemaAt(1) migration test (REFACTOR)`.
  </done>
</task>

</tasks>

<verification>
- `dart run build_runner build --delete-conflicting-outputs` succeeds.
- `flutter analyze` exits 0.
- `flutter test test/core/db/` passes ~10 tests covering DAO CRUD, bootstrap idempotency, and migration schemaAt(1) round-trip.
- `drift_schemas/v1.json` exists and is committed.
- `lib/core/db/database.steps.dart` exists.
- `test/core/db/generated/schema_v1.dart` exists.
- `pubspec.lock` continues to NOT list `sqlite3_flutter_libs` as a direct dependency (D-06).
- Plan 05's CI integration job will run `integration_test/database_smoke_test.dart` on Android Emulator.
</verification>

<success_criteria>
1. `child_profiles` table exists in Drift schema v1 with id (INTEGER PK), name (TEXT NOT NULL, 1–32 chars), created_at (INTEGER unix epoch).
2. `AppDatabase.schemaVersion == 1` (D-04) and `MigrationStrategy.onUpgrade` uses `stepByStep()` (framework wired even at v1).
3. `drift_schemas/v1.json` snapshot committed (D-05).
4. `schemaAt(1)` round-trip test passes — confirms the v1 snapshot loads and round-trips a row.
5. Idempotent bootstrap inserts default name "Hugrún" (D-03) on empty DB; re-running is a no-op; existing custom names are preserved.
6. Riverpod `appDatabase` provider exposes the database as an app-scoped singleton (`@Riverpod(keepAlive: true)`).
7. DAO unit tests cover read, watch, upsert (singleton semantics), and length constraint enforcement.
8. Integration test (`integration_test/database_smoke_test.dart`) opens AppDatabase on a real platform, runs bootstrap, reads back "Hugrún" — runs in Plan 05's CI.
9. No `sqlite3_flutter_libs` direct dependency anywhere (D-06 / research Finding 7).
</success_criteria>

<output>
After completion, create `.planning/phases/01-skeleton-drift-schema/01-02-SUMMARY.md` covering:
- Final Drift version resolved
- Schema dump location + size
- All test counts (DAO: 5, bootstrap: 3, migration: 2, integration: 1) and pass status
- Generated file locations (`*.g.dart`, `database.steps.dart`, `test/core/db/generated/`)
- Any deviations from CONTEXT.md decisions and why (should be zero)
- Schema-dump command documented for Phase 10's v2 work
- Commit hashes for RED/GREEN/REFACTOR cycles (3 atomic commits expected)
</output>
