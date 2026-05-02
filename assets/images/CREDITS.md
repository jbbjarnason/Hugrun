# `assets/images/` provenance

Phase 11 (Stock Image Library) shipped 32 placeholder illustrations for the
lexicon nouns under `letters/words/`. They are intentionally STYLIZED
PLACEHOLDERS, not curated stock photographs — a future designer pass can
swap in higher-fidelity art per noun without any code changes (the widget
code, `ExampleWordOverlay`, `MatchingActivity`, `CorrespondenceActivity`,
and `AdditionActivity`, all just read the canonical
`assets/images/letters/words/{slug}.webp` paths).

## How they were generated

Each image is composed by `tools/images/generate_lexicon_images.py`:

1. **Background.** A solid pastel fill rotated through a 6-color
   kid-friendly palette (warm yellow, blush pink, sky blue, mint, lavender,
   peach) — same family as the `LetterTile` palette in
   `lib/features/stafir/widgets/`.
2. **Glyph.** A single emoji rendered via Apple Color Emoji from the macOS
   system font (`/System/Library/Fonts/Apple Color Emoji.ttc`) at the only
   bitmap size that font reliably exposes (160 px), then upscaled to 360 px
   with bicubic resampling and centered.
3. **Word label.** The Icelandic noun in lowercase Helvetica Neue at 64 pt,
   so the kid sees the visual and the spelling together.

Output: 512 × 512 px lossy WebP at q=85 via `cwebp 1.6.0`. Average size
≈ 8 KB per image, well under the 200 KB per-image budget.

## Licensing

| Component | Source | License | Used as |
|-----------|--------|---------|---------|
| Generator script | this repo (`tools/images/generate_lexicon_images.py`) | project license | Source of truth for regenerating assets |
| Pastel backgrounds | this repo (palette constants in script) | project license | Background fill |
| Emoji glyphs | Apple Color Emoji (macOS system font) | Apple SLA — system-font use only | Rendered into pixel buffers locally; the font itself is NOT redistributed |
| Word labels | Helvetica Neue (macOS system font) | Apple SLA — system-font use only | Same as above |

Apple's macOS Software License Agreement permits rendering glyphs from
bundled system fonts into user-created content; we render once at
development time and ship only the resulting flattened WebP pixels. We do
not ship any TTF/TTC. iOS devices receiving these WebP files see them as
opaque raster art.

If a future designer pass replaces these placeholders with externally
sourced art, this file MUST be updated with per-image provenance, license
tags, and any required attribution. CC0 / public-domain sources are
preferred.

## Inventory

The 32 slugs below match `kStarterLexicon` in
`lib/core/lexicon/lexicon.dart` plus the two auxiliary slugs (`lampi`,
`ros`) referenced by `lib/core/numbers/correspondence_round.dart`.

| Slug | Icelandic | Glyph |
|------|-----------|-------|
| auga | auga | 👁️ |
| banani | banani | 🍌 |
| bill | bíll | 🚗 |
| blom | blóm | 🌸 |
| bok | bók | 📖 |
| bolti | bolti | ⚽ |
| braud | brauð | 🍞 |
| dukka | dúkka | 🪆 |
| epli | epli | 🍎 |
| fiskur | fiskur | 🐟 |
| fugl | fugl | 🐦 |
| hattur | hattur | 🎩 |
| hestur | hestur | 🐴 |
| hundur | hundur | 🐶 |
| hus | hús | 🏠 |
| kanina | kanína | 🐰 |
| koddi | koddi | 🛏️ |
| kottur | köttur | 🐱 |
| kyr | kýr | 🐄 |
| lampi | lampi | 💡 |
| mani | máni | 🌙 |
| mjolk | mjólk | 🥛 |
| mus | mús | 🐭 |
| peysa | peysa | 🧥 |
| ros | rós | 🌹 |
| skor | skór | 👟 |
| sokkar | sokkar | 🧦 |
| sol | sól | ☀️ |
| stoll | stóll | 🪑 |
| teppi | teppi | 🧶 |
| tre | tré | 🌳 |
| vatn | vatn | 💧 |

## Regenerating

From the repo root, on macOS:

```bash
python3 tools/images/generate_lexicon_images.py
```

Requirements: Python 3 with Pillow installed, plus `cwebp` on `PATH`
(`brew install webp`). The script overwrites all 32 files atomically and
reports per-file size on stdout.
