---
phase: 10
plan: 03
title: Photo persistence + Drift override source
status: complete
date: 2026-05-02
tags: [drift, image-codec, photo-repo, riverpod]
requirements: [PHOTO-01, PHOTO-03, PHOTO-04, PHOTO-06]
---

# Plan 10-03 — Photo persistence

Phase 10 Workstream C. `PhotoRepository` accepts a source `File`, downsizes
via the `image` package (≤1024 px max edge, JPEG q=85), saves under
`<appDocs>/hugrun_photos/<uuid>.jpg`, and inserts a `photo_tags` Drift row.
`DriftPhotoOverrideSource` implements the Phase 5 `PhotoOverrideSource`
contract against the new table. The Riverpod binding override is wired in
`lib/main.dart` so the matching activity automatically picks up parent
photos.

## Atomic commits

| Hash      | Type | Subject                                                                 |
|-----------|------|-------------------------------------------------------------------------|
| `679f172` | test | failing PhotoRepository + DriftPhotoOverrideSource tests (RED)          |
| `ef26b0b` | feat | photo persistence + Drift override source (GREEN)                       |

## Files

### Created
- `lib/features/parent_settings/photo_upload/photo_repository.dart`
- `lib/features/parent_settings/photo_upload/drift_photo_override_source.dart`
- `test/features/parent_settings/photo_upload/photo_repository_test.dart` — 8 tests
- `test/features/parent_settings/photo_upload/drift_photo_override_source_test.dart` — 6 tests

### Modified
- `pubspec.yaml` — added `image_picker ^1.1.2`, `image ^4.8.0`,
  `uuid ^4.5.3`, promoted `path` from dev_dependencies to direct main
- `pubspec.lock` — refreshed
- `lib/main.dart` — overrides `photoOverrideSourceProvider` at
  `ProviderScope` level with `DriftPhotoOverrideSource` (Phase 5
  default `EmptyPhotoOverrideSource` remains for tests)

## PhotoRepository contract

```dart
Future<String> addPhoto({
  required File source,
  required LexiconEntry tag,
});
Future<List<PhotoTag>> listPhotos();
Stream<List<PhotoTag>> watchPhotos();
Future<void> deletePhoto(int id);
```

- **D-11** Downsize: max edge 1024 px, JPEG quality 85. Aspect ratio
  preserved. Smaller images NOT upscaled.
- **D-12** Path: `<getApplicationDocumentsDirectory>/hugrun_photos/<uuid>.jpg`.
  App reinstall → photos lost (acceptable per PROJECT.md "no cloud").
- **D-22** Deps: `image_picker`, `image`, `uuid` declared. `path` promoted.
  `tools/check-no-tracking.sh` still passes.

## DriftPhotoOverrideSource

- Synchronous interface (Phase 5's `photosForWordSlug(slug) → List<String>`).
- Implementation caches the `lexicon_word → image_paths` map fed by a
  `select(photoTags).watch()` stream.
- `refresh()` escape-hatch for explicit invalidation (used in tests).
- `dispose()` cancels the stream subscription — wired via `ref.onDispose`
  in `main.dart`.

## Tests (14 new)

PhotoRepository:
- saves a downsized JPEG under `hugrun_photos/<uuid>.jpg`
- inserts `photo_tags` row with `image_path` + `lexicon_word`
- preserves smaller-than-1024 images (no upscaling)
- handles tall portrait images (height > width)
- throws on non-existent source file
- generates distinct filenames for multiple uploads
- `listPhotos()` returns rows
- JPEG output is non-empty (FFD8 magic header asserted)

DriftPhotoOverrideSource:
- implements `PhotoOverrideSource`
- returns empty list when `photo_tags` is empty
- returns image_path strings matching `lexicon_word`
- synchronous `photosForWordSlug` returns cached snapshot
- `refresh()` picks up new photos inserted after construction
- returns empty list for unknown wordSlug

## Decisions exercised

- **D-11** Image downsize via pure-Dart `image` package, max 1024 px,
  q=85 — bounds DB size
- **D-12** Path under app documents directory
- **D-13** `DriftPhotoOverrideSource` implements the Phase 5 abstract
  class
- **D-14** 40% Bernoulli stays in `RoundGenerator` (unchanged) — this
  source only answers "what photos exist for this slug?"
- **D-20** Photos NEVER leave device (verified — no HTTP code path in
  this layer; `tools/check-no-tracking.sh` enforces no analytics SDKs)
- **D-22** Pubspec additions; transitive `path` promoted to direct
  per `depend_on_referenced_packages` lint

## Deviations

1. **`path` package promoted from dev_dependencies → main** (Rule 3 —
   blocking). My PhotoRepository `lib/` code uses `package:path` for
   joining; the lint `depend_on_referenced_packages` correctly flags
   this. The package was already in dev_dependencies for a no-tracking
   test fixture; I moved it. No version bump.

2. **`Override` type in `lib/main.dart` overrides list** (Rule 1 — bug
   from initial typed-list attempt). Riverpod 4.x doesn't expose
   `Override` as a top-level type in this stack; dropped the explicit
   list-element type. Inference handles it.
