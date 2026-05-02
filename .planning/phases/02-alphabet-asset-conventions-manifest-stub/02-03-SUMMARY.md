---
phase: 2
plan: 3
title: Asset path CI guard (D-06 enforcement)
status: complete
tags: [ci, guard, assets, paths, pitfall-20]
date: 2026-05-02
duration: ~10 min
requires:
  - phase-1 ci.yml + check-no-tracking.sh self-test pattern
provides:
  - tools/check-asset-paths.sh (D-06 enforcement script)
  - tools/check-asset-paths_test.sh (self-test)
  - tools/test-fixtures/{bad,good}-asset-paths/ (fixture trees)
  - .github/workflows/ci.yml two new steps in analyze-and-test job
affects:
  - all future phases that ship asset files (3 / 4 / 6 / 8 / 9 / 10)
key-files:
  created:
    - tools/check-asset-paths.sh
    - tools/check-asset-paths_test.sh
    - tools/test-fixtures/bad-asset-paths/Foo.aac
    - tools/test-fixtures/bad-asset-paths/þrír.aac
    - "tools/test-fixtures/bad-asset-paths/with space.aac"
    - tools/test-fixtures/bad-asset-paths/áli.aac
    - tools/test-fixtures/bad-asset-paths/UPPER/lower.aac
    - tools/test-fixtures/bad-asset-paths/.gitkeep
    - tools/test-fixtures/good-asset-paths/letters/names/eth.aac
    - tools/test-fixtures/good-asset-paths/letters/words/hundur.aac
    - tools/test-fixtures/good-asset-paths/.gitkeep
  modified:
    - .github/workflows/ci.yml
decisions:
  - >
    Fixture run pattern: per-bad-fixture isolated tmpdirs + one bad-aggregate
    case + one good case + one empty case = 8 cases. The per-case approach
    surfaces failures with attribution ("uppercase-letter (Foo.aac)") rather
    than a blanket "bad fixtures failed."
  - >
    `.gitkeep` files are explicitly allowlisted by the script (the only
    permitted dotfile). All other dotfiles are rejected.
  - >
    Files without an extension are flagged as violations (separate from the
    "extension not in {aac, webp, png, svg}" branch).
metrics:
  cases: 8 (5 single-bad + 1 bad-aggregate + 1 good + 1 empty)
  commits: 3
---

# Phase 2 Plan 03: Asset Paths Guard Summary

**One-liner:** `tools/check-asset-paths.sh` walks `assets/` and rejects any
path with uppercase letters, non-ASCII bytes, spaces, or non-allowed
extensions; wired into the existing `analyze-and-test` CI job (no new jobs)
with a self-test exercising 5 bad fixtures + 2 good fixtures + empty tree —
PITFALL #20 (asset case-sensitivity drift between iOS Simulator and Linux
CI / Android) becomes a build-time failure.

## Commits

| Hash | Type | Message |
|---|---|---|
| `59e9507` | RED | `test(02-03): scaffold check-asset-paths fixtures + self-test (RED)` |
| `fba2879` | GREEN | `feat(02-03): add tools/check-asset-paths.sh enforcing D-06 conventions (GREEN)` |
| `4e3cdf6` | CI | `ci(02-03): wire check-asset-paths + self-test into analyze-and-test job (D-14, D-15)` |

## Self-test cases (8 total)

| # | Case | Fixture | Expect | Result |
|---|---|---|---|---|
| 1 | uppercase-letter (Foo.aac) | single-file tmpdir copy | fail | ✓ |
| 2 | non-ASCII (þrír.aac) | single-file tmpdir copy | fail | ✓ |
| 3 | space (with space.aac) | single-file tmpdir copy | fail | ✓ |
| 4 | non-ASCII (áli.aac) | single-file tmpdir copy | fail | ✓ |
| 5 | uppercase-directory (UPPER/lower.aac) | single-dir tmpdir copy | fail | ✓ |
| 6 | all bad fixtures together | tools/test-fixtures/bad-asset-paths/ | fail | ✓ |
| 7 | good fixtures (lowercase ASCII) | tools/test-fixtures/good-asset-paths/ | pass | ✓ |
| 8 | empty asset directory | empty mktemp | pass | ✓ |

Live exit-code matrix:

```
$ bash tools/check-asset-paths_test.sh > /dev/null 2>&1; echo $?
0

$ bash tools/check-asset-paths.sh tools/test-fixtures/good-asset-paths/ > /dev/null 2>&1; echo $?
0

$ bash tools/check-asset-paths.sh tools/test-fixtures/bad-asset-paths/ > /dev/null 2>&1; echo $?
1

$ bash tools/check-asset-paths.sh assets/ > /dev/null 2>&1; echo $?
0
```

## CI YAML diff summary

Two new steps inserted into the `analyze-and-test` job between
`check-no-tracking_test.sh` and `check-domain-purity.sh`:

```yaml
      - name: tools/check-asset-paths.sh
        run: bash tools/check-asset-paths.sh

      - name: tools/check-asset-paths_test.sh (self-test)
        run: bash tools/check-asset-paths_test.sh
```

- Per D-14: only the `analyze-and-test` job touched (additive).
- Per D-15: NO new top-level jobs added; total job count remains 3
  (`analyze-and-test`, `integration-no-network`, `marionette-e2e`).
- YAML still parses (`python3 -c "import yaml; yaml.safe_load(...)"` ✓).

## Deviations from plan

None. The script + self-test + CI wiring match the plan's interface spec
exactly. The two minor enhancements (per-bad-fixture attribution, empty-tree
case) were within Claude's discretion per the plan's wording: "Either is
acceptable; pick the per-case approach for clearer error attribution."

## Self-Check: PASSED

- `tools/check-asset-paths.sh` — FOUND, executable
- `tools/check-asset-paths_test.sh` — FOUND, executable, exits 0
- `tools/test-fixtures/bad-asset-paths/` — FOUND, contains 5 violation files + .gitkeep
- `tools/test-fixtures/good-asset-paths/` — FOUND, contains 2 conforming files + .gitkeep
- `.github/workflows/ci.yml` — modified, parses, contains 2 new step names
- Commit `59e9507` (RED) — FOUND
- Commit `fba2879` (GREEN script) — FOUND
- Commit `4e3cdf6` (CI wiring) — FOUND
