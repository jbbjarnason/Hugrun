---
phase: 01-skeleton-drift-schema
plan: 05
type: execute
wave: 4
depends_on:
  - "01-02"
  - "01-04"
files_modified:
  - .github/workflows/ci.yml
  - tools/check-no-tracking.sh
  - tools/check-flutter-version.sh
  - tools/check-domain-purity.sh
  - tools/check-no-tracking_test.sh
  - integration_test/no_network_test.dart
  - integration_test/test_helpers/no_network_http_overrides.dart
  - test/tools/check_no_tracking_test.dart
  - .gitignore
autonomous: true

requirements:
  - FOUND-01
  - FOUND-06
  - FOUND-10
  - FOUND-11

user_setup:
  - service: github-actions
    why: "CI runs in GitHub Actions per D-12; user must have a GitHub repo with Actions enabled"
    env_vars: []
    dashboard_config:
      - task: "Confirm GitHub Actions is enabled for the repository (default for public repos; check Settings → Actions for private)"
        location: "GitHub repo → Settings → Actions → General"

must_haves:
  truths:
    - "A CI workflow file exists at .github/workflows/ci.yml with three jobs: analyze-and-test, integration-no-network, marionette-e2e (D-12)"
    - "CI triggers on push to main and on pull request (D-13)"
    - "tools/check-no-tracking.sh fails the build if pubspec.lock contains any of the 9 banned analytics/ads/IAP packages (D-20)"
    - "tools/check-flutter-version.sh warns (does not fail) when local Flutter doesn't match .fvmrc (D-15)"
    - "tools/check-domain-purity.sh fails if any pure-Dart domain file imports package:flutter (D-08 enforcement)"
    - "An integration test (integration_test/no_network_test.dart) installs NoNetworkHttpOverrides in setUp() and the test fails if any HTTP request is attempted during the play session (D-18)"
    - "A NoNetworkHttpOverrides class exists at integration_test/test_helpers/no_network_http_overrides.dart that throws on any outbound HTTP request"
    - "tools/check-no-tracking.sh has at least one self-test (a script-level test) that confirms it correctly detects a banned package when one is added to pubspec.lock"
    - "All three CI jobs pass when run against the current state of main"
    - "Locally runnable: each CI command can be reproduced from the developer's shell"
  artifacts:
    - path: ".github/workflows/ci.yml"
      provides: "GitHub Actions CI definition with 3 jobs"
      contains: "marionette-e2e"
    - path: "tools/check-no-tracking.sh"
      provides: "CI guard against analytics/ads/IAP SDKs (D-20)"
      contains: "firebase_analytics"
    - path: "tools/check-flutter-version.sh"
      provides: "Soft warning when Flutter version diverges from .fvmrc (D-15)"
      contains: ".fvmrc"
    - path: "tools/check-domain-purity.sh"
      provides: "Domain layer purity enforcement (D-08)"
      contains: "package:flutter"
    - path: "integration_test/test_helpers/no_network_http_overrides.dart"
      provides: "NoNetworkHttpOverrides class throwing on outbound HTTP (D-18)"
      contains: "class NoNetworkHttpOverrides"
    - path: "integration_test/no_network_test.dart"
      provides: "Integration test asserting no network calls during play (FOUND-10)"
      contains: "NoNetworkHttpOverrides"
    - path: "test/tools/check_no_tracking_test.dart"
      provides: "Self-test for the no-tracking script — confirms it detects banned packages"
      contains: "check-no-tracking"
  key_links:
    - from: ".github/workflows/ci.yml"
      to: "tools/check-no-tracking.sh"
      via: "step in analyze-and-test job runs the script and exits non-zero on detection"
      pattern: "check-no-tracking\\.sh"
    - from: ".github/workflows/ci.yml"
      to: "integration_test/no_network_test.dart"
      via: "integration-no-network job runs `flutter test integration_test/no_network_test.dart`"
      pattern: "integration_test/no_network_test"
    - from: ".github/workflows/ci.yml"
      to: "tools/run-marionette.sh"
      via: "marionette-e2e job invokes run-marionette.sh ios && run-marionette.sh android"
      pattern: "run-marionette"
    - from: "integration_test/no_network_test.dart"
      to: "integration_test/test_helpers/no_network_http_overrides.dart"
      via: "setUp() installs HttpOverrides.global = NoNetworkHttpOverrides()"
      pattern: "HttpOverrides\\.global"
