// Pure-Dart abstraction for the photo-override slot in the Letter-to-Word
// Matching activity. Phase 5 ships an empty stub
// ([EmptyPhotoOverrideSource]); Phase 10's PHOTO-* features will swap the
// Riverpod binding for a Drift-backed implementation that returns
// parent-uploaded photo IDs tagged with the matching word slug.
//
// Decisions:
//   D-13     Photo override hook with ~40% Bernoulli routing in
//            RoundGenerator. Phase 5 implements the contract; Phase 10
//            populates it.
//   MATCH-04 Forward-compat for personalized photos.

/// Source of photo overrides keyed by example-word slug.
///
/// Phase 5 ships [EmptyPhotoOverrideSource]; Phase 10 (PHOTO-*) replaces
/// the binding with a Drift-backed implementation that returns parent-
/// uploaded photo IDs tagged with [wordSlug].
abstract class PhotoOverrideSource {
  const PhotoOverrideSource();

  /// Returns photo IDs (opaque strings) tagged with [wordSlug]. Empty
  /// list = no overrides; round generator falls back to stock placeholder.
  List<String> photosForWordSlug(String wordSlug);
}

/// Phase 5 default. Returns empty list for every slug. Phase 10 swaps this
/// out by overriding `photoOverrideSourceProvider` (Plan 05-02) with a
/// Drift-backed implementation.
class EmptyPhotoOverrideSource extends PhotoOverrideSource {
  const EmptyPhotoOverrideSource();

  @override
  List<String> photosForWordSlug(String wordSlug) => const <String>[];
}
