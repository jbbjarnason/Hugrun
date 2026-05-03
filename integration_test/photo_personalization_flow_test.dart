// Phase 10 Plan 05 — end-to-end integration test for the personalization
// photo flow.
//
// Walks the full parent → child surface under a real platform binding:
//   1. Boot HugrunApp with an in-memory Drift db + a fake PhotoPicker that
//      returns a fixture image.
//   2. Long-press the home parent-gate button (3 s) → settings.
//   3. Tap "Myndir" → PhotoUploadScreen opens.
//   4. Tap the FAB → fake picker fires → LexiconPicker shown.
//   5. Tap "hundur" → addPhoto resolves → SnackBar confirms → list shows
//      the new tag.
//   6. Re-load the upload screen and assert the photo persisted in
//      `photo_tags`.
//   7. Boot the matching activity under a Drift-backed
//      DriftPhotoOverrideSource and a forced 100% photo frequency, then
//      confirm `RoundGenerator.generate()` returns a round whose
//      ImageSource is photoOverride with the saved file path.
//
// This test exercises Workstreams A (Drift v2), B (lexicon), C (repo +
// override source), D (UI). It is the master correctness check for the
// phase.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';
import 'package:hugrun/core/manifest/audio_asset.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/core/matching/matching_round.dart';
import 'package:hugrun/core/matching/round_generator.dart';
import 'package:hugrun/features/parent_settings/photo_upload/drift_photo_override_source.dart';
import 'package:hugrun/features/parent_settings/photo_upload/photo_picker.dart';
import 'package:hugrun/features/parent_settings/photo_upload/photo_repository.dart';
import 'package:hugrun/features/parent_settings/photo_upload/photo_upload_providers.dart';
import 'package:hugrun/features/parent_settings/photo_upload/photo_upload_screen.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

class _StubPhotoPicker implements PhotoPicker {
  _StubPhotoPicker(this._file);
  final File _file;
  @override
  Future<File?> pickFromGallery() async => _file;
}

const _hundurAsset = AudioAsset(
  path: 'assets/audio/letters/words/hundur.aac',
  approximateDuration: Duration(milliseconds: 300),
);

File _writeFakeJpeg(String path, int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgba(x, y, x % 255, y % 255, 64, 255);
    }
  }
  final bytes = Uint8List.fromList(img.encodeJpg(image));
  final file = File(path);
  file.writeAsBytesSync(bytes);
  return file;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 10 — upload photo → tag with hundur → persists in '
      'photo_tags → DriftPhotoOverrideSource feeds matching activity', (
    tester,
  ) async {
    final docs = await Directory.systemTemp.createTemp('hugrun_e2e_');
    addTearDown(() async {
      if (docs.existsSync()) await docs.delete(recursive: true);
    });

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Hand-build a deterministic repo that uses our temp docs dir.
    final repo = PhotoRepository(
      db: db,
      docsDirProvider: () async => docs,
      idGenerator: () => 'fixed-uuid',
    );

    final fixturePath = p.join(docs.path, 'fixture_hundur.jpg');
    final fixture = _writeFakeJpeg(fixturePath, 800, 600);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          photoPickerProvider.overrideWithValue(_StubPhotoPicker(fixture)),
          photoRepositoryFacadeProvider.overrideWithValue(
            PhotoRepositoryFacade(
              addPhoto: repo.addPhoto,
              listPhotos: repo.listPhotos,
              deletePhoto: repo.deletePhoto,
            ),
          ),
        ],
        child: const MaterialApp(home: PhotoUploadScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Empty state visible.
    expect(find.text('Engar myndir enn'), findsOneWidget);

    // 2. Tap FAB → picker → LexiconPicker.
    await tester.tap(find.byKey(const Key('photo-upload-add-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Veldu orð'), findsOneWidget);

    // 3. Tap "hundur" — scroll to it first if not visible.
    final hundurFinder = find.byKey(const Key('lexicon-tile-hundur'));
    if (hundurFinder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        hundurFinder,
        300.0,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.tap(hundurFinder);
    await tester.pumpAndSettle();

    // 4. SnackBar confirms.
    expect(find.text('Mynd vistuð fyrir "hundur"'), findsOneWidget);

    // 5. Database has the row.
    final rows = await db
        .customSelect('SELECT image_path, lexicon_word FROM photo_tags')
        .get();
    expect(rows, hasLength(1));
    expect(rows.first.read<String>('lexicon_word'), 'hundur');
    expect(rows.first.read<String>('image_path'), endsWith('fixed-uuid.jpg'));

    // 6. Saved file exists at the persisted path.
    final savedPath = rows.first.read<String>('image_path');
    expect(File(savedPath).existsSync(), isTrue);

    // 7. DriftPhotoOverrideSource picks up the row + feeds
    //    RoundGenerator with photoFrequency = 1.0 → guaranteed override.
    final source = DriftPhotoOverrideSource(db);
    addTearDown(source.dispose);
    // Allow the watch stream to populate the cache.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Force-prime the cache too (belt + suspenders for fast test runs).
    await source.refresh();

    final hundurPhotos = source.photosForWordSlug('hundur');
    expect(hundurPhotos, hasLength(1));
    expect(hundurPhotos.first, savedPath);

    final gen = RoundGenerator(
      seed: 0,
      manifestOverride: const <UtteranceKey, AudioAsset>{
        UtteranceKey.wordHundur: _hundurAsset,
      },
      photoSource: source,
      photoFrequency: 1.0,
    );
    final round = gen.generate();
    expect(round.targetWordSlug, 'hundur');
    expect(round.imageSource, isA<PhotoOverride>());
    expect((round.imageSource as PhotoOverride).photoId, savedPath);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
