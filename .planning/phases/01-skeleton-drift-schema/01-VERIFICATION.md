---
status: human_needed
phase: 1
date: 2026-05-02
---

# Phase 1 Verification

## Status: `human_needed`

Phase 1 is substantively complete (4 of 5 plans). Two items require human action before final sign-off:

## Item 1 — Plan 04 Marionette package decision (blocking)

The Marionette package referenced by PROJECT.md / CONTEXT D-09 does not exist on pub.dev under the name `marionette`. The most plausible candidate is `marionette_flutter ^0.5.0` (leancodepl), but its description ("Flutter extensions for AI agent interaction via MCP — lets Claude, Copilot, and Cursor tap, scroll, type, and screenshot your app") indicates an MCP-based AI agent automation tool, not a scripted E2E test framework.

The PROJECT.md mention of "marionette-verify skill" plausibly refers to an external skill / harness that uses this MCP tool to drive E2E verification through an AI agent loop. If so, `marionette_flutter` is correct and the Plan 04 smoke test should be re-conceived as an MCP-driven exploratory verification rather than a scripted-assertion E2E suite.

**User decision required:**

- **Approve `marionette_flutter ^0.5.0`** as the Phase 1 Marionette implementation. (Most likely correct — recommended.)
- **Approve a different package by name and pub.dev URL.**
- **Escalate to `/gsd-discuss-phase`** for project-level review (e.g., to consider integration_test or patrol; PROJECT.md currently forbids patrol but the user could re-decide).

When unblocked, Plan 04 Tasks 2 + 3 can be completed in ~30 minutes (the implementation plan is ready; just swap in the resolved package name).

## Item 2 — Real-device `flutter run` verification (Phase 1 criterion 1)

`flutter build apk --debug` succeeded (built `app-debug.apk`, ~261 s).
`flutter build ios --no-codesign --debug` succeeded (built `Runner.app`, ~18 s post-pod-install).

Per the orchestrator's evaluation guidance, those builds are accepted as Phase 1 proof. However, the user should run on a real device or simulator at least once before merging Phase 1 to confirm:
- App launches without runtime errors
- Home screen renders with two rooms (Stafir / Tölur)
- Tapping each room navigates to its placeholder
- Long-pressing the gear icon for 3 s shows the ring fill and navigates to "Stillingar"
- App launcher label reads "Hugrún" (with accented `ú`)

**Suggested commands:**
```
xcrun simctl list devices available | grep "iPad Air"  # find a simulator
flutter run -d <DEVICE_ID>

emulator -list-avds                                    # find an AVD
flutter run -d <AVD_NAME>
```

## Verified by executor

| Phase 1 Success Criterion | Status | How Verified |
|---|---|---|
| 1. `flutter run` works on iOS+Android | partial | Build proofs only; real-device run pending (above) |
| 2. Home screen shows two rooms, both navigable | passed | 8 home_page widget tests green |
| 3. Parent-gate primitive 3 s ring fill gates settings | passed | 9 parent_gate widget+unit tests green |
| 4. Marionette E2E smoke test runs | blocked | Plan 04 checkpoint — see Item 1 |
| 5. CI workflow + no-tracking SDK check works | passed | `.github/workflows/ci.yml` valid YAML; tools/check-no-tracking.sh + self-test detect all 9 banned packages |

## Verification primitives the user can run themselves

```
# Test suite
flutter test
# Expected: 64 tests pass

# Static analysis
flutter analyze
# Expected: 0 issues

# Format
dart format --set-exit-if-changed .
# Expected: 0 changed

# Codegen smoke
dart run build_runner build --delete-conflicting-outputs
# Expected: succeeds with ~864 outputs

# Banned-package guard (Phase 1 success criterion 5)
bash tools/check-no-tracking.sh
bash tools/check-no-tracking_test.sh
# Expected: pass; self-test detects all 9 banned packages

# Domain purity
bash tools/check-domain-purity.sh
# Expected: pass

# Flutter-version drift
bash tools/check-flutter-version.sh
# Expected: pass (Flutter version matches .fvmrc=3.38.7)

# CI YAML validity
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"
# Expected: silent success
```

## Sign-off path

When the user has:
1. Approved a Marionette package (or escalated), AND
2. Verified `flutter run` works on at least one real device or simulator,

Phase 1 can be marked `passed`. Until then, status remains `human_needed`.
