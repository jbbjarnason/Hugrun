// Phase 10 Plan 03 — DriftPhotoOverrideSource tests (RED first).
//
// DriftPhotoOverrideSource implements the Phase 5 PhotoOverrideSource interface
// against the photo_tags Drift table. Returns image_paths for tagged photos
// matching a wordSlug, or empty list if none exist (round generator falls back
// to stock placeholder).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/matching/photo_override_source.dart';
import 'package:hugrun/features/parent_settings/photo_upload/drift_photo_override_source.dart';

void main() {
  late AppDatabase db;
  late DriftPhotoOverrideSource source;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    source = DriftPhotoOverrideSource(db);
  });

  tearDown(() async => db.close());

  test('implements PhotoOverrideSource', () {
    expect(source, isA<PhotoOverrideSource>());
  });

  test('returns empty list when photo_tags is empty', () async {
    final result = await source.photosForWordSlugAsync('hundur');
    expect(result, isEmpty);
  });

  test('returns image_path strings matching the lexicon_word', () async {
    await db.customStatement(
      "INSERT INTO photo_tags(image_path, lexicon_word, created_at) "
      "VALUES('/docs/hugrun_photos/a.jpg', 'hundur', 1700000000000)",
    );
    await db.customStatement(
      "INSERT INTO photo_tags(image_path, lexicon_word, created_at) "
      "VALUES('/docs/hugrun_photos/b.jpg', 'hundur', 1700000001000)",
    );
    await db.customStatement(
      "INSERT INTO photo_tags(image_path, lexicon_word, created_at) "
      "VALUES('/docs/hugrun_photos/c.jpg', 'köttur', 1700000002000)",
    );

    final hundurPhotos = await source.photosForWordSlugAsync('hundur');
    expect(hundurPhotos, hasLength(2));
    expect(hundurPhotos, contains('/docs/hugrun_photos/a.jpg'));
    expect(hundurPhotos, contains('/docs/hugrun_photos/b.jpg'));

    final kotturPhotos = await source.photosForWordSlugAsync('köttur');
    expect(kotturPhotos, equals(['/docs/hugrun_photos/c.jpg']));
  });

  test('synchronous photosForWordSlug returns cached snapshot', () async {
    await db.customStatement(
      "INSERT INTO photo_tags(image_path, lexicon_word, created_at) "
      "VALUES('/docs/hugrun_photos/a.jpg', 'hundur', 1700000000000)",
    );
    // Prime the cache.
    await source.refresh();

    final result = source.photosForWordSlug('hundur');
    expect(result, equals(['/docs/hugrun_photos/a.jpg']));
  });

  test('refresh() picks up new photos inserted after construction',
      () async {
    expect(source.photosForWordSlug('hundur'), isEmpty);

    await db.customStatement(
      "INSERT INTO photo_tags(image_path, lexicon_word, created_at) "
      "VALUES('/docs/hugrun_photos/late.jpg', 'hundur', 1700000003000)",
    );

    // Without refresh, cached empty list still returns.
    expect(source.photosForWordSlug('hundur'), isEmpty);

    await source.refresh();
    expect(
      source.photosForWordSlug('hundur'),
      equals(['/docs/hugrun_photos/late.jpg']),
    );
  });

  test('returns empty list for unknown wordSlug', () async {
    await db.customStatement(
      "INSERT INTO photo_tags(image_path, lexicon_word, created_at) "
      "VALUES('/docs/hugrun_photos/a.jpg', 'hundur', 1700000000000)",
    );
    await source.refresh();

    expect(source.photosForWordSlug('zzz_unknown'), isEmpty);
  });
}
