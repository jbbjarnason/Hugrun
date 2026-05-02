---
phase: 01-skeleton-drift-schema
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - pubspec.yaml
  - .fvmrc
  - analysis_options.yaml
  - .gitignore
  - lib/main.dart
  - lib/app/app.dart
  - lib/app/locale.dart
  - lib/features/home/home_page.dart
  - test/app/app_test.dart
  - test/features/home/home_page_test.dart
  - test/widget_test.dart
  - ios/Runner.xcodeproj/project.pbxproj
  - ios/Runner/Info.plist
  - android/app/build.gradle
  - android/app/src/main/AndroidManifest.xml
  - android/app/src/main/kotlin/is/hugrun/app/MainActivity.kt
  - assets/.gitkeep
  - lib/core/audio/.gitkeep
  - lib/core/db/.gitkeep
  - lib/core/parent_gate/.gitkeep
  - lib/core/manifest/.gitkeep
  - lib/features/stafir/.gitkeep
  - lib/features/tolur/.gitkeep
  - lib/features/parent_settings/.gitkeep
  - lib/mechanics/.gitkeep
  - lib/gen/.gitkeep
autonomous: true
requirements:
  - FOUND-01
  - FOUND-02
  - FOUND-06
user_setup: []

must_haves:
  truths:
    - "Running `flutter run` (or `fvm flutter run`) on iOS Simulator launches the Hugrún app and shows a placeholder home screen"
    - "Running `flutter run` on Android Emulator launches the Hugrún app and shows the same home screen"
    - "The app bundle ID is `is.hugrun.app` on both platforms"
    - "The app launcher name shows `Hugrún` on both platforms"
    - "The app's runtime locale is Icelandic (`is`)"
    - "Riverpod 4.x family, Drift 2.32+, drift_flutter 0.3+, just_audio 0.10.x, audio_session 0.2.x, freezed 3.x, build_runner, riverpod_generator 4.x, drift_dev 2.32+, freezed 3.x, flutter_gen_runner 5.x, and flutter_lints 6.x are present in pubspec.yaml with consistent versions"
    - "`flutter test` runs at least one passing widget test that asserts the home screen renders"
    - "The full feature-first directory skeleton (D-07) exists with `.gitkeep` files in stub folders"
  artifacts:
    - path: "pubspec.yaml"
      provides: "All Phase 1 pinned dependencies and asset declarations"
      contains: "flutter_riverpod"
    - path: ".fvmrc"
      provides: "Flutter SDK version pin (D-14)"
      contains: "flutter"
    - path: "analysis_options.yaml"
      provides: "Lint config + custom rule preventing Flutter imports in domain layer (D-08)"
      contains: "include:"
    - path: "lib/main.dart"
      provides: "App entry point with ProviderScope"
      contains: "ProviderScope"
    - path: "lib/app/app.dart"
      provides: "MaterialApp root widget with Icelandic locale + Hugrún title"
      contains: "MaterialApp"
    - path: "lib/features/home/home_page.dart"
      provides: "Placeholder home screen widget"
      contains: "class HomePage"
    - path: "test/features/home/home_page_test.dart"
      provides: "Widget test asserting HomePage renders"
      contains: "testWidgets"
  key_links:
    - from: "lib/main.dart"
      to: "lib/app/app.dart"
      via: "import + runApp(ProviderScope(child: HugrunApp()))"
      pattern: "ProviderScope.*HugrunApp"
    - from: "lib/app/app.dart"
      to: "lib/features/home/home_page.dart"
      via: "MaterialApp(home: HomePage())"
      pattern: "home:.*HomePage"
    - from: "pubspec.yaml"
      to: "Flutter test runner"
      via: "dev_dependencies: flutter_test, integration_test"
      pattern: "flutter_test:"
---

<objective>
Bootstrap the Hugrún Flutter project from a blank repo into a runnable iOS+Android app with all Phase 1 pubspec dependencies pinned, the full feature-first directory skeleton (D-07) in place, an Icelandic-locale `MaterialApp` wrapped in a `ProviderScope`, a placeholder home screen, and the TDD scaffolding (a passing widget test) that every later plan extends.

Purpose: Establish the architectural foundations every subsequent Phase 1 plan (database, rooms+gate, Marionette E2E, CI guards) depends on. Without this plan, no other plan can run because no Flutter project exists. Implements requirements FOUND-01 (Flutter on iOS+Android via fvm), FOUND-02 (Riverpod/Drift/just_audio in pubspec at consistent versions), and FOUND-06 (TDD workflow established — first failing-then-passing widget test committed).

