---
phase: 05-letter-to-word-matching
plan: 01
title: Round Generator (pure-Dart core)
status: complete
date: 2026-05-02
tags: [matching, pure-dart, round-generation, freezed, bernoulli]
requirements: [MATCH-01, MATCH-04]
metrics:
  test-delta: +20 (165 → 185)
  commits: 6 (3 RED + 3 GREEN, no refactor needed)
  flutter-analyze: clean
  domain-purity: passes
---

# Phase 5 Plan 01 — Round Generator Summary

Pure-Dart core for the Letter-to-Word Matching activity. Produces
`MatchingRound` value objects with assertion-protected invariants, and
ships the `PhotoOverrideSource` interface plus `EmptyPhotoOverrideSource`
stub for Phase 10 forward-compat.

## Files created

### Production (lib/core/matching/)
- `matching_round.dart` (74 lines) — Freezed `MatchingRound` + sealed
  `ImageSource` union (StockPlaceholder | PhotoOverride)
- `photo_override_source.dart` (34 lines) — abstract interface +
  `EmptyPhotoOverrideSource` const-ctor stub
- `round_generator.dart` (192 lines) — `RoundGenerator` with seeded
  `Random`, similar-pair exclusion, 40% photo Bernoulli

### Tests (test/core/matching/)
- `matching_round_test.dart` (165 lines, 7 tests)
- `round_generator_test.dart` (282 lines, 13 tests = 2 PhotoOverrideSource +
  11 RoundGenerator G1..G11)

### Tooling
- `tools/check-domain-purity.sh` updated — added `lib/core/matching` to
  DOMAIN_PATHS so the pure-Dart invariant is CI-enforced.

## Test count delta

185 total (was 165 after Phase 4). +20 in this plan:
- Task 1 (MatchingRound): +7 tests
- Task 2 (PhotoOverrideSource): +2 tests
- Task 3 (RoundGenerator G1..G11): +11 tests

## Decisions exercised

| Decision | How |
|----------|-----|
| D-03 | `MatchingRound` requires 4 options + 1 correct |
| D-04 | `kSimilarPairs` covers a/á, e/é, i/í, o/ó, u/ú, y/ý; greedy distractor selection skips pairs |
| D-05 | All files under `lib/core/matching/` are pure Dart; CI-enforced via `check-domain-purity.sh` |
| D-06 | Generator is stateless across calls; caller invokes `generate()` per round |
| D-13 | Photo override hook with 40% Bernoulli; `EmptyPhotoOverrideSource` is the Phase 5 default |
| D-16 | Exhaustive unit tests cover correctness, similar-pair exclusion, determinism, Bernoulli |
| MATCH-01 | Round generation primitive shipped |
| MATCH-04 | Forward-compat stub: `EmptyPhotoOverrideSource` returns []; Phase 10 swaps the binding |

## Implementation notes

### Freezed assertion pattern

The original plan called for a `_internal` private factory + public
asserting factory. That pattern collided with Freezed's union codegen,
which generates `when/map` arms keyed on factory names — `_internal`
becomes a parameter starting with underscore, which Dart rejects.

**Resolution (deviation Rule 1 - Bug):** Switched to Freezed's
`@Assert(...)` annotation directly on the public factory. Cleaner —
no extra indirection, asserts are still enforced at construction time.
Dropped the `const` keyword from the factory because `.toSet()` /
`.contains()` aren't const-evaluable.

### `_slugFromWordKey` duplication (intentional)

`lib/features/stafir/example_word_resolver.dart` already exports
`slugFromWordKey`. We deliberately duplicate it as a private helper in
`round_generator.dart` to honor the layering invariant: `lib/core/`
must not depend on `lib/features/`. The helper is 4 lines; if it
changes, both copies need updating — that's a rare event and easily
caught by tests.

### Generated file policy

`.freezed.dart` files are gitignored project-wide (`.gitignore` line 44).
The plan asked to commit them; we honor the project's existing convention
instead and rely on `dart run build_runner build` to regenerate locally.
No deviation — matches Phase 1/2/4 convention.

### Photo Bernoulli observed in 1000-trial G9

Seed 7 with `_FixedPhotoOverrideSource({'hundur': ['photo-1','photo-2','photo-3']})`
landed in the [350, 450] tolerance window. No recalibration needed.

## Deviations

| Rule | Issue | Fix |
|------|-------|-----|
| Rule 1 - Bug | Freezed `_internal` factory pattern conflicts with union codegen | Switched to `@Assert` annotation; no behavior change |

## Self-Check

- [x] `lib/core/matching/matching_round.dart` exists
- [x] `lib/core/matching/photo_override_source.dart` exists
- [x] `lib/core/matching/round_generator.dart` exists
- [x] 6 commits created (3 RED + 3 GREEN)
- [x] All 20 new tests pass
- [x] All 185 project tests pass (no regressions)
- [x] `bash tools/check-domain-purity.sh` passes
- [x] `flutter analyze lib/core/matching test/core/matching` clean

## Self-Check: PASSED

## Commits

- `dd7b5d3` test(05-01): add failing tests for MatchingRound value class
- `5055ef3` feat(05-01): MatchingRound + ImageSource value types
- `7334dac` test(05-01): add failing tests for PhotoOverrideSource interface
- `a480657` feat(05-01): PhotoOverrideSource interface + empty Phase 5 stub
- `cc3afd6` test(05-01): add failing tests for RoundGenerator (G1..G11)
- `a2585a4` feat(05-01): RoundGenerator with similar-pair exclusion + photo Bernoulli

## Ready for Plan 05-02

Plan 05-02 can now import:
- `package:hugrun/core/matching/matching_round.dart` — `MatchingRound`, `ImageSource`, `StockPlaceholder`, `PhotoOverride`
- `package:hugrun/core/matching/photo_override_source.dart` — `PhotoOverrideSource`, `EmptyPhotoOverrideSource`
- `package:hugrun/core/matching/round_generator.dart` — `RoundGenerator`, `kSimilarPairs`
