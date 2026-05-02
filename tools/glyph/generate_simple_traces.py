#!/usr/bin/env python3
"""
Phase 7 D-04, D-06 — generate 32 simplified MMAH-format JSON glyphs
for the Icelandic lowercase letters.

Each glyph file lives at `assets/tracing/{slug}.json` and matches the
schema consumed by the `stroke_order_animator` package:

    {
      "character": "<letter>",
      "strokes":  [<closed SVG outline path string>, ...],
      "medians":  [[[x, y], ...], ...],
      "radStrokes": []
    }

The package's CharacterPainter splits each `strokes[i]` into two contour
paths starting from the closest points to `medians[i].first` and
`medians[i].last` and animates them in sync to "fill in" the stroke.
For our purposes a stroke OUTLINE is a closed rectangular path of
constant thickness that wraps the median's polyline. The painter is
glyph-agnostic — Latin letterforms work fine.

D-04 disposition: Phase 7 ships SIMPLIFIED letterforms as functional
placeholders. They teach correct stroke-by-stroke mechanics. A polish
pass replaces them with authentic Briem Ítalíuskrift traces (logged as
deferred follow-up; documented in 07-SUMMARY.md and PROJECT.md).

Coordinate system: Make-Me-A-Hanzi 1024×1024 with Y inverted around
y=900. The package's StrokeOrder._parseStrokeOutlines / _parseMedians
applies the transform `Matrix4(1,0,0,0, 0,-1,0,0, 0,0,1,0, 0,900,0,1)`
internally, which means in the JSON we author medians/outlines in MMAH
"document space" (Y up). Authors can think of it as: y=900 is the top
of the canvas in screen space; lower y values render LOWER on screen.

Usage:
    python3 tools/glyph/generate_simple_traces.py [--out-dir DIR]

Defaults to writing under `assets/tracing/` relative to the repo root.

Idempotent: re-running overwrites the 32 JSON files in place.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

# ---------------------------------------------------------------------------
# Geometry helpers — MMAH document space (Y up, origin at bottom-left).
# Stroke outlines must be CLOSED PATHS that surround the median polyline.
# ---------------------------------------------------------------------------

# Half-width of the stroke outline (i.e. half the brush thickness in MMAH
# coordinate space). The package renders the outline filled, so this
# governs how thick each stroke looks at runtime.
HALF_WIDTH = 40.0


Point = Tuple[float, float]


def _normalize(dx: float, dy: float) -> Point:
    length = (dx * dx + dy * dy) ** 0.5
    if length == 0:
        return (0.0, 0.0)
    return (dx / length, dy / length)


def _segment_perpendicular(p0: Point, p1: Point) -> Point:
    """Unit perpendicular (right-hand rule) to the segment p0→p1."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    nx, ny = _normalize(dx, dy)
    return (-ny, nx)


def _outline_around_median(median: Sequence[Point]) -> str:
    """
    Construct a closed SVG path string that traces the rectangular
    outline around `median` at distance HALF_WIDTH on either side.

    The path goes:
      start (offset right) → end (offset right) → end (offset left) → start (offset left) → close.

    For multi-segment medians we offset each median point by the average
    of the perpendiculars of the adjacent segments (smoothed corner).
    Endpoint caps are square (no rounded ends) — sufficient for the
    package's contour-extraction algorithm, which finds the closest
    outline point to the median endpoints.
    """
    n = len(median)
    if n < 2:
        raise ValueError("Median must have at least 2 points")

    # For each median index, compute a perpendicular unit vector.
    perps: List[Point] = []
    for i in range(n):
        if i == 0:
            perps.append(_segment_perpendicular(median[0], median[1]))
        elif i == n - 1:
            perps.append(_segment_perpendicular(median[n - 2], median[n - 1]))
        else:
            p_prev = _segment_perpendicular(median[i - 1], median[i])
            p_next = _segment_perpendicular(median[i], median[i + 1])
            avg = ((p_prev[0] + p_next[0]) / 2.0, (p_prev[1] + p_next[1]) / 2.0)
            perps.append(_normalize(avg[0], avg[1]))

    right_side: List[Point] = [
        (median[i][0] + perps[i][0] * HALF_WIDTH,
         median[i][1] + perps[i][1] * HALF_WIDTH)
        for i in range(n)
    ]
    left_side: List[Point] = [
        (median[i][0] - perps[i][0] * HALF_WIDTH,
         median[i][1] - perps[i][1] * HALF_WIDTH)
        for i in range(n)
    ]

    parts: List[str] = []
    parts.append(f"M {right_side[0][0]:.1f} {right_side[0][1]:.1f}")
    for p in right_side[1:]:
        parts.append(f"L {p[0]:.1f} {p[1]:.1f}")
    # Walk the left side back to the start.
    for p in reversed(left_side):
        parts.append(f"L {p[0]:.1f} {p[1]:.1f}")
    parts.append("Z")
    return " ".join(parts)