Output: A Flutter project at the repo root with a runnable iOS+Android app, full directory skeleton per D-07, pinned pubspec, `.fvmrc`, analysis options, app ID `is.hugrun.app`, app name "Hugrún", Icelandic locale, and one passing widget test.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-skeleton-drift-schema/01-CONTEXT.md
@.planning/research/STACK.md
@.planning/research/ARCHITECTURE.md

<interfaces>
<!-- This plan creates the contracts that later plans (02 database, 03 rooms+gate) consume. -->
<!-- Key public types/exports introduced in this plan: -->

From `lib/app/app.dart`:
```dart
class HugrunApp extends StatelessWidget {
  const HugrunApp({super.key});
  // MaterialApp with title 'Hugrún', supportedLocales: [Locale('is')], locale: Locale('is')
  // home: HomePage()
}
```

From `lib/features/home/home_page.dart` (Phase 1 placeholder; Plan 03 replaces with two-room version):
```dart
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  // Renders Scaffold with placeholder content. Plan 03 will replace this body
  // with two room buttons (Stafir, Tölur) plus a parent-gate-wrapped settings entry.
}
```

From `lib/main.dart`:
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HugrunApp()));
}
```

From `pubspec.yaml` — runtime dependency manifest (target versions, verify alignment with `dart pub outdated` per D-01):
- flutter_riverpod ^4.x  (Riverpod 4 family — D-01)
- riverpod_annotation ^4.x
- drift ^2.32.1
- drift_flutter ^0.3.0  (D-06; do NOT add sqlite3_flutter_libs)
- just_audio ^0.10.5
- audio_session ^0.2.3
- freezed_annotation ^3.2.0

From `pubspec.yaml` — dev dependencies:
- flutter_test (sdk: flutter)
- integration_test (sdk: flutter)
- flutter_lints ^6.0.0
- build_runner ^2.10.4
- riverpod_generator ^4.x
- drift_dev ^2.32.1
- freezed ^3.2.3
- flutter_gen_runner ^5.10.0

(Marionette is added by Plan 04. Test/CI scripts are added by Plan 05.)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Run `flutter create` and write the first failing widget test (RED)</name>
  <files>
    pubspec.yaml,
    .fvmrc,
    .gitignore,
    test/widget_test.dart,
    test/features/home/home_page_test.dart
  </files>
  <behavior>
    Test 1 (test/features/home/home_page_test.dart): Pumping `ProviderScope(child: MaterialApp(home: HomePage()))` finds exactly one `HomePage` widget. Test MUST fail initially because `HomePage` doesn't exist yet.
    Test 2 (test/features/home/home_page_test.dart): The pumped app contains a `Scaffold`. Test MUST fail initially.
    Test 3 (test/features/home/home_page_test.dart): The pumped app's MaterialApp `title` is `'Hugrún'` and `supportedLocales` contains `Locale('is')`. Test MUST fail initially because `HugrunApp` doesn't exist.
  </behavior>
  <action>
    Per D-14, the goal is a runnable Flutter app pinned to a specific stable Flutter SDK via fvm. Execute these steps in order:

    1. From `/Users/jonb/Projects/hugrun/`, run `flutter --version` and capture the current stable Flutter version as `$FLUTTER_STABLE` (e.g. `3.41.5` or whatever stable shows). If the system Flutter is stable channel, use its exact version. Otherwise switch the system to `flutter channel stable && flutter upgrade` first.

    2. Run: `flutter create --org is.hugrun --project-name hugrun --platforms=ios,android --description "Icelandic literacy and numeracy for Hugrún" .`
       - Note: org `is.hugrun` + project name `hugrun` produces bundle ID `is.hugrun.hugrun`. We need `is.hugrun.app` per CONTEXT specifics. After creation, manually patch:
         - `ios/Runner.xcodeproj/project.pbxproj`: set `PRODUCT_BUNDLE_IDENTIFIER = is.hugrun.app;` for all three Runner build configs (Debug/Profile/Release).
         - `android/app/build.gradle` (or `build.gradle.kts` if Flutter 3.41 produced Kotlin DSL): set `applicationId "is.hugrun.app"` and `namespace "is.hugrun.app"`.
         - Move `MainActivity.kt` to `android/app/src/main/kotlin/is/hugrun/app/MainActivity.kt` and update its package declaration to `package is.hugrun.app`.
         - Set the Android launcher name via `android/app/src/main/AndroidManifest.xml`: `android:label="Hugrún"`.
         - Set the iOS display name via `ios/Runner/Info.plist`: `CFBundleDisplayName = Hugrún` and `CFBundleName = Hugrun` (CFBundleName must be ASCII for some toolchains).

    3. Create `.fvmrc` with content `{"flutter": "$FLUTTER_STABLE"}` substituting the version captured in step 1. Per D-14, fvm itself is not required to be installed locally yet; this just records the pin so CI (Plan 05) can install fvm and use it.

    4. Edit the generated `.gitignore` to additionally exclude `.fvm/` (fvm cache dir) and confirm it already excludes `*.g.dart` patterns (Drift/Riverpod codegen output is gitignored except `lib/gen/audio_manifest.g.dart` which Plan 02 will be added later by Phase 2 work — Phase 1 keeps `lib/gen/` empty besides `.gitkeep`).

    5. Replace generated `pubspec.yaml` with the Phase 1 pinned manifest. Use these dependencies (verify each version with `flutter pub outdated --show-all` AFTER the file is written; if any pin is unavailable, escalate to user — do NOT silently downgrade):

       Runtime:
       - flutter_riverpod: ^4.0.0
       - riverpod_annotation: ^4.0.0
       - drift: ^2.32.1
       - drift_flutter: ^0.3.0
       - just_audio: ^0.10.5
       - audio_session: ^0.2.3
       - freezed_annotation: ^3.2.0

       Dev:
       - flutter_test: { sdk: flutter }
       - integration_test: { sdk: flutter }
       - flutter_lints: ^6.0.0
       - build_runner: ^2.10.4
       - riverpod_generator: ^4.0.0
       - drift_dev: ^2.32.1
       - freezed: ^3.2.3
       - flutter_gen_runner: ^5.10.0
       - custom_lint: ^0.7.0   # required by riverpod_lint companion (riverpod 4 ships with custom_lint analyzer plugin)
       - riverpod_lint: ^3.0.0  # verify version aligns with riverpod 4.x family at install

       Add an `assets:` section listing `assets/` (single trailing slash) so future audio + image asset folders are picked up automatically.

       Set `environment.sdk: ">=3.9.0 <4.0.0"`.

       Set `name: hugrun`, `description: "Icelandic literacy and numeracy for Hugrún"`.

       DO NOT add `sqlite3_flutter_libs` (D-06; banned per research Finding 7). DO NOT add any package on the Plan 05 block-list (firebase_*, sentry_flutter, mixpanel_flutter, amplitude_flutter, google_mobile_ads, in_app_purchase, app_tracking_transparency, flutter_facebook_audience_network).

    6. Delete the auto-generated counter widget test in `test/widget_test.dart` (the `flutter create` boilerplate that tests the demo MyApp). Replace it with a one-line file that imports the new home page test or just contains a comment pointing to `test/features/home/home_page_test.dart`. Or simply delete it if there's no aggregator. (Aim: no orphaned tests referring to the demo `MyApp`.)

    7. Create `test/features/home/home_page_test.dart` with three failing tests as specified in `<behavior>`:
       ```dart
       import 'package:flutter/material.dart';
       import 'package:flutter_riverpod/flutter_riverpod.dart';
       import 'package:flutter_test/flutter_test.dart';
       import 'package:hugrun/app/app.dart';
       import 'package:hugrun/features/home/home_page.dart';

       void main() {
         testWidgets('HomePage renders inside HugrunApp', (tester) async {
           await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
           expect(find.byType(HomePage), findsOneWidget);
         });

         testWidgets('HomePage renders a Scaffold', (tester) async {
           await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
           expect(find.byType(Scaffold), findsOneWidget);
         });

         testWidgets('HugrunApp title is "Hugrún" with Icelandic locale', (tester) async {
           await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
           final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
           expect(app.title, 'Hugrún');
           expect(app.supportedLocales, contains(const Locale('is')));
         });
       }
       ```

    8. Run `flutter pub get`. Then run `flutter test`. Both home_page tests MUST fail with compile errors (HomePage / HugrunApp do not exist yet). This is the RED state — capture the failure output as proof, then proceed to Task 2.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter pub get &amp;&amp; ! flutter test test/features/home/home_page_test.dart 2&gt;&amp;1 | tee /tmp/hugrun-task1-red.log; grep -q "Error\|FAILED\|exception\|HomePage" /tmp/hugrun-task1-red.log</automated>
  </verify>
  <done>
    - Flutter project scaffolding exists (pubspec, ios/, android/, lib/, test/).
    - Bundle ID is `is.hugrun.app` on both platforms; launcher label is `Hugrún` on both.
    - `.fvmrc` exists pinning Flutter SDK to a captured stable version.
    - pubspec.yaml lists every Phase 1 dependency at the versions above; running `flutter pub get` succeeds.
    - `test/features/home/home_page_test.dart` exists with 3 tests that currently FAIL because `HugrunApp`/`HomePage` are not implemented.
    - No banned analytics/ads/IAP packages appear in pubspec.yaml or pubspec.lock.
    - Generated demo widget test (`test/widget_test.dart`) does not reference the auto-generated counter MyApp.
    - Commit: `test(01-01): scaffold flutter project + failing home page widget test (RED)`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Implement HugrunApp + HomePage placeholder + Icelandic locale + ProviderScope wiring (GREEN)</name>
  <files>
    lib/main.dart,
    lib/app/app.dart,
    lib/app/locale.dart,
    lib/features/home/home_page.dart,
    analysis_options.yaml,
    .gitignore,
    assets/.gitkeep,
    lib/core/audio/.gitkeep,
    lib/core/db/.gitkeep,
    lib/core/parent_gate/.gitkeep,
    lib/core/manifest/.gitkeep,
    lib/features/stafir/.gitkeep,
    lib/features/tolur/.gitkeep,
    lib/features/parent_settings/.gitkeep,
    lib/mechanics/.gitkeep,
    lib/gen/.gitkeep,
    test/app/app_test.dart
  </files>
  <behavior>
    The 3 widget tests from Task 1 MUST pass after this task. Additionally:
    Test 4 (test/app/app_test.dart): `HugrunApp` MaterialApp uses `Locale('is')` as its `locale` (not just supportedLocales). Test MUST pass after implementation.
  </behavior>
  <action>
    Implement the minimum code to turn the Task 1 tests green and stand up the full feature-first skeleton per D-07.

    1. Create `lib/app/locale.dart`:
       ```dart
       import 'package:flutter/widgets.dart';

       /// The single locale Hugrún supports. Per PROJECT.md "Localization beyond
       /// Icelandic is explicitly out of scope."
       const Locale kIcelandicLocale = Locale('is');

       /// Supported locales list for MaterialApp.supportedLocales. Single-entry by design.
       const List<Locale> kSupportedLocales = <Locale>[kIcelandicLocale];
       ```

    2. Create `lib/features/home/home_page.dart` as a Phase 1 placeholder. Plan 03 replaces this body with two rooms + parent gate; for now keep it minimal:
       ```dart
       import 'package:flutter/material.dart';

       /// Placeholder home page. Plan 01-03 replaces the body with the two-room
       /// (Stafir / Tölur) shell + parent gate to ParentSettingsScreen. Lives here
       /// now so widget tests can compile and the app can run end-to-end.
       class HomePage extends StatelessWidget {
         const HomePage({super.key});

         @override
         Widget build(BuildContext context) {
           return const Scaffold(
             body: Center(
               child: Text('Hugrún', textDirection: TextDirection.ltr),
             ),
           );
         }
       }
       ```

    3. Create `lib/app/app.dart`:
       ```dart
       import 'package:flutter/material.dart';
       import '../features/home/home_page.dart';
       import 'locale.dart';

       /// Root MaterialApp. Icelandic-only locale per project constraint.
       /// Title shown in app launcher metadata; the launcher label itself comes
       /// from native manifests (Info.plist / AndroidManifest.xml).
       class HugrunApp extends StatelessWidget {
         const HugrunApp({super.key});

         @override
         Widget build(BuildContext context) {
           return MaterialApp(
             title: 'Hugrún',
             locale: kIcelandicLocale,
             supportedLocales: kSupportedLocales,
             home: const HomePage(),
             debugShowCheckedModeBanner: false,
           );
         }
       }
       ```

    4. Replace generated `lib/main.dart`:
       ```dart
       import 'package:flutter/widgets.dart';
       import 'package:flutter_riverpod/flutter_riverpod.dart';
       import 'app/app.dart';

       void main() {
         WidgetsFlutterBinding.ensureInitialized();
         runApp(const ProviderScope(child: HugrunApp()));
       }
       ```

    5. Create the full feature-first skeleton (D-07). Add `.gitkeep` files to every empty folder so the structure is committed:
       - `lib/core/audio/.gitkeep` (placeholder — Plan 04 will fill)
       - `lib/core/db/.gitkeep` (Plan 02 fills)
       - `lib/core/parent_gate/.gitkeep` (Plan 03 fills)
       - `lib/core/manifest/.gitkeep` (Phase 2 fills)
       - `lib/features/stafir/.gitkeep` (Plan 03 adds StafirRoom; Phase 2+ fills)
       - `lib/features/tolur/.gitkeep` (Plan 03 adds TolurRoom; Phase 8+ fills)
       - `lib/features/parent_settings/.gitkeep` (Plan 03 adds stub screen)
       - `lib/mechanics/.gitkeep` (Phase 4+ fills)
       - `lib/gen/.gitkeep` (Phase 2 generates audio manifest here)
       - `assets/.gitkeep` (Phase 2+ adds audio + images)

    6. Create `analysis_options.yaml`:
       ```yaml
       include: package:flutter_lints/flutter.yaml

       analyzer:
         language:
           strict-casts: true
           strict-inference: true
           strict-raw-types: true
         exclude:
           - "**/*.g.dart"
           - "**/*.freezed.dart"
           - "build/**"
           - ".dart_tool/**"
         plugins:
           - custom_lint  # for riverpod_lint

       linter:
         rules:
           # Discretion: pragmatic strict-but-not-pedantic set
           always_declare_return_types: true
           avoid_print: true
           prefer_const_constructors: true
           prefer_const_declarations: true
           prefer_final_fields: true
           prefer_final_locals: true
           require_trailing_commas: true
           sort_pub_dependencies: false  # we group by category, not alphabetically

       # Custom rule for D-08 (domain layer purity) is enforced by Plan 05's
       # tools/check-domain-purity.sh — this analysis_options does NOT carry that
       # logic since `analyzer` extension API doesn't support per-file import
       # restrictions natively. The CI script greps for `package:flutter` imports
       # in domain files instead. See Plan 05 for the implementation.
       ```

    7. Create `test/app/app_test.dart` to add the 4th test:
       ```dart
       import 'package:flutter/widgets.dart';
       import 'package:flutter_riverpod/flutter_riverpod.dart';
       import 'package:flutter_test/flutter_test.dart';
       import 'package:hugrun/app/app.dart';
       import 'package:flutter/material.dart';

       void main() {
         testWidgets('HugrunApp uses Icelandic locale', (tester) async {
           await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
           final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
           expect(app.locale, const Locale('is'));
         });
       }
       ```

    8. Run `flutter pub get && flutter test`. ALL FOUR tests (3 from Task 1 + 1 from this task) MUST pass. If any fail, fix the implementation, not the tests.

    9. Run `flutter analyze`. MUST exit 0 with no issues.

    10. Smoke-launch on at least one platform locally if a device/simulator is attached: `flutter run -d <device_id>`. App must launch and show the centered "Hugrún" text. If no device is attached, skip — Plan 04 (Marionette) and Plan 05 (CI) will exercise this on iOS Simulator + Android Emulator. Document attempt in commit message.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter pub get &amp;&amp; flutter analyze &amp;&amp; flutter test test/features/home/home_page_test.dart test/app/app_test.dart</automated>
  </verify>
  <done>
    - All 4 widget tests pass (`flutter test`).
    - `flutter analyze` exits 0.
    - `lib/main.dart` wraps `HugrunApp` in `ProviderScope`.
    - `lib/app/app.dart` `MaterialApp` has `title: 'Hugrún'`, `locale: Locale('is')`, `supportedLocales: [Locale('is')]`.
    - Full feature-first skeleton (D-07) exists with `.gitkeep` files in every folder noted above.
    - `analysis_options.yaml` includes `flutter_lints` and configures `custom_lint` for riverpod_lint.
    - Commit: `feat(01-01): bootstrap Hugrún app — Icelandic MaterialApp + HomePage placeholder + ProviderScope (GREEN)`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Refactor — pubspec lock verification, codegen smoke, and skeleton sanity</name>
  <files>
    pubspec.lock,
    pubspec.yaml,
    test/app/app_test.dart,
    test/skeleton/skeleton_test.dart
  </files>
  <behavior>
    Test 5 (test/skeleton/skeleton_test.dart): Verifies the full feature-first directory layout exists by listing key paths and asserting they are accessible at file-system level (the test reads `Directory` listings from the project root). This is a meta-test: it pins D-07's structure so future refactors don't silently delete a folder.
    Test 6 (test/skeleton/skeleton_test.dart): Verifies pubspec.lock contains expected major versions for the locked Riverpod/Drift/just_audio family — fails the build if a transitive resolution downgrades any package out of family.
    All Task 1+2 tests must remain green.
  </behavior>
  <action>
    REFACTOR step (D-16). Tighten the bootstrap by adding self-checks that prevent silent regression of the directory layout and dependency family pins. No production code changes — only verification hardening.

    1. Run `flutter pub outdated --json` and review the output. Confirm the chosen pubspec versions resolve to the Riverpod 4.x family per D-01. If `flutter_riverpod` resolves to 3.x because no 4.x is published yet at execution time, escalate to user with a CHECKPOINT note in the commit message and the user can decide whether to drop to 3.x family. Do NOT silently mix 3.x runtime with 4.x annotations — it's a documented foot-gun (research Finding 6, PITFALLS Pitfall 7). If forced to drop to 3.x, ALSO drop `riverpod_annotation` and `riverpod_generator` to a 3.x-compatible major.

    2. Run a no-op codegen smoke: `dart run build_runner build --delete-conflicting-outputs`. This must complete without errors even though no `@riverpod`, `@DriftDatabase`, or `@freezed` annotations exist in lib/ yet. (build_runner runs to no-op success when there are no annotated source files.) Capture and commit the resulting `pubspec.lock` so subsequent CI gets identical resolutions.

    3. Create `test/skeleton/skeleton_test.dart`:
       ```dart
       import 'dart:io';
       import 'package:flutter_test/flutter_test.dart';

       void main() {
         group('Project skeleton (CONTEXT D-07)', () {
           const requiredDirs = <String>[
             'lib/app',
             'lib/core/audio',
             'lib/core/db',
             'lib/core/parent_gate',
             'lib/core/manifest',
             'lib/features/home',
             'lib/features/stafir',
             'lib/features/tolur',
             'lib/features/parent_settings',
             'lib/mechanics',
             'lib/gen',
             'test',
             'assets',
           ];
           for (final d in requiredDirs) {
             test('$d exists', () {
               expect(Directory(d).existsSync(), isTrue,
                   reason: 'D-07 requires $d to exist (with .gitkeep if empty)');
             });
           }
         });

         group('pubspec dependency family pins (D-01, D-06)', () {
           late String lock;
           setUpAll(() => lock = File('pubspec.lock').readAsStringSync());

           test('flutter_riverpod is 3.x or 4.x family (consistent)', () {
             // riverpod_annotation, riverpod_generator must agree.
             final core = RegExp(r'flutter_riverpod:\s*\n\s*dependency:.*?\n\s*description:.*?\n\s*source:.*?\n\s*version:\s*"(\d+)\.', dotAll: true).firstMatch(lock);
             final ann = RegExp(r'riverpod_annotation:\s*\n\s*dependency:.*?\n\s*description:.*?\n\s*source:.*?\n\s*version:\s*"(\d+)\.', dotAll: true).firstMatch(lock);
             expect(core, isNotNull, reason: 'flutter_riverpod must be in pubspec.lock');
             expect(ann, isNotNull, reason: 'riverpod_annotation must be in pubspec.lock');
             expect(core!.group(1), ann!.group(1),
                 reason: 'D-01: Riverpod runtime + annotation must share major version family');
           });

           test('drift_flutter present, sqlite3_flutter_libs is NOT a direct dep', () {
             expect(lock.contains('drift_flutter:'), isTrue);
             // sqlite3_flutter_libs may appear transitively but must not be marked
             // dependency: "direct main" — D-06 forbids direct dep.
             final transitive = RegExp(
               r'sqlite3_flutter_libs:\s*\n\s*dependency:\s*"direct main"',
             ).hasMatch(lock);
             expect(transitive, isFalse,
                 reason: 'D-06: sqlite3_flutter_libs must not be a direct dependency');
           });

           test('just_audio is 0.10.x family', () {
             final m = RegExp(r'just_audio:\s*\n\s*dependency:.*?\n\s*description:.*?\n\s*source:.*?\n\s*version:\s*"0\.(\d+)\.', dotAll: true).firstMatch(lock);
             expect(m, isNotNull);
             expect(int.parse(m!.group(1)!), greaterThanOrEqualTo(10));
           });
         });
       }
       ```

       Note: the regex tests are pragmatic — pubspec.lock format is stable but if Flutter changes its serialization, prefer parsing via `package:yaml`. We accept fragility here; the test exists primarily to fail loudly when someone tries to add `sqlite3_flutter_libs: ^x` directly to pubspec.

    4. Run `flutter test`. All tests (Task 1 + Task 2 + Task 3 = 6+ tests total) must pass.

    5. Run `dart format .` to normalize formatting; run `dart format --set-exit-if-changed .` to verify no diff remains.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; dart run build_runner build --delete-conflicting-outputs &amp;&amp; flutter test &amp;&amp; dart format --set-exit-if-changed . &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - `pubspec.lock` is committed with internally-consistent Riverpod family pins.
    - `dart run build_runner build` completes (no-op success).
    - `test/skeleton/skeleton_test.dart` passes — all D-07 directories exist; Riverpod runtime+annotation majors agree; drift_flutter present without direct sqlite3_flutter_libs; just_audio 0.10.x.
    - `dart format --set-exit-if-changed .` exits 0.
    - `flutter analyze` exits 0.
    - All 6+ tests pass under `flutter test`.
    - Commit: `chore(01-01): lock pubspec, verify skeleton + Riverpod family + drift_flutter (REFACTOR)`.
  </done>
</task>

</tasks>

<verification>
- `flutter pub get` resolves all dependencies.
- `flutter analyze` exits 0.
- `flutter test` runs 6+ tests all green.
- `dart run build_runner build --delete-conflicting-outputs` completes without errors (no-op since no annotated sources yet).
- `dart format --set-exit-if-changed .` exits 0.
- App ID is `is.hugrun.app` on both platforms (verified via grep on `Info.plist` and `build.gradle`).
- App launcher label is `Hugrún` on both platforms.
- `.fvmrc` exists with a real Flutter stable version.
- pubspec.yaml/lock contain Riverpod 4.x family (or consistent 3.x — escalated if forced).
- pubspec.yaml/lock contain `drift_flutter` but NOT `sqlite3_flutter_libs` as a direct dependency.
- pubspec.yaml does NOT list any banned analytics/ads/IAP package (this is verified at the project level by Plan 05's CI script; here we just visually confirm no banned imports made it in).
- Full D-07 directory skeleton exists with `.gitkeep` files committed.
</verification>

<success_criteria>
1. Running `flutter run` on a connected iOS Simulator OR Android Emulator launches the Hugrún app and shows a centered "Hugrún" placeholder home screen with no errors. (Local-only check; full CI on both platforms is Plan 04/05's job.)
2. The app bundle ID is `is.hugrun.app` on both iOS and Android.
3. The app launcher name displays "Hugrún" on both iOS and Android.
4. `flutter test` runs at least 6 widget/unit tests, all green, including assertions that HomePage renders inside HugrunApp with Icelandic locale.
5. The full feature-first directory skeleton from D-07 exists in the repo, with `.gitkeep` files committed for all empty leaf directories.
6. pubspec.yaml lists exactly the Phase 1 dependencies at the versions specified, with no banned analytics/ads/IAP packages, and pubspec.lock resolves a consistent Riverpod major-version family across runtime + annotation + generator.
7. `analysis_options.yaml` enforces `flutter_lints` + sensible strict mode flags + the `custom_lint` plugin for riverpod_lint.
</success_criteria>

<output>
After completion, create `.planning/phases/01-skeleton-drift-schema/01-01-SUMMARY.md` covering:
- Final Flutter SDK version pinned in `.fvmrc`
- Final Riverpod family major version chosen (3.x or 4.x — note any escalation)
- Files created (full list)
- Number of widget/unit tests + pass/fail counts
- Any deviations from CONTEXT.md decisions and why (should be zero)
- Commit hashes for RED/GREEN/REFACTOR cycles (3 atomic commits expected)
</output>
