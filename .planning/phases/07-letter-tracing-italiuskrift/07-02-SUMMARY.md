---
phase: 07
plan: 07-02
title: Pure-Dart MMAH glyph loader (lib/core/tracing)
status: complete
date: 2026-05-02
tags: [phase-7, tracing, pure-dart, tdd]
requirements_satisfied:
  - TRACE-01  # 32 lowercase Ítalíuskrift letterforms — loader verifies all 32 parse
metrics:
  test-delta: +17 (loader unit tests)
  domain-purity: passes
---

# Plan 07-02: Pure-Dart MMAH glyph loader — Summary

A small Flutter-free loader and validator for the 32 hand-authored
MMAH-format JSONs at `assets/tracing/`. Lives at `lib/core/tracing/`,
enforced Flutter-free by `tools/check-domain-purity.sh`.

## What was built

### lib/core/tracing/glyph_loader.dart (~145 lines)

Public surface:
- `kTracingAssetRoot` — `'assets/tracing'`.
- `assetPathFor(IcelandicLetter letter)` — maps to canonical
  `assets/tracing/{letter.assetSlug}.json`.
- `TraceGlyph` — value object holding `character`, `strokes`, `medians`,
  `radStrokes`, and the original `rawJson` string. The raw JSON is
  carried verbatim so the activity widget passes it directly to the
  package's `StrokeOrder(rawJson)` constructor.
- `parseGlyphJson(rawJson)` — strict parser. Throws `FormatException`
  on every schema violation:
  • invalid JSON
  • missing/non-list `strokes` or `medians`
  • empty `strokes` list
  • mismatched `strokes.length != medians.length`
  • non-string entries inside `strokes`
  • a median with fewer than 2 points
  • a non-numeric median coordinate

### Why pure-Dart

`StrokeOrder` from `stroke_order_animator` pulls `dart:ui` (it parses
SVG paths into `ui.Path` objects). That excludes it from the domain
layer. The glyph_loader holds raw data only — `String`s and `List`s of
numbers — so the unit tests run without a Flutter binding (via plain
`dart:io` File reads against the asset directory).

## Tests (17 passing)

- `assetPathFor` — 3 cases (a, ð, ö) covering the slug map.
- `parseGlyphJson` — 5 cases covering happy path, missing strokes,
  count mismatch, empty list, diacritic preservation.
- All 32 shipped JSONs at `assets/tracing/` parse successfully.
- Every glyph has `strokes.length == medians.length` and ≥1 stroke.
- Every median has ≥2 points.
- **Pitfall §2 enforcement:** for each diacritic letter (á é í ó ú ý ö),
  the last stroke's median bounding box sits strictly above all prior
  stroke medians' bounding boxes (verified via MMAH y-up coordinate
  comparison).
- ð and þ have exactly 2 strokes each (D-04 pedagogical convention).
- Every JSON is structurally valid (has the required top-level keys).
- Diacritic + two-part Icelandic letter manifest sets are accounted
  for in `kIcelandicAlphabet`.

## Architectural commitments — preserved

- **`lib/core/tracing/` Flutter-free** — registered in
  `tools/check-domain-purity.sh`. CI guard passes.
- **Strict parser** — bad JSON fails at LOAD time, not at first user
  touch. Production paths always succeed because the test suite
  validates the shipped JSONs.

## Deviations from plan

None — TDD red→green ran exactly as written.

## Files changed

### Created
- `lib/core/tracing/glyph_loader.dart` (~145 lines).
- `test/core/tracing/glyph_loader_test.dart` (~230 lines, 17 tests).

### Modified
- `tools/check-domain-purity.sh` — register `lib/core/tracing` in
  `DOMAIN_PATHS`.

## Commits

- `907891e test(07-02): add failing tests for tracing glyph loader (RED)`
- `5ca8722 feat(07-02): implement pure-Dart MMAH glyph loader (GREEN)`

## Self-Check: PASSED
