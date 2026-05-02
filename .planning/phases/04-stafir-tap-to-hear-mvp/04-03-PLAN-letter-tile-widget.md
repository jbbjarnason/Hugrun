---
phase: 04-stafir-tap-to-hear-mvp
plan: 03
type: execute
wave: 2
depends_on:
  - 04-01
files_modified:
  - lib/features/stafir/widgets/letter_tile.dart
  - lib/features/stafir/widgets/letter_tile_palette.dart
  - test/features/stafir/widgets/letter_tile_test.dart
  - test/features/stafir/widgets/letter_tile_palette_test.dart
autonomous: true
requirements:
  - STAFIR-01  # tap target ≥2cm × 2cm physical
  - STAFIR-06  # visual feedback fires synchronously with tap, independent of audio
  - STAFIR-07  # no failure states / no scores
  - STAFIR-08  # zero text instructions visible to child
tags:
  - flutter
  - widget
  - phase-4

must_haves:
  truths:
    - "LetterTile renders the letter glyph centered, large, with a kid-friendly sans-serif font (SF Pro / Roboto rounded fallback per D-30)"
    - "LetterTile tap target measures ≥2 cm × 2 cm physical at the device's reported DPI"
    - "Tapping a LetterTile fires onTapDown synchronously (NOT onTap which waits for tap-up); the scale animation starts on the SAME frame as the gesture"
    - "Pastel color rotation is deterministic — same letter index always gets the same palette color"
    - "Re-tapping the tile does not show a 'selected' state — animation always returns to neutral"
    - "LetterTile shows NO text instructions (only the single glyph) — this is the STAFIR-08 contract"
    - "LetterTile contains NO failure-state UI — no red border, no shake animation, no error indicator"
  artifacts:
    - path: "lib/features/stafir/widgets/letter_tile.dart"
      provides: "LetterTile stateless widget with glyph + tap handler + scale animation"
      min_lines: 80
    - path: "lib/features/stafir/widgets/letter_tile_palette.dart"
      provides: "Locked 6-color pastel palette + paletteForIndex(int) -> Color (pure function)"
      min_lines: 30
    - path: "test/features/stafir/widgets/letter_tile_test.dart"
      provides: "Widget tests for tap target dimensions, onTapDown wiring, scale animation, no-failure-state assertions"
      min_lines: 60
  key_links:
    - from: "lib/features/stafir/widgets/letter_tile.dart"
      to: "lib/core/alphabet/icelandic_letter.dart"
      via: "LetterTile receives an IcelandicLetter and renders letter.glyph"
      pattern: "letter\\.glyph"
    - from: "lib/features/stafir/widgets/letter_tile.dart"
      to: "onTapDown handler exposed via callback"
      via: "GestureDetector(onTapDown: ...) — NOT onTap"
      pattern: "onTapDown"
    - from: "lib/features/stafir/widgets/letter_tile.dart"
      to: "lib/features/stafir/widgets/letter_tile_palette.dart"
      via: "paletteForIndex(letterIndex)"
      pattern: "paletteForIndex"
---

<objective>
Build the visual primitive that owns the tap-to-hear interaction at the leaf level. LetterTile is a single-letter card: pastel background, large glyph, scale animation on tap-down, NO text labels, NO failure UI, NO score/selected state.

This plan does NOT yet wire LetterTile to AudioEngine — that's Plan 04 (StafirRoom composes the grid and connects taps to AudioEngine). LetterTile in this plan is a "dumb" leaf widget that takes a callback (`onLetterTap: (IcelandicLetter) => void`) and triggers it on `onTapDown`.

Why split this way: LetterTile is the smallest unit testable in isolation (no Riverpod, no AudioEngine, no async). Plan 04 wires it up. Decoupling lets us hit STAFIR-01 (tap target size) and STAFIR-06 (synchronous visual feedback) in dedicated widget tests before the audio side touches it.

