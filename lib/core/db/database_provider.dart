import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// App-scoped singleton — never autoDispose. Per ARCHITECTURE.md the DB lives
/// for the whole app lifetime (no scope leaks per PITFALLS #7).
///
/// Phase 1 deviation: hand-written provider instead of `@Riverpod(keepAlive)`
/// codegen. Riverpod codegen + drift_dev have an analyzer-version conflict on
/// pub.dev as of 2026-05-02 (see 01-01-SUMMARY.md). Phase 4 revisits and
/// migrates to codegen if the ecosystem aligns.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