# ---------------------------------------------------------------------------
# 32 Icelandic lowercase letterforms — simplified medians.
# Briem-style design constraints honored at the level of stroke order:
#   - Vertical strokes go top → bottom (y descending in screen space →
#     y ASCENDING in MMAH space, since y is inverted).
#   - Horizontal strokes go left → right.
#   - Closed-loop letters (a, d, g, o, p, q, etc.) are one stroke that
#     traces the body in standard cursive order: start at top-right of
#     the bowl, go counter-clockwise around, then continue with the
#     descender / vertical.
#   - Diacritic marks (á é í ó ú ý ö) are AUTHORED LAST.
#   - Two-part letters (ð, þ) — body first, then bowl/cross-bar.
#
# Coordinate notes (MMAH document space, Y up):
#   x: 100 (left margin) … 924 (right margin)
#   y: 100 (baseline)    … 900 (top of canvas)
#
# Lowercase x-height roughly 100 .. 600.
# Ascenders reach 800. Descenders dip to 0.
# ---------------------------------------------------------------------------

# Helper anchors for a typical lowercase letter.
BASELINE = 100.0
X_HEIGHT_TOP = 600.0
ASCENDER_TOP = 800.0
ACCENT_TOP = 880.0
DOT_Y = 750.0
DESCENDER_BOTTOM = 0.0


def _bowl_oval(cx: float, cy: float, rx: float, ry: float, n_steps: int = 12) -> List[Point]:
    """
    Counter-clockwise oval median starting at the right side (3 o'clock),
    going up-and-over (12), to the left (9), down (6), and back to the
    right side (close to 3) WITHOUT closing. Used for letters whose
    bowl is part of a single-stroke cursive motion (a, b, d, g, o, p, q).

    The package treats the median as a polyline with a defined start
    and end. For closed bowls the median's first and last point are
    near (but not identical to) each other on the bowl.
    """
    import math

    pts: List[Point] = []
    # Start at the right (angle 0), go counter-clockwise.
    # We go from 0 → 2*pi - small_gap so the path doesn't truly close.
    for i in range(n_steps + 1):
        t = (i / n_steps) * (2.0 * math.pi - 0.3)
        x = cx + rx * math.cos(t)
        y = cy + ry * math.sin(t)
        pts.append((x, y))
    return pts


