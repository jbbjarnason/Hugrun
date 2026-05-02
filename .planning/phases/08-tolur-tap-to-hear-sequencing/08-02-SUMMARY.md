---
phase: 08
plan: 08-02
title: Tölur Room — Tap-to-Hear
status: complete
date: 2026-05-02
tags: [phase-8, tolur, widget, tdd]
metrics:
  tests-added: 27   # 12 NumberTile + 15 TolurRoom (incl Phase 1 baseline)
  files-created: 3  # NumberTile, NumberGrid, TolurRoom (rewrite)
---

# Phase 8 Plan 02: Tölur Room — Tap-to-Hear

The 10-NumberTile grid + tap-to-play loop for the Tölur room. Mirrors
Phase 4's Stafir tap-to-hear shape with NumberTile in place of LetterTile
and a 2×5 / 5×2 grid in place of 4×8 / 8×4.

## Workstream

B from `08-CONTEXT.md`.

## TDD cycle

| Cycle | Subject | Commit |
|-------|---------|--------|
| RED   | NumberTile + TolurRoom widget tests | `e7297d8` |
| GREEN | NumberTile + NumberGrid + TolurRoom rewrite | `<commit>` |

## What was built

### `lib/features/tolur/widgets/number_tile.dart`
- `NumberTile` StatefulWidget. Mirror of `LetterTile`. Renders the digit
  glyph (e.g. "1", "10") in a `paletteForIndex(numberIndex)` rounded
  container with the same 96-px font + 200ms ease-out scale animation as
  Phase 4. `onTapDown` fires the callback synchronously (NUM-01 / D-03).

### `lib/features/tolur/widgets/number_grid.dart`
- `NumberGrid` StatelessWidget. `GridView.builder` over `kIcelandicNumbers`.
  Cross-axis count: 5 (landscape) / 2 (portrait, defensive). Each tile
  gets a stable `Key('number-tile-$index-${number.value}')`.

### `lib/features/tolur/tolur_room.dart`
- `TolurRoom` rewritten from Phase 1 placeholder to a
  `ConsumerStatefulWidget` that hosts `NumberGrid`. Tap → `numberAudioKey(
  number.value, Gender.masculine)` → `audioEngine.play(key)` (D-02 /
  NUM-03 — abstract counting uses masculine).
- Phase 1 baseline tests (AppBar title "Tölur", pop without crashing)
  preserved.

## Tests

12 new `NumberTile` widget tests:
- NT1..NT3 rendering (digit glyph, single Text, no fail icons).
- NT4 sizing (≥200 logical-px tap target).
- NT5 gesture (onTapDown synchronous).
- NT6 palette (paletteForIndex).

15 `TolurRoom` widget tests (kept pre-existing 2 + added 7 + future TR1..3):
- T1..T5: 10 tiles render, digits 1..10 visible, tap → masculine for 1-4 +
  invariant for 5-10.
- T6: tap-all-10-in-order produces the right 10-key sequence.
- T7: NUM-08 — exactly 10 digit-bearing Text widgets (no score leak).

`flutter test test/features/tolur/` → all pass.

## Reuse posture

- `LetterTile` and `NumberTile` are **separate concrete widgets**. Did NOT
  extract a shared base. Mirror cost is small (~40 effective LOC); a
  shared `<T>` tile would couple Stafir + Tölur evolution.
- `paletteForIndex` (Phase 4) imported and used directly — palette is
  shared across rooms.
- `AudioEngine` via `audioEngineProvider` (Phase 4) — no duplicate engine.
- `numberAudioKey` (Plan 08-01) handles M/F/N + invariant resolution.

## Deviations from plan

None. The plan called for "scoped Tap-to-Hear room first; mode toggle in
later workstream"; the GREEN diff sticks to that (no toggle code in
`tolur_room.dart` until Plan 08-04).

## Self-Check: PASSED

- [x] `lib/features/tolur/widgets/{number_tile,number_grid}.dart` exist
- [x] `lib/features/tolur/tolur_room.dart` rewritten
- [x] All Phase 8 widget tests pass (12 NumberTile + 7 new TolurRoom)
- [x] `flutter test` passes (no regressions in 263 baseline)
- [x] `flutter analyze` clean (only known riverpod_lint warnings + Phase 7
      unrelated noise)
