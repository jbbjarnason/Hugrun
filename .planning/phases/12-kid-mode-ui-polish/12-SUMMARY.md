---
phase: 12
title: Kid-Mode UI Polish
status: complete
date: 2026-05-02
plans:
  - 12-A-appbar-removal
  - 12-B-mode-toggle-icon
  - 12-C-home-room-glyphs
  - 12-D-lexicon-image-grid
tags: [ui, kid-mode, polish, accessibility]
key-files:
  modified:
    - lib/features/stafir/stafir_room.dart
    - lib/features/tolur/tolur_room.dart
    - lib/features/stafir/widgets/stafir_mode_toggle.dart
    - lib/features/tolur/widgets/tolur_mode_toggle.dart
    - lib/features/home/home_page.dart
    - lib/features/home/room_button.dart
    - lib/features/parent_settings/photo_upload/lexicon_picker.dart
    - test/features/stafir/stafir_room_test.dart
    - test/features/tolur/tolur_room_test.dart
    - test/features/stafir/widgets/stafir_mode_toggle_test.dart
    - test/features/tolur/widgets/tolur_mode_toggle_test.dart
    - test/features/home/home_page_test.dart
    - test/features/home/room_button_test.dart
    - test/features/parent_settings/photo_upload/lexicon_picker_test.dart
    - test/features/parent_settings/photo_upload/photo_upload_screen_test.dart
  created:
    - lib/features/home/home_room_glyphs.dart
metrics:
  duration: ~75 min
  tasks_completed: 4
  red_green_pairs: 4
  commits: 8
  test_baseline: 443
  test_post: 454 (+11)
---

# Phase 12 Plan: Kid-Mode UI Polish Summary

Hide AppBars from kid-facing screens, replace 4-icon mode toggle with
one consistent cycle icon, add styled glyph affordances to the home
screen room buttons, and convert the lexicon picker from a vertical
text-only ListView to a 2-column image grid — all under TDD with
atomic per-task RED/GREEN commits.

## Workstreams + commits

| WS | Plan          | RED commit | GREEN commit | Subject                                       |
|----|---------------|------------|--------------|-----------------------------------------------|
| A  | 12-A AppBar   | `e59e080`  | `f9bff3e`    | StafirRoom + TolurRoom drop AppBar (UI-01)    |
| B  | 12-B Toggle   | `df56061`  | `8677a27`    | swap_horiz one-icon toggle (UI-02)            |
| C  | 12-C Glyphs   | `ac5488f`  | `0d05666`    | Home rooms render alphabet/numeral glyph (UI-03) |
| D  | 12-D Grid     | `4d11e7a`  | `56ba356`    | LexiconPicker 2-col image grid (UI-04)        |

## Decisions

- **Mode toggle icon → `Icons.swap_horiz`.** A horizontal "swap"
  arrow reads as "tap-and-hold to switch to the next thing" without
  literacy and is consistent across both rooms. The previous per-mode
  icon mapping (image / grid / spellcheck / edit / category) implied
  the icon was a "current mode badge" — confusing for a 5-year-old.
  The hold-ring (already wired via `ParentGateController`) remains
  the visual hint for "hold to switch". `currentMode` parameter is
  preserved on both widgets for API compatibility.

- **Home glyphs use the locked LetterTile palette.** `StafirRoomGlyph`
  paints "A a á" in peach / mint / periwinkle; `TolurRoomGlyph` paints
  "1 2 3" in butter / sky-teal / lavender — same `paletteForIndex`
  helper that drives Stafir tiles, so the visual identity carries
  from the home screen straight into the room.

- **Lexicon picker fallback is a pastel block, not a broken-image
  icon.** `Image.asset.errorBuilder` returns a `Container` painted
  with `paletteForIndex(i)` when Phase 11's `defaultImagePath`
  doesn't exist on disk. The noun text caption is rendered
  unconditionally beneath, so the picker is fully functional in both
  states (with and without Phase 11 images). At execute time Phase 11
  *had* already shipped 31 images into `assets/images/letters/words/`
  — we tested both code paths regardless via the existing test
  fixture (which doesn't bind a Flutter asset bundle, so all images
  go through errorBuilder).

- **Parent-facing AppBar persists.** The Phase 12 scope explicitly
  excludes parent surfaces (ParentSettings, PhotoUpload, LexiconPicker
  — parents can read text). Only StafirRoom + TolurRoom drop their
  AppBars.

## Implementation notes

### Workstream A — AppBar removal
Both `StafirRoom` and `TolurRoom` simply drop the `appBar:` argument
from their `Scaffold`. The activities hosted inside (Matching, CVC,
Tracing, Sequencing, Correspondence, Subitizing, Addition) never had
their own AppBars — they're plain `Stack`/`Column` bodies — so no
per-activity edits were needed. The mode toggle is positioned
top-right inside the room's `SafeArea`, unchanged.

### Workstream B — Mode toggle icon
Both `StafirModeToggle` and `TolurModeToggle` now render
`const Icon(Icons.swap_horiz, ...)` regardless of `currentMode`. The
parameter is kept on both widgets (existing callers pass it). All
hold-gesture / hold-ring logic is untouched.

