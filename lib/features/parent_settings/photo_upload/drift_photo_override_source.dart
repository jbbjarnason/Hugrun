// Phase 10 Plan 03 — DriftPhotoOverrideSource.
//
// Real implementation of the Phase 5 PhotoOverrideSource abstract class
// (lib/core/matching/photo_override_source.dart). Phase 5 ships
// EmptyPhotoOverrideSource as the default; Phase 10 replaces it via the
// `photoOverrideSourceProvider` Riverpod binding so the matching activity
// picks up parent-uploaded photos automatically (no code change in
// the activity itself).
//
// The PhotoOverrideSource interface is synchronous (`List<String>` return),
// while Drift queries are async. The repository:
//   * Caches `lexicon_word → List<image_path>` in memory.
//   * Exposes `refresh()` for callers who add a photo to invalidate the cache.
//   * Subscribes to the photo_tags stream so the cache stays warm without
//     needing an explicit refresh after every insert.
//
// The 40% Bernoulli decision lives in `RoundGenerator` (Phase 5 D-13/D-14);
// this source only answers "what photos exist for this slug?".

import 'dart:async';

import '../../../core/db/database.dart';
import '../../../core/matching/photo_override_source.dart';

class DriftPhotoOverrideSource extends PhotoOverrideSource {
  DriftPhotoOverrideSource(AppDatabase db) : _db = db {
    // Initial best-effort prime; result discarded.
    unawaited(refresh());
    // Stay warm: every photo_tags change rebuilds the cache.
    _sub = _db
        .select(_db.photoTags)
        .watch()
        .listen((rows) => _rebuild(rows));
  }

  final AppDatabase _db;
  StreamSubscription<List<PhotoTag>>? _sub;

  Map<String, List<String>> _cache = const <String, List<String>>{};

  void _rebuild(List<PhotoTag> rows) {
    final next = <String, List<String>>{};
    for (final row in rows) {
      next.putIfAbsent(row.lexiconWord, () => <String>[]).add(row.imagePath);
    }
    _cache = next;
  }

  /// Force a re-read from the DB (synchronous callers can prime the cache
  /// before invoking [photosForWordSlug]).
  Future<void> refresh() async {
    final rows = await _db.select(_db.photoTags).get();
    _rebuild(rows);
  }

  /// Async variant — fetches directly without using the cache. Useful for
  /// tests and one-off lookups. Production code should prefer [refresh] +
  /// [photosForWordSlug] so the cache stays consistent.
  Future<List<String>> photosForWordSlugAsync(String wordSlug) async {
    final rows = await (_db.select(_db.photoTags)
          ..where((t) => t.lexiconWord.equals(wordSlug)))
        .get();
    return rows.map((r) => r.imagePath).toList();
  }

  @override
  List<String> photosForWordSlug(String wordSlug) {
    return List<String>.unmodifiable(_cache[wordSlug] ?? const <String>[]);
  }

  /// Releases the photo_tags stream subscription. Call from `ref.onDispose`
  /// when the Riverpod provider is torn down.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
