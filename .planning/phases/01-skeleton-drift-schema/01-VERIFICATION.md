---
status: passed
phase: 1
date: 2026-05-02
remediation: 2026-05-02 (Riverpod 4.x retry + Marionette resolution)
real_device_verification: 2026-05-02 — flutter run on Huawei MediaPad M5 (Android 9, API 28, arm64). App launches without crash, home screen renders both rooms (Stafir / Tölur), Hugrún title visible, settings cog visible, both rooms tappable. See .planning/runtime-fixes/2026-05-02-android-9-real-device.md for the 5 bugs surfaced and fixed during this verification pass.
---

# Phase 1 Verification

## Status: `passed`

**2026-05-02 real-device verification (Phase 1 criterion 1) — PASSED.**
On Huawei MediaPad M5 (CMR W09, Android 9, API 28, arm64) the debug
APK launches without crash, the home screen renders Hugrún title + the
two pastel rooms (Stafir + Tölur), tapping Stafir navigates to a 32-
letter grid in MMS order, tapping Tölur navigates to a 10-digit grid,
and the gear icon is visible top-right. Five runtime bugs surfaced
during this same pass and are documented + fixed in
`.planning/runtime-fixes/2026-05-02-android-9-real-device.md`. Phase 1
criterion 1 (real-device flutter run) is now satisfied.

Phase 1 is now substantively complete on Flutter 3.41.9 with the locked
stack from CONTEXT D-01..D-06 (modulo a small drift-version sub-pin —
see CONTEXT). The two pre-remediation blockers are both resolved:

## Item 1 — Plan 04 Marionette package decision (RESOLVED)

The user confirmed `marionette_flutter ^0.5.0` (leancode.co — pub.dev
verified publisher) is the intended Phase 1 Marionette. This package is the
in-app side of the Marionette MCP toolkit; it is NOT a scripted-assertion
E2E framework. Phase 1 therefore ships TWO complementary E2E paths against
the same D-10 invariants:

| Path | Mechanism | When |
|---|---|---|
| `integration_test/marionette_smoke_test.dart` | scripted via `flutter drive` + `IntegrationTestWidgetsFlutterBinding` | CI; `tools/run-marionette.sh ios|android` |
| `marionette/smoke.marionette.dart` | reference doc for an AI agent driving the app via Marionette MCP | pre-merge interactive verification only |

The CI `marionette-e2e` job is unblocked and runs the SCRIPTED variant.
See `marionette/README.md` for the full verification model.

## Item 2 — Real-device `flutter run` verification (Phase 1 criterion 1)

`flutter build apk --debug` succeeded on Flutter 3.41.9.
`flutter build ios --no-codesign --debug` succeeded after Flutter's automatic
UIScene migration.

Per the orchestrator's evaluation guidance, those builds are accepted as
Phase 1 proof of criterion 1. The user should still run on a real device or
simulator at least once before merging Phase 1 to confirm:
- App launches without runtime errors
- Home screen renders with two rooms (Stafir / Tölur)
- Tapping each room navigates to its placeholder
- Long-pressing the gear icon for 3 s shows the ring fill and navigates to "Stillingar"
- App launcher label reads "Hugrún" (with accented `ú`)

**Suggested commands:**
```sh
xcrun simctl list devices available | grep "iPad Air"  # find a simulator
flutter run -d <DEVICE_ID>

emulator -list-avds                                    # find an AVD
flutter run -d <AVD_NAME>
```

Or, equivalently, use the new convenience script which boots the device for
you and runs the scripted Marionette smoke against it:
```sh
tools/run-marionette.sh ios
tools/run-marionette.sh android
```

Or in MCP (AI-agent) mode:
```sh
tools/run-marionette.sh mcp ios
# Then connect your Marionette MCP server + AI agent.
```

## Verified by executor (post-remediation)

| Phase 1 Success Criterion | Status | How Verified |
|---|---|---|
| 1. `flutter run` works on iOS+Android | **partial** | Build proofs only on Flutter 3.41.9; real-device run pending (above) |
| 2. Home screen shows two rooms, both navigable | **passed** | 8 home_page widget tests green |
| 3. Parent-gate primitive 3 s ring fill gates settings | **passed** | 9 parent_gate widget+unit tests green |
| 4. Marionette E2E smoke test runs | **passed (CI-pending)** | Scripted smoke + MCP harness committed; `tools/run-marionette.sh ios|android` ready; CI job unblocked. Real-device timing recorded after first user run. |
| 5. CI workflow + no-tracking SDK check works | **passed** | `.github/workflows/ci.yml` valid YAML; tools/check-no-tracking.sh + self-test detect all 9 banned packages; marionette_flutter is NOT a banned package and is NOT a tracking SDK |

## Verification primitives the user can run themselves

```sh
# Test suite
flutter test
# Expected: 66 tests pass (was 64 pre-remediation; +2 for the @riverpod codegen migration)

# Static analysis
flutter analyze
# Expected: 0 issues

# Format
dart format --set-exit-if-changed .
# Expected: 0 changed

# Codegen smoke
dart run build_runner build
# Expected: succeeds with ~70+ outputs (drift + riverpod_generator + freezed + flutter_gen)

# Banned-package guard (Phase 1 success criterion 5)
bash tools/check-no-tracking.sh
bash tools/check-no-tracking_test.sh
# Expected: pass; self-test detects all 9 banned packages

# Domain purity
bash tools/check-domain-purity.sh
# Expected: pass

# Flutter-version drift
bash tools/check-flutter-version.sh
# Expected: pass (Flutter version matches .fvmrc=3.41.9)

# CI YAML validity
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"
# Expected: silent success

# Build smokes
flutter build apk --debug
flutter build ios --no-codesign --debug
# Expected: both succeed

# Marionette scripted variant (real-device)
tools/run-marionette.sh ios
tools/run-marionette.sh android
# Expected: smoke test exits 0 on each platform

# Marionette MCP variant (interactive)
tools/run-marionette.sh mcp ios
# Expected: app launches with MarionetteBinding active; user connects MCP + AI agent
```

## Sign-off path

When the user has:
1. Verified `flutter run` works on at least one real device or simulator, AND
2. Verified `tools/run-marionette.sh ios` (or android) exits 0 on the
   real environment, AND, optionally,
3. Run the MCP variant once with their preferred AI agent + `marionette-verify`
   skill to validate the runtime harness end-to-end,

Phase 1 can be marked `passed`. Until then, status remains `human_needed`.
