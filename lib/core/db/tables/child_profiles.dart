import 'package:drift/drift.dart';

/// Child profile table — Drift v1 schema.
///
/// Per CONTEXT D-03: id (auto-increment), name (TEXT NOT NULL, 1..32 chars),
/// created_at (DateTime stored as INTEGER unix epoch).
///
/// Singleton row enforced at the application level (bootstrap + DAO upsertName),
/// NOT at the DB level — keeps options open for v2 multi-child support without
/// rewriting v1 schema.
class ChildProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 32)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  String? get tableName => 'child_profiles';
}
