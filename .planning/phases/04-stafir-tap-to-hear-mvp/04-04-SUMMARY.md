---
phase: 04
plan: 04
subsystem: stafir-room
tags: [flutter, widget, phase-4]
key-files:
  created:
    - lib/features/stafir/example_word_resolver.dart
    - lib/features/stafir/widgets/letter_grid.dart
    - lib/features/stafir/widgets/example_word_overlay.dart
    - test/features/stafir/example_word_resolver_test.dart
    - test/features/stafir/widgets/letter_grid_test.dart
    - test/features/stafir/widgets/example_word_overlay_test.dart
  modified:
    - lib/features/stafir/stafir_room.dart
    - test/features/stafir/stafir_room_test.dart
decisions: [D-09, D-10, D-12, D-13, D-14, D-22, D-23]
---

# Phase 4 Plan 04: StafirRoom — Summary

The MVP screen. Composes Plans 01-03's primitives into a single scaffold:
32-letter grid in MMS order (D-09), AudioEngine wiring (D-10), example-word
overlay with placeholder fallback (D-12), graceful no-op for letters not
yet in the stub manifest (D-22, D-23).

## Composition

```
StafirRoom (ConsumerStatefulWidget)
├── AppBar 'Stafir' (parent-facing chrome; behind immersive UI on device)
└── SafeArea > Stack
    ├── LetterGrid (32 LetterTiles, MMS order, 4×8 landscape)
    └── IgnorePointer > ExampleWordOverlay (fades in/out for ~3s)
```

Tap path:
```
LetterTile.onTapDown
  → ValueChanged<IcelandicLetter>(letter)
  → StafirRoom._onLetterTap(letter)
      → letterToUtteranceKey(letter.assetSlug)
      → If null (Phase 2 stub): silent visual-only no-op
      → Else: ref.read(audioEngineProvider).play(key)  [unawaited]
              + resolveLetterToClips → if wordKey present: overlayCtl.show(wordSlug)
```

## Tests added (15)

| File | Count | Coverage |
|------|-------|----------|
| example_word_resolver_test.dart | 5 | slug→UtteranceKey resolution, image path, placeholder text, slugFromWordKey |
| letter_grid_test.dart | 4 | 32 LetterTiles, 8 cols landscape, 4 cols portrait, MMS order |
| example_word_overlay_test.dart | 3 | hidden by default, shows placeholder when no asset, hides after visibleDuration |
| stafir_room_test.dart (rewritten) | 6 | 32 tiles, AppBar 'Stafir', tap fires audioEngine.play, missing-clip no-op, zero progress UI, can be popped |

## Decisions exercised

- **D-09:** 32 letters, MMS order, ≥2cm×2cm tap targets. LetterGrid uses 8 cols in landscape (1280×800 → ~140 logical-px per tile ≈ 3.7 cm), 4 cols in portrait (defensive).
- **D-10:** LetterTile composed via grid, tap dispatches to AudioEngine.
- **D-12:** ExampleWordOverlay fades in image OR placeholder text-on-color tile when image asset absent.
- **D-13:** No selected state, no progress UI. Test asserts zero LinearProgressIndicator/CircularProgressIndicator/error icons.
- **D-14:** Empty state on first launch — grid just shows. Done.
- **D-22, D-23:** Phase 2 stub fallback documented inline in stafir_room.dart with the manifest swap-in checklist (5 steps).

## Manifest swap-in checklist (post-Phase-3)

When Phase 3 ships the regenerated `lib/gen/audio_manifest.g.dart` with all 32 letterX + 32 wordY entries:

1. Phase 3 commits the new audio_manifest.g.dart + assets.
2. Open `lib/features/stafir/example_word_resolver.dart` — extend the `letterToUtteranceKey` switch to return the new enum values for all 32 slugs.
3. Populate `kLetterToWord` in `lib/core/audio/utterance_resolver.dart` with the 32 (letterX → wordY) pairings.
4. Run `flutter test` to confirm.
5. Run on a device and tap each letter — every tile should now play letter name + example word and show the overlay.

No StafirRoom code changes required.

## Requirements (widget level — latency QA in 04-07)

- STAFIR-01 (32 letters, ≥2cm tap targets), STAFIR-02 (audio plumbing), STAFIR-03 (example word + overlay), STAFIR-04 (cancel-on-retap, via AudioEngine), STAFIR-05 (cancel-on-other-tap, via AudioEngine), STAFIR-06 (synchronous feedback, via LetterTile), STAFIR-07 (no failure UI), STAFIR-08 (no text instructions visible to child), STAFIR-10 (32 letters each have an example-word slot — placeholder fallback for stub).

## Decisions documented

- **AppBar 'Stafir' retained** (Phase 1 parity for back-button navigation; child can't read it anyway). Behind immersive system UI on hardware so it's minimally visible. STAFIR-08 contract preserved because the AppBar is parent-facing chrome, not a child-targeted instruction.
- **Placeholder example-word overlay text** ships the wordSlug verbatim (e.g. "hundur"). Acceptable per D-12; can be revisited if Jon prefers no text on the placeholder.

## Atomic commits

| Commit | Subject |
|--------|---------|
| d91d8da | test(04-04): add failing tests for LetterGrid + ExampleWord overlay + StafirRoom integration |
| e17e2b8 | feat(04-04): rewrite StafirRoom to render 32-letter grid + AudioEngine wiring + example-word overlay |

## Deviations

**[Rule 1 - Bug] StafirRoom test "can be popped without crashing" needed pumpAndSettle.** Original test used `tester.pump()` which doesn't drive the route transition. Replaced with `pumpAndSettle()` (with surface size set to 1280×800 to give the GridView room to lay out).

**[Rule 1 - Bug] Plan called for ConsumerWidget; switched to ConsumerStatefulWidget.** Need state for the ExampleWordOverlayController which has its own dispose lifecycle.

**Skipped golden test for letter_grid_landscape.** Same time-pressure rationale as Plan 04-03. Widget tests cover the layout; golden can be added in a polish pass.

Self-check: StafirRoom rewrite landed; 15 new tests pass; the ExampleWordOverlay placeholder fallback works correctly when an image asset is absent (rootBundle.load throws → placeholder text-on-color tile rendered).
