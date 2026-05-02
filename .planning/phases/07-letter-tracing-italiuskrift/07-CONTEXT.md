# Phase 7: Letter Tracing (Ítalíuskrift) - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto`
**Research:** `.planning/phases/07-letter-tracing-italiuskrift/07-RESEARCH.md` (gsd-phase-researcher, Confidence: HIGH)

<domain>
## Phase Boundary

Letter tracing activity in Stafir room using the `stroke_order_animator: ^3.3.1` package + hand-authored MMAH-format JSON glyphs (32 lowercase Icelandic letters in Ítalíuskrift style). Calibrated tolerance ~50-60% of stroke width. Soft stroke-order (visual hint, never hard rejection). No fail state, no timer. Completion celebration with child's name in voice-over.

**Requirements covered (5):** TRACE-01..05

</domain>

<decisions>
## Implementation Decisions

### Library adoption (research finding)

- **D-01:** Adopt `stroke_order_animator: ^3.3.1` (BSD-3-Clause). The package is glyph-agnostic — works with any writing system that has Make-Me-A-Hanzi-format JSON. Solves rendering, soft stroke-order with animated hints, brush widget, and the four-check tolerance algorithm out of the box. Saves ~2 days vs hand-rolling.
- **D-02:** Glyph data in MMAH JSON format: `{character: "a", strokes: [SVG path], medians: [[[x,y], ...]]}`. One file per letter at `assets/tracing/{slug}.json`. 32 files, ~1KB each.

### Glyph authoring (the major effort)

- **D-03:** Source: Briem's *The Icelandic Method* (1985) PDF, freely-distributed at `luc.devroye.org/Briem1985-IcelandicMethod.pdf`. Contains the *Italiuskrift05* font designed for Icelandic primary-school italic instruction.
- **D-04:** **Phase 7 ships SIMPLIFIED letterforms in MMAH format.** Hand-authoring all 32 in true Briem style is ~1.5-2 days designer effort — out of scope for autonomous execution. Phase 7's executor will:
  1. Use a simple programmatic generation (or copy from a Latin Make-Me-A-Hanzi-style open dataset if one exists)
  2. Each letter has 1-3 strokes following standard Latin lowercase order (top-to-bottom, left-to-right; for letters like "a" / "o" the closed loop counts as one stroke)
  3. Diacritic marks (á, é, í, ó, ú, ý, ö) are always the LAST stroke
  4. Two-part letters (ð, þ) have body first, then bowl/cross-bar
- **D-05:** Phase 7's letterforms are **functional placeholders** — they teach stroke-by-stroke mechanics correctly but aren't visually identical to Briem. A polish pass replaces them with authentic Ítalíuskrift traces (logged as a follow-up). User decision documented in CONTEXT — proceed with simplified forms, note this in PROJECT.md "Out of Scope" or "Deferred" once Phase 7 ships.
- **D-06:** A small Dart/Python tool (`tools/glyph/generate_simple_traces.py`) generates the 32 JSON files from a template. Each letter's stroke paths use simple cubic Bezier curves matching the letter's overall shape. Editable by hand later.

### Activity widget

- **D-07:** `lib/features/stafir/tracing/tracing_activity.dart`. Reuses StafirRoom mode toggle pattern — Stafir now has 4 modes: Letters / Match / CVC / Trace.
- **D-08:** Round = one letter to trace. Random selection from `kIcelandicAlphabet`. Renders the `StrokeOrderAnimator` widget at center, ~70% of viewport.
- **D-09:** No round counter, no progress UI, no fail state. Wrong-stroke = soft hint (faded ghost stroke from the package's built-in `hintAfterStrokes` parameter).
- **D-10:** Completion celebration: full-screen scale-up of the completed letter + checkmark + audio narration "Frábært, Hugrún!" (or name-aware variant). Reuses Phase 4's welcome-narration name-variant pattern.

### Tolerance calibration

- **D-11:** Default tolerance values from package: `lengthBounds: 0.4..1.2`, `startMargin: 0.15`, `endMargin: 0.2`, `directionTolerance: 90°`. These are kid-friendly. Tunable per Hugrún at the tablet — Phase 7 ships defaults and adds a `LetterTracingPolicy` const that the user can adjust later without changing code.
- **D-12:** STAFIR-related success criterion: tracing tolerance "calibrated on Hugrún's tablet". Like Phase 4's latency, this is a manual checkpoint — Phase 7 documents the calibration procedure but ships defaults.

### Audio integration

- **D-13:** Tap each completed stroke = no audio (the visual completion is enough feedback). Round complete = celebration narration via AudioEngine.
- **D-14:** New manifest entry: `narrationCelebrationTracing` ("Frábært!" or "Vel gert!"). Phase 7 ships placeholder; Phase 3 review pipeline can add when convenient — soft fallback to existing `narrationWelcome` if missing.

### Mode toggle expansion

- **D-15:** `StafirMode` enum extended: Letters / Match / CVC / **Trace**. 3-second hold cycles all 4. Same kid-mode safety.

### Test strategy

- **D-16:** Unit tests for the JSON parsing wrapper (verify all 32 letters load valid MMAH format).
- **D-17:** Widget tests for TracingActivity using mocked `StrokeOrderAnimationController` (don't depend on package internals).
- **D-18:** Integration test: open Stafir → toggle to Trace → trace a letter → verify celebration fires.

### Drift schema

- **D-19:** No new tables. Phase 7 doesn't track tracing completions (consistent with no-progress philosophy for the child).

### Claude's Discretion

- Exact letterform generation approach — simple Bezier curves, font glyph extraction, or a third-party Latin MMAH dataset
- Animation curves for celebration
- Whether to ship celebration narration with placeholder or wait for Phase 3 manifest extension

</decisions>

<canonical_refs>
- `.planning/PROJECT.md`, `REQUIREMENTS.md` TRACE-01..05
- `.planning/ROADMAP.md` § Phase 7
- `.planning/phases/07-letter-tracing-italiuskrift/07-RESEARCH.md` — full research dump
- `.planning/phases/05-letter-to-word-matching/05-SUMMARY.md` — mode toggle pattern
- `.planning/phases/06-cvc-blending-phoneme-audio-set/06-SUMMARY.md` — 4th mode addition pattern
- `.planning/research/PITFALLS.md` Pitfall #10 (tracing tolerance)
- https://pub.dev/packages/stroke_order_animator
- https://luc.devroye.org/Briem1985-IcelandicMethod.pdf
</canonical_refs>

<code_context>
- Reuses LetterTile (no — tracing replaces it for the trace mode), AudioEngine, mode toggle pattern
- `lib/features/stafir/tracing/` — new
- `assets/tracing/` — new asset folder for 32 JSON glyph files
- `tools/glyph/generate_simple_traces.py` — new helper (out of `tools/`)
- pubspec.yaml — add `stroke_order_animator: ^3.3.1`
- pubspec.yaml `flutter:` `assets:` — add `assets/tracing/`
- tools/check-asset-paths.sh may need to allow `.json` extension under `assets/tracing/`
- manifest.yaml — extend with `narrationCelebrationTracing`
</code_context>

<deferred>
- Authentic Briem letterforms (replace simplified placeholders) — designer pass post-Phase 7
- Tracing completion tracking in Drift — explicitly out of v1 (no-progress philosophy)
- Uppercase letterforms — out of v1 scope
- Tengiskrift (cursive) — explicitly out of scope per PROJECT.md (age-appropriate v2+)
</deferred>

---

*Phase: 7 — Letter Tracing (Ítalíuskrift)*
*Context gathered: 2026-05-02*
