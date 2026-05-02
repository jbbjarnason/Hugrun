---
phase: 2
plan: 1
title: Alphabet primitive (IcelandicLetter + kIcelandicAlphabet)
status: complete
tags: [alphabet, freezed, domain, mms]
date: 2026-05-02
duration: ~10 min
requires:
  - phase-1 freezed (3.2.5) + freezed_annotation (3.1.0)
  - phase-1 build_runner (2.15.0)
provides:
  - IcelandicLetter @freezed model (glyph, name, assetSlug)
  - kIcelandicAlphabet const list of 32 letters in MMS school order
  - tools/check-domain-purity.sh extension covering lib/core/alphabet/
affects:
  - phase-3 audio manifest pipeline (slug map drives filename emission)
  - phase-4 Stafir grid (renders kIcelandicAlphabet)
  - phase-6 phoneme set (keyed off the same slugs)
key-files:
  created:
    - lib/core/alphabet/icelandic_letter.dart
    - lib/core/alphabet/alphabet.dart
    - test/core/alphabet/alphabet_test.dart
    - test/core/alphabet/icelandic_letter_test.dart
  modified:
    - tools/check-domain-purity.sh
decisions:
  - >
    Did NOT commit the generated lib/core/alphabet/icelandic_letter.freezed.dart.
    Project .gitignore line 44 excludes **/*.freezed.dart and CI's existing
    build_runner step regenerates it. The plan instructed to commit it; the
    project policy (zero generated *.dart files committed; sole exception is
    lib/gen/audio_manifest.g.dart per .gitignore line 45) takes precedence.
metrics:
  tests_added: 10 (7 alphabet + 3 IcelandicLetter)
  commits: 3
---

# Phase 2 Plan 01: Alphabet Summary

**One-liner:** Canonical 32-letter Icelandic alphabet (`kIcelandicAlphabet`) in
MMS school order, backed by a `@freezed` `IcelandicLetter` model and locked
down by 7 unit tests covering D-04 (length, order, no-CQWZ, slug map, slug
uniqueness, slug regex, non-empty names).

## Commits

| Hash | Type | Message |
|---|---|---|
| `360df35` | RED | `test(02-01): add failing alphabet + IcelandicLetter tests (RED)` |
| `4606245` | GREEN | `feat(02-01): IcelandicLetter freezed model + kIcelandicAlphabet (32 letters, MMS order) (GREEN)` |
| `9584581` | REFACTOR | `refactor(02-01): document alphabet row-grouping rationale` |

## Test count delta

| | Before | After |
|---|---|---|
| `flutter test` | 66 | **76** (+10: 7 alphabet + 3 IcelandicLetter) |

## D-04 assertions confirmed

- `kIcelandicAlphabet.length == 32` ✓
- Glyph order matches `[a, á, b, d, ð, e, é, f, g, h, i, í, j, k, l, m, n, o, ó, p, r, s, t, u, ú, v, x, y, ý, þ, æ, ö]` ✓
- No `c`, `q`, `w`, `z` ✓
- Each `assetSlug` matches the D-03 mapping table ✓
- All 32 slugs unique ✓
- All slugs match `^[a-z][a-z0-9_]*$` ✓
- Each `name` non-empty ✓

## Domain purity confirmed

`tools/check-domain-purity.sh` `DOMAIN_PATHS` array now contains:

```bash
DOMAIN_PATHS=(
  "lib/core/db/tables"
  "lib/core/parent_gate"
  "lib/core/alphabet"       # Phase 2 Plan 01
  "lib/core/manifest"       # Phase 2 Plan 02 (added in plan 02-02)
)
```

Both `lib/core/alphabet/icelandic_letter.dart` and
`lib/core/alphabet/alphabet.dart` import only `package:freezed_annotation`
and the local `icelandic_letter.dart` — no `package:flutter/...` imports.
The script confirms zero violations.

## Deviations from plan

### Deviation 1 [Rule 1 - Project Policy] — generated freezed file not committed

**Found during:** Task 2 GREEN.

**Issue:** Plan 02-01 Task 2 instructs:
> Commit the generated file (project policy: generated files in `lib/gen/`
> and Phase 1's `lib/core/db/database.g.dart` / `database_provider.g.dart`
> are committed — follow the same convention for `*.freezed.dart`).

This claim is incorrect. The repository's `.gitignore` (lines 39–45) excludes
all `**/*.g.dart` and `**/*.freezed.dart` files with one explicit exception:
`!lib/gen/audio_manifest.g.dart`. Verified via `git ls-files | grep -E
"\.(g|freezed|gen)\.dart$"` — zero hits. Phase 1's `database.g.dart` etc. are
NOT committed; CI regenerates them via the existing `build_runner build` step
in `.github/workflows/ci.yml`.

**Fix:** Followed project `.gitignore` policy — did NOT commit
`lib/core/alphabet/icelandic_letter.freezed.dart`. CI will regenerate it on
every run. The freezed file IS present locally and the tests pass against it.

**Files affected:** `lib/core/alphabet/icelandic_letter.freezed.dart` (NOT
committed; regenerated on demand).

**Commit:** `4606245` (commit message documents the deviation explicitly).

## Self-Check: PASSED

- `lib/core/alphabet/icelandic_letter.dart` — FOUND
- `lib/core/alphabet/alphabet.dart` — FOUND
- `test/core/alphabet/alphabet_test.dart` — FOUND
- `test/core/alphabet/icelandic_letter_test.dart` — FOUND
- `tools/check-domain-purity.sh` (modified) — FOUND, contains `lib/core/alphabet`
- Commit `360df35` (RED) — FOUND
- Commit `4606245` (GREEN) — FOUND
- Commit `9584581` (REFACTOR) — FOUND
