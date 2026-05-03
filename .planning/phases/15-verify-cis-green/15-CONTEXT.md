---
phase: 15
title: Verify All CIs Green on Remote
status: in_progress
date: 2026-05-02
---

# Phase 15 — Verify All CIs Green on Remote

## Goal

After Phase 14 wired up GitHub Actions (`ci.yml`, `deploy-android.yml`,
`deploy-ios.yml`) and pushed the repo to https://github.com/jbbjarnason/Hugrun,
this phase exists for one job: turn the remote CI runs green. The phase is
done when all five CI jobs reach `success` (or are honestly skipped with a
documented reason).

## Background — what was already passing on the previous push

Push @ `2e99e4c` (Phase 14 final commit + Phase 11.1 photos):
- `deploy-ios` ✓ success
- `deploy-android` ✓ success
- `CI` (3-job aggregate) ✗ failure at 8m 1s

So the deploy paths were already proven green; the entry CI workflow was the
sole blocker.

## Diagnosed failures (from `gh run view 25272571573 --log-failed`)

1. **`analyze-and-test (Ubuntu)`** — `dart format --set-exit-if-changed .`
   exited 1. 81 files in `lib/` and `integration_test/` had drifted out of
   canonical Dart format. (Confirmed locally: `dart format` reformatted 81
   files without flagging any errors.)

2. **`integration-no-network (Ubuntu)`** — `flutter test integration_test
   -d linux` failed with:
   `Failed to load no_network_test.dart: No Linux desktop project configured.`
   The repo only ships `android/` + `ios/` platform folders by design — the
   app does not target Linux desktop. But the integration test binding needs
   *some* desktop runtime on the Ubuntu CI runner.

3. **`marionette-e2e (macOS)`** — On iOS Simulator, the Phase 1 smoke test
   asserted `find.text('Stafir')` after tapping into StafirRoom. Phase 12
   UI-01 removed visible AppBar titles from kid surfaces (PROJECT.md
   "no text instructions for non-readers" invariant), so this assertion now
   matches zero widgets. The pre-Phase-12 smoke test was simply stale.

## Out-of-scope

- Anything in `lib/`, `assets/`, audio pipeline, lexicon (except
  format-only whitespace changes — semantic-equivalent).
- Adding store-deploy secrets (Apple Developer / Play Console). The
  deploy workflows are designed to skip-on-missing-secret gracefully;
  setting up those credentials is human-only work.
- Creating a permanent `linux/` desktop target. The app is iOS + Android
  only; any Linux runtime is purely a CI test scaffold.

## Constraints

- 5 fix-iterations per failing job before declaring `human_needed`.
- ~60 minutes wall-clock budget.
- All fixes atomic-committed so the iteration history is auditable.
- No `--no-verify` / no force pushes.
