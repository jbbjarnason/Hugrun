---
phase: 09
status: passed
date: 2026-05-02
---

# Phase 9 Verification

## Status: `passed`

All scope and quality gate items from the Phase 9 prompt are satisfied
without remaining human checkpoints.

## What was verified

### Functional invariants

- [x] **CorrespondenceActivity** renders N copies of the noun image,
      taps fire numeral audio in counting order using the noun's gender.
      Re-tapping a counted target is a silent no-op (D-05). Round
      complete → MatchingCelebration + auto-advance.
- [x] **SubitizingActivity** flashes 1..5 dots in dice/line/random/finger
      arrangements for 1.5s, then renders 5 numeral options 1..5. Wrong
      tap = silent (D-09). Correct tap = celebration + auto-advance.
- [x] **AdditionActivity** renders two object groups (addend1, addend2
      copies of the noun) with **no `+` symbol or operator glyph**.
      Bottom row 5 numeral options 1..5; correct = celebration; wrong =
      silent (D-13). AD1 test pins the no-`+` invariant.
- [x] **TolurMode** reshape: 2 values (`tapToHear`, `activity`).
      Activity mode renders an `ActivityRotator` that picks one of 4
      numeracy widgets each mount.

### Quality gate

- [x] CorrespondenceActivity, SubitizingActivity, AdditionActivity
      all implemented + tested
- [x] Round generators pure Dart, in `lib/core/numbers/`
- [x] No `+` symbol anywhere in addition UI (AD1)
- [x] Wrong taps/drops are silent no-ops across all 4 activities
- [x] Tölur Activity mode rotates through 4 activities
- [x] Integration test compile-clean
- [x] `flutter analyze` clean modulo documented riverpod_lint warnings
- [x] `flutter test` 441 pass (Phase 9 contributes 54 new)
- [x] `flutter build apk --debug` succeeds
- [x] `tools/check-domain-purity.sh`, `check-asset-paths.sh`,
      `check-no-tracking.sh` all pass
- [x] No edits to Phase 10 territory:
      - No Drift schema bumps
      - No lexicon changes
      - No photo_upload UI changes
      - No `manifest.yaml` extensions
      - No new pubspec dependencies
- [x] Atomic commits per RED/GREEN cycle (16 task commits)
- [x] VERIFICATION.md status: passed

## What's not blocking

Phase 9 ships without round-entry narration audio. The 4 activities
reuse Phase 8's 18 numeral keys for tap-to-count audio (correspondence)
and stay silent on round entry (subitizing, addition) per CONTEXT
D-20. When the audio polish pass adds narrations like "Hversu margir
hundar?" / "Tveir hundar koma", the activities will route through the
same `audioEngine.play(key)` calls — no structural change required.

## Pre-existing issues (NOT Phase 9 caused)

- Phase 10's RED-phase tests in `test/features/parent_settings/photo_upload/`
  fail by design — those are Phase 10's WIP. Phase 9 made no edits to
  that subtree. Phase 10's planner addressed those tests in its own
  GREEN cycles after Phase 9 closed.
- `analyze` reports 15 documented `scoped_providers_should_specify_dependencies`
  warnings on test files; same family Phase 5/6/7/8 already documented.

## Reviewer hot spots

| Concern              | Mitigation                                                |
| -------------------- | --------------------------------------------------------- |
| `+` symbol in UI     | AD1 widget test fails the build if any `+` text or         |
|                      | `Icons.add` slips into the addition tree.                  |
| Counting gender bug  | CR2 + CR3 tests pin masculine vs feminine resolver paths. |
| Subitizing arrangem. | G3 test asserts all 4 arrangements reachable.             |
| Activity rotation    | AR2 + integration test confirm ≥3 distinct activities.    |
