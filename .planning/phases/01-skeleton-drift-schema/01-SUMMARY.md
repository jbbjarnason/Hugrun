---
phase: 1
title: Skeleton & Drift Schema
status: complete (with documented blockers)
plans: 5
plans_complete: 4 (01, 02, 03, 05)
plans_blocked: 1 (04 — Marionette package escalation)
date: 2026-05-02
---

# Phase 1 Master Summary

## Wave-by-wave execution log

### Wave 1 — Plan 01 (bootstrap) — COMPLETE
- 3 atomic commits (RED `5dfd52a` → GREEN `2e4a1ef` → REFACTOR `2507119`)
- 21 widget+skeleton+pubspec-pin tests green
- Flutter project scaffolded; bundle ID = `is.hugrun.app`; launcher = `Hugrún` on both platforms; Icelandic locale wired with `flutter_localizations` delegates
- See `01-01-SUMMARY.md`. 9 documented deviations forced by ecosystem mid-migration on pub.dev as of 2026-05-02 + local Flutter 3.38.7 SDK pinning.

### Wave 2 — Plans 02 (database) + 03 (rooms+gate) — COMPLETE (sequential)
- **Plan 02:** 3 atomic commits (`a82e2fd` → `0dd6206` → `76867cf`); +10 tests (5 dao + 3 bootstrap + 2 migration). Drift v1 schema with stepByStep migration scaffolding, schema snapshot at `drift_schemas/drift_schema_v1.json`. See `01-02-SUMMARY.md`.
- **Plan 03:** 3 atomic commits (`7ff0c05` → `b09d95f` → `22c03c6`); +26 tests (9 gate + 3 button + 2 stafir + 2 tolur + 2 parent_settings + 5 home additions). Two-room shell + ParentGate primitive + ParentSettings stub. See `01-03-SUMMARY.md`.

### Wave 3 — Plan 04 (Marionette E2E) — BLOCKED at CHECKPOINT
- **0 commits.** No Marionette package exists on pub.dev under the name `marionette`. The closest match (`marionette_flutter` v0.5.0) is an MCP-based AI agent automation tool, not a scripted E2E test framework.
- Per the orchestrator's `<critical_constraints>` #2, **substitution is NOT permitted**. The user explicitly mandated Marionette.
- Escalation: see `01-04-SUMMARY.md`. The most likely intended package is `marionette_flutter` (leancodepl) given the PROJECT.md reference to "Marionette… parallelizable via marionette-verify skill" — but this requires user confirmation.

### Wave 4 — Plan 05 (CI + guards) — COMPLETE (with Marionette job guarded)
- 3 atomic commits (`426d32f` → `889d511` → `66b43af`); +12 tests (10 no-tracking + 2 no-network).
- Four guard scripts (no-tracking, flutter-version, domain-purity, self-test). NoNetworkHttpOverrides class. CI workflow with three jobs.
- The `marionette-e2e` CI job is **guarded with `if: false`** until Plan 04 unblocks. Removing the guard is a one-line YAML edit.
- See `01-05-SUMMARY.md`.

## Test counts (cumulative)

| Plan | Tests added | Cumulative `flutter test` |
|---|---|---|
| 01 | 21 | 21 |
| 02 | 10 | 31 |
| 03 | 26 | 57 (deduped — home_page tests count twice in raw add) |
| 04 | 0 (BLOCKED) | 57 |
| 05 | 12 (10 no-tracking unit + 2 no-network integration) | 64 (10 unit added; 2 integration not in `flutter test` count) |

`flutter test` final wall-clock: 64 unit/widget tests, all green. Plus 1 unrun integration test (no_network) ready for CI.

`flutter analyze`: clean (0 issues).
`dart format --set-exit-if-changed .`: clean.

## Phase 1 success criteria evaluation

| # | Criterion (per ROADMAP.md) | Status | Notes |
|---|---|---|---|
| 1 | `flutter run` works on iOS+Android | **PASSED (build proof)** | `flutter build apk --debug` ✓ (`build/app/outputs/flutter-apk/app-debug.apk`); `flutter build ios --no-codesign --debug` ✓ (`build/ios/iphoneos/Runner.app`). Real-device run requires `human_needed`. |
| 2 | Home screen shows two rooms, navigable to placeholders | **PASSED** | 8 home_page tests green incl. tap-each-room → placeholder route assertions. |
| 3 | Parent gate primitive with 3s ring fill exists; gates settings stub | **PASSED** | 9 parent_gate tests green; `find.byKey(Key('parent-gate-ring'))` confirmed; `Stillingar` placeholder exists; full long-press→navigate flow tested. |
| 4 | Marionette E2E smoke test runs | **NOT MET (blocked)** | Plan 04 checkpoint — Marionette package does not exist on pub.dev. Marker `if: false` in CI YAML. User decision required. |
| 5 | CI workflow + no-tracking SDK check works | **PASSED** | `.github/workflows/ci.yml` valid YAML; `tools/check-no-tracking.sh` + self-test detect all 9 banned packages locally. CI itself not yet pushed/run. |

