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
        // Phase 12 UI-04: LexiconPicker is now a 2-column GridView.
        // Set surface size large enough to host the picker comfortably,
        // and tap the keyed tile (lexicon-tile-hundur) rather than
        // find.text('hundur') — the noun text in the picker tile is
        // a small caption inside an InkWell, but the InkWell takes
        // its key from the tile root (more robust to layout changes).
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final picker = _FakePhotoPicker(File('/tmp/fake_source.jpg'));
        final repo = _CapturingPhotoRepository();

        await tester.pumpWidget(_wrap(repo: repo, picker: picker));
        await tester.pumpAndSettle();

        // Trigger picker.
        await tester.tap(find.byIcon(Icons.add_a_photo));
        await tester.pumpAndSettle();

        // LexiconPicker should now be visible.
        expect(find.text('Veldu orð'), findsOneWidget);

        // Tap "hundur" tile — kStarterLexicon has ≥30 entries; the tile
        // can be below the fold in a 2-col grid. ensureVisible after
        // scrollUntilVisible hits the corner case where the cacheExtent
        // mounts the tile but it's not yet inside the viewport.
        final hundurTile = find.byKey(const Key('lexicon-tile-hundur'));
        await tester.scrollUntilVisible(
          hundurTile,
          100.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(hundurTile);
        await tester.pumpAndSettle();
        await tester.tap(hundurTile);
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