def medians_for_letter(slug: str) -> List[List[Point]]:
    """
    Return the list-of-strokes-as-medians for a given letter slug. Each
    stroke is a list of (x, y) points in MMAH document space (Y up).

    These are FUNCTIONAL PLACEHOLDERS, not authentic Briem traces. They
    satisfy the package's expectations (start/end points, direction,
    stroke length) so the activity is structurally correct.
    """
    cx = 512.0  # horizontal center
    bowl_rx = 180.0
    bowl_ry = 160.0
    bowl_cy = 350.0  # midpoint of the x-height
    descender_dip = -100.0

    # ---------- Plain Latin letters ----------
    if slug == 'a':
        # Single-stroke cursive 'a': counter-clockwise bowl, then drop down a vertical.
        bowl = _bowl_oval(cx - 30, bowl_cy, bowl_rx, bowl_ry, n_steps=14)
        # End the bowl at right side, then drop a short vertical tail.
        bowl.append((cx + bowl_rx - 30, BASELINE + 20))
        return [bowl]

    if slug == 'b':
        # Vertical down from ascender to baseline, then bowl on the right going down.
        spine = [(cx - 100, ASCENDER_TOP), (cx - 100, BASELINE)]
        bowl = _bowl_oval(cx - 100 + bowl_rx, bowl_cy - 30, bowl_rx, 140, n_steps=12)
        return [spine, bowl]

    if slug == 'd':
        # 'd' = bowl on the LEFT, then vertical on the RIGHT going down.
        bowl = _bowl_oval(cx - 30, bowl_cy, bowl_rx, bowl_ry, n_steps=14)
        spine = [(cx - 30 + bowl_rx, ASCENDER_TOP), (cx - 30 + bowl_rx, BASELINE)]
        return [bowl, spine]

    if slug == 'e':
        # Cursive 'e' — single-stroke loop. Start mid-x-height, go right, up, around, down.
        return [[
            (cx - 130, bowl_cy),
            (cx + 130, bowl_cy + 30),
            (cx + 90, bowl_cy + 150),
            (cx - 130, bowl_cy + 100),
            (cx - 150, bowl_cy - 80),
            (cx + 80, BASELINE + 30),
            (cx + 150, BASELINE + 80),
        ]]

    if slug == 'f':
        # Top hook + vertical descender, then horizontal cross-bar at x-height.
        # Body: hook from top-right going up-left, then straight down to descender bottom.
        body = [
            (cx + 30, ASCENDER_TOP - 20),
            (cx - 60, ASCENDER_TOP),
            (cx - 80, ASCENDER_TOP - 80),
            (cx - 80, DESCENDER_BOTTOM + 100),
        ]
        crossbar = [(cx - 160, X_HEIGHT_TOP - 20), (cx + 60, X_HEIGHT_TOP - 20)]
        return [body, crossbar]

    if slug == 'g':
        # Bowl on top, then descender hooking left.
        bowl = _bowl_oval(cx - 30, bowl_cy + 50, bowl_rx, bowl_ry, n_steps=14)
        descender = [
            (cx - 30 + bowl_rx, BASELINE + 30),
            (cx - 30 + bowl_rx, DESCENDER_BOTTOM + 80),
            (cx - 80, DESCENDER_BOTTOM + 30),
        ]
        return [bowl, descender]

    if slug == 'h':
        # Left vertical (ascender to baseline) + arch on the right.
        spine = [(cx - 130, ASCENDER_TOP), (cx - 130, BASELINE)]
        arch = [
            (cx - 130, X_HEIGHT_TOP - 100),
            (cx - 30, X_HEIGHT_TOP),
            (cx + 90, X_HEIGHT_TOP - 100),
            (cx + 90, BASELINE),
        ]
        return [spine, arch]

    if slug == 'i':
        # Single short vertical from x-height to baseline; dot is a SEPARATE last stroke.
        # Plain 'i' (NOT 'í'): no accent. 1 stroke for body + 1 dot stroke.
        body = [(cx, X_HEIGHT_TOP), (cx, BASELINE)]
        dot = [(cx - 18, DOT_Y), (cx + 18, DOT_Y)]
        return [body, dot]

    if slug == 'j':
        # Vertical from x-height down THROUGH baseline to descender bottom, hooking left.
        # Plain 'j' has a dot (like 'i') as the LAST stroke.
        body = [
            (cx, X_HEIGHT_TOP),
            (cx, DESCENDER_BOTTOM + 100),
            (cx - 80, DESCENDER_BOTTOM + 30),
        ]
        dot = [(cx - 18, DOT_Y), (cx + 18, DOT_Y)]
        return [body, dot]

    if slug == 'k':
        # Vertical spine, then "bow tie" — diagonal up-right, diagonal down-right.
        spine = [(cx - 130, ASCENDER_TOP), (cx - 130, BASELINE)]
        bow = [
            (cx + 100, X_HEIGHT_TOP - 40),
            (cx - 130, bowl_cy),
            (cx + 110, BASELINE + 30),
        ]
        return [spine, bow]

    if slug == 'l':
        # Single vertical from ascender to baseline.
        return [[(cx, ASCENDER_TOP), (cx, BASELINE)]]

    if slug == 'm':
        # 3 verticals connected by 2 arches — drawn as a single polyline.
        return [[
            (cx - 200, X_HEIGHT_TOP),
            (cx - 200, BASELINE),
            (cx - 200, X_HEIGHT_TOP - 80),
            (cx - 80, X_HEIGHT_TOP),
            (cx, X_HEIGHT_TOP - 80),
            (cx, BASELINE),
            (cx, X_HEIGHT_TOP - 80),
            (cx + 130, X_HEIGHT_TOP),
            (cx + 200, X_HEIGHT_TOP - 80),
            (cx + 200, BASELINE),
        ]]

    if slug == 'n':
        # Like 'h' but the spine starts at x-height, not ascender.
        spine = [(cx - 130, X_HEIGHT_TOP), (cx - 130, BASELINE)]
        arch = [
            (cx - 130, X_HEIGHT_TOP - 60),
            (cx - 30, X_HEIGHT_TOP),
            (cx + 90, X_HEIGHT_TOP - 100),
            (cx + 90, BASELINE),
        ]
        return [spine, arch]

    if slug == 'o':
        # Single closed-loop oval, counter-clockwise.
        return [_bowl_oval(cx, bowl_cy, bowl_rx, bowl_ry, n_steps=16)]

    if slug == 'p':
        # Vertical descender + bowl on the right.
        spine = [(cx - 100, X_HEIGHT_TOP), (cx - 100, DESCENDER_BOTTOM + 50)]
        bowl = _bowl_oval(cx - 100 + bowl_rx, bowl_cy + 30, bowl_rx, 140, n_steps=12)
        return [spine, bowl]

    if slug == 'r':
        # Short vertical + small hook to the right at the top.
        spine = [(cx - 60, X_HEIGHT_TOP), (cx - 60, BASELINE)]
        hook = [
            (cx - 60, X_HEIGHT_TOP - 50),
            (cx + 30, X_HEIGHT_TOP),
            (cx + 100, X_HEIGHT_TOP - 50),
        ]
        return [spine, hook]

    if slug == 's':
        # S-curve — single stroke.
        return [[
            (cx + 100, X_HEIGHT_TOP - 30),
            (cx - 80, X_HEIGHT_TOP),
            (cx - 130, X_HEIGHT_TOP - 100),
            (cx + 80, bowl_cy + 30),
            (cx + 130, bowl_cy - 100),
            (cx - 30, BASELINE),
            (cx - 130, BASELINE + 80),
        ]]

    if slug == 't':
        # Vertical + horizontal cross-bar.
        spine = [(cx, ASCENDER_TOP - 100), (cx, BASELINE + 50), (cx + 80, BASELINE + 30)]
        crossbar = [(cx - 130, X_HEIGHT_TOP - 50), (cx + 100, X_HEIGHT_TOP - 50)]
        return [spine, crossbar]

    if slug == 'u':
        # U-curve — single stroke from top-left, down, across, up.
        return [[
            (cx - 130, X_HEIGHT_TOP),
            (cx - 130, BASELINE + 80),
            (cx - 30, BASELINE),
            (cx + 90, BASELINE + 80),
            (cx + 90, X_HEIGHT_TOP),
        ]]

    if slug == 'v':
        # V — single stroke down-and-up.
        return [[
            (cx - 150, X_HEIGHT_TOP),
            (cx, BASELINE + 30),
            (cx + 150, X_HEIGHT_TOP),
        ]]

    if slug == 'x':
        # 'x' = two diagonal strokes.
        d1 = [(cx - 130, X_HEIGHT_TOP), (cx + 130, BASELINE + 30)]
        d2 = [(cx + 130, X_HEIGHT_TOP), (cx - 130, BASELINE + 30)]
        return [d1, d2]

    if slug == 'y':
        # Two diagonals joining + descender. Authored as 2 strokes:
        #   1. Left diagonal down, then continue down through baseline to descender hook.
        #   2. Right diagonal down to baseline.
        body = [
            (cx - 130, X_HEIGHT_TOP),
            (cx, BASELINE + 80),
            (cx + 50, DESCENDER_BOTTOM + 30),
            (cx - 80, DESCENDER_BOTTOM + 50),
        ]
        right = [(cx + 130, X_HEIGHT_TOP), (cx, BASELINE + 80)]
        return [body, right]

    # ---------- Icelandic-specific letters ----------
    if slug == 'eth':
        # ð = body (looks like reversed 'd' — bowl + descender curve) + cross-bar on top.
        # Body: bowl with a tail going up-and-back.
        body = _bowl_oval(cx - 30, bowl_cy, bowl_rx, bowl_ry, n_steps=14)
        # Tail rises from top of bowl up-and-left to the ascender area.
        body.append((cx - 30 - bowl_rx + 80, ASCENDER_TOP - 40))
        crossbar = [
            (cx - 80, ASCENDER_TOP - 40),
            (cx + 30, ASCENDER_TOP - 40),
        ]
        return [body, crossbar]

    if slug == 'thorn':
        # þ = vertical (ascender to descender) + bowl on the right at x-height.
        spine = [(cx - 100, ASCENDER_TOP), (cx - 100, DESCENDER_BOTTOM + 50)]
        bowl = _bowl_oval(cx - 100 + bowl_rx, bowl_cy + 30, bowl_rx, 140, n_steps=12)
        return [spine, bowl]

    if slug == 'ae':
        # æ = 'a' bowl joined to 'e' bowl, drawn as one continuous stroke.
        return [[
            (cx - 270, bowl_cy + 30),
            (cx - 130, bowl_cy + 150),
            (cx - 30, bowl_cy + 80),
            (cx - 30, BASELINE + 30),
            (cx, bowl_cy),
            (cx + 200, bowl_cy + 30),
            (cx + 130, bowl_cy + 150),
            (cx - 30, bowl_cy + 100),
            (cx - 30, bowl_cy - 80),
            (cx + 130, BASELINE + 30),
            (cx + 220, BASELINE + 80),
        ]]

    # ---------- Diacritic letters: body first, accent LAST ----------
    if slug == 'a_acute':
        bowl = _bowl_oval(cx - 30, bowl_cy, bowl_rx, bowl_ry, n_steps=14)
        bowl.append((cx + bowl_rx - 30, BASELINE + 20))
        # Acute accent: short diagonal up-right at top.
        accent = [(cx - 60, ACCENT_TOP - 80), (cx + 60, ACCENT_TOP)]
        return [bowl, accent]

    if slug == 'e_acute':
        body = [
            (cx - 130, bowl_cy),
            (cx + 130, bowl_cy + 30),
            (cx + 90, bowl_cy + 150),
            (cx - 130, bowl_cy + 100),
            (cx - 150, bowl_cy - 80),
            (cx + 80, BASELINE + 30),
            (cx + 150, BASELINE + 80),
        ]
        accent = [(cx - 60, ACCENT_TOP - 80), (cx + 60, ACCENT_TOP)]
        return [body, accent]

    if slug == 'i_acute':
        body = [(cx, X_HEIGHT_TOP), (cx, BASELINE)]
        accent = [(cx - 60, ACCENT_TOP - 80), (cx + 60, ACCENT_TOP)]
        return [body, accent]

    if slug == 'o_acute':
        body = _bowl_oval(cx, bowl_cy, bowl_rx, bowl_ry, n_steps=16)
        accent = [(cx - 60, ACCENT_TOP - 80), (cx + 60, ACCENT_TOP)]
        return [body, accent]

    if slug == 'u_acute':
        body = [
            (cx - 130, X_HEIGHT_TOP),
            (cx - 130, BASELINE + 80),
            (cx - 30, BASELINE),
            (cx + 90, BASELINE + 80),
            (cx + 90, X_HEIGHT_TOP),
        ]
        accent = [(cx - 60, ACCENT_TOP - 80), (cx + 60, ACCENT_TOP)]
        return [body, accent]

    if slug == 'y_acute':
        body = [
            (cx - 130, X_HEIGHT_TOP),
            (cx, BASELINE + 80),
            (cx + 50, DESCENDER_BOTTOM + 30),
            (cx - 80, DESCENDER_BOTTOM + 50),
        ]
        right = [(cx + 130, X_HEIGHT_TOP), (cx, BASELINE + 80)]
        accent = [(cx - 60, ACCENT_TOP - 80), (cx + 60, ACCENT_TOP)]
        return [body, right, accent]

    if slug == 'o_umlaut':
        body = _bowl_oval(cx, bowl_cy, bowl_rx, bowl_ry, n_steps=16)
        # Umlaut: TWO dots side-by-side. Authored as a single 2-point stroke
        # to keep the package's stroke-count manageable. The tracing widget
        # treats it as a horizontal sweep "left dot → right dot".
        umlaut = [(cx - 60, DOT_Y), (cx + 60, DOT_Y)]
        return [body, umlaut]

    raise KeyError(f"No median definition for slug={slug!r}")


