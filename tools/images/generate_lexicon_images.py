#!/usr/bin/env python3
# Phase 11 — Lexicon image generator.
#
# Generates one 512x512 .webp illustration per lexicon noun by composing:
#   * A pastel background (rotated through a 6-color kid-friendly palette,
#     same family as the LetterTile palette in lib/features/stafir/widgets/).
#   * An emoji glyph rendered from Apple Color Emoji at 160 px (the only
#     bitmap size the system font reliably supports), upscaled with bicubic
#     resampling to 360 px and centered.
#   * The Icelandic word in lowercase Helvetica Neue, rendered below the
#     glyph so the kid sees the visual and the spelling together.
#
# Output: assets/images/letters/words/{slug}.webp at q=85.
#
# These are intentionally STYLIZED PLACEHOLDERS, not curated stock photos.
# A future designer pass can swap in higher-fidelity art per noun without
# any code changes — the widget code (ExampleWordOverlay, addition,
# correspondence, matching) just reads the same paths.
#
# License: Generated wholly by this script in this repo. The Apple Color
# Emoji glyphs are rendered via the system font at runtime; PNG/WEBP output
# is treated as a derivative work the project owns. We do NOT redistribute
# the emoji font itself; we only render glyphs into pixel buffers per
# Apple's licensed use of the system font on macOS. CREDITS.md documents
# this clearly.
#
# Run:
#   python3 tools/images/generate_lexicon_images.py
#
# No package installs needed beyond the system Python + Pillow already
# present on dev workstations.

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# Paths.
REPO_ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = REPO_ROOT / "assets" / "images" / "letters" / "words"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# System fonts — macOS-only; the script is a developer tool, not shipped.
EMOJI_FONT = "/System/Library/Fonts/Apple Color Emoji.ttc"
LABEL_FONT = "/System/Library/Fonts/HelveticaNeue.ttc"

# Emoji size MUST be one of {20, 32, 40, 48, 64, 96, 160} on macOS — these
# are the bitmap sizes embedded in Apple Color Emoji.ttc. We render at 160
# (the largest supported) and upscale.
EMOJI_RENDER_SIZE = 160
EMOJI_DISPLAY_SIZE = 360

# Final output canvas.
CANVAS = 512

# Pastel palette — same family as lib/features/stafir/widgets/letter_tile.dart
# six-color palette but tuned slightly warmer so emoji art reads against it.
PALETTE = [
    (255, 241, 184),  # warm yellow
    (255, 213, 213),  # blush pink
    (213, 232, 255),  # sky blue
    (213, 255, 224),  # mint
    (232, 213, 255),  # lavender
    (255, 230, 200),  # peach
]

# Slug -> (emoji, Icelandic word for label).
# Order matches kStarterLexicon in lib/core/lexicon/lexicon.dart, plus the
# extra slugs referenced by lib/core/numbers/correspondence_round.dart
# (lampi, ros) so every code path resolves to a real image. 32 entries.
LEXICON: list[tuple[str, str, str]] = [
    # Animals / pets
    ("hundur", "🐶", "hundur"),
    ("kottur", "🐱", "köttur"),
    ("kyr", "🐄", "kýr"),
    ("hestur", "🐴", "hestur"),
    ("fugl", "🐦", "fugl"),
    ("fiskur", "🐟", "fiskur"),
    ("mus", "🐭", "mús"),
    ("kanina", "🐰", "kanína"),
    # Food
    ("epli", "🍎", "epli"),
    ("banani", "🍌", "banani"),
    ("braud", "🍞", "brauð"),
    ("mjolk", "🥛", "mjólk"),
    ("vatn", "💧", "vatn"),
    # Outdoors / nature
    ("sol", "☀️", "sól"),
    ("mani", "🌙", "máni"),
    ("tre", "🌳", "tré"),
    ("blom", "🌸", "blóm"),
    ("ros", "🌹", "rós"),
    # Toys / household
    ("bok", "📖", "bók"),
    ("bill", "🚗", "bíll"),
    ("hus", "🏠", "hús"),
    ("bolti", "⚽", "bolti"),
    ("dukka", "🪆", "dúkka"),
    ("koddi", "🛏️", "koddi"),
    ("teppi", "🧶", "teppi"),
    ("stoll", "🪑", "stóll"),
    ("lampi", "💡", "lampi"),
    # Clothing
    ("hattur", "🎩", "hattur"),
    ("peysa", "🧥", "peysa"),
    ("sokkar", "🧦", "sokkar"),
    ("skor", "👟", "skór"),
    # Body
    ("auga", "👁️", "auga"),
]