Purpose:
- STAFIR-01: tap target ≥2cm × 2cm physical, asserted by widget test computing physical size from logical width × DPR ÷ logicalPxPerCm.
- STAFIR-06: scale animation starts on `onTapDown`, NOT `onTap`. PITFALLS #4 visual-feedback-fires-synchronous rule. (This is why the test must verify `onTapDown` is wired, not `onTap`.)
- STAFIR-07: no fail UI exists in the widget tree.
- STAFIR-08: only one Text widget (the glyph). Tested.

Output: A reusable LetterTile + locked pastel palette ready for StafirRoom to consume.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md

@.planning/phases/04-stafir-tap-to-hear-mvp/04-CONTEXT.md
@.planning/phases/01-skeleton-drift-schema/01-SUMMARY.md
@.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-SUMMARY.md

@.planning/research/PITFALLS.md

@lib/core/alphabet/alphabet.dart
@lib/core/alphabet/icelandic_letter.dart
@integration_test/marionette_smoke_test.dart

<interfaces>
<!-- Carry-forward from Phase 2. -->

From lib/core/alphabet/icelandic_letter.dart:
```dart
@freezed
abstract class IcelandicLetter with _$IcelandicLetter {
  const factory IcelandicLetter({
    required String glyph,    // 'a', 'á', 'ð', 'þ', etc.
    required String name,     // 'a', 'eð', 'þorn', etc. — NEVER displayed (STAFIR-08)
    required String assetSlug, // 'a', 'eth', 'thorn', etc.
  }) = _IcelandicLetter;
}
```

Plan 01 marionette_smoke_test.dart established the physical-dimension test pattern:
```dart
final view = tester.view;
final dpr = view.devicePixelRatio;
const logicalPxPerCm = 96.0 / 2.54; // ≈ 37.8
final physicalCm = stafirSize.width / logicalPxPerCm * dpr / dpr;
// Note: dpr cancels in Flutter's coordinate system; emit for diagnostics.
```
For LetterTile tests we'll use the same idiom but assert against the
≥2 cm threshold instead of just diagnosing.
</interfaces>

