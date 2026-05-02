import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'database.dart';

part 'database_provider.g.dart';

/// App-scoped singleton — never autoDispose. Per ARCHITECTURE.md the DB lives
/// for the whole app lifetime (no scope leaks per PITFALLS #7).
///
/// D-02: `@Riverpod(keepAlive: true)` codegen. Earlier Phase 1 used a
/// hand-written `Provider<AppDatabase>` because the analyzer/build constraints
/// on Flutter 3.38.7 prevented riverpod_generator + drift_dev from coexisting;
/// post-3.41.9 + drift_dev 2.31.x + riverpod_generator 4.0.3 they overlap on
/// analyzer ^9 and the codegen migration is now possible.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
