---
phase: 1
plan: 01
subsystem: bootstrap
tags: [flutter, riverpod, skeleton, tdd]
tech-stack:
  added:
    - flutter_riverpod ^3.3.1
    - drift ^2.28.x
    - drift_flutter ^0.2.7
    - just_audio ^0.10.5
    - audio_session ^0.2.3
    - path_provider ^2.1.5
    - flutter_localizations (sdk)
  patterns:
    - feature-first directory layout with peer mechanics/ (D-07)
    - hand-written Riverpod providers (codegen deferred — D-02 extension)
key-files:
  created:
    - .fvmrc
    - pubspec.yaml
    - pubspec.lock
    - analysis_options.yaml
    - lib/main.dart
    - lib/app/app.dart
    - lib/app/locale.dart
    - lib/features/home/home_page.dart
    - test/app/app_test.dart
    - test/features/home/home_page_test.dart
    - test/skeleton/skeleton_test.dart
    - 11 .gitkeep files (empty leaf folders)
  modified:
    - .gitignore
    - ios/Runner.xcodeproj/project.pbxproj (bundle id is.hugrun.app)
    - ios/Runner/Info.plist (CFBundleDisplayName=Hugrún)
    - android/app/build.gradle.kts (applicationId+namespace=is.hugrun.app)
    - android/app/src/main/AndroidManifest.xml (label=Hugrún)
    - android/app/src/main/kotlin/is/hugrun/app/MainActivity.kt (moved + repackaged)
decisions: []
metrics:
  duration: ~25 min
  tasks: 3
  tests: 21 passing (17 skeleton + 1 app + 3 home)
  completed: 2026-05-02
---

# Phase 1 Plan 01: Bootstrap Summary

Bootstrapped a runnable Flutter project for Hugrún (iOS + Android), with the Phase 1 dependency manifest, the full feature-first directory skeleton (D-07), an Icelandic-locale `MaterialApp` wrapped in `ProviderScope`, and a passing widget-test suite.

## Final Flutter SDK
- `.fvmrc` pins **Flutter 3.38.7** (current local stable; research suggested 3.41.5 but that has not yet shipped to local channels).

## Final Riverpod family
- `flutter_riverpod ^3.3.1` only.
- `riverpod_annotation` and `riverpod_generator` are **deferred to Phase 4** — see Deviations below. Phase 1 has only one provider (`appDatabaseProvider`, Plan 02) and hand-writing it is trivial.

## Files Created

| Path | Purpose |
|---|---|
| `.fvmrc` | Pin Flutter to 3.38.7 |
| `pubspec.yaml` + `pubspec.lock` | Phase 1 deps with version-conflict notes |
| `analysis_options.yaml` | flutter_lints + strict mode + practical rules |
| `lib/main.dart` | App entry — `runApp(ProviderScope(child: HugrunApp()))` |
| `lib/app/app.dart` | `HugrunApp` MaterialApp w/ title 'Hugrún', Icelandic locale, localizationsDelegates |
| `lib/app/locale.dart` | `kIcelandicLocale` constant |
| `lib/features/home/home_page.dart` | Placeholder Scaffold (Plan 03 replaces) |
| `test/app/app_test.dart` | 1 test (HugrunApp uses Icelandic locale) |
| `test/features/home/home_page_test.dart` | 3 tests (HomePage renders, has Scaffold, title='Hugrún' + supports 'is') |
| `test/skeleton/skeleton_test.dart` | 17 tests (D-07 dirs + pubspec family pins) |
| 11 × `.gitkeep` | Empty leaf folders per D-07 |

## Test Results
```
flutter test
00:01 +21: All tests passed!
flutter analyze
No issues found! (ran in 1.7s)
dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 8.4s with 85 outputs (178 actions)
dart format --set-exit-if-changed .
0 changed
```

## Deviations from CONTEXT decisions

These deviations are **forced by the actual ecosystem state on pub.dev as of 2026-05-02** combined with **local Flutter 3.38.7's bundled SDK pins**. Each is logged here per Rule 1 / Rule 3 (auto-fix blocking issues).

### Dev_1 (Riverpod codegen deferred — D-01 / D-02 extension)
- **Plan said:** Pin Riverpod 4.x family + use `@riverpod` codegen.
- **Actual:** `flutter_riverpod` latest is 3.3.1 (not 4.x); `riverpod_generator 4.0.3` requires analyzer ^9 while `drift_dev 2.28+` requires build ^3 / analyzer 7-9. The two codegens can almost align but Flutter 3.38.7's bundled meta 1.17.0 / test_api 0.7.7 force older versions of each.
- **Action:** Use `flutter_riverpod: ^3.3.1` only, **no codegen**. Phase 1 has exactly one provider (`appDatabaseProvider`, Plan 02), which is trivially hand-written. Phase 4 (when AudioEngine lands) re-evaluates and migrates to codegen if/when the ecosystem aligns.

### Dev_2 (drift_flutter 0.2.7 instead of 0.3.0)
- **Plan said:** Use `drift_flutter ^0.3.0` (D-06).
- **Actual:** `drift_flutter 0.3.0` requires `sqlite3 ^3.0.0`, which forces `drift_dev` to analyzer 10+, which conflicts with Flutter 3.38.7 SDK-bundled `meta 1.17.0`.
- **Action:** Pin to `drift_flutter ^0.2.7` (sqlite3 ^2.4.6, drift ^2.21+ ish). The "no `sqlite3_flutter_libs` direct dep" intent of D-06 is preserved — `drift_flutter` still pulls it transitively. Phase 4 revisits after Flutter SDK upgrade.

