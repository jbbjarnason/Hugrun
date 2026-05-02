---
phase: 09
plan: 01
title: One-to-One Correspondence Activity (NUM-04)
status: complete
date: 2026-05-02
tags: [phase-9, tolur, correspondence, num-04, tdd]
requirements_satisfied:
  - NUM-04   # one-to-one correspondence
metrics:
  tests-added: 18    # 11 model + 7 widget
  files-created: 4
  flutter-analyze: clean (modulo documented riverpod_lint warnings)
  domain-purity: passes
---

# Plan 09-01: One-to-One Correspondence — Summary

Pure-Dart `CorrespondenceRound` + `Noun` value model and the
`CorrespondenceActivity` widget. Round shows N copies of a pictured
noun (N ∈ 1..5); tapping each in sequence fires the gendered numeral
audio in counting order using the noun's grammatical gender.

## Files created

- `lib/core/numbers/correspondence_round.dart` (223 lines)
  - `Noun` (word + gender + imagePath)
  - `kCorrespondenceNouns` — 8 nouns drawn from Phase 4/5 example
    words spanning all 3 grammatical genders (hundur, fiskur, lampi
    masc; kýr, sól, rós fem; hús, epli neut)
  - `TapTarget` indexed 0..count-1
  - `CorrespondenceRound` with asserting factory (count.value 1..5)
  - `CorrespondenceRoundGenerator(seed)` deterministic generator
- `lib/features/tolur/correspondence/correspondence_activity.dart` (151 lines)
- `lib/features/tolur/correspondence/correspondence_providers.dart`
- `test/core/numbers/correspondence_round_test.dart` (11 tests)
- `test/features/tolur/correspondence/correspondence_activity_test.dart` (7 tests)

## Commits

- `b2ecb7a` test(09-01) RED — model tests
- `56e8c21` feat(09-01) GREEN — model + generator
- `75b3a19` test(09-01) RED — widget tests
- `c573425` feat(09-01) GREEN — CorrespondenceActivity widget

## Quality gate

- [x] CorrespondenceRound + generator pure Dart in `lib/core/numbers/`
      (allow-list already includes that directory from Phase 8)
- [x] Re-tap on counted target = silent no-op (D-05)
- [x] Counting uses noun.gender (D-02): masculine noun → numberOneMasc...;
      feminine noun → numberOneFem...
- [x] Round complete = MatchingCelebration overlay + auto-advance
- [x] No fail UI (no error/cancel/close icons)
- [x] Image fallback to text placeholder when asset missing (Phase 5
      pattern — Phase 10 swaps in personalized photos)

## Decisions exercised

D-01 (round model: count + noun + tap targets), D-02 (gender from noun),
D-03 (random count + random noun from kCorrespondenceNouns), D-04
(counting order = ascending 1..N), D-05 (re-tap = no-op).

## Deviations from plan

**1. [Rule 3 - Blocking] Inline placeholder for missing image assets.**
The plan called out "noun" as a struct including `imagePath`, but Phase
4/5 ship without `assets/images/letters/words/*.webp` files (the asset
folder is registered but empty — Phase 5 uses text-on-color placeholders
for matching). I followed the same pattern: `Image.asset` with an
errorBuilder fallback to a Text widget showing the noun word. No
behavior change vs. the plan; the activity is functional now and the
image swap-in is automatic when assets land (or Phase 10 personalization
fires).

**2. Removed initial intra-tile check_circle.** First implementation
added a small green check-circle icon overlay on counted targets. The
green border on the AnimatedContainer is sufficient visual feedback;
the extra icon was redundant with the round-complete celebration.
Removed before commit — keeps the surface clean per NUM-08.

No deviations from CONTEXT D-01..D-05.
