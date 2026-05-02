// Phase 10 Plan 03 — Photo persistence repository.
//
// Owns the lifecycle of parent-uploaded photos:
//   1. Accept a source File (provided by image_picker at the UI layer).
//   2. Decode + downsize to ≤1024 px max edge (D-11).
//   3. Re-encode as JPEG quality 85 (D-11).
//   4. Save under <appDocs>/hugrun_photos/<uuid>.jpg with a UUID filename.
//   5. Insert a row into the photo_tags Drift table.
//
// PRIVACY: photos NEVER leave the device. This file makes ZERO network calls.
// `tools/check-no-tracking.sh` enforces no analytics SDKs in the dep graph;
// the `image` and `image_picker` packages used here are platform-channel /
// pure-Dart only.
//
// Testability: the constructor accepts injection points for the docs
// directory provider and the UUID generator so unit tests can run in a
// temp dir with deterministic filenames (see photo_repository_test.dart).

import 'dart:io';

import 'package:drift/drift.dart' as d;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/lexicon/lexicon_entry.dart';

/// Max edge length for stored photos (D-11). Bigger images are downscaled
/// proportionally; smaller images are saved at their original size.
const int kPhotoMaxEdgePx = 1024;

/// JPEG re-encode quality for stored photos (D-11). 85 is a standard "good
/// quality, modest size" target.
const int kPhotoJpegQuality = 85;

/// Subdirectory under the app documents directory where photos are stored.
const String kPhotoSubdir = 'hugrun_photos';

/// Provider signature for the app documents directory. Production wires
/// `path_provider.getApplicationDocumentsDirectory`; tests wire a temp dir.
typedef DocsDirProvider = Future<Directory> Function();

/// Generator signature for UUID filenames. Production uses `Uuid().v4`; tests
/// supply a deterministic counter.
typedef IdGenerator = String Function();

/// Default production docs-dir provider — `path_provider`'s
/// `getApplicationDocumentsDirectory()`. Wrapped so tests can inject a
/// temp dir without depending on the platform-channel mock.
Future<Directory> _defaultDocsDir() async =>
    await pp.getApplicationDocumentsDirectory();

/// Default production UUID generator.
String _defaultUuid() => const Uuid().v4();

/// Repository for parent-uploaded photo personalization.
class PhotoRepository {
  PhotoRepository({
    required AppDatabase db,
    DocsDirProvider docsDirProvider = _defaultDocsDir,
    IdGenerator idGenerator = _defaultUuid,
  })  : _db = db,
        _docsDirProvider = docsDirProvider,
        _idGenerator = idGenerator;

  final AppDatabase _db;
  final DocsDirProvider _docsDirProvider;
  final IdGenerator _idGenerator;

  /// Adds a tagged photo. Returns the saved image path.
  ///
  /// 1. Decodes [source].
  /// 2. Downsizes to ≤[kPhotoMaxEdgePx] max edge (preserves aspect ratio).
  /// 3. Re-encodes as JPEG quality [kPhotoJpegQuality].
  /// 4. Writes to `<docsDir>/<kPhotoSubdir>/<uuid>.jpg`.
  /// 5. Inserts a `photo_tags` row.
  ///
  /// Throws if [source] does not exist or is not a decodable image.
  Future<String> addPhoto({
    required File source,
    required LexiconEntry tag,
  }) async {
    if (!source.existsSync()) {
      throw FileSystemException(
        'PhotoRepository.addPhoto: source not found',
        source.path,
      );
    }

    final raw = await source.readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw const FormatException(
        'PhotoRepository.addPhoto: source not decodable as an image',
      );
    }

    // Downsize only when needed; never upscale.
    final maxEdge =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final img.Image processed;
    if (maxEdge > kPhotoMaxEdgePx) {
      // image package preserves aspect ratio when only one dimension is set.
      processed = decoded.width > decoded.height
          ? img.copyResize(decoded, width: kPhotoMaxEdgePx)
          : img.copyResize(decoded, height: kPhotoMaxEdgePx);
    } else {
      processed = decoded;
    }

    final encoded = img.encodeJpg(processed, quality: kPhotoJpegQuality);

    final docsDir = await _docsDirProvider();
    final photoDir = Directory(p.join(docsDir.path, kPhotoSubdir));
    if (!photoDir.existsSync()) {
      photoDir.createSync(recursive: true);
    }
    final filename = '${_idGenerator()}.jpg';
    final destPath = p.join(photoDir.path, filename);
    await File(destPath).writeAsBytes(encoded);

    await _db.into(_db.photoTags).insert(
          PhotoTagsCompanion.insert(
            imagePath: destPath,
            lexiconWord: tag.word,
            createdAt: DateTime.now(),
          ),
        );

    return destPath;
  }

  /// Returns all stored photo tags ordered most-recent-first.
  Future<List<PhotoTag>> listPhotos() async {
    final query = _db.select(_db.photoTags)
      ..orderBy([
        (t) => d.OrderingTerm(
              expression: t.createdAt,
              mode: d.OrderingMode.desc,
            ),
      ]);
    return query.get();
  }

  /// Reactive variant for the upload screen UI.
  Stream<List<PhotoTag>> watchPhotos() {
    final query = _db.select(_db.photoTags)
      ..orderBy([
        (t) => d.OrderingTerm(
              expression: t.createdAt,
              mode: d.OrderingMode.desc,
            ),
      ]);
    return query.watch();
  }

  /// Deletes a photo row + the underlying file. Tolerant of missing files.
  Future<void> deletePhoto(int id) async {
    final row = await (_db.select(_db.photoTags)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    final f = File(row.imagePath);
    if (f.existsSync()) {
      try {
        await f.delete();
      } catch (_) {
        // Best-effort; the row removal still goes through.
      }
    }
    await (_db.delete(_db.photoTags)..where((t) => t.id.equals(id))).go();
  }
}
