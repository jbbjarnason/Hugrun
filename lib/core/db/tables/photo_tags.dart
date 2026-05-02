import 'package:drift/drift.dart';

/// PhotoTags — Drift v2 schema (Phase 10 D-01).
///
/// One row per parent-uploaded photo. The `image_path` is an absolute path on
/// the device's app-documents directory (per `path_provider`); the
/// `lexicon_word` is the Icelandic noun the parent tagged the photo with.
///
/// `lexicon_word` is stored as plain text (not a foreign key into a lexicon
/// table) — the curated lexicon lives in pure Dart code (`lib/core/lexicon/`),
/// not in the database, so a string column is the simplest correct join key.
///
/// `created_at` is INTEGER millisecond unix-epoch (matches build.yaml
/// `store_date_time_values_as_text: false`).
///
/// PRIVACY: photos NEVER leave the device. There is no upload, no sync, no
/// cloud — this table tracks local files only.
class PhotoTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get imagePath => text()();
  TextColumn get lexiconWord => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  String? get tableName => 'photo_tags';
}
