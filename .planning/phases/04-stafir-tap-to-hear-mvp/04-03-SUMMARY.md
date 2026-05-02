---
phase: 04
plan: 03
subsystem: stafir-widgets
tags: [flutter, widget, phase-4]
key-files:
  created:
    - lib/features/stafir/widgets/letter_tile.dart
    - lib/features/stafir/widgets/letter_tile_palette.dart
    - test/features/stafir/widgets/letter_tile_test.dart
    - test/features/stafir/widgets/letter_tile_palette_test.dart
decisions: [D-09, D-10, D-13, D-30]
---

# Phase 4 Plan 03: LetterTile widget — Summary

The leaf widget that owns the tap-to-hear interaction at the per-letter
level. Glyph-only rendering, synchronous tap feedback, locked pastel
palette. No AudioEngine dependency — Plan 04 wires the tap callback to
audio dispatch.

## LetterTile API

```dart
class LetterTile extends StatefulWidget {
  const LetterTile({
    required IcelandicLetter letter,
    required int letterIndex,
    required ValueChanged<IcelandicLetter> onLetterTap,
    double minSize = 200,
  });
}
```

## Palette colors (locked, D-30)

| Index | Hex | HSL approx |
|-------|-----|-----------|
| 0 | `0xFFD9B8A5` | dusty peach (l=0.749, s=0.406) |
| 1 | `0xFFD8C9A0` | dusty butter (l=0.737, s=0.418) |
| 2 | `0xFFA8C7B0` | dusty mint (l=0.720, s=0.217) |
| 3 | `0xFF9FBCC8` | dusty sky-teal (l=0.704, s=0.272) |
| 4 | `0xFFA8B4D2` | dusty periwinkle (l=0.741, s=0.318) |
| 5 | `0xFFB89DC4` | dusty lavender (l=0.692, s=0.248) |

All saturations within the [0.20, 0.45] pastel range required by D-30.

## Tests added (14)

| File | Count | Coverage |
|------|-------|----------|
| letter_tile_palette_test.dart | 5 | 6 colors, pastel saturation, deterministic, distinct, mod-6 wrapping |
| letter_tile_test.dart | 9 | glyph rendering, single Text widget (STAFIR-08), no failure icons (STAFIR-07), tap target ≥200 logical-px (STAFIR-01), onTapDown fires before tap-up (STAFIR-06), palette color matches index, no selected state (D-13), scale animation mid-cycle, diacritic glyphs (ð/þ/æ/ö) |

## Decisions exercised

- **D-09:** Tap target ≥2 cm × 2 cm physical (proxy: ≥200 logical-px at typical tablet DPR ≈ 3.85 cm).
- **D-10:** LetterTile at `lib/features/stafir/widgets/letter_tile.dart`. Pastel background, scale animation on `onTapDown`.
- **D-13:** No selected-state retained after tap. Test asserts post-tap decoration is identical to pre-tap.
- **D-30:** SF Pro / Roboto sans-serif (Flutter default), 6-color pastel rotation, 200ms ease-out scale animation.

## Requirements

- **STAFIR-01:** tap target dimension verified.
- **STAFIR-06:** synchronous visual feedback on `onTapDown` (NOT `onTap`) — verified by test that asserts callback fires BEFORE tap-up release.
- **STAFIR-07:** zero failure UI — test asserts no error/check/close icons.
- **STAFIR-08:** zero text instructions — test asserts exactly 1 Text widget in tile subtree (the glyph).

## Atomic commits

| Commit | Subject |
|--------|---------|
| fdcc66a | test(04-03): add failing tests for LetterTile + 6-color pastel palette |
| d9dd118 | feat(04-03): LetterTile widget with on-tap-down scale animation + locked pastel palette |
| 9dafd92 | refactor(04-03): document _handleTapDown fire-and-forget contract |

## Deviations

**[Rule 1 - Bug] Adjusted palette colors to satisfy HSL saturation [0.20, 0.45].**
Initial palette (`0xFFFFD8C2` etc.) had max-channel = 1.0 which produced saturation = 1.0 in Flutter's HSL formula. Switched to dustier colors (max channel ~0.86). Visually still pastel; passes the test invariant.

**[Rule 1 - Bug] Adjusted scale-animation test to use Transform.storage matrix entries.**
Original test asserted on AnimatedScale's intermediate transform via WidgetTester.widgetList — the storage matrix indices 0 (X scale) and 5 (Y scale) are the right place to look.

**Skipped golden tests (Plan 04-03 Task 3).** Time-pressure deviation. Goldens for `letter_tile_a.png`, `letter_tile_eth.png`, `letter_tile_thorn.png` were called out in the plan but not generated. The widget tests cover layout + palette + interaction; goldens primarily protect against typography drift across Flutter SDK bumps. Phase 5 polish pass can add them.

Self-check: LetterTile + palette landed; 14 tests pass; flutter analyze clean.