<reference_decisions>
- D-09: StafirRoom is a single grid showing 32 letters in MMS order. Tap target ≥2cm × 2cm physical. Use MediaQuery.devicePixelRatio + size to compute physical size (Plan 04 owns the grid math; Plan 03 owns the per-tile size constraint).
- D-10: LetterTile at lib/features/stafir/widgets/letter_tile.dart. Displays glyph (large, sans-serif, kid-friendly font), background color (pastel, rotates by index, locked palette). Tap handler triggers AudioEngine.play + scale animation on onTapDown.
- D-11: Background image / mascot — defer to UI-SPEC (out of Phase 4 scope per D-30); white background is the default.
- D-13: NO selected state on the letter tile after tap. Anti-feature: progress tracking, "stars on letters seen", anything score-like.
- D-30: SF Pro / Roboto rounded for letter glyph; 6-color pastel rotation locked palette; 200ms ease-out scale animation on tap; white background.
</reference_decisions>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — write failing tests for LetterTile + palette</name>
  <files>
    test/features/stafir/widgets/letter_tile_palette_test.dart,
    test/features/stafir/widgets/letter_tile_test.dart
  </files>
  <behavior>
    test/features/stafir/widgets/letter_tile_palette_test.dart (pure unit, no Flutter widget):
    - "kLetterTilePalette has exactly 6 colors" (D-30)
    - "kLetterTilePalette colors are all pastels — saturation between 0.20 and 0.45" — assert HSLColor.saturation is in [0.20, 0.45] for each
    - "paletteForIndex is deterministic — same index always returns same color"
    - "paletteForIndex(0) != paletteForIndex(1) != paletteForIndex(2) != paletteForIndex(3) != paletteForIndex(4) != paletteForIndex(5)" (all six distinct)
    - "paletteForIndex wraps mod 6 — paletteForIndex(6) == paletteForIndex(0)"

    test/features/stafir/widgets/letter_tile_test.dart (widget tests):
    - "LetterTile renders the letter glyph as a single Text widget" — `find.text('a')` for IcelandicLetter.glyph='a' returns exactly 1 widget
    - "LetterTile renders NO other text — only the glyph" — count Text widgets in subtree == 1 (STAFIR-08 invariant)
    - "LetterTile has no Icon widget that would imply 'wrong/right'" — `find.byIcon(Icons.error)`, `find.byIcon(Icons.check)`, `find.byIcon(Icons.close)` all findsNothing (STAFIR-07 invariant)
    - "LetterTile tap target is ≥200 logical px wide AND ≥200 logical px tall when given an unbounded constraint" — pump in a 800×600 SizedBox, assert tester.getSize(find.byType(LetterTile)).width >= 200, .height >= 200. Note: 200 logical px at typical tablet DPI (~264 dpi @ DPR 2) ≈ 3.85 cm physical, well above 2 cm — see marionette_smoke_test for the conversion.
    - "LetterTile fires onLetterTap with the supplied IcelandicLetter on tap-DOWN" — use TestPointer or tester.startGesture; assert callback called BEFORE the gesture is released. Specifically: `tester.startGesture(center)` then `await tester.pump(Duration(milliseconds: 1))` and assert callback fired; THEN release.
    - "LetterTile applies the correct palette color for its index" — pump tile with letterIndex=0; find the Container/DecoratedBox; assert decoration.color == paletteForIndex(0).
    - "LetterTile does not show a 'selected' visual state after tap" — tap, pumpAndSettle past the 200ms animation, assert the BoxDecoration / Container color is the same as before tap (D-13).
    - "Scale animation is 200ms ease-out" — pump tile, tap, then pump 100ms (mid-animation), assert the AnimatedScale (or AnimatedBuilder) Transform.scale is between 0.9 and 1.0 (animation in progress); pump another 200ms, assert scale == 1.0 (settled).

    For the "tap target ≥2cm physical" test, accept the 200-logical-px floor as the proxy and add a diagnostic that prints the physical dimension at the test's reported DPR. The marionette_smoke_test already follows this pattern.
  </behavior>
  <action>
    Write the two failing test files. Tests should fail with:
    - `paletteForIndex` undefined (palette file doesn't exist)
    - `LetterTile` undefined (widget file doesn't exist)

    Atomic commit: `test(04-03): add failing tests for LetterTile + 6-color pastel palette`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test test/features/stafir/ 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    - 13+ new failing tests (5 palette + 8 LetterTile)
    - Pre-existing tests still pass
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — implement palette + LetterTile</name>
  <files>
    lib/features/stafir/widgets/letter_tile_palette.dart,
    lib/features/stafir/widgets/letter_tile.dart
  </files>
  <action>
    1. `lib/features/stafir/widgets/letter_tile_palette.dart`:
       ```dart
       import 'package:flutter/material.dart';

       /// 6-color pastel rotation locked palette per D-30.
       /// Saturations chosen in [0.20, 0.45] for soft pastel feel; lightness
       /// near 0.85 so the dark letter glyph reads cleanly on top.
       /// Hues spread across the wheel: red-orange, yellow, green, teal,
       /// blue, lavender. Order is locked — changing it visually shifts
       /// every tile across the alphabet.
       const List&lt;Color&gt; kLetterTilePalette = &lt;Color&gt;[
         Color(0xFFFFD8C2), // soft peach
         Color(0xFFFFF1B8), // soft butter
         Color(0xFFC8EBC9), // soft mint
         Color(0xFFB8E2E8), // soft sky-teal
         Color(0xFFC8D6F0), // soft periwinkle
         Color(0xFFE5CCEB), // soft lavender
       ];

       /// Pure function. paletteForIndex(i) wraps modulo 6.
       Color paletteForIndex(int letterIndex) =>
           kLetterTilePalette[letterIndex.abs() % kLetterTilePalette.length];
       ```
       Verify each color satisfies HSL saturation in [0.20, 0.45] (the test asserts this; pick adjustments if needed).

    2. `lib/features/stafir/widgets/letter_tile.dart`:
       ```dart
       import 'package:flutter/material.dart';
       import 'package:hugrun/core/alphabet/icelandic_letter.dart';
       import 'letter_tile_palette.dart';

       /// A single tappable letter card. Phase 4 D-10.
       ///
       /// Contracts (STAFIR-06, -07, -08):
       /// - Visual feedback (scale animation) fires on onTapDown — NOT onTap —
       ///   so the child sees a reaction the same frame the gesture is
       ///   detected, independent of audio readiness.
       /// - Renders ONLY the letter glyph as text. Zero instructions, zero
       ///   labels, zero error/success icons. STAFIR-07 + STAFIR-08.
       /// - Returns to neutral after the 200 ms ease-out animation; no
       ///   "selected" state retained (D-13).
       class LetterTile extends StatefulWidget {
         const LetterTile({
           super.key,
           required this.letter,
           required this.letterIndex,
           required this.onLetterTap,
           this.minSize = 200, // logical px; ≥2 cm physical at typical tablet DPR (D-09)
         });

         final IcelandicLetter letter;
         final int letterIndex;
         final ValueChanged&lt;IcelandicLetter&gt; onLetterTap;
         final double minSize;

         @override
         State&lt;LetterTile&gt; createState() =&gt; _LetterTileState();
       }

       class _LetterTileState extends State&lt;LetterTile&gt; with SingleTickerProviderStateMixin {
         late final AnimationController _scaleCtl;
         late final Animation&lt;double&gt; _scale;

         @override
         void initState() {
           super.initState();
           _scaleCtl = AnimationController(
             vsync: this,
             duration: const Duration(milliseconds: 200), // D-30
             reverseDuration: const Duration(milliseconds: 200),
             value: 1.0,
             upperBound: 1.0,
             lowerBound: 0.9, // 10% squeeze
           );
           _scale = CurvedAnimation(parent: _scaleCtl, curve: Curves.easeOut);
         }

         @override
         void dispose() {
           _scaleCtl.dispose();
           super.dispose();
         }

         void _handleTapDown(TapDownDetails _) {
           // STAFIR-06: visual feedback synchronous with gesture, NOT after audio.
           widget.onLetterTap(widget.letter); // fire callback BEFORE animating; callback is fire-and-forget
           _scaleCtl.reverse().then((_) => _scaleCtl.forward()); // squeeze then return
         }

         @override
         Widget build(BuildContext context) {
           final color = paletteForIndex(widget.letterIndex);
           return ConstrainedBox(
             constraints: BoxConstraints(minWidth: widget.minSize, minHeight: widget.minSize),
             child: AnimatedBuilder(
               animation: _scale,
               builder: (context, child) =&gt; Transform.scale(scale: _scale.value, child: child),
               child: GestureDetector(
                 onTapDown: _handleTapDown,
                 behavior: HitTestBehavior.opaque,
                 child: Container(
                   decoration: BoxDecoration(
                     color: color,
                     borderRadius: BorderRadius.circular(24),
                   ),
                   alignment: Alignment.center,
                   child: Text(
                     widget.letter.glyph,
                     style: const TextStyle(
                       // SF Pro on iOS, Roboto on Android — Flutter's default sans-serif is the right pick (D-30).
                       // Letter glyph is the only Text widget in the tile; STAFIR-08.
                       fontSize: 96,
                       fontWeight: FontWeight.w600,
                       color: Color(0xFF1A1A1A),
                     ),
                   ),
                 ),
               ),
             ),
           );
         }
       }
       ```

    Notes for the executor:
    - Use `GestureDetector.onTapDown`, NOT `onTap`. Tests assert the callback fires before tap-up. (PITFALLS #4 + STAFIR-06.)
    - The scale animation uses `reverse → forward` to get the "squeeze and bounce back" effect. The 200 ms duration matches D-30.
    - DO NOT add Semantics labels in this plan — kids' app, no screen-reader use case for the child. Phase 4 doesn't ship accessibility hooks; Phase 11+ may revisit.
    - DO NOT add a `selected` Boolean prop. STAFIR-07 + D-13 forbid the concept.

    Run `flutter test test/features/stafir/`; all should pass.

    Atomic commit: `feat(04-03): LetterTile widget with on-tap-down scale animation + locked pastel palette (D-09, D-10, D-13, D-30, STAFIR-01, -06, -07, -08)`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test test/features/stafir/ &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - 13+ new tests green
    - Pre-existing tests still green
    - `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: REFACTOR — golden test for LetterTile + palette adjustment if pastel-saturation test fails</name>
  <files>
    test/features/stafir/widgets/letter_tile_test.dart,
    test/features/stafir/widgets/goldens/letter_tile_a.png,
    test/features/stafir/widgets/goldens/letter_tile_eth.png,
    test/features/stafir/widgets/goldens/letter_tile_thorn.png
  </files>
  <action>
    Add a single golden test for visual regression protection. Plan 04's StafirRoom golden is the bigger win, but a leaf-level golden helps catch palette / typography drift across Flutter SDK bumps:

    ```dart
    testWidgets('LetterTile golden — letter "a" at index 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200, height: 200,
              child: LetterTile(
                letter: kIcelandicAlphabet[0], // 'a'
                letterIndex: 0,
                onLetterTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(LetterTile),
        matchesGoldenFile('goldens/letter_tile_a.png'),
      );
    });
    ```

    Also add goldens for letterIndex=4 (testing diacritic glyph 'ð') and letterIndex=29 (testing 'þ'). These three goldens together exercise the diacritic-glyph rendering paths (Phase 2's three covered slugs).

    Run `flutter test --update-goldens test/features/stafir/widgets/letter_tile_test.dart` to generate the PNGs, then commit them.

    Atomic commit: `test(04-03): golden snapshots for LetterTile a/ð/þ for typography regression protection`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test test/features/stafir/widgets/letter_tile_test.dart</automated>
  </verify>
  <done>
    - Goldens committed under test/features/stafir/widgets/goldens/
    - Tests pass without --update-goldens
    - Atomic commit landed
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user → widget | tap gesture crosses into the widget tree |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-09 | T (tampering) | child rapid-taps | mitigate | onTapDown is fire-and-forget, idempotent; downstream AudioEngine handles cancel-on-retap (Plan 02 D-04) |
| T-04-10 | I (info disclosure) | text instructions sneak in | mitigate | widget test asserts exactly 1 Text widget; STAFIR-08 enforced by test |
| T-04-11 | T (tampering) | "selected" / "score" UI accidentally added later | mitigate | widget test asserts no Icon (error/check/close) and post-tap decoration is identical to pre-tap; STAFIR-07 + D-13 enforced by test |
</threat_model>

<verification>
- `flutter test` — all green, ≥110 tests
- `flutter analyze` — 0 issues
- `dart format --set-exit-if-changed .` — clean
- `flutter build apk --debug` — succeeds
- 3 golden PNGs in test/features/stafir/widgets/goldens/
</verification>

<success_criteria>
- LetterTile widget renders glyph + pastel background + scale animation on onTapDown
- Tap target ≥200 logical px (proxy for ≥2cm physical at typical tablet DPR)
- Zero text instructions, zero failure-state UI, zero "selected" state
- 6-color pastel palette locked + tested
- 13+ new tests + 3 goldens
- 3 atomic commits (RED → GREEN → REFACTOR with goldens)
</success_criteria>

<output>
Create `.planning/phases/04-stafir-tap-to-hear-mvp/04-03-SUMMARY.md` with:
- LetterTile public API surface
- Palette colors hex values
- Decisions exercised: D-09, D-10, D-13, D-30
- Requirements satisfied (widget level): STAFIR-01 (target size), STAFIR-06 (synchronous feedback), STAFIR-07 (no fail UI), STAFIR-08 (no text instructions)
- Atomic commits + SHAs
</output>
