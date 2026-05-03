// Phase 10 Plan 04 — PhotoUploadScreen.
//
// Parent-facing screen for managing personalized photos. Reachable from
// ParentSettingsScreen via the "Myndir" entry (Phase 10 D-08).
//
// Layout:
//   * AppBar title: "Myndir" (Photos)
//   * Body: list of existing tagged photos (most recent first), each row
//     shows the lexicon word + a thumbnail. Long-press → delete confirm.
//   * FAB: "Add a photo" — opens injected PhotoPicker, then navigates
//     to LexiconPicker on the same Navigator stack, then dispatches to
//     PhotoRepository.addPhoto.
//
// All Icelandic text — parent UI. STAFIR-08 ("zero text instructions visible
// to child") doesn't apply: parent gate (3 s hold from Phase 1) prevents the
// child from reaching here.
//
// Privacy: photos are NEVER uploaded. The "share" affordance does not exist.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/lexicon/lexicon_entry.dart';
import 'lexicon_picker.dart';
import 'photo_upload_providers.dart';

class PhotoUploadScreen extends ConsumerStatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  ConsumerState<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends ConsumerState<PhotoUploadScreen> {
  List<PhotoTag>? _photos;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final repo = ref.read(photoRepositoryFacadeProvider);
    final photos = await repo.listPhotos();
    if (!mounted) return;
    setState(() => _photos = photos);
  }

  Future<void> _onAddPhotoPressed() async {
    final picker = ref.read(photoPickerProvider);
    final repo = ref.read(photoRepositoryFacadeProvider);
    final source = await picker.pickFromGallery();
    if (source == null) return;
    if (!mounted) return;

    final selected = await Navigator.of(context).push<LexiconEntry>(
      MaterialPageRoute<LexiconEntry>(
        builder: (_) => LexiconPicker(
          onSelected: (entry) => Navigator.of(context).pop(entry),
        ),
      ),
    );
    if (selected == null) return;
    if (!mounted) return;

    await repo.addPhoto(source: source, tag: selected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mynd vistuð fyrir "${selected.word}"'),
        duration: const Duration(seconds: 1),
      ),
    );
    await _refresh();
  }

  Future<void> _confirmDelete(PhotoTag tag) async {
    final repo = ref.read(photoRepositoryFacadeProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eyða mynd?'),
        content: Text(tag.lexiconWord),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hætta við'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eyða'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await repo.deletePhoto(tag.id);
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    return Scaffold(
      appBar: AppBar(title: const Text('Myndir')),
      body: photos == null
          ? const Center(child: CircularProgressIndicator())
          : photos.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final tag = photos[i];
                return ListTile(
                  key: Key('photo-row-${tag.id}'),
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: _PhotoThumbnail(path: tag.imagePath),
                  ),
                  title: Text(tag.lexiconWord),
                  onLongPress: () => _confirmDelete(tag),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        key: const Key('photo-upload-add-fab'),
        onPressed: _onAddPhotoPressed,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Engar myndir enn',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Bættu við myndum sem munu birtast '
              'í leikjum með rétta orðinu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      // Defensive — file may have been deleted out-of-band.
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
    return Image.file(file, fit: BoxFit.cover);
  }
}
