import 'package:drift/drift.dart';

/// ActivityLog — Drift v2 schema (Phase 10 D-01).
///
/// Forward-compat surface for the v2 parent-companion review screen
/// (PARENT-V2-01, deferred). The table is created by the v1→v2 migration so
/// future versions don't need another schema bump just to start logging; no
/// writers are wired in v1 — this table stays empty until v2 features land.
///
/// `activity_type` is an opaque string slug (e.g. `'stafir.tap'`,
/// `'tolur.subitize'`). `timestamp` is INTEGER millisecond unix-epoch.
class ActivityLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get activityType => text()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  String? get tableName => 'activity_log';
}
