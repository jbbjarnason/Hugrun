// Phase 10 Plan 03 — PhotoRepository tests (RED first).
//
// PhotoRepository:
//   * Downsizes the source image to ≤1024 px max edge (D-11).
//   * Encodes JPEG quality 85 (D-11).
//   * Writes to <docDir>/hugrun_photos/<uuid>.jpg.
//   * Inserts a `photo_tags` row with image_path + lexicon_word.
//
// We test by injecting a fake docs directory (a temp dir) and a fake
// IdGenerator + bypassing image_picker entirely (the repository accepts a
// File source). image_picker is mocked at the widget layer (Workstream D),
// not here.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/lexicon/gender.dart';
import 'package:hugrun/core/lexicon/lexicon_entry.dart';
import 'package:hugrun/features/parent_settings/photo_upload/photo_repository.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

LexiconEntry _hundur() => const LexiconEntry(
  word: 'hundur',
  gender: Gender.masculine,
  defaultImagePath: 'assets/images/letters/words/hundur.webp',
);

/// Writes a fake JPEG to [path] of the requested dimensions.
File _writeFakeJpeg(String path, int width, int height) {
  final image = img.Image(width: width, height: height);
  // Fill with a simple gradient so the JPEG codec doesn't trivially produce
  // an empty payload.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x % 255, y % 255, 128, 255);
    }
  }
  final bytes = img.encodeJpg(image, quality: 95);
  final f = File(path);
  f.writeAsBytesSync(bytes);
  return f;
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late PhotoRepository repo;
  var uuidCounter = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hugrun_photos_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    uuidCounter = 0;
    repo = PhotoRepository(
      db: db,
      docsDirProvider: () async => tmp,
      idGenerator: () => 'fake-uuid-${++uuidCounter}',
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  test(
    'addPhoto saves a downsized JPEG under hugrun_photos/<uuid>.jpg',
    () async {
      final source = _writeFakeJpeg(p.join(tmp.path, 'source.jpg'), 2048, 1536);

      await repo.addPhoto(source: source, tag: _hundur());

      final destDir = Directory(p.join(tmp.path, 'hugrun_photos'));
      expect(destDir.existsSync(), isTrue);
      final files = destDir.listSync().whereType<File>().toList();
      expect(files, hasLength(1));
      expect(p.basename(files.first.path), 'fake-uuid-1.jpg');

      // Saved JPEG decodes back at ≤1024 px max edge.
      final saved = img.decodeJpg(files.first.readAsBytesSync())!;
      final maxEdge = saved.width > saved.height ? saved.width : saved.height;
      expect(maxEdge, lessThanOrEqualTo(1024));
    },
  );

  test(
    'addPhoto inserts a photo_tags row with image_path + lexicon_word',
    () async {
      final source = _writeFakeJpeg(p.join(tmp.path, 'source.jpg'), 800, 600);

      await repo.addPhoto(source: source, tag: _hundur());

      final rows = await db
          .customSelect('SELECT image_path, lexicon_word FROM photo_tags')
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.read<String>('lexicon_word'), 'hundur');
      expect(
        rows.first.read<String>('image_path'),
        endsWith('hugrun_photos/fake-uuid-1.jpg'),
      );
    },
  );

  test('addPhoto preserves smaller-than-1024 images (no upscaling)', () async {
    final source = _writeFakeJpeg(p.join(tmp.path, 'source.jpg'), 600, 400);

    await repo.addPhoto(source: source, tag: _hundur());

    final saved = img.decodeJpg(
      File(
        p.join(tmp.path, 'hugrun_photos', 'fake-uuid-1.jpg'),
      ).readAsBytesSync(),
    )!;
    expect(saved.width, 600);
    expect(saved.height, 400);
  });

  test('addPhoto handles tall portrait images (height > width)', () async {
    final source = _writeFakeJpeg(p.join(tmp.path, 'source.jpg'), 1080, 1920);

    await repo.addPhoto(source: source, tag: _hundur());

    final saved = img.decodeJpg(
      File(
        p.join(tmp.path, 'hugrun_photos', 'fake-uuid-1.jpg'),
      ).readAsBytesSync(),
    )!;
    final maxEdge = saved.width > saved.height ? saved.width : saved.height;
    expect(maxEdge, lessThanOrEqualTo(1024));
    // Aspect ratio preserved (within rounding).
    final ratio = saved.height / saved.width;
    expect(ratio, closeTo(1920 / 1080, 0.02));
  });

  test('addPhoto throws on non-existent source file', () async {
    final missing = File(p.join(tmp.path, 'does_not_exist.jpg'));
    await expectLater(
      () => repo.addPhoto(source: missing, tag: _hundur()),
      throwsA(isA<Exception>()),
    );
  });

  test('addPhoto generates distinct filenames for multiple uploads', () async {
    final s1 = _writeFakeJpeg(p.join(tmp.path, 's1.jpg'), 800, 600);
    final s2 = _writeFakeJpeg(p.join(tmp.path, 's2.jpg'), 800, 600);

    await repo.addPhoto(source: s1, tag: _hundur());
    await repo.addPhoto(source: s2, tag: _hundur());

    final files = Directory(
      p.join(tmp.path, 'hugrun_photos'),
    ).listSync().whereType<File>().toList();
    expect(files, hasLength(2));
    final names = files.map((f) => p.basename(f.path)).toSet();
    expect(names, equals({'fake-uuid-1.jpg', 'fake-uuid-2.jpg'}));
  });

  test('listPhotos returns photo_tags rows joined with file paths', () async {
    final s1 = _writeFakeJpeg(p.join(tmp.path, 's1.jpg'), 400, 300);
    await repo.addPhoto(source: s1, tag: _hundur());

    final tags = await repo.listPhotos();
    expect(tags, hasLength(1));
    expect(tags.first.lexiconWord, 'hundur');
    expect(tags.first.imagePath, endsWith('fake-uuid-1.jpg'));
  });

  test('JPEG output is non-empty (encoder produced bytes)', () async {
    final source = _writeFakeJpeg(p.join(tmp.path, 's.jpg'), 800, 600);
    await repo.addPhoto(source: source, tag: _hundur());

    final saved = File(p.join(tmp.path, 'hugrun_photos', 'fake-uuid-1.jpg'));
    expect(saved.lengthSync(), greaterThan(0));
    // And: it's actually a JPEG (FFD8 magic header).
    final bytes = saved.readAsBytesSync();
    expect(bytes.length, greaterThanOrEqualTo(2));
    expect(
      Uint8List.fromList(bytes.take(2).toList()),
      equals(Uint8List.fromList([0xFF, 0xD8])),
    );
  });
}
