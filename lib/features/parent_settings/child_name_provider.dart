import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database_provider.dart';

part 'child_name_provider.g.dart';

/// Streams the current child's name from Drift `child_profiles`.
///
/// Returns `null` when the table is empty (defensive — bootstrap inserts
/// 'Hugrún' on first launch, so production code rarely sees null; only
/// test setups that skip bootstrap will).
///
/// Decisions:
///   D-20  app-scoped (`keepAlive: true`) — settings screen + welcome
///         narration both watch this provider. Survives navigation.
///   D-21  Updating name via settings invalidates this stream's value;
///         the next welcome narration variant is selected based on the
///         current value, but mid-session re-narration is suppressed by
///         WelcomeNarrationController's once-flag (Plan 04-06).
///   PERS-01  Default 'Hugrún' (set by Phase 1 ensureDefaultChildProfile).
///   PERS-02  Persists in Drift across restart.
@Riverpod(keepAlive: true)
Stream<String?> childName(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.childProfilesDao.watchLatest().map((profile) => profile?.name);
}
