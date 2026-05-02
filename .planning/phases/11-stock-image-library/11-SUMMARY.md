---
phase: 11
phase_name: Stock Image Library
subsystem: assets
tags: [phase-11, assets, lexicon, fix-pass]
status: shipped
completed: 2026-05-02
duration_minutes: 16
requirements_satisfied: [IMG-01, IMG-02, IMG-03]
dependency_graph:
  requires: [Phase 10 — kStarterLexicon paths exist as constants]
  provides:
    - 32 webp images at assets/images/letters/words/
    - regeneration tooling (tools/images/generate_lexicon_images.py)
    - asset-existence test (test/core/lexicon/lexicon_assets_test.dart)
  affects:
    - Phase 4 ExampleWordOverlay — now renders real images instead of placeholder
    - Phase 5 MatchingActivity — auto-renders the new images
    - Phase 9 CorrespondenceActivity / AdditionActivity — auto-renders the new images
tech_stack_added: []
key_files:
  created:
    - assets/images/letters/words/auga.webp
    - assets/images/letters/words/banani.webp
    - assets/images/letters/words/bill.webp
    - assets/images/letters/words/blom.webp
    - assets/images/letters/words/bok.webp
    - assets/images/letters/words/bolti.webp
    - assets/images/letters/words/braud.webp
    - assets/images/letters/words/dukka.webp
    - assets/images/letters/words/epli.webp
    - assets/images/letters/words/fiskur.webp
    - assets/images/letters/words/fugl.webp
    - assets/images/letters/words/hattur.webp
    - assets/images/letters/words/hestur.webp
    - assets/images/letters/words/hundur.webp
    - assets/images/letters/words/hus.webp
    - assets/images/letters/words/kanina.webp
    - assets/images/letters/words/koddi.webp
    - assets/images/letters/words/kottur.webp
    - assets/images/letters/words/kyr.webp
    - assets/images/letters/words/lampi.webp
    - assets/images/letters/words/mani.webp
    - assets/images/letters/words/mjolk.webp
    - assets/images/letters/words/mus.webp
    - assets/images/letters/words/peysa.webp
    - assets/images/letters/words/ros.webp
    - assets/images/letters/words/skor.webp
    - assets/images/letters/words/sokkar.webp
    - assets/images/letters/words/sol.webp
    - assets/images/letters/words/stoll.webp
    - assets/images/letters/words/teppi.webp
    - assets/images/letters/words/tre.webp
    - assets/images/letters/words/vatn.webp
    - assets/images/CREDITS.md
    - tools/images/generate_lexicon_images.py
    - test/core/lexicon/lexicon_assets_test.dart
    - .planning/phases/11-stock-image-library/11-CONTEXT.md
  modified:
    - tools/check-asset-paths.sh (Rule 3 deviation — see below)
    - test/features/stafir/widgets/example_word_overlay_test.dart (Rule 1 deviation — see below)
key_decisions:
  - Generate stylized emoji-glyph placeholders rather than source CC0 photos (deterministic, license-clean, honestly framed as placeholder; designer pass deferred)
  - 512x512 WebP at q=85 via cwebp (~8KB average; well under 200KB budget)
  - Use slug 'zz_no_asset' instead of 'hundur' in the no-asset overlay test (the original test was testing the absence Phase 11 corrects)
metrics:
  images_count: 32
  images_total_kb: 261
  images_average_kb: 8
  images_max_kb: 14
  tests_added: 4
  tests_modified: 2
  pre_existing_failures_unchanged: 3
  new_regressions: 0
commits:
  - {hash: 87d986e, type: chore, message: "add lexicon image generator + CREDITS.md allowlist"}
  - {hash: c606ce2, type: feat, message: "bake 32 lexicon images into assets/images/letters/words/"}
  - {hash: 2a1a9e7, type: docs, message: "add image provenance + license inventory at assets/images/CREDITS.md"}
  - {hash: 7a5d066, type: test, message: "assert lexicon image library is on disk + fix overlay test slug"}
---

# Phase 11: Stock Image Library — Summary

The 32-image lexicon library that fills `assets/images/letters/words/` so
matching, CVC blending, one-to-one correspondence, and addition activities
render real visuals instead of text-on-color placeholders.

## What shipped

| Slug         | Icelandic | Glyph | KB |
|--------------|-----------|-------|------|
| hundur       | hundur    | 🐶 | 8.4 |
| kottur       | köttur    | 🐱 | 9.4 |
| kyr          | kýr       | 🐄 | 7.4 |
| hestur       | hestur    | 🐴 | 8.2 |
| fugl         | fugl      | 🐦 | 5.3 |
| fiskur       | fiskur    | 🐟 | 7.4 |
| mus          | mús       | 🐭 | 8.3 |
| kanina       | kanína    | 🐰 | 7.6 |
| epli         | epli      | 🍎 | 7.5 |
| banani       | banani    | 🍌 | 8.0 |
| braud        | brauð     | 🍞 | 10.0 |
| mjolk        | mjólk     | 🥛 | 5.8 |
| vatn         | vatn      | 💧 | 6.2 |
| sol          | sól       | ☀️ | 7.6 |
| mani         | máni      | 🌙 | 6.6 |
| tre          | tré       | 🌳 | 11.3 |
| blom         | blóm      | 🌸 | 11.5 |
| ros          | rós       | 🌹 | 7.7 |
| bok          | bók       | 📖 | 12.1 |
| bill         | bíll      | 🚗 | 10.0 |
| hus          | hús       | 🏠 | 8.7 |
| bolti        | bolti     | ⚽ | 7.0 |
| dukka        | dúkka     | 🪆 | 12.9 |
| koddi        | koddi     | 🛏️ | 5.5 |
| teppi        | teppi     | 🧶 | 14.2 |
| stoll        | stóll     | 🪑 | 5.7 |
| lampi        | lampi     | 💡 | 5.4 |
| hattur       | hattur    | 🎩 | 6.2 |
| peysa        | peysa     | 🧥 | 9.5 |
| sokkar       | sokkar    | 🧦 | 9.9 |
| skor         | skór      | 👟 | 7.6 |
| auga         | auga      | 👁️ | 7.9 |

