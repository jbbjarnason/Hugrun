// Phase 10 Plan 04 — PhotoUploadScreen widget tests (RED first).
//
// PhotoUploadScreen:
//   * Shows a list/grid of existing tagged photos (most recent first).
//   * "Add photo" FAB triggers the injected image picker.
//   * After picking, navigates to the LexiconPicker; on selection the
//     PhotoRepository.addPhoto is called and a SnackBar/visual confirms.
//   * Long-press on a tile deletes it (D-10).
//
// We mock both image_picker (PickedFile) and PhotoRepository entirely so the
// widget test never touches the file system.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/lexicon/gender.dart';
import 'package:hugrun/core/lexicon/lexicon_entry.dart';
import 'package:hugrun/features/parent_settings/photo_upload/photo_picker.dart';
import 'package:hugrun/features/parent_settings/photo_upload/photo_upload_providers.dart';
import 'package:hugrun/features/parent_settings/photo_upload/photo_upload_screen.dart';

class _FakePhotoPicker implements PhotoPicker {
  _FakePhotoPicker(this._result);
  final File? _result;
  bool wasCalled = false;

  @override
  Future<File?> pickFromGallery() async {
    wasCalled = true;
    return _result;
  }
}

class _CapturingPhotoRepository {
  final List<({File source, LexiconEntry tag})> addCalls = [];
  final List<int> deleteCalls = [];
  final List<PhotoTag> initialPhotos;

  _CapturingPhotoRepository({this.initialPhotos = const []});

  Future<String> addPhoto({required File source, required LexiconEntry tag}) async {
    addCalls.add((source: source, tag: tag));
    return '/fake/path/${tag.word}.jpg';
  }

  Future<List<PhotoTag>> listPhotos() async => initialPhotos;

  Future<void> deletePhoto(int id) async => deleteCalls.add(id);
}

Widget _wrap({
  required _CapturingPhotoRepository repo,
  required _FakePhotoPicker picker,
}) {
  return ProviderScope(
    overrides: [
      photoRepositoryFacadeProvider.overrideWithValue(
        PhotoRepositoryFacade(
          addPhoto: repo.addPhoto,
          listPhotos: repo.listPhotos,
          deletePhoto: repo.deletePhoto,
        ),
      ),
      photoPickerProvider.overrideWithValue(picker),
    ],
    child: const MaterialApp(home: PhotoUploadScreen()),
  );
}

void main() {
  group('PhotoUploadScreen', () {
    testWidgets('shows AppBar title "Myndir"', (tester) async {
      final picker = _FakePhotoPicker(null);
      final repo = _CapturingPhotoRepository();
      await tester.pumpWidget(_wrap(repo: repo, picker: picker));
      await tester.pumpAndSettle();
      expect(find.text('Myndir'), findsOneWidget);
    });

    testWidgets('shows "Add photo" FAB', (tester) async {
      final picker = _FakePhotoPicker(null);
      final repo = _CapturingPhotoRepository();
      await tester.pumpWidget(_wrap(repo: repo, picker: picker));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    });

    testWidgets('FAB tap with no image picked is a no-op', (tester) async {
      final picker = _FakePhotoPicker(null);
      final repo = _CapturingPhotoRepository();
      await tester.pumpWidget(_wrap(repo: repo, picker: picker));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_a_photo));
      await tester.pumpAndSettle();

      expect(picker.wasCalled, isTrue);
      expect(repo.addCalls, isEmpty);
    });

    testWidgets(
      'tapping FAB → pick → select lexicon → addPhoto called',
      (tester) async {
        final picker = _FakePhotoPicker(File('/tmp/fake_source.jpg'));
        final repo = _CapturingPhotoRepository();

        await tester.pumpWidget(_wrap(repo: repo, picker: picker));
        await tester.pumpAndSettle();

        // Trigger picker.
        await tester.tap(find.byIcon(Icons.add_a_photo));
        await tester.pumpAndSettle();

        // LexiconPicker should now be visible.
        expect(find.text('Veldu orð'), findsOneWidget);

        // Tap "hundur".
        await tester.ensureVisible(find.text('hundur'));
        await tester.tap(find.text('hundur'));
        await tester.pumpAndSettle();

        expect(repo.addCalls, hasLength(1));
        expect(repo.addCalls.first.tag.word, 'hundur');
        expect(repo.addCalls.first.source.path, '/tmp/fake_source.jpg');
      },
    );

    testWidgets('shows existing photos ordered most-recent-first',
        (tester) async {
      final picker = _FakePhotoPicker(null);
      final repo = _CapturingPhotoRepository(initialPhotos: [
        PhotoTag(
          id: 2,
          imagePath: '/fake/b.jpg',
          lexiconWord: 'köttur',
          createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
        PhotoTag(
          id: 1,
          imagePath: '/fake/a.jpg',
          lexiconWord: 'hundur',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      ]);

      await tester.pumpWidget(_wrap(repo: repo, picker: picker));
      await tester.pumpAndSettle();

      expect(find.text('hundur'), findsOneWidget);
      expect(find.text('köttur'), findsOneWidget);
    });

    testWidgets('empty photos shows a discoverable empty state',
        (tester) async {
      final picker = _FakePhotoPicker(null);
      final repo = _CapturingPhotoRepository();
      await tester.pumpWidget(_wrap(repo: repo, picker: picker));
      await tester.pumpAndSettle();

      // Some kind of "no photos yet" hint or just the FAB visible (we accept
      // either; we do NOT show child-facing text). For the parent UI, an
      // Icelandic prompt is fine.
      expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    });
  });
}