# ---------------------------------------------------------------------------
# 32-letter manifest matching kIcelandicAlphabet in
# lib/core/alphabet/alphabet.dart (MMS school order).
# ---------------------------------------------------------------------------

ICELANDIC_LETTERS: List[Tuple[str, str]] = [
    # (glyph, slug) — MMS school order.
    ('a', 'a'),
    ('á', 'a_acute'),
    ('b', 'b'),
    ('d', 'd'),
    ('ð', 'eth'),
    ('e', 'e'),
    ('é', 'e_acute'),
    ('f', 'f'),
    ('g', 'g'),
    ('h', 'h'),
    ('i', 'i'),
    ('í', 'i_acute'),
    ('j', 'j'),
    ('k', 'k'),
    ('l', 'l'),
    ('m', 'm'),
    ('n', 'n'),
    ('o', 'o'),
    ('ó', 'o_acute'),
    ('p', 'p'),
    ('r', 'r'),
    ('s', 's'),
    ('t', 't'),
    ('u', 'u'),
    ('ú', 'u_acute'),
    ('v', 'v'),
    ('x', 'x'),
    ('y', 'y'),
    ('ý', 'y_acute'),
    ('þ', 'thorn'),
    ('æ', 'ae'),
    ('ö', 'o_umlaut'),
]