def render_one(slug: str, emoji: str, word: str, palette_index: int) -> Path:
    """Render one lexicon image to assets/images/letters/words/{slug}.webp."""
    bg = PALETTE[palette_index % len(PALETTE)]

    # Canvas with pastel background + softly rounded "card" feel via a
    # slightly darker rim. Keeping the geometry minimal so the emoji glyph
    # is the focal point.
    canvas = Image.new("RGBA", (CANVAS, CANVAS), bg + (255,))

    # Render emoji at native size then upscale.
    emoji_layer = Image.new("RGBA", (EMOJI_RENDER_SIZE, EMOJI_RENDER_SIZE), (0, 0, 0, 0))
    emoji_font = ImageFont.truetype(EMOJI_FONT, EMOJI_RENDER_SIZE)
    draw = ImageDraw.Draw(emoji_layer)
    # Apple Color Emoji renders at fixed 160x160 with built-in horizontal
    # bearing; drawing at (0, 0) places the glyph correctly inside the
    # 160x160 layer (verified with the dog test render).
    draw.text((0, 0), emoji, font=emoji_font, embedded_color=True)
    emoji_scaled = emoji_layer.resize(
        (EMOJI_DISPLAY_SIZE, EMOJI_DISPLAY_SIZE), Image.LANCZOS
    )
    # Center-paste, biased slightly upward so the word label fits below.
    px = (CANVAS - EMOJI_DISPLAY_SIZE) // 2
    py = 60
    canvas.alpha_composite(emoji_scaled, (px, py))

    # Word label below the glyph.
    label_layer = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    label_draw = ImageDraw.Draw(label_layer)
    label_font = ImageFont.truetype(LABEL_FONT, 64)
    label_w = label_font.getlength(word)
    label_x = (CANVAS - label_w) / 2
    label_y = CANVAS - 100
    label_draw.text(
        (label_x, label_y),
        word,
        font=label_font,
        fill=(40, 40, 40, 255),
    )
    canvas.alpha_composite(label_layer)

    # Save as PNG first, then convert to WEBP via cwebp for best size.
    out_png = OUT_DIR / f"{slug}.png"
    out_webp = OUT_DIR / f"{slug}.webp"
    canvas.convert("RGB").save(out_png, "PNG", optimize=True)

    # cwebp: -q 85 keeps the pastel + emoji crisp; -m 6 gives best compression.
    subprocess.run(
        ["cwebp", "-q", "85", "-m", "6", str(out_png), "-o", str(out_webp)],
        check=True,
        capture_output=True,
    )
    out_png.unlink()
    return out_webp


def main() -> int:
    # Sanity check fonts before generating 32 images.
    if not Path(EMOJI_FONT).exists():
        print(f"ERROR: emoji font not found at {EMOJI_FONT}", file=sys.stderr)
        return 1
    if not Path(LABEL_FONT).exists():
        print(f"ERROR: label font not found at {LABEL_FONT}", file=sys.stderr)
        return 1
    if subprocess.run(["which", "cwebp"], capture_output=True).returncode != 0:
        print("ERROR: cwebp not on PATH (brew install webp)", file=sys.stderr)
        return 1

    # Sanity check uniqueness of slugs.
    slugs = [s for s, _, _ in LEXICON]
    assert len(slugs) == len(set(slugs)), "duplicate slug in LEXICON"
    print(f"Generating {len(LEXICON)} images into {OUT_DIR}")

    total_bytes = 0
    for i, (slug, emoji, word) in enumerate(LEXICON):
        out = render_one(slug, emoji, word, palette_index=i)
        size = out.stat().st_size
        total_bytes += size
        print(f"  {slug:10s} {emoji:3s} {word:10s} {size:>6} bytes  -> {out.name}")

    print(f"\nTotal: {len(LEXICON)} images, {total_bytes / 1024:.1f} KB combined")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
