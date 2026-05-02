---
phase: 07
title: Letter Tracing (Ítalíuskrift)
status: human_needed
plans:
  - 07-01-adopt-stroke-order-animator-and-glyph-data
  - 07-02-pure-dart-glyph-loader
  - 07-03-tracing-activity-and-providers
  - 07-04-mode-toggle-and-integration-test
date: 2026-05-02
tags: [phase-7, tracing, italiuskrift, stroke-order-animator, simplified, post-mvp]
requirements_satisfied:
  - TRACE-01  # 32 lowercase Ítalíuskrift letterforms (SIMPLIFIED, see Deferred)
  - TRACE-03  # soft stroke-order via package's hintAfterStrokes default
  - TRACE-04  # no failure state, no timer
  - TRACE-05  # celebration narration on completion (D-14 fallback chain)
requirements_pending:
  - TRACE-02  # tolerance calibration on Hugrún's tablet — manual checkpoint
metrics:
  total-tests: 348
  test-delta: +31 (17 loader unit + 8 widget + 6 toggle/room + integration)
  flutter-analyze: 11 warnings (all riverpod_lint scoped-providers in test
    files — same family Phases 5/6 documented; no Phase 7-introduced new
    classes of warnings)
  flutter-build-apk-debug: passes
  domain-purity: passes (lib/core/tracing registered)
  asset-paths: passes (.json extension allowed under assets/tracing/)
  no-tracking: passes
  manifest-utterances: 100 (Phase 6 baseline) — no Phase 7 manifest extension
    (D-14 left for Phase 3 review pipeline; activity uses soft fallback to
    narrationWelcome until then)
  enum-utterancekey-entries: 45 (Phase 6 baseline) — no Phase 7 extension
    (D-14)
  glyph-files-shipped: 32
  package-deps-added: 1 direct (stroke_order_animator) + 2 transitive
    (svg_path_parser, http — http unused at runtime)
---

# Phase 7: Letter Tracing (Ítalíuskrift) — Master Summary

A post-MVP activity that teaches Icelandic primary-school italic
letterforms via guided stroke-order tracing. Phase 7 adds:

- **The `stroke_order_animator: ^3.3.1` package** as the rendering +
  tolerance + hint-animation engine (BSD-3-Clause; saves ~2 days vs.
  hand-rolling a tracing CustomPainter).
- **32 simplified MMAH-format JSON glyphs** at `assets/tracing/`,
  one per Icelandic lowercase letter (a á b d ð e é f g h i í j k l m
  n o ó p r s t u ú v x y ý þ æ ö). Diacritics-as-last-stroke; ð and þ
  body-first-then-bowl/cross-bar.
- **A pure-Dart MMAH glyph loader** at `lib/core/tracing/` — schema
  validator + value object. Flutter-free.
- **The TracingActivity widget + Riverpod providers** under
  `lib/features/stafir/tracing/`. Composes the package's
  `StrokeOrderAnimator`, fires celebration audio on completion,
  auto-advances to a new random letter. No fail state, no timer,
  no progress UI.
- **A 4th Stafir room mode** — Letters / Match / CVC / **Trace**.
  Same 3-second hold-to-toggle gesture; new pencil icon for trace.

Plans executed: all 4 (07-01 through 07-04, plus an integration test
under 07-05).

## Plan summaries

| Plan | Subject | Commits | Tests | Status |
|------|---------|---------|-------|--------|
| 07-01 | Package adoption + 32 glyph JSONs | 2 | 0 (data only) | complete |
| 07-02 | Pure-Dart glyph loader | 2 | +17 unit | complete |
| 07-03 | TracingActivity + Riverpod providers | 2 + 1 refactor | +8 widget | complete |
| 07-04 | 4-mode toggle expansion | 2 | +6 widget + integration | complete |

Total: 9 atomic commits. Trail in `git log`:

