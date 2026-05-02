# Phase 7: Letter Tracing (Ítalíuskrift) - Research

**Researched:** 2026-05-02
**Domain:** Flutter CustomPainter tracing surface + Ítalíuskrift letterform digitization for 32 Icelandic lowercase letters, 5-year-old motor calibration
**Confidence:** HIGH on rendering/perf and tolerance algorithm; HIGH on a viable Ítalíuskrift sourcing path (commercial font + hand-author medians); MEDIUM on the exact Briem font's accented-character coverage (needs in-hand verification before plan execution)

## Summary

Phase 7 has two technical risks the project SUMMARY.md flagged. Both are now answered with practical paths forward, no speculation:

1. **Ítalíuskrift digitization (Q1):** No published "stroke order JSON" for Ítalíuskrift exists, but two viable sourcing paths land at the same hand-author estimate. **Recommended path:** purchase or license a commercial Briem italic font that includes Icelandic accented glyphs (Briem Hand by Sorkin Type / Briem Script Std / Briem Operina), trace each lowercase glyph to extract centerline + outline polylines, hand-author stroke order. Estimated effort: **1.5–2 days for one designer**, calibrated against the 32-letter set. **Free fallback:** the freely-distributed *The Icelandic Method* PDF (Briem 1985, on Luc Devroye's archive) contains the entire teaching font Italiuskrift05 as raster pages; trace from PDF if a TTF/OTF is unavailable. Both paths produce the same hand-authored JSON; the font path just makes the tracing 2x faster than tracing scanned PDF pages.

2. **CustomPainter performance at 60Hz (Q3):** Impeller path drawing performance has known weaknesses on Android (issue #143077 still open) but they manifest only at hundreds of complex stroked/filled paths per frame. Phase 7's worst-case frame paints **~5 paths**: outline glyph (static, can be cached as a `ui.Picture`), 1–3 traced-stroke polylines (small, growing), 1 active user stroke. With `RepaintBoundary` isolation, `shouldRepaint` returning false unless the stroke buffer changed, and `Picture` caching for the static outline, **60fps is achievable on iPad Air M2 (Impeller/Metal) and on any Android tablet running Impeller/Vulkan API 29+**. The April 2025 stroke-pipeline rewrite (PR #167422, ~1.37x rasterizer improvement) shipped in Flutter 3.32+; Hugrún is on 3.41.5 so the win is already inherited.

**Primary recommendation:** Adopt `stroke_order_animator: ^3.3.1` from pub.dev as the rendering + tolerance engine. It is a fully glyph-agnostic Flutter package: it consumes a JSON document with `{strokes: [SVG path string], medians: [[[x,y], ...]], radStrokes: [int]}` for any glyph, in any writing system. We hand-author 32 JSON files (one per Icelandic lowercase letter) that match the Make-Me-A-Hanzi schema — Latin glyphs work fine because the schema doesn't know or care about Chinese. The package gives us correct-stroke detection, animated stroke-order ghost (the "hint" feature, threshold of 3 misses by default), brush rendering, length/start-end/direction tolerance — all of TRACE-01..04. Phase 7 wires its own celebration audio via `onQuizCompleteCallback` for TRACE-05.

This converts Phase 7 from "build a tracing engine + digitize 32 glyphs + tune tolerance" to "**digitize 32 glyphs + thin Riverpod wrapper around stroke_order_animator + audio wiring**." That is the single most consequential finding in this research session. [VERIFIED: pub.dev, github.com/chill-chinese/stroke-order-animator]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Letterform geometry (outline path + median) | Asset bundle (JSON in `assets/tracing/`) | Static const Dart map | Pure data, hand-authored, build-time only. Loaded once at activity entry. |
| Stroke-matching algorithm (tolerance, direction, start/end) | Core / mechanic (`lib/mechanics/tracing/`) | Riverpod activity scope | Uses `stroke_order_animator` controller; pure Dart logic on top of `dart:ui` `Path`. |
| Touch input sampling | Flutter framework (`Listener` / built-in gesture in `StrokeOrderAnimator` widget) | — | OS-level pointer events, sampled at native display rate (60Hz iPad Air, 60Hz typical Android tablet). No throttle. |
| Static outline rendering | CustomPainter inside `StrokeOrderAnimator` | `RepaintBoundary` isolation | Pre-rendered ideal letter; `shouldRepaint` false unless the controller `notifyListeners()` fires. |
| Active stroke rendering | CustomPainter, separate paint pass | Inside same `RepaintBoundary` | Only the in-progress stroke triggers repaints — bounded to ~16ms budget. |
| Stroke-order enforcement (soft) | Activity-scoped state in controller | UI hint animation | "Wrong stroke" emits `onWrongStrokeCallback`; after N misses, animated hint plays. Never rejects, never blocks input. |
| Completion celebration | Feature room (`lib/features/stafir/tracing/`) | Phase 4's AudioEngine + Phase 4's narrationWelcome name pattern | Activity calls AudioEngine after `onQuizCompleteCallback` fires; child name is selected via the existing pre-baked-clip set per PERS-03 / Phase 4 mechanism. |
| Persistence | None at this phase (Phase 7 ships no Drift schema change) | — | No completion tracking; no scores; no timer. Re-entering the activity starts fresh. Matches no-fail philosophy. |

[VERIFIED: existing Hugrún codebase patterns in `/Users/jonb/Projects/hugrun/lib/features/stafir/`, `/Users/jonb/Projects/hugrun/lib/core/audio/audio_engine.dart`]

## Standard Stack

### Core (new for Phase 7)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `stroke_order_animator` | ^3.3.1 | Stroke-order rendering, tolerance matching, animated hints, brush widget | Glyph-agnostic. The package is built around a JSON schema (Make-Me-A-Hanzi format) that admits any path-and-median data. BSD-3-Clause. Active maintenance (chill-chinese org). [VERIFIED: pub.dev/api/packages/stroke_order_animator latest=3.3.1, sdk constraint >=3.2.0 <4.0.0 — compatible with hugrun's `^3.11.5`] |
| `svg_path_parser` | ^1.1.2 | Parse SVG path strings (`M150 0 L75 200 ...`) into `dart:ui` `Path` objects | Already a transitive dep of `stroke_order_animator`. Used by the package internally; we reuse it if we need to convert hand-authored SVG strings into Paths in tests. [VERIFIED: pub.dev/api/packages/svg_path_parser latest=1.1.2] |

### Already-in-stack (used unchanged from earlier phases)

| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| `flutter_riverpod` | ^3.3.1 (existing) | Activity-scoped state, controller injection | Wrap the StrokeOrderAnimationController as a Riverpod provider keyed on the current letter |
| `just_audio` | ^0.10.5 (existing) | Celebration audio via existing AudioEngine | Phase 4's warm-pool AudioEngine plays the completion narration. No new players, no new providers. |
| `freezed` / `freezed_annotation` | ^3.x (existing) | Optional: a typed `LetterTrace` wrapper around the JSON if we want compile-time stroke counts | Nice-to-have, not required — `StrokeOrder` from the package is already a strongly-typed class. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `stroke_order_animator` | Hand-built CustomPainter from PITFALLS § 9 + ARCHITECTURE § tracing skeleton (the current sketch) | Building the animator from scratch is **2–3 days of careful work** (gesture handling, length/start-end/direction tolerance, animated hints, RepaintBoundary discipline, picture caching). The package solves all of that in a maintained, BSD-licensed dependency. Hand-rolling is the right answer only if `stroke_order_animator` blocks for some reason after spike. |
| Make-Me-A-Hanzi JSON schema | A custom schema (`{glyph, strokes: [{points, order}]}` per ARCHITECTURE.md sketch) | The MMAH schema is what `stroke_order_animator` consumes natively. Custom schemas mean either patching the package or writing a transformer — pure overhead. The schema is general enough for Latin glyphs. |
| `flutter_svg` for outline rendering | `svg_path_parser` + `Canvas.drawPath` | `flutter_svg` ships an entire SVG renderer; we only need path parsing. The package already pulls `svg_path_parser` transitively. |
| Free *Italiuskrift05* font | Commercial Briem Hand / Briem Script Std | The free 1985 font may lack proper kerning or Icelandic accent positioning that's been improved in commercial versions. **However**, since we are tracing each glyph by hand to extract centerlines (not using the font as a runtime asset), the free version is sufficient. Commercial fonts only buy us cleaner outlines for tracing. |

**Installation (Phase 7 plan task):**
```bash
flutter pub add stroke_order_animator
# svg_path_parser pulled transitively
```

**Version verification:**
```bash
$ curl -s https://pub.dev/api/packages/stroke_order_animator | jq -r '.latest.version'
3.3.1
$ curl -s https://pub.dev/api/packages/svg_path_parser | jq -r '.latest.version'
1.1.2
```
Both verified 2026-05-02. [VERIFIED: pub.dev]

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          Stafir Room (existing)                           │
│   Mode toggle: Letters → Match → CVC → Trace (Phase 7 adds 4th mode)     │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                       TracingActivity (Phase 7 new)                       │
│  • Picks current IcelandicLetter (Riverpod activity scope)                │
│  • Loads JSON from assets/tracing/{slug}.json                             │
│  • Constructs StrokeOrderAnimationController(StrokeOrder(jsonString))     │
│  • Wires onQuizCompleteCallback → celebration audio + child-name clip    │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│         StrokeOrderAnimator widget (from stroke_order_animator pkg)       │
│  • Renders outline (static path) + traced strokes + active user stroke   │
│  • Wraps its own canvas in RepaintBoundary internally                     │
│  • Pointer events handled internally via Listener; sampled at native rate │
│  • Calls controller.checkStroke(points) on each pen-up                    │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                  ┌─────────────────┴─────────────────┐
                  ▼                                   ▼
┌──────────────────────────────┐      ┌──────────────────────────────────┐
│     Asset: 32 JSON files      │      │ AudioEngine (Phase 4)             │
│  assets/tracing/a.json        │      │ Plays completion clip             │
│  assets/tracing/aacute.json   │      │ Selects name-aware variant if     │
│  ... (32 total, ~1KB each)    │      │ available, falls back to generic  │
│  Hand-authored MMAH-format    │      │ (existing Phase 4 mechanism)      │
└──────────────────────────────┘      └──────────────────────────────────┘
```

The static outline + active user stroke + completed strokes all render through `stroke_order_animator`'s internal CustomPainter. We do not author our own CustomPainter for Phase 7. The activity widget wraps the animator widget, plus a top-of-screen "current letter" affordance, plus the celebration overlay.

### Recommended Project Structure

```
lib/
├── features/
│   └── stafir/
│       └── tracing/                       # NEW for Phase 7
│           ├── tracing_activity.dart       # Composes StrokeOrderAnimator + room chrome
│           ├── trace_controller_provider.dart  # @riverpod controller per current letter
│           └── trace_completion_handler.dart   # Wires celebration audio + name selection
└── mechanics/
    └── tracing/                           # already a folder (skeleton in Phase 1/2)
        ├── trace_data_loader.dart         # Loads + caches JSON for all 32 letters
        ├── stroke_order_json.dart         # Optional: validates/parses our hand-authored JSON
        └── tracing_widget.dart            # Optional: thin wrapper if we want to control colors

assets/
└── tracing/
    ├── a.json
    ├── aacute.json
    ├── b.json
    ├── d.json
    ├── eth.json                            # ð → eth (D-06 asset path convention)
    ├── e.json
    ├── eacute.json
    ├── f.json
    ... (32 files total, lowercase ASCII slugs)
    └── oumlaut.json                        # ö → oumlaut
```

[VERIFIED: existing `lib/mechanics/` folder per ls; existing slug convention via `lib/core/manifest/utterance_key.dart` patterns]

### Pattern 1: Make-Me-A-Hanzi JSON for Latin glyphs

**What:** Hand-author one JSON file per Icelandic lowercase letter following the schema `stroke_order_animator` already understands.

**When to use:** All 32 letters. The schema is glyph-agnostic — the package never validates "is this Chinese."

**Example (a.json — single-stroke 'a' in Ítalíuskrift):**
```json
{
  "strokes": [
    "M 612 332 C 612 332 580 280 540 270 C 480 255 420 290 400 360 C 380 430 410 510 480 530 C 540 545 600 510 612 470 L 612 700 L 660 700"
  ],
  "medians": [
    [[612, 332], [560, 290], [490, 280], [430, 320], [400, 400], [415, 480], [475, 520], [555, 510], [605, 470], [612, 700], [660, 700]]
  ],
  "radStrokes": []
}
```

The coordinate system is Make-Me-A-Hanzi's 1024×1024 with Y inverted around y=900 (the package handles the transform internally — see `_parseStrokeOutlines` in source). Hand-authored Latin glyphs use the same canvas.

**For multi-stroke letters** (e.g., "k" — 1 vertical + 1 diagonal-pair, "ð" with the cross-bar, "x" with two diagonals), each stroke is a separate entry in the `strokes` and `medians` arrays. The list order **is** the canonical stroke order; that's what the controller enforces (softly).

**Diacritics** (á, é, í, ó, ú, ý, ö): the dot/accent **is its own stroke**, authored last. So 'á' is two strokes: the 'a' base, then the acute mark. The package will replay the ghost in that order. This matches Briem's pedagogical convention — the body of the letter is one motion, the dot/accent is a separate, terminal mark.

[CITED: github.com/chill-chinese/stroke-order-animator/blob/main/lib/src/stroke_order.dart, github.com/skishore/makemeahanzi/blob/master/README.md]

### Pattern 2: Picture-cached static outline

**What:** Render the canonical outline into a `ui.Picture` once when the letter loads, paint it inside the CustomPainter via `canvas.drawPicture()` instead of `canvas.drawPath()`.

**When to use:** Anywhere the package allows us to inject custom painting. `stroke_order_animator` already does this internally for its outline path (we don't need to recreate it).

**Why this matters:** `Picture` caching avoids re-tessellating the static letter path every frame. The April 2025 Impeller stroke-pipeline rewrite (#167422) reduced stroke cost ~1.37x, but caching avoids the cost entirely. Static-outline + dynamic-stroke is the classic "two layers" pattern Flutter docs recommend.

[CITED: github.com/flutter/flutter/pull/167422 (merged April 25 2025), api.flutter.dev/flutter/dart-ui/Picture-class.html]

### Pattern 3: RepaintBoundary discipline

**What:** Wrap the tracing canvas in a `RepaintBoundary` so child repaints don't trigger sibling layout, and parent rebuilds don't tear down the canvas.

**When to use:** Around the `StrokeOrderAnimator` widget at the activity composition level.

```dart
RepaintBoundary(
  child: StrokeOrderAnimator(controller),
)
```

**Why this matters:** The activity has other moving parts (the "current letter" header, the next-letter button after completion, the celebration overlay). Without `RepaintBoundary`, every frame of the celebration animation also dirties the (idle) tracing canvas's layer. With it, the tracing canvas paints exactly when its controller `notifyListeners()` fires.

**Don't over-apply:** `RepaintBoundary` adds memory cost (~width × height × 4 bytes for the cached layer). One boundary at the right place beats five sprinkled around.

[CITED: medium.com/@ilham-asgarli/repaintboundary-in-flutter, api.flutter.dev/flutter/widgets/RepaintBoundary-class.html]

### Anti-Patterns to Avoid

- **Per-frame distance computation against the ideal path.** PITFALLS.md flagged this; STACK.md flagged this. If we evaluate "is the user's finger near the centerline" on every `onPanUpdate`, we burn CPU on `Path.computeMetrics()` 60 times a second. The `stroke_order_animator` controller checks once per `onPanEnd` (when `checkStroke()` is called). That's the right cadence: while the child draws, just record points; when they lift, evaluate. The visual feedback during drawing is just "show me what I drew" (cheap polyline), not "judge me as I draw" (expensive metric).
- **Calling `path.computeMetrics()` without `.toList()`.** The Flutter API doc explicitly warns: it returns a lazy `Iterable`; calling `.length` traverses it; calling it twice traverses it twice. If we ever need metrics, cache once. [CITED: api.flutter.dev/flutter/dart-ui/Path/computeMetrics.html]
- **Using `flutter_svg` to render the outline.** Overkill — pulls a full SVG renderer to render a single `<path>`. Just parse the path string with `svg_path_parser` and call `canvas.drawPath`.
- **Hand-rolling the gesture detector with `RawGestureDetector` for "higher precision."** Native pointer events on iOS/Android already arrive at touch-screen sample rate (60Hz on iPad Air; 60Hz on most Android tablets; 120Hz on iPad Pro). Flutter's `Listener` widget delivers them unmodified. There is no precision to gain by switching APIs.
- **Authoring a custom JSON schema.** The MMAH schema works. Re-inventing it forces us to also re-invent the parser. Don't.
- **Using a font runtime to render the trace path.** Fonts are for displaying glyphs as text, not for stroke-level pedagogy. The font is a tracing source (we eyeball the centerlines from rendered glyphs) — it's not a runtime asset.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stroke-tolerance matching algorithm | A custom polyline-distance-against-Path matcher | `StrokeOrderAnimationController.checkStroke()` from `stroke_order_animator` | The package's algorithm is exactly what we need: length within bounds (0.2x–3x for short strokes, 0.5x–1.5x for long), start within margin (200/150 px in 1024-space), end within margin, direction matches median orientation. Already calibrated for stylus-on-tablet input. Tunable via `setBrushWidth()` and similar setters. |
| Animated stroke-order ghost | A custom AnimationController + path-drawing animation that renders the ideal stroke as a hint | The package's hint feature (`hintAfterStrokes` parameter, default 3 misses → animated hint plays) | Already implemented. Configurable misses-threshold, color, animation speed. Hugrún will see it after 3 wrong starts. |
| Multi-stroke order enforcement | Per-stroke state machine + "you must do stroke 1 first" UI | Same controller — calls `onCorrectStrokeCallback(strokeIndex)` when the user nails the current stroke; `onWrongStrokeCallback(strokeIndex)` when they miss; never blocks input on wrong-stroke | Soft enforcement is what TRACE-03 requires. The package matches exactly: it just doesn't progress until the right stroke is drawn correctly. The child can keep drawing forever; the activity doesn't fail or reset. |
| SVG path string → Flutter Path | A custom parser for `M`/`L`/`C`/`Z` commands | `svg_path_parser` (transitive dep) | Don't write parsers for standard formats. |
| Per-frame dirty tracking for shouldRepaint | Custom equality on stroke-buffer length | The controller already calls `notifyListeners()` only on actual state change; the package's `CustomPainter.shouldRepaint` already returns false correctly | One-line concern; the package handled it. |
| Picture-caching for static outline | Manual `PictureRecorder` + `Picture` lifecycle | The package internally renders the outline as a path; if perf measurement shows tessellation cost, raise it as an issue against the package, not as a hand-roll | Premature optimization. Measure first. |
| Coordinate system normalization (1024×1024 → tablet pixels) | Custom matrix math | The package handles the transform; we just hand it the JSON | The MMAH coordinate convention is documented and the package's transform is already correct. |

**Key insight:** The Phase 7 work after `stroke_order_animator` adoption is **content authoring + room composition + audio wiring**, not engine building. Treat it like Phase 5 (matching) or Phase 6 (CVC) in terms of complexity, not like Phase 3 (TTS pipeline).

## Runtime State Inventory

> Phase 7 is a greenfield activity addition, not a rename/refactor/migration phase. The
> only persistent state Phase 7 introduces is asset files. There is no Drift schema
> change, no live-service config, no OS-registered state, and no env-var change.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — Phase 7 ships no Drift change. (Optional later: `tracing_completions` table tracking which letters Hugrún has traced; not in this phase per "no scoring" philosophy and per ROADMAP.) | None |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | New asset folder `assets/tracing/` declared in `pubspec.yaml`'s `flutter.assets:` list. flutter_gen_runner regenerates `lib/gen/assets.gen.dart` to expose typed `Assets.tracing.a()` style references — this is a normal codegen step, not stale runtime state. | Add `assets/tracing/` to `pubspec.yaml`; run `dart run build_runner build` |

## Common Pitfalls

### Pitfall 1: Hand-authored JSON misses the right coordinate system

**What goes wrong:** The author works in a regular pixel-down coordinate system (Y increases down), commits 32 JSON files, and at runtime every glyph is upside-down because Make-Me-A-Hanzi uses (0,900) as upper-left.

**Why it happens:** The MMAH coordinate transform `Matrix4(1,0,0,0, 0,-1,0,0, 0,0,1,0, 0,900,0,1)` is in the package source (`stroke_order.dart`, `_parseStrokeOutlines`). It's not in any prominent README. An author who hasn't read the source assumes screen coordinates.

**How to avoid:**
- Author one prototype glyph (recommend the simple 'l' — single vertical stroke) and visually verify it renders right-side-up in the simulator before authoring the other 31.
- Build a small dev-only "trace JSON viewer" widget that renders any of the 32 JSON files standalone, with axis labels. ~30 minutes of work, saves hours of guessing.
- Document the coordinate convention in `lib/mechanics/tracing/stroke_order_json.dart` as a doc comment so future contributors don't repeat the discovery.

**Warning signs:**
- Glyph is upside-down or mirrored.
- Stroke order plays "wrong direction" — the package's `strokeHasRightDirection()` check trips because the median list is reversed in screen space.

### Pitfall 2: Diacritic stroke-order surprises

**What goes wrong:** The dot on 'í' is authored as the first stroke (because it's the highest point on the page); the package then expects the user to tap the dot first. The child draws the body of the 'i' first, gets a "wrong stroke" hint, gets confused.

**Why it happens:** Visual ordering ≠ pedagogical ordering. Briem's Ítalíuskrift teaches body-first, accent-last for **all** diacritic letters (á, é, í, ó, ú, ý, ö). Authors unfamiliar with that convention default to top-down.

**How to avoid:**
- Hard rule in the JSON-authoring step: **diacritic mark is always the last stroke for any accented letter**. Validate with a test: for letters in `{á, é, í, ó, ú, ý, ö}`, assert `strokes.length >= 2` and assert the last median's bounding box is above the second-to-last median's bounding box.
- For ð and þ specifically: ð is body + cross-bar (two strokes), þ is body + bowl (two strokes). The cross-bar / bowl is the second stroke. Don't treat them like Latin 'd' and 'p' (which they're not).

**Warning signs:**
- The child draws the body of 'á' and gets a "wrong stroke" hint.
- Native-speaker reviewer says "that's not how it's taught."

### Pitfall 3: Tolerance is too tight after migrating from package defaults

**What goes wrong:** The plan reads `stroke_order_animator` defaults (200/150-px start-end margin, 0.5–1.5x length range), thinks "those are for Chinese characters drawn in 1024×1024," and tightens them. On Hugrún's tablet they reject every wobbly trace.

**Why it happens:** The defaults are calibrated against native pixel-on-screen for stylus and finger touch on phones. Tightening to "make it more accurate" violates TRACE-02 (50–60% of stroke width) and PITFALL #9 in research/PITFALLS.md (5yo motor skills).

**How to avoid:**
- **Start with package defaults.** Calibrate by sitting Hugrún down with the prototype 'l' glyph and the simplest accented letter ('á') and observing rejections. Loosen, never tighten, from there. Pin the calibrated values as a const map in `tracing_widget.dart`.
- For TRACE-02, "stroke width" is the brush width. Default is 8.0 px in the package. Hugrún's actual tablet target = ≥2 cm × 2 cm tap target convention from STAFIR-01; the brush should look chunky like a crayon (PITFALLS § 9 says ~12–18 px). At brushWidth=18 px, the 50–60% tolerance is 9–11 px on each side — but the package's tolerance is configured as length-range and start-end-margin (in MMAH coordinate space), not "distance from centerline per point." Translate: ensure `setBrushWidth(18)` and `hintAfterStrokes >= 5` for Hugrún's first session, then tune.
- Do not write a custom per-point distance check. The package's algorithm intentionally evaluates only stroke endpoints + length + direction, not per-point distance — that is what makes it forgiving for wobbly hands. Replacing it with a centerline-distance check is a regression.

**Warning signs:**
- Hugrún draws what looks correct and the activity rejects it.
- Calibration session ends with the developer in the loop ("hold on, let me adjust"). Forgiveness > correctness; default to looser.

### Pitfall 4: Activity entry causes a frame stutter while loading 32 JSONs

**What goes wrong:** TracingActivity loads `assets/tracing/{slug}.json` for the current letter on entry. Naively, `rootBundle.loadString(...)` is async; the activity renders empty for one or two frames, then "pops" the glyph in. Feels broken.

**Why it happens:** Flutter assets load lazily; the first call is a real disk read. 32 JSONs at ~1 KB each is tiny but the I/O scheduling is real on cold start.

**How to avoid:**
- Pre-warm the trace data at app start. Add a `traceDataProvider` (Riverpod, app-scoped, eager) that loads all 32 JSONs into a `Map<IcelandicLetter, StrokeOrder>` during app init. Total cost: ~32 KB of JSON parsed once. Same pattern Phase 4's AudioEngine warm-pool uses.
- Loading is synchronous after warm-up: `ref.read(traceDataProvider).requireValue[letter]` returns instantly.

**Warning signs:**
- Trace activity renders empty for >100ms on entry.
- DevTools shows `rootBundle.loadString` calls in the activity's first-frame timeline.

### Pitfall 5: Accent positioning differs between the chosen tracing source and what schools use

**What goes wrong:** The Briem Hand commercial font places the acute on 'á' at a different angle/position than Ítalíuskrift workbooks do. Or the dot on 'í' is centered in the font but offset right in the workbook. Native-speaker reviewer says "this isn't quite right."

**Why it happens:** Briem designed multiple typefaces over decades. Briem Hand (commercial), Briem Operina (commercial chancery italic), Briem Script Std (Microsoft Office bundling), and Italiuskrift05 (1985 free teaching font, in *The Icelandic Method* PDF) are all his work but reflect different design intents. Only Italiuskrift05 was designed specifically for Icelandic primary-school italic instruction.

**How to avoid:**
- Source the tracings from **Italiuskrift05 in the Briem 1985 PDF (free, on Luc Devroye's archive — direct PDF link verified 200 OK, 5 MB)** as the authoritative primary reference. Use the commercial fonts only as supplementary outline sources if Italiuskrift05's PDF rendering is too coarse to trace.
- Have a native-speaker (parent in Hugrún's case) verify each accented glyph against an actual MMS workbook before review-pass sign-off. The MMS *Ítalíuskrift 1A–4A* workbook series (Bergsveinsdóttir & Briem 2011/2013) is the school-classroom canonical reference.
- If the workbook and the font diverge, **the workbook wins** — the workbook is what Hugrún sees in school.

**Warning signs:**
- A diacritic glyph (á / é / í / ó / ú / ý / ö) looks different from the workbook page when held side-by-side.
- Reviewer hesitates on a specific letter.

[VERIFIED PDF availability: `curl -sIL https://luc.devroye.org/Briem1985-IcelandicMethod.pdf` → HTTP 200, 5085292 bytes, application/pdf, last-modified 2009-07-22]

## Code Examples

Verified patterns from `stroke_order_animator` source code and existing Hugrún codebase.

### Loading and instantiating the controller

```dart
// lib/features/stafir/tracing/tracing_activity.dart  (Phase 7, sketch)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroke_order_animator/stroke_order_animator.dart';

class TracingActivity extends ConsumerStatefulWidget {
  const TracingActivity({super.key, required this.letter});
  final IcelandicLetter letter;

  @override
  ConsumerState<TracingActivity> createState() => _TracingActivityState();
}

class _TracingActivityState extends ConsumerState<TracingActivity>
    with TickerProviderStateMixin {
  late StrokeOrderAnimationController _controller;

  @override
  void initState() {
    super.initState();
    final strokeOrder = ref.read(traceDataProvider).requireValue[widget.letter]!;
    _controller = StrokeOrderAnimationController(
      strokeOrder,
      this,
      brushWidth: 18.0,                  // calibrated per PITFALLS § 9
      hintAfterStrokes: 5,               // looser than default 3 for 5yo
      strokeColor: const Color(0xFF6FA8DC),
      brushColor: const Color(0xFF1F4D80),
      onQuizCompleteCallback: _onComplete,
    );
    _controller.startQuiz();             // tracing == quiz mode
  }

  void _onComplete(QuizSummary summary) {
    // TRACE-05: celebration audio with child name
    final clipKey = ref.read(traceCompletionClipProvider(widget.letter));
    ref.read(audioEngineProvider).play(clipKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: StrokeOrderAnimator(_controller),
    );
  }
}
```

[Source: github.com/chill-chinese/stroke-order-animator/blob/main/example/lib/main.dart adapted to Hugrún patterns]

### The tolerance algorithm (for plan-checker reference)

The package's `strokeIsCorrect` is the authoritative tolerance algorithm Phase 7 uses. Pseudocode:

```
strokeIsCorrect(userPoints, currentMedian):
  strokeLength = pathLengthOf(userPoints)
  medianLength = pathLengthOf(currentMedian)

  # Be more lenient on short strokes (< 150 in MMAH 1024-space)
  if medianLength < 150:
    allowedLengthRange = [0.2 * medianLength, 3 * medianLength]
    startEndMargin = 200
  else:
    allowedLengthRange = [0.5 * medianLength, 1.5 * medianLength]
    startEndMargin = 150

  return  strokeLengthWithinBounds(strokeLength, allowedLengthRange)
      AND strokeStartIsWithinMargin(userPoints[0], currentMedian[0], startEndMargin)
      AND strokeEndIsWithinMargin(userPoints[-1], currentMedian[-1], startEndMargin)
      AND strokeHasRightDirection(userPoints, currentMedian)

strokeHasRightDirection(points, median):
  # User start is closer to median start than user end is, AND/OR
  # user end is closer to median end than user start is.
  return  distance(points[0], median[0]) < distance(points[-1], median[0])
      OR  distance(points[-1], median[-1]) < distance(points[0], median[-1])
```

This is **not** Fréchet distance (Hanzi Writer's web JS algorithm). It is a simpler four-check rule. For 5-year-old motor input, simpler is better — Fréchet over a wobbly polyline can produce surprising rejections that the four-check rule sails past.

[Source: github.com/chill-chinese/stroke-order-animator/blob/main/lib/src/stroke_order_animation_controller.dart, methods `strokeIsCorrect`, `getAllowedLengthRange`, `getStartEndMargin`, `strokeHasRightDirection`]

### Asset registration

```yaml
# pubspec.yaml — add to flutter.assets:
flutter:
  uses-material-design: true
  assets:
    - assets/audio/letters/names/
    - assets/audio/letters/words/
    - assets/audio/letters/phonemes/
    - assets/audio/numbers/masculine/
    - assets/audio/numbers/feminine/
    - assets/audio/numbers/neuter/
    - assets/audio/narration/
    - assets/images/letters/words/
    - assets/images/numbers/
    - assets/images/ui/
    - assets/tracing/                  # NEW Phase 7
```

After adding, run `dart run build_runner build --delete-conflicting-outputs` so flutter_gen_runner emits typed references in `lib/gen/assets.gen.dart`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-build a CustomPainter from scratch (per ARCHITECTURE.md draft + STACK.md "CustomPainter for tracing" notes) | Use `stroke_order_animator` package — glyph-agnostic, MMAH-format JSON consumer | Package published 2024-Q3, current 3.3.1 (Jul 2025) | Phase 7 turns into a content-authoring + integration phase, not engine-building. Estimated savings: 1–2 days of engineering work. |
| Skia rendering on Android | Impeller default on Android API 29+ (Flutter 3.27+) | 2025 | Stroke perf is now Vulkan-backed on Android; #143077 (path tessellation) only affects hundreds-of-paths-per-frame scenarios, not Phase 7's 5-paths-per-frame ceiling |
| Skia path stroke (intermediate polyline conversion) | Direct curve iteration in Impeller (#167422) | Flutter 3.32+, April 2025 merge | ~1.37x rasterizer improvement for stroked paths. Inherited automatically since Hugrún is on 3.41.5. |
| Fréchet distance + Procrustes (Hanzi Writer / curve-matcher in JS) | Simpler four-check rule (length + start + end + direction) in `stroke_order_animator` | 2024 design choice in the Flutter port | Forgiving for child motor input; deterministic; cheap (no Procrustes rotation search) |

**Deprecated/outdated:**
- `flutter_path_drawing` is maintained but its original author (Dan Field) passed in 2024; for Phase 7 needs `svg_path_parser` (which is `stroke_order_animator`'s transitive dep) is sufficient and we do not need `flutter_path_drawing` directly.
- The 36-letter Icelandic alphabet (with C/Q/W/Z) is pre-1980; modern is 32 letters. Phase 2's `kIcelandicAlphabet` already encodes this; Phase 7 inherits it.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Briem's commercial fonts (Briem Hand, Briem Script Std, Briem Operina) include all 32 Icelandic accented lowercase glyphs (á ð é í ó ú ý þ æ ö specifically) | Q1 / Standard Stack alternatives | Tracing source falls back to the free Italiuskrift05 PDF, which provably does include them. Adds maybe a half-day of effort tracing rasterized PDF instead of font outlines. **Mitigation:** verify in licensing/discuss-phase before purchasing any commercial font. |
| A2 | 60Hz pointer events from native iPad and Pixel Tablet hardware are sufficient for 5yo motor input | Q3 / Architectural Responsibility Map | Worst case: child's hand outpaces sample rate; trace looks slightly jagged. Solvable with `PointerEventResampler` (built-in Flutter API). Not worth pre-optimizing. |
| A3 | The "5–60% of stroke width" tolerance from TRACE-02 and PITFALLS § 9 maps to the package's start-end-margin parameter (150/200 px in MMAH 1024-space) | Q4 / Common Pitfalls § 3 | The mapping is approximate; actual calibration is a Phase 7 plan task with Hugrún at the tablet. Risk is low because the calibration is the explicit work, not an assumption that drives a design choice. |
| A4 | Hugrún's tablet specifications (model, OS, screen DPI) are in the same class as iPad Air / Pixel Tablet / Galaxy Tab A8, all of which run Impeller | Q3 | If Hugrún has an old Android tablet (API <29), Impeller falls back to OpenGL on that device specifically — `stroke_order_animator` still works; perf may be 2-3x slower but Phase 7's ~5-path ceiling has plenty of headroom. **Mitigation:** verify her tablet model in discuss-phase. |
| A5 | Diacritic-as-last-stroke is the universal Briem convention for all 7 accented Icelandic lowercase letters (á é í ó ú ý ö) and ö in particular | Q2 / Common Pitfalls § 2 | If a specific MMS workbook teaches a different order for any letter, JSON authoring follows the workbook (per Pitfall 5). Adds per-letter native-speaker review time. |
| A6 | Make-Me-A-Hanzi's 1024×1024-with-Y-flipped coordinate space is fine for hand-authored Latin glyphs | Pattern 1 | None — the schema is geometry only; it doesn't care about glyph origin. |
| A7 | The stroke_order_animator package will not be deprecated or abandoned mid-project (3.3.1 is current; org `chill-chinese` actively maintains it) | Standard Stack | Standard package risk. The package is BSD-3-Clause; if abandoned we can fork. Source is ~600 lines of Dart — trivial to vendor in. |

## Open Questions

1. **Briem font commercial license: does it cover hand-tracing for derived asset bundles?**
   - What we know: the Briem website permits use "for scholarship, research and your own personal uses only." That's narrower than "use in a commercial product." Briem Hand (Sorkin Type Co), Briem Script Std (Monotype), Briem Operina (P22) are licensed via standard font foundry EULAs.
   - What's unclear: whether a font EULA covers "use the rendered glyph as visual reference to hand-author centerline polyline data." Most font EULAs cover the font *binary* and *embedded use*, not derivative shape extraction.
   - Recommendation: **route through the free Italiuskrift05 from Briem's 1985 PDF as the authoritative reference.** That PDF is permitted for personal use, and Hugrún's app currently is one. Public-release legal review (deferred to v2 per ROADMAP) can re-evaluate.

2. **Hugrún's actual tablet model and OS version**
   - What we know: PROJECT.md says "Hugrún's tablet is the test device" but specifies neither model nor OS.
   - What's unclear: iPad Air (Impeller/Metal), Pixel Tablet (Impeller/Vulkan), Galaxy Tab A (older Android, possibly OpenGL fallback), or something else?
   - Recommendation: **answered in discuss-phase before plan execution.** Affects only Pitfall 4 / Pitfall #3 calibration; doesn't change the architecture.

3. **Calibrated tolerance values that satisfy TRACE-02**
   - What we know: package defaults are 200/150 px start-end-margin in MMAH 1024-space, length range 0.5–1.5x for long strokes.
   - What's unclear: the exact pinned values that yield 50–60%-of-stroke-width on Hugrún's actual screen.
   - Recommendation: **dedicated Phase 7 plan task** with Hugrún at the tablet. Pin values in `lib/mechanics/tracing/tolerance_constants.dart` and unit-test them. Listed as success criterion #2 in ROADMAP § Phase 7.

4. **Should `tracing_completions` Drift table land in Phase 7?**
   - What we know: ROADMAP says no scoring; PROJECT.md says no progress indicators. But internal "session continuity" (don't replay celebration on instant re-entry) might want minimal state.
   - What's unclear: whether the no-fail philosophy extends to "no completion memory" or just "no externally-visible scoring."
   - Recommendation: **defer to discuss-phase.** Default position: don't add a table. Re-entering an activity replays celebration; the "downside" (a kid hearing the celebration twice) is mild and matches the no-stake feel. Add the table only if Hugrún herself is bothered by it.

5. **Brush rendering width ≠ tolerance width — which TRACE-02 measures**
   - What we know: TRACE-02 says tolerance is "~50–60% of stroke width on each side," tying tolerance to brush width.
   - What's unclear: stroke_order_animator's `brushWidth` (visual rendering only) is not used in `strokeIsCorrect` — that uses MMAH-coordinate-space margins.
   - Recommendation: in the Phase 7 plan, **decouple TRACE-02's "stroke width" from the visual `brushWidth`.** The acceptance criterion is the calibrated start-end-margin and length range against Hugrún's drawing. Document the mapping: visual brushWidth=18 logical px ≈ start-end-margin of 150–200 in MMAH space. If discuss-phase finds this is a problem, we can layer a custom per-frame distance-from-centerline tolerance check on top of the package — but only if the package's algorithm proves insufficient in calibration.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK 3.41.5 | Phase 7 build | ✓ | 3.41.5 (per pubspec env `^3.11.5` Dart, Flutter pinned via fvm) | — |
| Dart >=3.2 | stroke_order_animator pub constraint | ✓ | 3.11+ | — |
| pub.dev access | Adding `stroke_order_animator` | ✓ | — | Vendor source (~600 lines, BSD-3-Clause) if registry unavailable |
| Internet at build time | Initial `pub get` | ✓ | — | Once-fetched, lockfile pins version offline |
| Internet at runtime | None — Phase 7 has zero network calls | n/a | — | n/a (FOUND-10 invariant maintained) |
| Briem 1985 *Icelandic Method* PDF | Tracing reference for Italiuskrift05 | ✓ | 5.0 MB at luc.devroye.org/Briem1985-IcelandicMethod.pdf (HTTP 200 verified 2026-05-02) | Briem.net free e-books page (multiple Briem teaching materials); MMS workbook *Ítalíuskrift 1A* via interlibrary loan or local Icelandic bookshop |
| MMS workbook *Ítalíuskrift 1A–4A* (Bergsveinsdóttir & Briem 2011/2013) | Native-speaker reviewer cross-check | unverified | 4-volume workbook series, ISBN per MMS catalog | Available from MMS; in-Iceland bookshops; school libraries — physically obtainable. **Mitigation:** if not available before plan execution, fall back to the 1985 PDF as primary reference. |
| Designer with vector-tracing tooling (Inkscape, Illustrator, Figma) | Hand-authoring 32 JSON files | varies | — | Can be done in any text editor + visual JSON viewer; tracing-by-eye in a browser SVG editor is sufficient |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:**
- MMS workbook physical copy — fallback to PDF is fine for Phase 7's hand-authoring; reviewer cross-check can use the workbook later.

## Validation Architecture

> nyquist_validation = true per .planning/config.json. Section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test 3.41.5 (existing) + integration_test (existing) + Marionette E2E (existing per FOUND-07) |
| Config file | None for `flutter_test` (default discovery via `test/` folder) |
| Quick run command | `flutter test` |
| Full suite command | `flutter test && flutter test integration_test/` |

Existing harness verified by reading the project root: `test/`, `integration_test/`, `marionette/` directories all present.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRACE-01 | All 32 lowercase Ítalíuskrift letterforms load and produce a valid `StrokeOrder` | unit | `flutter test test/features/stafir/tracing/trace_data_loader_test.dart` | Wave 0 |
| TRACE-01 | `StrokeOrderAnimator` widget renders for each letter; one-tap shows correct first-stroke ghost | widget | `flutter test test/features/stafir/tracing/tracing_activity_widget_test.dart` | Wave 0 |
| TRACE-02 | Calibrated tolerance constants (length range, start-end margin, brush width) match expected MMAH-space values; mid-stroke tolerance behaves per pinned spec | unit | `flutter test test/mechanics/tracing/tolerance_constants_test.dart` | Wave 0 |
| TRACE-02 | Latency-style human verify: tolerance feels right on Hugrún's tablet (per LATENCY-VERIFICATION.md template from Phase 4) | manual-only | n/a | Wave N (calibration plan task) |
| TRACE-03 | Wrong-stroke-first triggers `onWrongStrokeCallback` after `hintAfterStrokes` misses; no input is rejected; activity continues to accept further strokes | widget | `flutter test test/features/stafir/tracing/tracing_soft_order_test.dart` | Wave 0 |
| TRACE-04 | No timer fires; pause + resume preserves controller state; navigating away and back does not reset progress | integration | `flutter test integration_test/tracing_no_fail_test.dart` | Wave 0 |
| TRACE-05 | On `onQuizCompleteCallback`, AudioEngine plays the name-aware celebration clip when one exists for the active child name; falls back to the generic clip otherwise | widget+integration | `flutter test test/features/stafir/tracing/trace_completion_handler_test.dart` | Wave 0 |
| TRACE-05 | E2E: open Stafir → switch to trace mode → trace 'h' end-to-end → celebration plays | E2E | Marionette flow (see Phase 4 E2E pattern) | Wave 0 |
| All | Diacritic letters have ≥2 strokes and the last stroke median is above the previous (Pitfall §2) | unit | `flutter test test/features/stafir/tracing/diacritic_stroke_order_test.dart` | Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test` (skips `integration_test/`)
- **Per wave merge:** `flutter test && flutter test integration_test/`
- **Phase gate:** Full suite green + Marionette flow + manual TRACE-02 calibration sign-off via human-verify checkpoint (see Phase 4 LATENCY-VERIFICATION.md as template) before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/features/stafir/tracing/trace_data_loader_test.dart` — covers TRACE-01
- [ ] `test/features/stafir/tracing/tracing_activity_widget_test.dart` — covers TRACE-01 (widget level)
- [ ] `test/mechanics/tracing/tolerance_constants_test.dart` — covers TRACE-02
- [ ] `test/features/stafir/tracing/tracing_soft_order_test.dart` — covers TRACE-03
- [ ] `integration_test/tracing_no_fail_test.dart` — covers TRACE-04
- [ ] `test/features/stafir/tracing/trace_completion_handler_test.dart` — covers TRACE-05
- [ ] `test/features/stafir/tracing/diacritic_stroke_order_test.dart` — covers cross-cutting Pitfall §2
- [ ] `assets/tracing/*.json` (32 files, hand-authored) — Phase 7 content task
- [ ] `marionette/scenarios/tracing_smoke.yaml` (or equivalent) — E2E scenario, modeled on Phase 4's existing Marionette scenario
- [ ] `.planning/phases/07-letter-tracing-italiuskrift/CALIBRATION.md` — TRACE-02 human-verify procedure (modeled on Phase 4's `LATENCY-VERIFICATION.md`)

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRACE-01 | Letter tracing activity in Stafir room uses the Ítalíuskrift lowercase letterforms for all 32 letters | Q1 sourcing path (Italiuskrift05 PDF + optional commercial fonts) + Q2 stroke-data-model recommendation (Make-Me-A-Hanzi JSON) + Pattern 1 example. 32 hand-authored JSON files in `assets/tracing/`. |
| TRACE-02 | Tracing tolerance is ~50–60% of stroke width on each side (calibrated on Hugrún's tablet) | Q4 tolerance algorithm pseudocode + Common Pitfalls §3 + Open Questions §3 + §5 (decoupling brush width from tolerance margin) + Wave 0 test `tolerance_constants_test.dart` |
| TRACE-03 | Stroke order is enforced softly — wrong-stroke starts produce a visual hint (faded ghost), never a hard rejection | Don't-Hand-Roll § "Animated stroke-order ghost" — package's `hintAfterStrokes` parameter handles this exactly. Soft-order is the package's default behavior; never blocks input. |
| TRACE-04 | Letter tracing has no failure state, no timer; child can stop and resume freely | Architectural Responsibility Map § "Persistence" + Q5 soft-order UX. Activity carries no timer; navigation away does not destroy controller (held by a Riverpod activity-scoped provider that re-creates fresh state on re-entry, identical to no-progress). |
| TRACE-05 | On completion, tracing plays a celebration animation including the child's name in the voice-over | Code Examples § "Loading and instantiating the controller" — `onQuizCompleteCallback` wires to existing Phase 4 AudioEngine + childNameProvider mechanism. PERS-03's name-aware-fallback pattern is reused. |

## Project Constraints (from CLAUDE.md)

- **Tech stack — Flutter**: Phase 7 stays in Flutter, no native bridges. ✓
- **State management — Riverpod**: TracingActivity uses `@riverpod` codegen pattern (existing in Phase 4 `audio_engine_provider.g.dart`). ✓
- **Persistence — Drift (SQLite)**: Phase 7 introduces no schema change; Drift untouched. ✓
- **Audio runtime — `just_audio` + `Ticker`**: Celebration audio uses existing AudioEngine with no new players. ✓
- **Animation — CustomPainter for tracing (deferred to post-MVP)**: Phase 7 is post-MVP. Uses `stroke_order_animator`'s internal CustomPainter; we do not write a new one. Falls under the spirit of CONSTRAINTS § "CustomPainter for tracing" — the package's painter is what we adopt. ✓
- **Testing — TDD with Marionette for E2E**: Wave 0 lists all required test files before implementation. Marionette scenario added per FOUND-07 pattern. ✓
- **Privacy / safety**: No ads, no IAP, no analytics SDKs, no network calls during play, no accounts, no cloud, no sync. Phase 7 introduces zero network surface; tracing JSON is fully offline. ✓ [VERIFIED: stroke_order_animator's example imports `http` for online MMAH lookup; **we do NOT use that path** — we hand-author offline JSONs and load from `rootBundle` only.]
- **Audio quality**: Celebration clips inherit Phase 3's loudness-normalized -19 LUFS / -1 dBTP pipeline. Phase 7 plan adds new clip names to manifest.yaml; pipeline re-bake required (matches Phase 6 D-20 protocol). ✓
- **Child UX bars**: Tap response < ~50ms — pointer-event sampling is native, brush rendering happens within the package's CustomPainter. No fail states (TRACE-03/04). No timers (TRACE-04). No scores. No text instructions. ✓
- **CLAUDE.md § "GSD Workflow Enforcement"**: All file edits go through GSD commands. This research is via `/gsd-research-phase`. ✓
- **STACK.md "Don't sample distance per-frame"**: Honored — package uses `onPanEnd` evaluation, not per-frame. ✓
- **STACK.md "RepaintBoundary around tracing canvas"**: Honored in code example. ✓
- **STACK.md "no analytics, no go_router, no just_audio_background"**: Phase 7 adds none. ✓

## Implementation Effort Estimate

| Task | Type | Estimate | Notes |
|------|------|----------|-------|
| Author 32 JSON glyphs (Ítalíuskrift lowercase) | Content | **1.5–2 days** for one author with vector tracing tools, working from Italiuskrift05 PDF | Trace each glyph in Inkscape/Figma → export median polyline + outline path → hand-edit JSON. Native-speaker review cross-check adds 0.5 day. |
| Wave 0 test scaffolding (8 test files + Marionette scenario) | Test scaffolding | 0.5 day | Mostly skeletons; tests stay red until implementation lands per TDD |
| `traceDataProvider` + asset bundle wiring | Code | 0.5 day | Riverpod app-scoped provider; load 32 JSONs at warm-up |
| `TracingActivity` widget + `RepaintBoundary` + controller lifecycle | Code | 0.5 day | Sketch in Code Examples; ~150 lines |
| Stafir mode toggle expansion (3 → 4 modes) | Code | 0.25 day | Mirror Phase 6 D-15 expansion pattern |
| Celebration clip authoring (TTS pipeline rerun) | Audio pipeline | 0.5 day | New name-aware narration clips per child name; standard Phase 3 protocol |
| Tolerance calibration with Hugrún | Calibration session | 0.5 day | Sit with Hugrún at the tablet; iterate; pin constants |
| Marionette E2E + LATENCY-VERIFICATION-style human verify | Verification | 0.25 day | Modeled on Phase 4 |
| **Total** | | **~5 days** for solo build | Compares to ~7 days if hand-rolling the engine. The package adoption saves ~2 days net. |

The dominant cost is glyph authoring (1.5–2 days). Everything else is integration on patterns Hugrún has already established in Phases 1–6.

## Sources

### Primary (HIGH confidence)

- [pub.dev/packages/stroke_order_animator](https://pub.dev/packages/stroke_order_animator) — package latest 3.3.1, BSD-3-Clause, sdk constraint `>=3.2.0 <4.0.0`. Verified via pub.dev API JSON 2026-05-02.
- [github.com/chill-chinese/stroke-order-animator](https://github.com/chill-chinese/stroke-order-animator) — `lib/src/stroke_order.dart`, `lib/src/stroke_order_animation_controller.dart`, README, `example/lib/main.dart`. Tolerance algorithm read directly from source.
- [github.com/skishore/makemeahanzi](https://github.com/skishore/makemeahanzi) — Make-Me-A-Hanzi data schema (`strokes`, `medians`, `radStrokes`); coordinate convention 1024×1024 with (0,900) upper-left.
- [primarium.info/handwriting-models/italiuskrift](https://primarium.info/handwriting-models/italiuskrift/) — Ítalíuskrift overview, MMS authority, 2013 publication, lowercase + uppercase + connected/unconnected letterforms, exit strokes
- [luc.devroye.org/fonts-51826.html](https://luc.devroye.org/fonts-51826.html) — *The Icelandic Method* (Briem 1985), Italiuskrift05 / BriemAnvil06 / BriemAnvilSans07 fonts, free PDF distribution since 1985
- [luc.devroye.org/Briem1985-IcelandicMethod.pdf](https://luc.devroye.org/Briem1985-IcelandicMethod.pdf) — direct PDF download, HTTP 200 verified 2026-05-02, 5.0 MB
- [briem.net](https://www.briem.net/) — Briem's homepage, "Free books" + "Free teaching aids" sections; license: download for "scholarship, research and your own personal uses only"
- [docs.flutter.dev/perf/impeller](https://docs.flutter.dev/perf/impeller) — Impeller default on iOS, default on Android API 29+, OpenGL fallback below
- [github.com/flutter/flutter/pull/167422](https://github.com/flutter/flutter/pull/167422) — April 25 2025 merged stroke-pipeline rewrite, 1.37x rasterizer improvement
- [api.flutter.dev/flutter/dart-ui/Path/computeMetrics.html](https://api.flutter.dev/flutter/dart-ui/Path/computeMetrics.html) — official caching guidance
- [api.flutter.dev/flutter/widgets/RepaintBoundary-class.html](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html) — official docs
- [.planning/research/PITFALLS.md § Pitfall 9](file:///Users/jonb/Projects/hugrun/.planning/research/PITFALLS.md) — tracing tolerance research, 5yo motor research, 50–60%-of-stroke-width recommendation
- [.planning/research/FEATURES.md § Letter tracing](file:///Users/jonb/Projects/hugrun/.planning/research/FEATURES.md) — stroke order ghost timing, off-path UX, completion celebration
- [.planning/research/STACK.md § CustomPainter for tracing](file:///Users/jonb/Projects/hugrun/.planning/research/STACK.md) — "Don't compute distance per-frame," RepaintBoundary, Picture caching guidance

### Secondary (MEDIUM confidence)

- [github.com/flutter/flutter/issues/143077](https://github.com/flutter/flutter/issues/143077) — open umbrella issue on Impeller path tessellation perf; only relevant at hundreds-of-paths-per-frame scale
- [chanind.github.io/2019/03/15/shape-matching-in-javascript.html](https://chanind.github.io/2019/03/15/shape-matching-in-javascript.html) — Hanzi Writer (JS) Fréchet+Procrustes algorithm; informative for understanding the alternative
- [hanziwriter.org/docs.html](https://hanziwriter.org/docs.html) — `leniency` parameter (JS port), `showHintAfterMisses` default 3
- [pub.dev/packages/svg_path_parser](https://pub.dev/packages/svg_path_parser) — version 1.1.2 verified

### Tertiary (LOW confidence / requires live verification)

- Briem commercial font Icelandic-glyph completeness (A1 in Assumptions Log) — requires opening the actual TTF/OTF file to verify
- Hugrún's actual tablet model (A4) — requires asking the parent/builder
- Whether commercial Briem font EULAs cover hand-tracing-derived asset use (Open Question §1) — requires legal review for commercial release

## Metadata

**Confidence breakdown:**
- Standard stack (`stroke_order_animator` adoption): HIGH — verified via pub.dev API + source read
- Architecture (room composition, asset folder, Riverpod scoping): HIGH — mirrors existing Phase 4–6 patterns in the codebase
- Pitfalls: HIGH — anchored to package source (coordinate space, tolerance algorithm) and existing project research (5yo motor)
- Q1 sourcing (Ítalíuskrift): HIGH on free PDF availability (verified 200 OK), MEDIUM on whether commercial font EULAs accommodate hand-tracing
- Q2 stroke order data model: HIGH — package's schema is the model
- Q3 perf: HIGH for the 5-paths-per-frame case relevant here, with concrete cite to PR #167422
- Q4 tolerance algorithm: HIGH — read directly from package source
- Q5 soft stroke-order UX: HIGH — package implements exactly the "soft hint after N misses, never reject" pattern PROJECT.md and PITFALLS.md call for

**Research date:** 2026-05-02
**Valid until:** 2026-06-01 (30 days; stable libraries, slow-moving Icelandic education materials, no signals of stroke_order_animator deprecation)