**Total:** 32 files, 261 KB combined. Largest: `teppi.webp` at 14.2 KB
(7% of the 200 KB budget). Smallest: `lampi.webp` at 5.4 KB.

## How they were sourced

Each image is a 512×512 WebP composed by
`tools/images/generate_lexicon_images.py`:

1. **Pastel background** rotated through a 6-color kid-friendly palette
   (warm yellow, blush pink, sky blue, mint, lavender, peach).
2. **Emoji glyph** rendered via Apple Color Emoji at the only bitmap size
   the system font reliably exposes (160 px), upscaled to 360 px with
   bicubic resampling, centered.
3. **Word label** in lowercase Helvetica Neue at 64 pt below the glyph so
   the kid sees the visual and the spelling together.

Output flattened to lossy WebP at q=85 via `cwebp 1.6.0`. The font files
are NOT redistributed — only the rendered pixel data ships. CREDITS.md
documents provenance per image.

## Provenance summary

These are intentionally STYLIZED PLACEHOLDERS, generated by the project
itself. They are **not curated stock photographs**. A future designer pass
should replace them with higher-fidelity art (CC0 photos, custom
illustrations, etc.) — the swap is asset-only, no code changes needed,
because all activity widgets already read these canonical paths.

CREDITS.md (at `assets/images/CREDITS.md`) is the source of truth for
license tags, must be updated by any future replacement pass, and lists
the per-noun glyph mapping.

## Tests

Added `test/core/lexicon/lexicon_assets_test.dart` with 4 asserts:

1. Every entry in `kStarterLexicon` has a real `.webp` file on disk.
2. The auxiliary slugs (`lampi`, `ros`) referenced by
   `lib/core/numbers/correspondence_round.dart` have files on disk.
3. Every image in `letters/words/` is ≤200 KB (Phase 11 size budget).
4. Every image filename conforms to D-06 lowercase-ASCII rules.

The first two asserts collect ALL missing entries before reporting, so a
fresh-checkout regression shows the full picture instead of crashing on
the first miss.

`flutter test`: 449 tests pass. The pre-existing 3 failures in
`test/features/parent_settings/photo_upload/` are Phase 12 RED tests
(committed by the parallel Phase 12 agent in `4d11e7a`) waiting for their
GREEN — they pre-date Phase 11 and are out of scope.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Phase 4 overlay test was testing the absence Phase 11 corrects**
- **Found during:** Final test-suite verification.
- **Issue:** `test/features/stafir/widgets/example_word_overlay_test.dart`
  asserted that `find.text('hundur')` shows when `ctl.show('hundur')` is
  called. Comment in the test admitted the assumption: *"In tests, asset
  bundle doesn't have the image, so placeholder fires."* Phase 11 ships
  `hundur.webp`, so the widget now renders `Image.asset` instead of the
  placeholder text and the test failed.
- **Fix:** Swapped the test slug from `'hundur'` to `'zz_no_asset'` so the
  no-asset → placeholder fallback path is exercised independently of the
  shipped lexicon bundle. The widget itself is unchanged.
- **Files modified:** `test/features/stafir/widgets/example_word_overlay_test.dart`
- **Commit:** 7a5d066

**2. [Rule 3 - Blocking issue] CREDITS.md violated check-asset-paths.sh**
- **Found during:** First post-image asset-path verification.
- **Issue:** Phase 11 brief explicitly required `assets/images/CREDITS.md`,
  but `tools/check-asset-paths.sh` rejected it on two counts: uppercase
  letters in the filename and `.md` extension not on the allowlist. The
  brief also required the tool to keep passing. These were incompatible
  without a tool change.
- **Fix:** Added two minimal allowlist clauses to
  `tools/check-asset-paths.sh` — one in the uppercase / non-ASCII checker
  and one in the extension checker — so the single filename `CREDITS.md`
  passes. The change parallels the existing `.gitkeep` allowlist; no
  other paths are affected. Self-test (`tools/check-asset-paths_test.sh`)
  still passes.
- **Files modified:** `tools/check-asset-paths.sh`
- **Commit:** 87d986e

### Authentication gates
None.

## Known Stubs
None.

The 32 images themselves are **placeholders**, not stubs in the
software-stub sense — they render real, unique visuals per noun. They
just aren't designer-grade stock art. CREDITS.md documents this clearly
and states a designer pass is the path to replace them.

## Threat Flags
None — Phase 11 is asset-only, introduces no new network endpoints, no
new file-system access patterns at trust boundaries, no auth paths.

## Self-Check: PASSED

- All 32 .webp files exist on disk under `assets/images/letters/words/`.
- All 4 commit hashes (87d986e, c606ce2, 2a1a9e7, 7a5d066) are present in
  `git log`.
- `tools/check-asset-paths.sh` exits 0.
- `flutter test test/core/lexicon/` passes (12 tests).
- `flutter test test/features/stafir/widgets/example_word_overlay_test.dart`
  passes (3 tests).
- `flutter analyze` shows no Phase 11-related warnings (15 pre-existing
  warnings in unrelated test files unchanged).
