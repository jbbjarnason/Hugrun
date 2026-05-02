// Phase 10 Plan 04 — Riverpod providers for the PhotoUploadScreen.
//
// We expose a small "facade" type alias of repository methods rather than
// the full PhotoRepository class so widget tests don't need to construct
// a real Drift connection just to render the screen.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/lexicon/lexicon_entry.dart';
import 'photo_picker.dart';
import 'photo_repository.dart';

/// Facade around [PhotoRepository] for use by the photo upload screen.
///
/// Production wires the real repo's methods; tests inject capturing fakes.
class PhotoRepositoryFacade {
  PhotoRepositoryFacade({
    required this.addPhoto,
    required this.listPhotos,
    required this.deletePhoto,
  });

  final Future<String> Function({required File source, required LexiconEntry tag})
      addPhoto;
  final Future<List<PhotoTag>> Function() listPhotos;
  final Future<void> Function(int id) deletePhoto;
}

/// Production photo picker — wraps `image_picker` plugin.
final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);

/// Production [PhotoRepositoryFacade] wired to the Drift app database.
final photoRepositoryFacadeProvider = Provider<PhotoRepositoryFacade>(
  (ref) {
    final repo = PhotoRepository(db: ref.watch(appDatabaseProvider));
    return PhotoRepositoryFacade(
      addPhoto: ({required File source, required LexiconEntry tag}) =>
          repo.addPhoto(source: source, tag: tag),
      listPhotos: repo.listPhotos,
      deletePhoto: repo.deletePhoto,
    );
  },
);