```
cad9fd6 test(07-05): add Phase 7 letter-tracing flow integration test
65bb880 refactor(07): remove unused imports + dead code from Phase 7 tests/widget
b108713 feat(07-04): extend StafirMode to 4 modes + render TracingActivity (GREEN)
53f33e2 test(07-04): add failing tests for 4-mode toggle (RED — Phase 7 D-15)
8d365ac feat(07-03): implement TracingActivity widget + Riverpod providers (GREEN)
f904a11 test(07-03): add failing tests for TracingActivity widget (RED)
5ca8722 feat(07-02): implement pure-Dart MMAH glyph loader (GREEN)
907891e test(07-02): add failing tests for tracing glyph loader (RED)
0216fce feat(07-01): generate 32 simplified MMAH glyph traces (Phase 7 D-02..D-06)
b1b97f4 feat(07-01): add stroke_order_animator dependency (Phase 7 D-01)
```

## What was built (the tracing loop)

```
StafirRoom (in trace mode after the toggle cycles 3 times)
  ↓
[Adult holds top-right toggle for 3 seconds — three times from default]
  ↓
StafirModeToggle.onToggle fires three times
  (letters→match, match→cvc, cvc→trace)
  ↓
StafirRoom._mode swaps to StafirMode.trace
  ↓
TracingActivity mounts → reads tracingCurrentLetterProvider (random letter)
                       → watches traceDataProvider (FutureProvider, loads
                         32 MMAH JSONs from rootBundle on first read)
  ↓
StrokeOrderAnimationController constructed from StrokeOrder(rawJson)
  with brushWidth=18, hintAfterStrokes=5
  ↓
StrokeOrderAnimator widget renders ◯ outline + medians + brush
  ↓
[Child traces strokes in order — package matches via 4-check tolerance:
 length, start, end, direction]
  ↓
Wrong stroke → soft hint (faded ghost via hintAfterStrokes); no audio,
                no negative chrome (TRACE-03/04)
  ↓
All N strokes correct → onQuizCompleteCallback fires
  ↓
selectCelebrationKey() → narrationCelebrationTracing if in enum
                        → narrationWelcome otherwise (D-14 soft fallback)
  ↓
audioEngine.play(celebrationKey) — silent fallback if not yet reviewed
  ↓
Auto-advance Timer (1.2s) → tracingCurrentLetterProvider.set(nextLetter)
  ↓
TracingActivity rebuilds for nextLetter, controller swaps, round resets
  ↓
[Loop continues — infinite rounds, no counter, no score]
```

## Quality gate (verified at phase close)

- [x] `stroke_order_animator: ^3.3.1` in pubspec.yaml; resolves cleanly
- [x] 32 MMAH JSON glyph files at `assets/tracing/`; loader test
      verifies all 32 parse
- [x] TracingActivity widget renders + auto-advances + fires celebration
      audio
- [x] StafirMode enum has 4 values; toggle cycles
- [x] Integration test compiles clean (`flutter analyze`: 0 issues)
- [x] `flutter analyze` clean modulo 11 documented riverpod_lint warnings
      (same family Phase 5/6 documented; no new warning classes)
- [x] `flutter test` 348 / 348 pass
- [x] `flutter build apk --debug` succeeds
- [x] `tools/check-domain-purity.sh` updated; passes
- [x] `tools/check-asset-paths.sh` updated for `.json`; passes
- [x] `tools/check-no-tracking.sh` passes (stroke_order_animator and its
      transitive deps are not on the banned list)
- [x] Atomic commits per RED/GREEN cycle
- [x] VERIFICATION.md status: `human_needed` (TRACE-02 tolerance
      calibration on Hugrún's tablet — manual checkpoint)

## Architectural commitments — preserved

- **Pure-Dart `lib/core/tracing/`** — enforced via CI script. No Flutter
  imports under that subtree.
- **Reuse-not-duplicate** — AudioEngine, StafirModeToggle (extended,
  not forked), ParentGateController (via the toggle), kIcelandicAlphabet,
  the existing StafirRoom switch-arm pattern. All imported and used
  directly.
- **No fail-state UI** — 0 stars, 0 trophies, 0 score numbers,
  0 "wrong" text, 0 timer-display widgets. Tests T2 / T3 / T6 assert.
- **Soft order (TRACE-03)** — uses the package's
  `hintAfterStrokes=5` default; activity never blocks input.
- **D-14 silent fallback** — `narrationCelebrationTracing` not yet in
  the enum; activity is structurally functional and plays the welcome
  clip in the meantime — exactly the documented contract.
- **Coordinate system documented** in `tools/glyph/generate_simple_traces.py`
  doc comment so future contributors don't repeat Pitfall §1 (MMAH
  Y-up authoring).

