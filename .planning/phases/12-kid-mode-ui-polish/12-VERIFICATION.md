---
status: passed
phase: 12
date: 2026-05-02
---

# Phase 12 Verification

**Status:** PASSED — all 4 workstreams shipped, 11 quality-gate
items satisfied. No human-verify checkpoints needed (Phase 12 is
purely structural — kid-screen polish that is verifiable via
widget tests).

## Quality gate

All items in `12-SUMMARY.md`'s quality gate are checked:

- **454 / 1 tests pass** (443 baseline → 454 — net +11). The
  single failure is `audio_manifest_test.dart` "Phase 6 phoneme +
  new word keys are NOT in the Phase 2 stub manifest (D-21)" —
  this failure pre-dates Phase 12 (verified by `git stash`
  round-trip during execution) and is owned by Phase 13's
  manifest regeneration. Logged in `deferred-items.md`.
- **`flutter analyze`**: 15 warnings, ALL pre-existing
  `scoped_providers_should_specify_dependencies` already
  documented in Phase 10's verification. Zero new issues
  introduced by Phase 12.
- **`flutter build apk --debug`**: succeeds
  (`build/app/outputs/flutter-apk/app-debug.apk`).

## Critical invariants verified

1. **PROJECT.md "zero text instructions visible to child"** —
   StafirRoom and TolurRoom no longer render an AppBar or any
   Text title. Verified by:
   - `stafir_room_test.dart`: "StafirRoom shows NO AppBar"
   - `stafir_room_test.dart`: "S6 — NO AppBar in any mode"
     (cycles letters → match → cvc, asserts `findsNothing` each
     time).
   - `tolur_room_test.dart`: "TolurRoom shows NO AppBar"

2. **Mode-toggle invariant: ONE icon per cycle affordance** —
   `Icons.swap_horiz` rendered across all 4 Stafir modes and
   both Tölur modes. Verified by:
   - `stafir_mode_toggle_test.dart` M3: "all 4 mode icons
     identical (1 unique)".
   - M3b: explicit `expect(icon, Icons.swap_horiz)` per mode.
   - `tolur_mode_toggle_test.dart` TM3 / TM3b: same shape.

3. **Pre-reader navigability — home glyphs present** —
   home_page_test asserts `home-room-glyph-stafir` and
   `home-room-glyph-tolur` keys exist as findable widgets.

4. **Lexicon picker is a 2-column GridView** — verified by:
   - `lexicon_picker_test.dart` Phase 12 UI-04: "renders a
     2-column GridView (was vertical ListView)" — pulls the
     `SliverGridDelegateWithFixedCrossAxisCount` and asserts
     `crossAxisCount == 2`.
   - Phase 12 UI-04: "grid declares one slot per lexicon entry"
     (estimated child count == kStarterLexicon.length, currently 30).

5. **Backward-compat — RoomButton without glyph still works** —
   the existing `room_button_test.dart` "RoomButton renders the
   provided label" / tap target tests pass unchanged. Phase 12
   only added the optional `glyph:` parameter; the no-glyph code
   path falls back to the original `headlineLarge` label posture.

6. **No edits outside Phase 12 scope.** Phase 12's commits modify:
   - `lib/features/home/`           (home page + room button + glyphs)
   - `lib/features/stafir/`         (room, mode toggle)
   - `lib/features/tolur/`          (room, mode toggle)
   - `lib/features/parent_settings/photo_upload/lexicon_picker.dart`
   - corresponding `test/` files
   - `.planning/phases/12-kid-mode-ui-polish/`
   No diff in `assets/images/` (Phase 11), `tools/tts/` or
   `lib/gen/audio_manifest.g.dart` (Phase 13).

7. **Atomic commits per RED/GREEN cycle.** 8 commits across 4
   workstreams:

   | Hash      | WS | Type | Subject                                            |
   |-----------|----|------|----------------------------------------------------|
   | `e59e080` | A  | test | failing AppBar absence on StafirRoom + TolurRoom (RED) |
   | `f9bff3e` | A  | feat | remove AppBar from StafirRoom + TolurRoom (GREEN)  |
   | `df56061` | B  | test | failing one-icon mode toggle assertion (RED)       |
   | `8677a27` | B  | feat | swap_horiz across both mode toggles (GREEN)        |
   | `ac5488f` | C  | test | failing RoomButton + HomePage glyph assertions (RED) |
   | `0d05666` | C  | feat | add styled glyphs to home rooms (GREEN)            |
   | `4d11e7a` | D  | test | failing 2-col GridView assertion (RED)             |
   | `56ba356` | D  | feat | LexiconPicker 2-col image grid (GREEN)             |

8. **Parent gate intact.** Home screen's 3-second hold parent gate
   (cog icon top-right, opens `ParentSettingsScreen`) untouched —
   the existing `home_page_test.dart` test
   "Long-press settings icon for 3s navigates to
   ParentSettingsScreen" passes unchanged.

## Files modified summary

| File                                                                | Lines  |
|---------------------------------------------------------------------|--------|
| `lib/features/stafir/stafir_room.dart`                              | -1 +5  |
| `lib/features/tolur/tolur_room.dart`                                | -1 +3  |
| `lib/features/stafir/widgets/stafir_mode_toggle.dart`               | -22 +19 |
| `lib/features/tolur/widgets/tolur_mode_toggle.dart`                 | -16 +13 |
| `lib/features/home/home_page.dart`                                  | -2 +6  |
| `lib/features/home/room_button.dart`                                | -7 +35 |
| `lib/features/home/home_room_glyphs.dart` *(NEW)*                   | +112   |
| `lib/features/parent_settings/photo_upload/lexicon_picker.dart`     | -16 +120 |
| `test/features/stafir/stafir_room_test.dart`                        | -8 +12 |
| `test/features/tolur/tolur_room_test.dart`                          | -10 +6 |
| `test/features/stafir/widgets/stafir_mode_toggle_test.dart`         | -10 +35 |
| `test/features/tolur/widgets/tolur_mode_toggle_test.dart`           | -10 +25 |
| `test/features/home/home_page_test.dart`                            | -0 +30 |
| `test/features/home/room_button_test.dart`                          | -1 +40 |
| `test/features/parent_settings/photo_upload/lexicon_picker_test.dart` | -35 +78 |
| `test/features/parent_settings/photo_upload/photo_upload_screen_test.dart` | -7 +22 |

## Phase 12 does NOT touch

- `assets/images/` (Phase 11)
- `tools/tts/`, `lib/gen/audio_manifest.g.dart` (Phase 13)
- `lib/features/stafir/{matching,cvc,tracing}/` activity bodies
- `lib/features/tolur/{sequencing,correspondence,subitizing,addition}/`
  activity bodies (the activities never had AppBars; the AppBar
  removal is at the room-Scaffold level only)
- Drift schema, audio engine, parent gate, welcome narration,
  alphabet, phonemes, numerals, lexicon data