def _build_glyph_json(glyph: str, slug: str) -> dict:
    medians = medians_for_letter(slug)
    strokes = [_outline_around_median(m) for m in medians]
    medians_int = [
        [[round(p[0], 1), round(p[1], 1)] for p in stroke] for stroke in medians
    ]
    return {
        'character': glyph,
        'strokes': strokes,
        'medians': medians_int,
        'radStrokes': [],
    }


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--out-dir',
        default=None,
        help='Directory to write JSON files into. Default: assets/tracing/ '
             'relative to repo root.',
    )
    args = parser.parse_args(list(argv))

    repo_root = Path(__file__).resolve().parent.parent.parent
    out_dir = Path(args.out_dir) if args.out_dir else repo_root / 'assets' / 'tracing'
    out_dir.mkdir(parents=True, exist_ok=True)

    if len(ICELANDIC_LETTERS) != 32:
        print(
            f"FATAL: expected 32 letters, manifest has {len(ICELANDIC_LETTERS)}",
            file=sys.stderr,
        )
        return 2

    written = 0
    for glyph, slug in ICELANDIC_LETTERS:
        try:
            data = _build_glyph_json(glyph, slug)
        except KeyError as e:
            print(f"FATAL: {e}", file=sys.stderr)
            return 2
        out_path = out_dir / f"{slug}.json"
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
            f.write('\n')
        written += 1
    print(f"Wrote {written} glyph JSON files to {out_dir}")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
