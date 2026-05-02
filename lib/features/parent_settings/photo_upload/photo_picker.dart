// Phase 10 Plan 04 — PhotoPicker abstraction.
//
// Wraps the image_picker plugin so tests can substitute a fake without
// touching platform channels. Production wiring is in
// `photo_upload_providers.dart`; the abstract class lives here so both
// production and test code can implement it.

import 'dart:io';

import 'package:image_picker/image_picker.dart' as ip;

abstract class PhotoPicker {
  /// Returns the selected image file from the photo library, or `null` if
  /// the user cancelled. Camera capture is deferred (per `<deviations>`
  /// guidance — camera adds platform permissions complexity that isn't
  /// needed for the v1 personalization flow).
  Future<File?> pickFromGallery();
}

/// Production [PhotoPicker] backed by `image_picker`.
///
/// Privacy note: `image_picker` shows the native iOS/Android picker UI;
/// the user's photo library data never leaves the device. The XFile path
/// returned by the plugin is a tmp-cache path; we copy/downsize it into
/// app documents dir in [PhotoRepository] before persisting.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker() : _picker = ip.ImagePicker();

  final ip.ImagePicker _picker;

  @override
  Future<File?> pickFromGallery() async {
    final picked = await _picker.pickImage(source: ip.ImageSource.gallery);
    if (picked == null) return null;
    return File(picked.path);
  }
}