## Key decisions exercised

D-01 (package adoption), D-02 (MMAH JSON format), D-03 (Briem 1985
PDF as authoritative reference), **D-04 (SIMPLIFIED letterforms ship
in v1)**, D-05 (placeholder pedagogy), D-06 (Python generator), D-07
(activity widget composition), D-08 (animator at center, ~70%
viewport), D-09 (no fail UI / soft hint), D-10 (completion celebration
+ auto-advance), D-11 (default tolerance values), D-12 (manual
calibration checkpoint), D-13 (no per-stroke audio), D-14
(narrationCelebrationTracing fallback to narrationWelcome), **D-15
(4-mode toggle)**, D-16/D-17/D-18 (test strategy — unit, widget,
integration), D-19 (no Drift schema change).

All 19 decisions in 07-CONTEXT.md were reached.

## Deviations summary

The full deviation list lives in each plan SUMMARY. Highlights:

1. **Asset-paths checker extended** (Plan 07-01, Rule 2). The plan's
   pubspec changes added a `.json` extension under `assets/tracing/`
   which the existing `tools/check-asset-paths.sh` allow-list rejected.
   Auto-fix per Rule 2; included in the same atomic commit as the
   glyph generator.

2. **Riverpod 3.x scoping** (Plan 07-03, minor). Initial draft used
   Riverpod 2's `StateProvider` / `Override` types; this project's 3.x
   family has dropped those. Adapted to `@Riverpod` Notifier-class
   codegen for the current-letter provider; documented inline.

3. **Manifest extension deferred** (Plan 07-03, D-14 honored). Phase 7
   does NOT extend manifest.yaml or `UtteranceKey` with
   `narrationCelebrationTracing`. The activity uses
   `selectCelebrationKey()` to soft-fallback to `narrationWelcome`
   (always present). Phase 3's review pipeline will add the new clip
   when it's baked + reviewed; the activity will start firing it
   without code changes (runtime symbol lookup via
   `UtteranceKey.values.where(name=='...')`).

4. **Phase 7 + Phase 8 ran in parallel** — observed harmless
   working-tree concurrency: my Phase 7 commits and Phase 8's commits
   were interleaved in `git log`. Both phases respected the file-level
   boundary (`lib/features/stafir/tracing/` vs.
   `lib/features/tolur/`); the only shared files were
   `pubspec.yaml` (each phase added their own dep + assets entry, no
   conflict), `tools/check-domain-purity.sh` (each phase added their
   `lib/core/{tracing,numbers}` entry, no conflict), and the test
   suite (no test name collisions). All 348 tests pass at phase close.

## Files created/modified summary

### Created (lib/)
- `lib/core/tracing/glyph_loader.dart` (~145 lines)
- `lib/features/stafir/tracing/tracing_activity.dart` (~180 lines)
- `lib/features/stafir/tracing/trace_data_provider.dart` (~95 lines)
- `lib/features/stafir/tracing/trace_data_provider.g.dart` (gitignored)
- `lib/features/stafir/tracing/tracing_celebration.dart` (~30 lines)

### Modified (lib/)
- `lib/features/stafir/stafir_mode.dart` — 3 → 4 mode values
- `lib/features/stafir/widgets/stafir_mode_toggle.dart` — 4-arm switch
- `lib/features/stafir/stafir_room.dart` — switch arm for trace

### Modified (top-level config)
- `pubspec.yaml` — direct dep `stroke_order_animator: ^3.3.1`;
  declare `assets/tracing/`
