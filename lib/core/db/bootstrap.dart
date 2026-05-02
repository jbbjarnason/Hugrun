import 'database.dart';

/// Inserts the default child profile name ('Hugrún' per D-03) on first launch.
///
/// Idempotent: if any row exists, this is a no-op. Phase 4's parent settings
/// UI lets the parent change the name; this only ensures "first run" creates
/// a row so downstream code can rely on a profile being present.
Future<void> ensureDefaultChildProfile(
  AppDatabase db, {
  String defaultName = 'Hugrún',
}) async {
  final existing = await db.childProfilesDao.count();
  if (existing == 0) {
    await db.childProfilesDao.upsertName(name: defaultName);
  }
}
