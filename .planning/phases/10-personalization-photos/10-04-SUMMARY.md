---
phase: 10
plan: 04
title: Photo upload UI
status: complete
date: 2026-05-02
tags: [flutter-widgets, parent-settings, image-picker]
requirements: [PHOTO-01, PHOTO-02]
---

# Plan 10-04 — Photo upload UI

Phase 10 Workstream D. Parent-facing UI for managing personalized photos.
`PhotoUploadScreen` (reachable from `ParentSettingsScreen` via the new
"Myndir" button) hosts the add-photo flow, the existing-photos list,
and long-press delete. `LexiconPicker` offers an alphabetical list of
the 30 starter lexicon entries; tapping one returns the chosen
`LexiconEntry` to the caller.

The `image_picker` plugin is wrapped in a `PhotoPicker` abstraction
(`ImagePickerPhotoPicker` in production, fakes in tests) so widget
tests never touch platform channels.

## Atomic commits

| Hash      | Type | Subject                                                          |
|-----------|------|------------------------------------------------------------------|
| `f27a0ec` | test | failing PhotoUploadScreen + LexiconPicker tests (RED)            |
| `3196058` | feat | photo upload screen + lexicon picker (GREEN)                     |

## Files

### Created
- `lib/features/parent_settings/photo_upload/photo_picker.dart` — `PhotoPicker` interface + `ImagePickerPhotoPicker`
- `lib/features/parent_settings/photo_upload/photo_upload_providers.dart` — `photoPickerProvider`, `photoRepositoryFacadeProvider`
- `lib/features/parent_settings/photo_upload/lexicon_picker.dart` — alphabetical list widget
- `lib/features/parent_settings/photo_upload/photo_upload_screen.dart` — main screen
- `test/features/parent_settings/photo_upload/lexicon_picker_test.dart` — 5 tests
- `test/features/parent_settings/photo_upload/photo_upload_screen_test.dart` — 6 tests

### Modified
- `lib/features/parent_settings/parent_settings_screen.dart` — added "Myndir" button (D-08) + new constant `photosButton`

## UX

- **AppBar (Myndir)**: "Myndir"
- **AppBar (Lexicon)**: "Veldu orð"
- **FAB**: `Icons.add_a_photo`
- **Empty state**: "Engar myndir enn" + brief explanation
- **Tile content**: lexicon word + 48×48 thumbnail (file image)
- **Long-press → delete confirm dialog**:
  - "Eyða mynd?" title
  - Cancel: "Hætta við" / Confirm: "Eyða"
- **After save**: SnackBar "Mynd vistuð fyrir 'hundur'" (1 s)

All Icelandic — parent UI, gated by 3 s parent-gate hold from Phase 1.

## Tests (11 new)

LexiconPicker:
- renders the configured number of itemBuilder slots
  (`SliverChildBuilderDelegate.estimatedChildCount == kStarterLexicon.length`)
- a sample of off-screen entries can be scrolled into view
- tapping a tile invokes `onSelected` with the entry
- AppBar shows Icelandic title "Veldu orð"
- every entry tile is tappable

PhotoUploadScreen:
- shows AppBar title "Myndir"
- shows "Add photo" FAB
- FAB tap with no image picked is a no-op
- tapping FAB → pick → select lexicon → `addPhoto` called with
  the right `(source, tag)` pair
- shows existing photos ordered most-recent-first
- empty state visible when no photos

## Decisions exercised

- **D-08** PhotoUploadScreen reachable from ParentSettingsScreen
- **D-09** Add flow: FAB → image_picker → LexiconPicker → addPhoto → SnackBar + list refresh
- **D-10** Long-press to delete

## Deviations

1. **`scrollUntilVisible` instead of `ensureVisible`** in widget tests
   (Rule 1 — test bug). `ensureVisible` requires the widget to be in
   the element tree; `ListView.builder` lazily constructs tiles.
   Switched to `tester.scrollUntilVisible(...)` which performs drag
   gestures until the target is reachable. Pattern reused in 3 tests.

2. **Camera capture deferred to v2** (per `<deviations_protocol>` —
   "image_picker has unexpected platform-specific behavior on Android").
   PhotoPicker exposes only `pickFromGallery()`. v1 personalization
   does not need camera capture; gallery covers the parent flow
   without the platform-permissions complexity. `PhotoPicker` is an
   abstract class so a v2 `pickFromCamera()` can be added without
   breaking callers.
