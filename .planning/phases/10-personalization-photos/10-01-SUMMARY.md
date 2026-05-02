---
phase: 10
plan: 01
title: Drift v2 Schema Migration
status: complete
date: 2026-05-02
tags: [drift, sqlite, migrations, schemaAt]
requirements: [PHOTO-07]
---

# Plan 10-01 — Drift v2 schema migration

Phase 10 Workstream A. Drift `schemaVersion` bumps from 1 → 2; the new
schema adds two tables — `photo_tags` (parent-uploaded photo overrides)
and `activity_log` (forward-compat for the v2 parent-companion screen).
The migration is **non-destructive** (D-04): the existing `child_profiles`
row + structure are preserved.

## Atomic commits

| Hash      | Type   | Subject                                                                           |
|-----------|--------|-----------------------------------------------------------------------------------|
| `077cfe8` | test   | failing v1→v2 migration test (RED) — schemaVersion, photo_tags, activity_log      |
| `20627c5` | feat   | drift v2 schema migration adds photo_tags + activity_log (GREEN)                  |

## Files

### Created
- `lib/core/db/tables/photo_tags.dart` — `image_path`, `lexicon_word`, `created_at`
- `lib/core/db/tables/activity_log.dart` — `activity_type`, `timestamp` (no writers in v1)
- `drift_schemas/drift_schema_v2.json` — drift_dev snapshot
- `test/core/db/migrations/v1_to_v2_test.dart` — 3 tests
- `test/core/db/generated/schema_v2.dart` — drift_dev verifier helper

### Modified
- `lib/core/db/database.dart` — `schemaVersion = 2`, `stepByStep(from1To2: ...)`
- `lib/core/db/database.steps.dart` — drift_dev regenerated with `Schema2`

## Tests

- `migrates v1 → v2: child_profiles row preserved through upgrade` ✓
- `v2 photo_tags accepts insert + readback after migration` ✓
- `schemaVersion is 2` ✓

Existing 14 DB tests (Phase 1 Plan 02) all still pass — no regression.

## Decisions exercised

- **D-01** schema bump v1→v2 with `photo_tags` + `activity_log`
- **D-02** `stepByStep` migration scaffold (already wired in Phase 1 Plan 02)
- **D-03** `drift_schemas/drift_schema_v2.json` snapshot via
  `drift_dev schema dump` + verifier helper via `drift_dev schema generate`
- **D-04** non-destructive — `child_profiles` untouched

## Deviations

None. Plan executed as written.