---

<objective>
Wire up the CI pipeline (D-12, D-13) plus the four guards that enforce Phase 1's security/privacy/purity invariants:
1. `tools/check-no-tracking.sh` — fails the build if any banned analytics/ads/IAP SDK appears in `pubspec.lock` (D-20, FOUND-11).
2. `integration_test/no_network_test.dart` + `NoNetworkHttpOverrides` — fails if any HTTP request fires during a play session (D-18, FOUND-10).
3. `tools/check-flutter-version.sh` — soft warning on Flutter SDK drift from `.fvmrc` (D-15).
4. `tools/check-domain-purity.sh` — hard fail if pure-Dart domain files import `package:flutter` (D-08).

Plus: `.github/workflows/ci.yml` with three jobs running on every push to `main` and every pull request, exercising all of the above plus `flutter test`, `flutter analyze`, `dart format --set-exit-if-changed`, and the Plan 04 Marionette smoke on macOS.

Purpose: Implements FOUND-01 (CI confirms Flutter on iOS+Android), FOUND-06 (CI runs `flutter test` on every commit), FOUND-10 (no network calls during play, verified by integration test), FOUND-11 (no analytics/ads/IAP SDKs, verified by CI guard on pubspec.lock). This plan is the "no analytics/ads/IAP SDKs ever" enforcement that PROJECT.md is most insistent about.

Output: One workflow file, four guard scripts, two integration test files, one self-test for the no-tracking script, with all three CI jobs green against current main.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/01-skeleton-drift-schema/01-CONTEXT.md
@.planning/phases/01-skeleton-drift-schema/01-01-SUMMARY.md
@.planning/phases/01-skeleton-drift-schema/01-02-SUMMARY.md
@.planning/phases/01-skeleton-drift-schema/01-03-SUMMARY.md
@.planning/phases/01-skeleton-drift-schema/01-04-SUMMARY.md
@.planning/research/PITFALLS.md

<interfaces>
<!-- This plan is pure infrastructure: shell scripts, GitHub Actions YAML,
     and an integration test. It depends on Plans 01–04 having shipped because
     CI runs against the resulting codebase. -->