## Files created / modified (consolidated)

**Created (substantive):**
- Phase 1 source: 9 Dart files under `lib/` (app, core, features)
- Phase 1 tests: 11 Dart files under `test/` + 1 under `integration_test/`
- Codegen: 4 generated Dart files (`*.g.dart`, `database.steps.dart`, schema_v1.dart)
- Tooling: 4 shell scripts under `tools/`
- CI: `.github/workflows/ci.yml`
- Schema: `drift_schemas/drift_schema_v1.json`
- Project meta: `.fvmrc`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `build.yaml`, `.gitignore`

**Modified (Flutter scaffold):**
- `ios/Runner.xcodeproj/project.pbxproj` (bundle ID is.hugrun.app)
- `ios/Runner/Info.plist` (CFBundleDisplayName=Hugrún)
- `android/app/build.gradle.kts` (applicationId+namespace=is.hugrun.app)
- `android/app/src/main/AndroidManifest.xml` (label=Hugrún)
- `android/app/src/main/kotlin/is/hugrun/app/MainActivity.kt` (moved + repackaged)

## Atomic commits made (chronological)

| Hash | Plan | Phase | Type | Message (truncated) |
|---|---|---|---|---|
| `5dfd52a` | 01 | RED | test | scaffold flutter project + failing home page widget test |
| `2e4a1ef` | 01 | GREEN | feat | bootstrap Hugrún app — Icelandic MaterialApp + HomePage placeholder + ProviderScope |
| `2507119` | 01 | REFACTOR | chore | lock pubspec, verify skeleton + Riverpod family + drift_flutter |
| `a82e2fd` | 02 | RED | test | add failing Drift DAO/migration/bootstrap tests |
| `0dd6206` | 02 | GREEN | feat | add Drift v1 schema + DAO + bootstrap + Riverpod provider |
| `76867cf` | 02 | REFACTOR | chore | commit drift v1 schema snapshot + wire schemaAt(1) migration test |
| `7ff0c05` | 03 | RED | test | add failing tests for two-room shell + parent gate |
| `b09d95f` | 03 | GREEN | feat | implement ParentGate primitive (3s hold + ring fill, no haptics) |
| `22c03c6` | 03 | GREEN | feat | two-room home shell + Stafir/Tölur/ParentSettings placeholders + parent-gate-wired settings entry |
| `426d32f` | 05 | RED | test | add failing tests for CI guards + no-network override |
| `889d511` | 05 | GREEN | feat | implement CI guard scripts + NoNetworkHttpOverrides |
| `66b43af` | 05 | GREEN | ci | wire GitHub Actions with 3 jobs |

**Total: 12 atomic commits.** Plan 04: 0 commits (BLOCKED).

## Outstanding work (deferred or blocked)

### BLOCKED — requires user decision
1. **Plan 04 (Marionette E2E) — package identification.** User must approve `marionette_flutter ^0.5.0` (the leancodepl MCP-based agent harness that PROJECT.md most likely refers to) OR escalate to `/gsd-discuss-phase`.

### Real-device verification (`human_needed`)
2. **`flutter run` on actual iPad / Android tablet.** Build artifacts exist (`flutter build apk --debug` and `flutter build ios --no-codesign` both succeeded), but a physical-device run is recommended before declaring criterion 1 fully met. The user can:
   - iOS: `flutter run -d <iPad-simulator-id>` after `xcrun simctl list devices`
   - Android: `flutter run -d <emulator-id>` after `emulator -list-avds`

### Deferred to Phase 4 (per documented Plan 01 deviations)
3. **Riverpod codegen** — `riverpod_annotation` + `riverpod_generator` deferred until ecosystem aligns analyzer versions across drift_dev / riverpod_generator / Flutter SDK. Phase 1 hand-written `appDatabaseProvider` is trivial and not blocking.
4. **freezed + flutter_gen_runner + custom_lint + riverpod_lint** — deferred for the same analyzer/build-runner conflict.
5. **drift / drift_flutter** version bump to 2.32.x / 0.3.x — once Flutter SDK ships unbundled meta/test_api.

### Phase 1 CI never run
6. **Push and observe.** The CI YAML is committed but never executed. Recommend `git push -u origin main` (or open a PR) to validate the three jobs run as designed before declaring Phase 1 "merged."

## Status
**4 of 5 plans complete.** Plan 04 blocked pending user/orchestrator decision on Marionette package identity. All other Phase 1 success criteria met within the constraints of local Flutter 3.38.7 + 2026-05-02 pub.dev ecosystem state.
