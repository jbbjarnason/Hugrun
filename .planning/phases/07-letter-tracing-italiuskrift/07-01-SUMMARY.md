---
phase: 07
plan: 07-01
title: Adopt stroke_order_animator + glyph data
status: complete
date: 2026-05-02
tags: [phase-7, tracing, package-adoption, glyph-data, simplified]
requirements_satisfied:
  - TRACE-01  # 32 lowercase Ítalíuskrift letterforms (simplified)
metrics:
  pubspec-deps-added: 1 (stroke_order_animator)
  pubspec-deps-transitive: 2 (svg_path_parser, http)
  glyph-files-shipped: 32
  glyph-data-bytes: ~26 KB total (avg ~800 B/file)
---

# Plan 07-01: Adopt stroke_order_animator + glyph data — Summary

A two-step foundation pass: add the `stroke_order_animator: ^3.3.1`
package, then generate 32 simplified MMAH-format JSON glyphs that the
package consumes for Ítalíuskrift letterforms. **Simplified** — see D-04.

## What was built

### Package adoption
- `pubspec.yaml` adds `stroke_order_animator: ^3.3.1` (BSD-3-Clause).
- Transitively pulls `svg_path_parser` and `http`. The latter is
  unused by the activity at runtime — we load JSONs from `rootBundle`,
  not from the package's online MMAH downloader.
- `tools/check-no-tracking.sh` passes (no banned packages).
- `assets/tracing/` declared as an asset folder.

### Glyph data
- `tools/glyph/generate_simple_traces.py` (pure Python, ~360 lines).
  Encodes hand-authored medians for all 32 Icelandic lowercase letters
  in MMAH 1024×1024 document space (Y-up). Produces a closed-path SVG
  outline around each median by offsetting HALF_WIDTH=40 px on each
  side (rectangular cap; rounded corners via averaged perpendiculars).
- `assets/tracing/{slug}.json` × 32. Slugs match
  `kIcelandicAlphabet[*].assetSlug` (a, a_acute, b, d, eth, e, e_acute,
  f, g, h, i, i_acute, j, k, l, m, n, o, o_acute, p, r, s, t, u,
  u_acute, v, x, y, y_acute, thorn, ae, o_umlaut). Each ~700–900 B.

### Stroke-order pedagogy honored
- Diacritics (`á é í ó ú ý ö`) — accent is the **last** stroke.
  Pitfall §2 of the research is encoded in the generator + checked
  by the loader test suite.
- Two-part Icelandic letters (`ð`, `þ`) — body first, then cross-bar
  (ð) / bowl (þ). Exactly 2 strokes each.
- Plain Latin lowercase — 1 stroke unless the letterform pedagogically
  splits (e.g. `f` body + cross-bar; `t` body + cross-bar; `h`/`n`/`b`/
  `d`/`p` spine + arch/bowl; `i`/`j` body + dot; `k` spine + bow;
  `x` two diagonals; `y` body + right diagonal).

## Architectural commitments — preserved

- **Pure-Python tool** under `tools/glyph/`. Idempotent — re-runs
  overwrite the 32 files in place.
- **MMAH-coordinate-system convention** documented in the script's
  doc comment so future contributors don't re-hit Pitfall §1.
- **No new banned packages** — all transitive deps clean.

## Deviations from plan

### Auto-fixed issues
None — Plan 07-01 ran exactly as written.

### Asset-paths checker extended (Rule 2 — auto-add missing
critical functionality)
The plan's pubspec changes added a `.json` extension under
`assets/tracing/` which the existing `tools/check-asset-paths.sh`
allow-list rejected. **Fix:** extend `ALLOWED_EXTS` with `'json'`
and update the allow-list documentation. Self-test
`tools/check-asset-paths_test.sh` still passes.

## Files changed

### Created
- `tools/glyph/generate_simple_traces.py` (370 lines).
- `assets/tracing/*.json` (32 files, ~26 KB total).

### Modified
- `pubspec.yaml` — add direct dep + assets folder.
- `pubspec.lock` — auto-updated by `flutter pub get`.
- `tools/check-asset-paths.sh` — allow `.json` (D-06 update).

## Commits

- `b1b97f4 feat(07-01): add stroke_order_animator dependency (Phase 7 D-01)`
- `0216fce feat(07-01): generate 32 simplified MMAH glyph traces (D-02..D-06)`

## Self-Check: PASSED