- `pubspec.lock` — auto-updated
- `tools/check-asset-paths.sh` — allow `.json` extension
- `tools/check-domain-purity.sh` — register `lib/core/tracing`

### Created (assets/)
- `assets/tracing/*.json` (32 simplified MMAH glyph files,
  ~26 KB total)
- `assets/tracing/.gitkeep`

### Created (tools/)
- `tools/glyph/generate_simple_traces.py` (~370 lines, Python)

### Created (test/)
- `test/core/tracing/glyph_loader_test.dart` (~230 lines, 17 tests)
- `test/features/stafir/tracing/tracing_activity_test.dart` (~320
  lines, 8 tests)

### Modified (test/)
- `test/features/stafir/widgets/stafir_mode_toggle_test.dart` — M1,
  M1b, M3 updated for 4 modes
- `test/features/stafir/stafir_room_test.dart` — add S4d, S4e + import

### Created (integration_test/)
- `integration_test/stafir_tracing_flow_test.dart` (~150 lines)

## Deferred / Open

### Authentic Briem letterforms (designer pass)
**Phase 7 ships SIMPLIFIED placeholders.** Each letter has the right
stroke count, the right pedagogical order (body-first, accent-last),
and a plausible centerline — but the actual letterform geometry is a
rectangular outline around a hand-coded Bezier-shaped median, not an
authentic Ítalíuskrift trace.

**Resolution path:** A polish-pass plan (suggested name: `07-99` or a
new Phase 11 entry) replaces each `assets/tracing/*.json` with traces
extracted from Italiuskrift05 in the Briem 1985 PDF. The activity code
does not change; the loader, activity widget, and integration flow are
all glyph-agnostic. Estimated effort: 1.5–2 days for one designer with
vector tooling, per the research.

This deferral is documented in `.planning/PROJECT.md` Beyond MVP and
in this SUMMARY's metadata.

### TRACE-02 calibration (manual)
Tracing tolerance "calibrated on Hugrún's tablet" is the **human-verify
checkpoint** at phase close. Phase 7 ships the package's defaults
(brushWidth=18, hintAfterStrokes=5, length-range 0.5..1.5 for long
strokes, start-end margin 150–200 in MMAH coordinate space). The
calibration session belongs to Jon — sit Hugrún at the tablet, observe
rejections, loosen-not-tighten if needed, pin the calibrated values in
`LetterTracingPolicy`. See `07-VERIFICATION.md` for the procedure.

### narrationCelebrationTracing audio clip
Phase 7 plays `narrationWelcome` ("Halló Hugrún") on completion via the
D-14 soft fallback. A dedicated celebration clip ("Frábært, Hugrún!"
or "Vel gert!") is not yet in the manifest — Phase 3's review pipeline
adds it when the bake + review is done. The activity will start firing
the new clip without code changes (runtime symbol lookup).

## Phase 7 closing posture

The letter-tracing activity is **structurally complete**: 348 tests
pass, flutter analyze is clean (modulo 11 documented warnings), the
debug APK builds, the activity correctly renders all 32 letters, fires
the package's stroke-order tolerance algorithm, plays celebration audio
on completion, auto-advances to a new random letter, never shows a
fail/error/score/timer indicator. The 4-mode Stafir toggle cycles
correctly. Integration test compiles clean.

Three threads remain open at phase close:

1. **TRACE-02 tolerance calibration session** — manual checkpoint;
   does not block code-quality sign-off (matches Phase 4 latency-
   verification posture).

2. **Authentic Briem letterforms** — explicitly deferred (D-04). The
   simplified placeholders are functional for v1 ship but visually do
   not match Briem's Ítalíuskrift exactly.

3. **`narrationCelebrationTracing` clip** — soft-fallback to welcome
   clip works today; Phase 3's review pipeline will resolve.

The Phase 7 scope is closed from a code-quality standpoint. Phase 8
(Tölur Tap-to-Hear & Sequencing) can ship in parallel — it has been
running concurrently and respects the file-boundary line.