### Dev_3 (drift 2.28.x instead of 2.32.x)
- **Plan said:** Use `drift ^2.32.1`.
- **Actual:** `drift_dev 2.32.1` requires analyzer ^10 (incompatible with Flutter SDK-bundled deps); `drift_dev 2.30.x` uses `build ^4` which requires build_runner 2.10+ which generates Dart-build-hook scripts that `dart compile` cannot run.
- **Action:** Pin to `drift: >=2.28.0 <2.29.0` and `drift_dev: >=2.28.0 <2.28.2`. This is the last drift_dev that uses `build ^2`, allowing `build_runner ^2.4.x` (which generates `dart compile`-compatible scripts).

### Dev_4 (build_runner 2.4.x instead of 2.10.4+)
- **Plan said:** `build_runner ^2.10.4`.
- **Actual:** build_runner 2.10+ generates entry-point scripts using Dart's new "build hook" feature. `dart compile` (used by `flutter pub run build_runner`) does not support build hooks; only the new `dart build` command does, and that's not yet wired through `flutter pub run`.
- **Action:** Pin to `build_runner: >=2.4.0 <2.5.0`. Verified: `dart run build_runner build` succeeds with 178 actions in 8.4s.

### Dev_5 (freezed deferred to Phase 4)
- **Plan said:** Add `freezed_annotation ^3.2.0` runtime + `freezed ^3.2.3` dev.
- **Actual:** Even pinned to `freezed 3.2.3` (analyzer 7-9), the conflict with `drift_dev` (build ^3-^5) is resolvable only at the cost of older builds that don't function. freezed 3.2.3 needs build ^3, drift_dev 2.28.1 uses build ^2.
- **Action:** Drop freezed entirely from Phase 1. Phase 1 has zero `@freezed`-annotated types — the only data class is the auto-generated Drift `ChildProfile` companion (Plan 02). Phase 4 brings freezed back when `Letter` / `Word` / `AudioClip` immutable models land.

### Dev_6 (flutter_gen_runner deferred to Phase 2)
- **Plan said:** `flutter_gen_runner ^5.10.0` for typed asset references.
- **Actual:** flutter_gen_runner 5.x requires build_runner 2.10+ (same Dart 3.10.7 build-hook conflict as Dev_4).
- **Action:** Drop. Phase 1 has no audio assets to reference. Phase 2 (audio asset baking) revisits.

### Dev_7 (custom_lint + riverpod_lint deferred)
- **Plan said:** `custom_lint ^0.7.0` + `riverpod_lint ^3.0.0`.
- **Actual:** custom_lint 0.8.x (newest) needs analyzer ^8; drift_dev 2.32.1 needs analyzer ^10. Even pinning to drift_dev 2.28.x, riverpod_lint 3.x requires custom_lint 0.7+, which requires analyzer 7-8 — clashes with build_runner / drift transitive deps.
- **Action:** Defer until Phase 4. Lints provided by `flutter_lints ^6.0.0` + analysis_options strict mode are sufficient for Phase 1.

### Dev_8 (flutter_localizations added — Rule 1 / Rule 2 inline fix)
- **Plan didn't mention** `flutter_localizations` in pubspec. But once `MaterialApp(supportedLocales: [Locale('is')])` was wired, the test failed with "A MaterialLocalizations delegate that supports the is locale was not found."
- **Action:** Add `flutter_localizations: { sdk: flutter }` and wire `localizationsDelegates: [GlobalMaterial..., GlobalWidgets..., GlobalCupertino...].delegate` into `HugrunApp`. This is Rule 2 (auto-add missing critical functionality — the locale wiring is incomplete without it).

### Dev_9 (test/widget_test.dart removed)
- **Plan said:** Replace counter-app boilerplate with placeholder file.
- **Actual:** A file with `// comments only` and no `void main()` causes Flutter test runner to fail with "Undefined name 'main'."
- **Action:** Delete `test/widget_test.dart` entirely. Real widget tests live under `test/features/home/home_page_test.dart` and `test/app/app_test.dart`.

## Commits (atomic, RED→GREEN→REFACTOR)
- `5dfd52a` test(01-01): scaffold flutter project + failing home page widget test (RED)
- `2e4a1ef` feat(01-01): bootstrap Hugrún app — Icelandic MaterialApp + HomePage placeholder + ProviderScope (GREEN)
- `2507119` chore(01-01): lock pubspec, verify skeleton + Riverpod family + drift_flutter (REFACTOR)

## Self-Check
- All 21 tests passing (`flutter test`)
- `flutter analyze` clean
- `dart format --set-exit-if-changed .` clean
- `dart run build_runner build` succeeds (no-op since no annotated sources yet)
- Bundle IDs verified: `is.hugrun.app` on both ios pbxproj + android build.gradle.kts
- App labels verified: `Hugrún` in Info.plist + AndroidManifest.xml
- D-07 directory skeleton complete with .gitkeep markers

## Status
**COMPLETE — GREEN** with documented deviations. All Phase 1 Plan 01 success criteria met within the constraints of local Flutter 3.38.7 and the mid-migration pub.dev ecosystem.
