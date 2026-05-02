# Phase 11 — Stock Image Library — Context

**Phase:** 11
**Status:** Shipped (2026-05-02)
**Type:** Asset-only fix-pass — no widget code changes
**Depends on:** Phase 10
**Requirements:** IMG-01, IMG-02, IMG-03

## Why this phase exists

The 2026-05-02 screenshot review of the Hugrún build flagged that activities
relying on the lexicon — matching, CVC blending, one-to-one correspondence,
and addition — were rendering text-on-color placeholders where real images
should be. The lexicon (`lib/core/lexicon/lexicon.dart`) declares 30 nouns,
each with a canonical `assets/images/letters/words/{slug}.webp` path, but
the directory shipped empty (just a `.gitkeep`). Phase 4's `ExampleWordOverlay`
and Phase 5/9 activities silently fell back to placeholder rendering.

Phase 11 fills in those 30 image paths plus 2 auxiliary slugs (`lampi`,
`ros`) referenced directly by Phase 9's `correspondence_round.dart`, for a
total of **32 webp files**.

## Scope (and explicit non-scope)

### In scope
- `assets/images/letters/words/` — 32 .webp files
- `assets/images/CREDITS.md` — provenance + license inventory
- `tools/images/generate_lexicon_images.py` — regeneration script
- `tools/check-asset-paths.sh` — minimal allowlist for `CREDITS.md`
- `test/core/lexicon/lexicon_assets_test.dart` — asset-existence test
- `test/features/stafir/widgets/example_word_overlay_test.dart` — slug fix
  caused by images now existing on disk

### Out of scope
- Any widget / activity code (Phase 12 owns kid-mode UI changes)
- `tools/tts/`, `lib/gen/audio_manifest.g.dart` (Phase 13 owns audio regen)
- Authentic Briem letterforms / tracing improvements (deferred to designer pass)
- Curated CC0 photographs (deferred — current images are stylized placeholders)

## Approach decision

The phase brief listed four options for sourcing imagery:
1. Wikimedia Commons / public-domain photos via `curl`
2. Generate simple SVG illustrations programmatically
3. Use an icon set (Material Icons etc.)
4. Generate styled placeholder images

A hybrid of options **2 and 4 was chosen**: each lexicon noun gets a
single emoji glyph rendered from Apple Color Emoji (system font on macOS)
on a kid-friendly pastel background with the Icelandic word labeled below.

Rationale:
- **Deterministic.** No network failures during 32 sequential downloads.
- **License-clean.** Output WebPs are flattened pixel data we own; the
  emoji and label fonts are NOT redistributed. CREDITS.md is explicit.
- **Better than text-on-color.** Each image shows a recognizable visual
  (a dog, a cat, a sun) per noun.
- **Honest about what shipped.** These are placeholders; a designer pass
  can swap in higher-fidelity art per noun without code changes.

## Constraints honored

- ≤200KB per image — actual: ≈ 8KB average, ≤14KB max.
- Lowercase ASCII filenames matching lexicon slugs (Phase 2 D-06).
- `tools/check-asset-paths.sh` passes.
- `flutter analyze` clean for all Phase 11 files.
- No edits to widget code, no edits to `tools/tts/` or `audio_manifest.g.dart`.
