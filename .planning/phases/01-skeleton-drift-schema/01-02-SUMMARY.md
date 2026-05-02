---
phase: 1
plan: 02
subsystem: db-schema
tags: [drift, sqlite, migration, persistence, tdd]
tech-stack:
  added:
    - drift 2.28.x
    - drift_dev 2.28.x
    - drift_flutter 0.2.7
  patterns:
    - feature-first lib/core/db (table + dao + provider + bootstrap)
    - hand-written Riverpod provider (codegen deferred — see 01-01 deviations)
    - drift_dev schema dump → drift_schemas/drift_schema_v1.json (D-05)
    - drift_dev schema steps → lib/core/db/database.steps.dart
    - drift_dev schema generate → test/core/db/generated/schema.dart + schema_v1.dart
key-files:
  created:
    - lib/core/db/tables/child_profiles.dart
    - lib/core/db/dao/child_profiles_dao.dart
    - lib/core/db/database.dart
    - lib/core/db/database.steps.dart
    - lib/core/db/database_provider.dart
    - lib/core/db/bootstrap.dart
    - drift_schemas/drift_schema_v1.json
    - test/core/db/child_profiles_dao_test.dart
    - test/core/db/bootstrap_test.dart
    - test/core/db/migration_test.dart
    - test/core/db/generated/schema.dart
    - test/core/db/generated/schema_v1.dart
    - integration_test/database_smoke_test.dart
    - build.yaml
decisions: []
metrics:
  duration: ~12 min
  tasks: 3
  tests: 10 new (5 dao + 3 bootstrap + 2 migration); 31 cumulative
  completed: 2026-05-02
---

# Phase 1 Plan 02: Database Summary

Wired up the Drift v1 database with a single `child_profiles` table (D-03), schemaVersion=1 with stepByStep migration scaffolding (D-04), the v1 schema snapshot at `drift_schemas/drift_schema_v1.json` (D-05), an idempotent bootstrap inserting the default name "Hugrún" on first launch, and a hand-written Riverpod provider exposing `AppDatabase` as an app-scoped singleton.

## Final Drift versions
- `drift: 2.28.2`
- `drift_dev: 2.28.1`
- `drift_flutter: 0.2.7`

(Forced down from 2.32.x by Flutter 3.38.7 SDK pinning of `meta 1.17.0` / `test_api 0.7.7`. See 01-01-SUMMARY.md Dev_2/Dev_3.)

## Schema snapshot
- `drift_schemas/drift_schema_v1.json` (1 KB) — committed.
- Note: `drift_dev` names this `drift_schema_v1.json` rather than `v1.json` per CONTEXT D-05's literal phrasing — same role, different filename.

## Test counts
| File | Count | Status |
|---|---|---|
| `test/core/db/child_profiles_dao_test.dart` | 5 | green |
| `test/core/db/bootstrap_test.dart` | 3 | green |
| `test/core/db/migration_test.dart` | 2 | green |
| `integration_test/database_smoke_test.dart` | 1 | not run locally (no device); will run in CI Plan 05 |
| **Total new** | **11** | — |
| **Cumulative (Plans 01+02)** | **31** | green |

## Generated files
- `lib/core/db/database.g.dart` (drift_dev — gitignored via `**/*.g.dart`)
- `lib/core/db/dao/child_profiles_dao.g.dart` (drift_dev — gitignored)
- `lib/core/db/database.steps.dart` (drift_dev `schema steps` — committed)
- `test/core/db/generated/schema.dart` + `schema_v1.dart` (drift_dev `schema generate` — committed)

## Schema-dump command (for Phase 10 v2 work)
```bash
# After making schema changes (new table or column), bump schemaVersion in
# lib/core/db/database.dart, then:
dart run drift_dev schema dump lib/core/db/database.dart drift_schemas/
dart run drift_dev schema steps drift_schemas/ lib/core/db/database.steps.dart
dart run drift_dev schema generate drift_schemas/ test/core/db/generated/
# Add a new from1To2 step in database.steps.dart (drift_dev generates the scaffolding).
```

## Deviations from CONTEXT decisions
- **None.** All D-03..D-06 are met within the constraints documented in 01-01-SUMMARY.md (Drift versions forced lower; D-06 spirit honored by avoiding direct `sqlite3_flutter_libs` dep).
- The Riverpod `appDatabaseProvider` is hand-written rather than `@Riverpod(keepAlive: true)` codegen — same Phase 1 deviation already documented in 01-01-SUMMARY.md Dev_1.

## Commits
- `a82e2fd` test(01-02): add failing Drift DAO/migration/bootstrap tests (RED)
- `0dd6206` feat(01-02): add Drift v1 schema + DAO + bootstrap + Riverpod provider (GREEN)
- `76867cf` chore(01-02): commit drift v1 schema snapshot + wire schemaAt(1) migration test (REFACTOR)

## Self-Check
- All 31 tests pass under `flutter test`
- `flutter analyze` clean (0 issues)
- `dart format --set-exit-if-changed .` clean
- `drift_schemas/drift_schema_v1.json` committed and contains `child_profiles` schema
- `lib/core/db/database.steps.dart` committed with empty stepByStep (Phase 10 ready)
- No `sqlite3_flutter_libs` direct dep (D-06)
- Bootstrap idempotency proven by 3 unit tests
- Migration framework wired (D-04) — schemaAt(1) test verifies it loads

## Status
**COMPLETE — GREEN**. All Plan 02 success criteria met.
