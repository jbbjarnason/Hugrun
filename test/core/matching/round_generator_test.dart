// Plan 05-01 Task 2 tests (initial slice): PhotoOverrideSource interface.
//
// Task 3 (RoundGenerator G1..G11) is appended in the next test commit
// alongside its production file.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/matching/photo_override_source.dart';

// File-local test-double — kept for parity with Task 3 fixtures.
class _FixedPhotoOverrideSource extends PhotoOverrideSource {
  const _FixedPhotoOverrideSource(this._byslug);
  final Map<String, List<String>> _byslug;

  @override
  List<String> photosForWordSlug(String wordSlug) =>
      _byslug[wordSlug] ?? const <String>[];
}

void main() {
  group('PhotoOverrideSource', () {
    test('Test 1: abstract interface returns photos by slug', () {
      const src = _FixedPhotoOverrideSource(<String, List<String>>{
        'hundur': <String>['photo-1', 'photo-2'],
      });
      expect(src.photosForWordSlug('hundur'), <String>['photo-1', 'photo-2']);
      expect(src.photosForWordSlug('katur'), isEmpty);
    });

    test('Test 2: EmptyPhotoOverrideSource returns [] for every slug', () {
      const src = EmptyPhotoOverrideSource();
      expect(src.photosForWordSlug('hundur'), isEmpty);
      expect(src.photosForWordSlug(''), isEmpty);
      expect(src.photosForWordSlug('any-slug-at-all'), isEmpty);
    });
  });
}