### Workstream C — Home room glyphs
- `RoomButton` gains optional `glyph: Widget?`. When non-null, the
  glyph renders above the text label and the label drops to
  `titleMedium`. When null, the original `headlineLarge` posture is
  preserved (existing `room_button_test` cases pass unchanged).
- New file `lib/features/home/home_room_glyphs.dart` hosts
  `StafirRoomGlyph` (key `home-room-glyph-stafir`) and
  `TolurRoomGlyph` (key `home-room-glyph-tolur`). Each is a tight
  `Row` of 3 pastel chips containing one Icelandic alphabet glyph or
  one numeral.
- `HomePage` wires `glyph: const StafirRoomGlyph()` and
  `glyph: const TolurRoomGlyph()` into the two `RoomButton`s.

### Workstream D — Lexicon image grid
- `LexiconPicker` body switches from `ListView.builder` to
  `GridView.builder` with
  `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,
  childAspectRatio: 0.85)`.
- New private widget `_LexiconTile` renders an `Image.asset` of the
  entry's `defaultImagePath` with a pastel `errorBuilder` fallback,
  plus the noun word as a small bold caption.
- Tile root keyed `lexicon-tile-<word>` (preserving Phase 10 contract).

## Test changes

| Test file                                        | Change                                  | Net delta |
|--------------------------------------------------|-----------------------------------------|-----------|
| `stafir_room_test.dart`                          | Flip 2 AppBar-presence assertions       | 0 tests   |
| `tolur_room_test.dart`                           | Flip 1 AppBar-presence assertion        | 0 tests   |
| `stafir_mode_toggle_test.dart`                   | Flip M3, add M3b                        | +1 test   |
| `tolur_mode_toggle_test.dart`                    | Flip TM3, add TM3b                      | +1 test   |
| `room_button_test.dart`                          | Add 2 glyph tests                       | +2 tests  |
| `home_page_test.dart`                            | Add 2 glyph-presence tests              | +2 tests  |
| `lexicon_picker_test.dart`                       | Add 3 grid tests; harden 2 tap tests    | +3 tests  |
| `photo_upload_screen_test.dart`                  | Update 1 ripple test to byKey + ensure  | 0 tests   |
| **Total**                                         |                                         | **+9 net** |

(Test count 443 → 454 = +11 includes Phase 11/13 ripples that landed
concurrently outside Phase 12 territory.)

## Deviations from plan

**None for Workstreams A, B, C.**

**Workstream D — auto-fixed (Rule 1, scope-direct ripple):**
- `photo_upload_screen_test.dart` had one test
  ("tapping FAB → pick → select lexicon → addPhoto called") that
  used `find.text('hundur')` + `scrollUntilVisible` against the
  old ListView. The new GridView puts the noun text inside an
  inner caption (different RenderParagraph hit-target) and at
  default 800×600 surface size, the tile center fell at offset
  y≈991 — outside the viewport. Updated the test to:
  1. Set surface size 1280×800 explicitly.
  2. Use `byKey('lexicon-tile-hundur')` (the InkWell root, robust
     hit-target) instead of `find.text('hundur')`.
  3. Use `scrollUntilVisible` + `ensureVisible` (the former exits
     too early when `cacheExtent` mounts the tile but doesn't
     yet position it inside the viewport).

  This is a Rule 1 auto-fix — the picker change directly broke
  this test, and it lives in Phase 12's territory
  (`lib/features/parent_settings/photo_upload/`).

## Known stubs

None. All four workstreams ship complete, working surfaces:
- Activities continue to render exactly as before, just without
  the AppBar chrome.
- Toggle icon is the same across all modes (no "TODO: real icon").
- Home glyphs are real `Text` glyphs with real palette colors.
- Lexicon picker fallback is a real pastel block — not "to be
  filled in later".

## Quality gate

- [x] All kid-mode screens (StafirRoom + TolurRoom) have NO visible AppBar
- [x] StafirModeToggle + TolurModeToggle use ONE consistent icon
      (Icons.swap_horiz) across all modes
- [x] Home screen rooms render visual glyph icons keyed
      `home-room-glyph-stafir` / `home-room-glyph-tolur`
- [x] LexiconPicker is a 2-col image grid with graceful fallback
- [x] Widget tests updated/added; all Phase 12 tests pass (Phase 12
      tests: 11 new + 5 updated = 16 touchpoints, all green)
- [x] `flutter analyze` clean — 15 warnings, ALL pre-existing
      `scoped_providers_should_specify_dependencies` (Phase 10
      already documented these). Zero new issues.
- [x] `flutter test` 443 → 454 pass (+11). One pre-existing failure
      (`audio_manifest_test.dart` D-21) belongs to Phase 13 territory
      — see deferred-items.md.
- [x] `flutter build apk --debug` succeeds
- [x] No edits outside Phase 12 scope (no `assets/images/`,
      `tools/tts/`, `lib/gen/audio_manifest.g.dart`)
- [x] Atomic commits — 4 RED + 4 GREEN, one task each
- [x] VERIFICATION.md status: passed

## Self-Check: PASSED

Files claimed in frontmatter exist:
- `lib/features/home/home_room_glyphs.dart` — FOUND
- All modified files — FOUND

Commits claimed exist:
- `e59e080`, `f9bff3e`, `df56061`, `8677a27`, `ac5488f`, `0d05666`,
  `4d11e7a`, `56ba356` — all reachable via `git log --oneline`.