Banned packages (D-20 — exact list, the script's block-list):
1. firebase_analytics
2. firebase_crashlytics
3. sentry_flutter
4. mixpanel_flutter
5. amplitude_flutter
6. google_mobile_ads
7. in_app_purchase
8. app_tracking_transparency
9. flutter_facebook_audience_network

Block-list (not allow-list) per D-20: future legitimate dev_dependencies are not blocked.

NoNetworkHttpOverrides contract (D-18):
```dart
class NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError(
      'Network access is forbidden during play sessions (D-18 / FOUND-10). '
      'A test or runtime path attempted to create an HttpClient.',
    );
  }
}
```

CI job topology (D-12):
```
analyze-and-test (Ubuntu)
  - flutter pub get
  - dart format --set-exit-if-changed .
  - flutter analyze
  - flutter test
  - dart run build_runner build --delete-conflicting-outputs
  - tools/check-no-tracking.sh
  - tools/check-domain-purity.sh

integration-no-network (Ubuntu — uses Linux desktop integration_test)
  - flutter pub get
  - flutter test integration_test/no_network_test.dart -d linux
    OR uses Android Emulator on Ubuntu (KVM enabled) for the integration test

marionette-e2e (macOS)
  - flutter pub get
  - tools/run-marionette.sh ios
  - tools/run-marionette.sh android
```

Note: integration_test on Ubuntu is tricky — Flutter Linux desktop is the cheapest target (no emulator needed). If `flutter config --enable-linux-desktop` works in CI, run integration tests under `-d linux`. Otherwise, fall back to running them inside the Android emulator on the macOS marionette job.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write failing tests for guard scripts + no-network override (RED)</name>
  <files>
    test/tools/check_no_tracking_test.dart,
    integration_test/no_network_test.dart,
    integration_test/test_helpers/no_network_http_overrides.dart,
    tools/check-no-tracking_test.sh
  </files>
  <behavior>
    Test 1 (test/tools/check_no_tracking_test.dart): Running `tools/check-no-tracking.sh` against a fixture pubspec.lock that does NOT contain banned packages exits 0.
    Test 2 (test/tools/check_no_tracking_test.dart): Running `tools/check-no-tracking.sh` against a fixture pubspec.lock that DOES contain `firebase_analytics:` exits non-zero AND emits `firebase_analytics` to stderr.
    Test 3 (test/tools/check_no_tracking_test.dart): Loop test — for each of the 9 banned packages, simulate it appearing in a fixture and assert the script flags it.
    Test 4 (integration_test/no_network_test.dart): With `HttpOverrides.global = NoNetworkHttpOverrides()`, attempting `HttpClient()` throws `StateError`.
    Test 5 (integration_test/no_network_test.dart): Pumping the full Hugrún app (`HugrunApp` from Plan 01) under NoNetworkHttpOverrides for the duration of a smoke session (open home, tap each room, hold parent gate) does NOT throw — confirms no production code path attempts a network request.
    Test 6 (tools/check-no-tracking_test.sh — bash self-test): Bash-level test of the same guard, runnable in CI without Dart. Same fixtures.

    All MUST fail at this stage because production code (the script + the override class) does not exist yet.
  </behavior>
  <action>
    1. Create `test/tools/check_no_tracking_test.dart`:
       ```dart
       @TestOn('vm')  // shells out to bash; not for browser
       library;

       import 'dart:io';
       import 'package:flutter_test/flutter_test.dart';
       import 'package:path/path.dart' as p;

       const bannedPackages = <String>[
         'firebase_analytics',
         'firebase_crashlytics',
         'sentry_flutter',
         'mixpanel_flutter',
         'amplitude_flutter',
         'google_mobile_ads',
         'in_app_purchase',
         'app_tracking_transparency',
         'flutter_facebook_audience_network',
       ];

       Future<ProcessResult> runCheck(String fixturePubspecLock) async {
         final tmp = Directory.systemTemp.createTempSync('hugrun-check-no-tracking-');
         try {
           await File(p.join(tmp.path, 'pubspec.lock')).writeAsString(fixturePubspecLock);
           return await Process.run(
             'bash',
             [p.absolute('tools/check-no-tracking.sh')],
             workingDirectory: tmp.path,
           );
         } finally {
           tmp.deleteSync(recursive: true);
         }
       }

       void main() {
         test('exits 0 on clean pubspec.lock', () async {
           final result = await runCheck('packages:\n  flutter:\n    dependency: "direct main"\n');
           expect(result.exitCode, 0,
               reason: 'stdout=${result.stdout}, stderr=${result.stderr}');
         });

         for (final pkg in bannedPackages) {
           test('exits non-zero when $pkg is present', () async {
             final fixture = '''
       packages:
         $pkg:
           dependency: "direct main"
           description:
             name: $pkg
           source: hosted
           version: "1.0.0"
       ''';
             final result = await runCheck(fixture);
             expect(result.exitCode, isNot(0));
             expect((result.stdout as String) + (result.stderr as String),
                 contains(pkg));
           });
         }
       }
       ```

    2. Create `integration_test/test_helpers/no_network_http_overrides.dart` (skeleton for tests; production class added in Task 2):
       ```dart
       // Phase 1 placeholder — Task 2 implements.
       ```
       Leave the file empty or with a TODO. The integration test below will fail to import it.

    3. Create `integration_test/no_network_test.dart`:
       ```dart
       import 'dart:io';

       import 'package:flutter/material.dart';
       import 'package:flutter_riverpod/flutter_riverpod.dart';
       import 'package:flutter_test/flutter_test.dart';
       import 'package:integration_test/integration_test.dart';
       import 'package:hugrun/app/app.dart';

       import 'test_helpers/no_network_http_overrides.dart';

       void main() {
         IntegrationTestWidgetsFlutterBinding.ensureInitialized();

         setUp(() {
           HttpOverrides.global = NoNetworkHttpOverrides();
         });
         tearDown(() {
           HttpOverrides.global = null;
         });

         test('NoNetworkHttpOverrides throws on HttpClient construction', () {
           expect(() => HttpClient(), throwsStateError);
         });

         testWidgets('Full Phase 1 play session attempts no network', (tester) async {
           await tester.pumpWidget(const ProviderScope(child: HugrunApp()));
           await tester.pumpAndSettle();
           // Tap each room and back out — exercises Plan 01-03 paths.
           await tester.tap(find.byKey(const Key('home-room-stafir')));
           await tester.pumpAndSettle();
           await tester.pageBack();
           await tester.pumpAndSettle();
           await tester.tap(find.byKey(const Key('home-room-tolur')));
           await tester.pumpAndSettle();
           await tester.pageBack();
           await tester.pumpAndSettle();
           // Long-press settings icon.
           final gesture = await tester.startGesture(
             tester.getCenter(find.byIcon(Icons.settings)),
           );
           await tester.pump(const Duration(seconds: 3));
           await gesture.up();
           await tester.pumpAndSettle();
           // If anything tried to hit the network, the override would have
           // thrown by now.
           expect(true, isTrue);
         });
       }
       ```

    4. Create `tools/check-no-tracking_test.sh` — bash self-test (D-20 explicitly says block-list with self-test):
       ```bash
       #!/usr/bin/env bash
       # Self-test for tools/check-no-tracking.sh
       # Runs in CI as part of the analyze-and-test job.
       set -euo pipefail

       SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-no-tracking.sh"
       FAILS=0

       run_case() {
         local name="$1"
         local fixture="$2"
         local expect="$3"  # 'pass' or 'fail'
         local tmp; tmp="$(mktemp -d)"
         printf '%s' "$fixture" > "$tmp/pubspec.lock"
         if (cd "$tmp" && bash "$SCRIPT") &>/dev/null; then
           if [[ "$expect" != "pass" ]]; then
             echo "FAIL: $name (expected fail, got pass)" >&2
             FAILS=$((FAILS + 1))
           fi
         else
           if [[ "$expect" != "fail" ]]; then
             echo "FAIL: $name (expected pass, got fail)" >&2
             FAILS=$((FAILS + 1))
           fi
         fi
         rm -rf "$tmp"
       }

       run_case "clean lock passes" 'packages:\n  flutter:\n    dependency: "direct main"\n' "pass"
       for pkg in firebase_analytics firebase_crashlytics sentry_flutter mixpanel_flutter \
                  amplitude_flutter google_mobile_ads in_app_purchase \
                  app_tracking_transparency flutter_facebook_audience_network; do
         run_case "detects $pkg" "packages:\n  $pkg:\n    version: \"1.0.0\"\n" "fail"
       done

       if [[ "$FAILS" -gt 0 ]]; then
         echo "SELF-TEST FAILED: $FAILS case(s) failed" >&2
         exit 1
       fi
       echo "self-test ok"
       ```
       `chmod +x tools/check-no-tracking_test.sh`.

    5. Run `flutter test test/tools/check_no_tracking_test.dart`. Tests must fail because `tools/check-no-tracking.sh` does not exist yet (RED).
    
    Run `bash tools/check-no-tracking_test.sh`. Must fail because the underlying `check-no-tracking.sh` doesn't exist (RED).
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; ! bash tools/check-no-tracking_test.sh 2&gt;/dev/null &amp;&amp; ! flutter test test/tools/check_no_tracking_test.dart 2&gt;/dev/null</automated>
  </verify>
  <done>
    - test/tools/check_no_tracking_test.dart, integration_test/no_network_test.dart, integration_test/test_helpers/no_network_http_overrides.dart (placeholder), tools/check-no-tracking_test.sh exist.
    - Tests fail in RED state because guards are not yet implemented.
    - Commit: `test(01-05): add failing tests for CI guards + no-network override (RED)`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Implement guard scripts + NoNetworkHttpOverrides (GREEN)</name>
  <files>
    tools/check-no-tracking.sh,
    tools/check-flutter-version.sh,
    tools/check-domain-purity.sh,
    integration_test/test_helpers/no_network_http_overrides.dart
  </files>
  <behavior>
    Tests 1–6 from Task 1 pass GREEN.
  </behavior>
  <action>
    1. Create `tools/check-no-tracking.sh` (D-20):
       ```bash
       #!/usr/bin/env bash
       # CI guard: fails if any banned analytics/ads/IAP SDK appears in pubspec.lock.
       # Source: CONTEXT D-20. Block-list, not allow-list.
       # Maps to FOUND-11 ("no analytics/ads/IAP SDKs in dep graph").
       set -euo pipefail

       LOCK="${1:-pubspec.lock}"
       if [[ ! -f "$LOCK" ]]; then
         echo "ERROR: $LOCK not found" >&2
         exit 2
       fi

       BANNED=(
         firebase_analytics
         firebase_crashlytics
         sentry_flutter
         mixpanel_flutter
         amplitude_flutter
         google_mobile_ads
         in_app_purchase
         app_tracking_transparency
         flutter_facebook_audience_network
       )

       FOUND_ANY=0
       for pkg in "${BANNED[@]}"; do
         # Match `  pkg:` at start of an indented line (pubspec.lock format).
         # Skip comments (lines starting with #).
         if grep -E "^[[:space:]]+${pkg}:" "$LOCK" | grep -v '^[[:space:]]*#' >/dev/null; then
           echo "FORBIDDEN PACKAGE FOUND: $pkg" >&2
           echo "  See PROJECT.md 'no analytics/ads/IAP' constraint and CONTEXT D-20." >&2
           FOUND_ANY=1
         fi
       done

       if [[ "$FOUND_ANY" -eq 1 ]]; then
         echo "" >&2
         echo "Build failed: $LOCK contains banned package(s) listed above." >&2
         echo "If you have a legitimate need to add one, escalate to /gsd-discuss-phase" >&2
         echo "and update CONTEXT D-20 — do not silently bypass this check." >&2
         exit 1
       fi
       echo "tools/check-no-tracking.sh: $LOCK passes (no banned packages)"
       ```
       `chmod +x tools/check-no-tracking.sh`.

       Note the pattern uses `grep -v '^[[:space:]]*#'` to filter out comments per the planner's "self-invalidating grep gate" warning — header prose mentioning a banned package would otherwise trigger a false positive.

    2. Create `tools/check-flutter-version.sh` (D-15 — soft warning):
       ```bash
       #!/usr/bin/env bash
       # Soft check: warn (do not fail) when local Flutter doesn't match .fvmrc.
       # Per CONTEXT D-15 — guides user toward installing fvm without blocking work.
       set -uo pipefail  # NOT -e: we want to keep going on flutter --version failures

       if [[ ! -f .fvmrc ]]; then
         echo "WARN: .fvmrc not found; skipping Flutter version check" >&2
         exit 0
       fi

       PINNED="$(grep -oE '"flutter":\s*"[^"]+"' .fvmrc | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
       if [[ -z "$PINNED" ]]; then
         echo "WARN: .fvmrc has no parseable Flutter version" >&2
         exit 0
       fi

       LOCAL="$(flutter --version 2>/dev/null | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | head -n1 | awk '{print $2}')"
       if [[ -z "$LOCAL" ]]; then
         echo "WARN: cannot detect local Flutter version (is fvm/flutter on PATH?)" >&2
         exit 0
       fi

       if [[ "$LOCAL" != "$PINNED" ]]; then
         echo "WARN: Flutter version drift — .fvmrc pins $PINNED, local is $LOCAL" >&2
         echo "      Install fvm and run 'fvm use $PINNED' to align." >&2
       else
         echo "tools/check-flutter-version.sh: Flutter $LOCAL matches .fvmrc"
       fi
       exit 0  # never fail
       ```
       `chmod +x tools/check-flutter-version.sh`.

    3. Create `tools/check-domain-purity.sh` (D-08):
       ```bash
       #!/usr/bin/env bash
       # CI guard: domain-layer purity. No file under lib/core/db/models/,
       # lib/core/manifest/types/ (or other future "domain" subtrees) may import
       # package:flutter — domain is pure Dart per CONTEXT D-08.
       # Block-list of paths declared here; future paths added as the domain grows.
       set -euo pipefail

       DOMAIN_PATHS=(
         "lib/core/db/tables"   # tables are pure Dart per Drift convention
         # When Phase 2 adds lib/core/manifest/types/, add it here.
         # When Phase 4 adds lib/domain/, add it here.
       )

       FAIL=0
       for dir in "${DOMAIN_PATHS[@]}"; do
         if [[ ! -d "$dir" ]]; then continue; fi
         while IFS= read -r -d '' f; do
           # Skip generated files.
           if [[ "$f" == *.g.dart ]] || [[ "$f" == *.freezed.dart ]]; then continue; fi
           if grep -E "^[[:space:]]*import[[:space:]]+'package:flutter/" "$f" >/dev/null; then
             echo "DOMAIN PURITY VIOLATION: $f imports package:flutter" >&2
             echo "  Per CONTEXT D-08, domain layer files must be pure Dart." >&2
             FAIL=1
           fi
         done < <(find "$dir" -name '*.dart' -print0)
       done

       if [[ "$FAIL" -eq 1 ]]; then
         echo "" >&2
         echo "Build failed: domain-layer files import Flutter (D-08)." >&2
         exit 1
       fi
       echo "tools/check-domain-purity.sh: domain layer is Flutter-free"
       ```
       `chmod +x tools/check-domain-purity.sh`.

    4. Replace `integration_test/test_helpers/no_network_http_overrides.dart` (D-18):
       ```dart
       import 'dart:io';

       /// Throws on any outbound HTTP request. Install in `setUp()` of any
       /// integration test that should validate the no-network constraint
       /// (FOUND-10). Per CONTEXT D-18 — covers FOUND-10 verification.
       class NoNetworkHttpOverrides extends HttpOverrides {
         @override
         HttpClient createHttpClient(SecurityContext? context) {
           throw StateError(
             'Network access is forbidden during play sessions (D-18 / FOUND-10). '
             'A test or runtime path attempted to create an HttpClient.',
           );
         }
       }
       ```

    5. Run all the tests:
       ```
       flutter test test/tools/check_no_tracking_test.dart   # GREEN: 10 tests pass
       bash tools/check-no-tracking_test.sh                  # GREEN: self-test passes
       bash tools/check-flutter-version.sh                   # GREEN (or WARN): exits 0
       bash tools/check-domain-purity.sh                     # GREEN: no violations
       bash tools/check-no-tracking.sh                       # GREEN against current pubspec.lock
       ```

    6. Run `flutter test integration_test/no_network_test.dart` locally if a device or `flutter config --enable-linux-desktop` works. If not possible locally, document and lean on the CI job (Task 3) to verify.
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; bash tools/check-no-tracking.sh &amp;&amp; bash tools/check-no-tracking_test.sh &amp;&amp; bash tools/check-flutter-version.sh &amp;&amp; bash tools/check-domain-purity.sh &amp;&amp; flutter test test/tools/check_no_tracking_test.dart</automated>
  </verify>
  <done>
    - tools/check-no-tracking.sh, tools/check-flutter-version.sh, tools/check-domain-purity.sh exist and are executable.
    - integration_test/test_helpers/no_network_http_overrides.dart implements NoNetworkHttpOverrides per D-18.
    - All Task 1 tests pass GREEN.
    - All four guard scripts exit 0 against the current state of main.
    - Commit: `feat(01-05): implement CI guard scripts + NoNetworkHttpOverrides (GREEN)`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Wire .github/workflows/ci.yml with three jobs and verify each passes (GREEN)</name>
  <files>
    .github/workflows/ci.yml,
    .gitignore
  </files>
  <behavior>
    A push to a branch (or to main) triggers GitHub Actions to run three jobs:
    1. analyze-and-test (Ubuntu) — green
    2. integration-no-network (Ubuntu) — green
    3. marionette-e2e (macOS) — green

    All three jobs exit 0 against the current state of main.
  </behavior>
  <action>
    1. Create `.github/workflows/ci.yml`:
       ```yaml
       name: CI

       on:
         push:
           branches: [main]
         pull_request:
           branches: [main]

       env:
         FVM_VERSION: 3.2.1   # adjust to current fvm release at execution time

       jobs:
         analyze-and-test:
           name: analyze-and-test (Ubuntu)
           runs-on: ubuntu-latest
           steps:
             - uses: actions/checkout@v4

             - name: Read .fvmrc
               id: fvmrc
               run: |
                 FLUTTER_VERSION="$(grep -oE '"flutter":\s*"[^"]+"' .fvmrc | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
                 echo "flutter_version=$FLUTTER_VERSION" >> "$GITHUB_OUTPUT"

             - uses: subosito/flutter-action@v2
               with:
                 flutter-version: ${{ steps.fvmrc.outputs.flutter_version }}
                 channel: stable
                 cache: true

             - name: flutter --version
               run: flutter --version

             - name: flutter pub get
               run: flutter pub get

             - name: dart format --set-exit-if-changed
               run: dart format --set-exit-if-changed .

             - name: flutter analyze
               run: flutter analyze

             - name: build_runner build
               run: dart run build_runner build --delete-conflicting-outputs

             - name: flutter test
               run: flutter test

             - name: tools/check-no-tracking.sh
               run: bash tools/check-no-tracking.sh

             - name: tools/check-no-tracking_test.sh (self-test)
               run: bash tools/check-no-tracking_test.sh

             - name: tools/check-domain-purity.sh
               run: bash tools/check-domain-purity.sh

             - name: tools/check-flutter-version.sh (soft)
               run: bash tools/check-flutter-version.sh

         integration-no-network:
           name: integration-no-network (Ubuntu)
           runs-on: ubuntu-latest
           steps:
             - uses: actions/checkout@v4

             - name: Read .fvmrc
               id: fvmrc
               run: |
                 FLUTTER_VERSION="$(grep -oE '"flutter":\s*"[^"]+"' .fvmrc | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
                 echo "flutter_version=$FLUTTER_VERSION" >> "$GITHUB_OUTPUT"

             - uses: subosito/flutter-action@v2
               with:
                 flutter-version: ${{ steps.fvmrc.outputs.flutter_version }}
                 channel: stable
                 cache: true

             - name: Enable Linux desktop
               run: |
                 sudo apt-get update
                 sudo apt-get install -y ninja-build libgtk-3-dev clang
                 flutter config --enable-linux-desktop

             - name: flutter pub get
               run: flutter pub get

             - name: build_runner
               run: dart run build_runner build --delete-conflicting-outputs

             - name: integration_test under NoNetworkHttpOverrides
               run: |
                 flutter test integration_test/no_network_test.dart \
                   -d linux \
                   --reporter=expanded

         marionette-e2e:
           name: marionette-e2e (macOS)
           runs-on: macos-latest
           steps:
             - uses: actions/checkout@v4

             - name: Read .fvmrc
               id: fvmrc
               run: |
                 FLUTTER_VERSION="$(grep -oE '"flutter":\s*"[^"]+"' .fvmrc | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
                 echo "flutter_version=$FLUTTER_VERSION" >> "$GITHUB_OUTPUT"

             - uses: subosito/flutter-action@v2
               with:
                 flutter-version: ${{ steps.fvmrc.outputs.flutter_version }}
                 channel: stable
                 cache: true

             - name: flutter pub get
               run: flutter pub get

             - name: build_runner
               run: dart run build_runner build --delete-conflicting-outputs

             - name: Boot iPad Air simulator
               run: |
                 xcrun simctl list devices available
                 # Pick the first iPad Air available.
                 IPAD_ID="$(xcrun simctl list devices available | grep -E 'iPad Air' | head -n1 | grep -oE '\([0-9A-F-]+\)' | tr -d '()')"
                 echo "IPAD_ID=$IPAD_ID" >> "$GITHUB_ENV"
                 xcrun simctl boot "$IPAD_ID"

             - name: Run Marionette on iOS Simulator
               run: tools/run-marionette.sh ios

             - name: Set up Android emulator
               uses: reactivecircus/android-emulator-runner@v2
               with:
                 api-level: 34
                 target: google_apis
                 arch: x86_64
                 profile: pixel_tablet
                 script: tools/run-marionette.sh android
       ```

       Notes:
       - `subosito/flutter-action@v2` is the standard community action for installing Flutter at a specific version. We could install fvm and use it, but flutter-action is simpler for CI and reads the same version.
       - `reactivecircus/android-emulator-runner@v2` is the standard for booting an Android emulator inside macOS GHA runners (KVM/HAXM available there).
       - Linux desktop integration is the cheapest way to run integration_test on Ubuntu without an emulator. If `pumpAndSettle` hits issues with the desktop window manager in CI, fall back to running the integration test inside the Android emulator on the macOS job.
       - Pin action versions (`@v4`, `@v2`) for reproducibility.

    2. `.gitignore`: confirm `.dart_tool/`, `build/`, `.fvm/`, `*.g.dart` (Drift/Riverpod outputs other than committed manifest), `.idea/`, `.vscode/`, `*.iml` are excluded. Add `coverage/` if not already.

    3. Commit and push to a feature branch. Open a PR to main. Verify all three jobs run and pass.

    4. If any job fails:
       - **analyze-and-test**: usually `dart format` differences from local OS line endings, or a missing `build_runner` invocation. Fix and re-push.
       - **integration-no-network**: Linux desktop entry point may be missing. Confirm `linux/` directory exists (Plan 01's `flutter create` may not have included it; if missing, run `flutter create --platforms=linux .` and commit the `linux/` directory). Alternative: run integration test on the macOS Android emulator instead.
       - **marionette-e2e**: longest job; iOS simulator boot can be flaky. Increase boot timeout. Pin `xcode-select` to a specific Xcode if multiple are installed.

    5. Once all three jobs are green, merge the PR (or land directly on main if branching strategy is `none` per config.json).
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; test -f .github/workflows/ci.yml &amp;&amp; bash tools/check-no-tracking.sh &amp;&amp; bash tools/check-no-tracking_test.sh &amp;&amp; bash tools/check-domain-purity.sh &amp;&amp; bash tools/check-flutter-version.sh &amp;&amp; flutter test &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - .github/workflows/ci.yml exists with three jobs (analyze-and-test, integration-no-network, marionette-e2e).
    - All three jobs trigger on push-to-main and pull-request (D-13).
    - All three jobs pass when run against current main.
    - Local `flutter test`, `flutter analyze`, `dart format --set-exit-if-changed`, and all four guard scripts exit 0.
    - Phase 1 success criterion 5 is met: "CI runs `flutter test` on every commit, and a CI check on `pubspec.lock` fails the build if any analytics/ads/IAP SDK is added."
    - Commit: `ci(01-05): wire GitHub Actions with 3 jobs (analyze-and-test, integration-no-network, marionette-e2e) (GREEN)`.
  </done>
</task>

</tasks>

<verification>
- `.github/workflows/ci.yml` defines three jobs and all three pass green against current main.
- `tools/check-no-tracking.sh` exits non-zero when any of the 9 banned packages appears in pubspec.lock; passes against current main.
- `tools/check-no-tracking_test.sh` self-test passes.
- `tools/check-flutter-version.sh` exits 0 (warning level) when Flutter SDK matches .fvmrc; never fails.
- `tools/check-domain-purity.sh` exits 0 when no domain-tier file imports package:flutter; fails otherwise.
- `integration_test/no_network_test.dart` passes locally (Linux desktop or simulator) and in CI.
- `flutter test test/tools/check_no_tracking_test.dart` passes (10 tests covering every banned package).
- `flutter analyze` exits 0; `dart format --set-exit-if-changed .` exits 0; `flutter test` runs full Phase 1 suite green.
</verification>

<success_criteria>
1. CI runs `flutter test` on every commit (FOUND-06 verified).
2. CI check on pubspec.lock fails the build if any of the 9 banned analytics/ads/IAP SDKs is added (FOUND-11, D-20).
3. Integration test verifies no network calls during a play session (FOUND-10, D-18).
4. CI runs Marionette E2E on both iOS Simulator and Android Emulator (FOUND-07, D-11) — green.
5. CI workflow file lives at `.github/workflows/ci.yml` with three jobs per D-12 and triggers per D-13.
6. tools/check-flutter-version.sh provides a soft Flutter SDK drift warning (D-15).
7. tools/check-domain-purity.sh enforces D-08 by failing on `package:flutter` imports in domain-tier files.
8. Phase 1 success criterion 5 is met end-to-end.
</success_criteria>

<output>
After completion, create `.planning/phases/01-skeleton-drift-schema/01-05-SUMMARY.md` covering:
- All four guard script paths + lines of code each
- CI YAML file size + job count + trigger configuration
- Confirmation each banned package is detected by self-test
- Confirmation NoNetworkHttpOverrides throws on HttpClient construction
- All three CI jobs' first-run pass timestamps + wall-clock durations
- Any deviations from CONTEXT D-12/D-13/D-15/D-18/D-20 (should be zero)
- Confirmation that phase 1 success criterion 5 ("CI fails on pubspec.lock with banned SDKs") is provably wired
- Commit hashes
</output>
