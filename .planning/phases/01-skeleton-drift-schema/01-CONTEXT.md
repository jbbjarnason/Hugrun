# Phase 1: Skeleton & Drift Schema - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto` (Claude picked recommended option for each gray area; decisions logged inline)

<domain>
## Phase Boundary

A runnable Flutter app on iOS and Android with the architectural foundations every later phase will land on: Flutter SDK pinned (fvm), Riverpod (codegen) + Drift + just_audio in pubspec, Drift v1 schema with stepwise migration scaffolding, two-room home shell (Stafir/Tölur — both placeholders), parent-gate primitive (3s hold, ring-fill), TDD workflow established, Marionette E2E smoke test green on both platforms in CI, and a CI guard that fails the build if any analytics/ads/IAP SDK is introduced.

**Requirements covered:** FOUND-01, 02, 03, 06, 07, 08, 09, 10, 11 (9 of 11; FOUND-04 alphabet constant + FOUND-05 asset conventions are Phase 2).

</domain>

<decisions>
## Implementation Decisions

### Riverpod Family

- **D-01:** Pin Riverpod 4.x family — `flutter_riverpod ^4.x`, `riverpod_annotation ^4.x`, `riverpod_generator ^4.x`. Verify alignment via `dart pub outdated` at project creation. The generator is the productivity win; mixing 3.x runtime with 4.x annotations is a documented foot-gun (research Finding 6).
- **D-02:** Use `@riverpod` annotations (codegen). Hand-written `Provider`/`StateNotifierProvider` is reserved only for the AudioEngine root provider in Phase 4 if codegen ergonomics conflict with the warm-pool lifecycle.

> **Resolved on Flutter 3.41.9 (remediation 2026-05-02):** Riverpod's runtime
> stays on `flutter_riverpod ^3.3.1` because there is no 4.x runtime stable
> on pub.dev as of execution. The maintainer ships matching codegen at
> `riverpod_annotation 4.0.2` + `riverpod_generator 4.0.3`, which
> internally target `riverpod 3.2.1` — i.e., the 4.x codegen IS designed for
> a 3.x runtime, and PITFALLS #6's "foot-gun" warning does not apply to the
> maintainer-recommended pairing. D-02 codegen migration completed:
> `lib/core/db/database_provider.dart` now uses `@Riverpod(keepAlive: true)`.
> `riverpod_lint ^3.1.3` is also installed (via `analysis_options.yaml`
> `plugins:`) — the previous Dev_7 deferral is resolved.

### Drift Schema v1

- **D-03:** `child_profiles` table with columns `id INTEGER PRIMARY KEY, name TEXT NOT NULL, created_at INTEGER NOT NULL`. Single row only (single child). Default name "Hugrún" inserted on first launch by an idempotent bootstrap.
- **D-04:** `schemaVersion = 1`. Stepwise migration framework wired up via `MigrationStrategy(onUpgrade: stepByStep(...))` even with no upgrades needed yet — this avoids retrofitting the framework when Phase 10 adds `photo_tags`.
- **D-05:** `drift_dev schema dump 1` snapshot committed to `drift_schemas/v1.json` for future migration tests using `schemaAt(1)`. Standard pattern from research.
- **D-06:** Use `drift_flutter ^0.3.0` — do NOT add `sqlite3_flutter_libs` directly (research Finding 7).

> **Partial resolution on Flutter 3.41.9:** `drift ^2.31.0` and
> `drift_flutter ^0.2.8` (NOT 0.3.0 as D-06 specifies). drift_flutter 0.3.0
> requires sqlite3 ^3 → forces drift_dev 2.32.x → analyzer ^10. analyzer
> ^10 is incompatible with riverpod_lint 3.1.x and riverpod_generator 4.0.3
> (both need analyzer ^9). Per the remediation prompt's prioritization
> ("the user explicitly chose to retry rather than accept the previous
> fallback" — and the codegen migration is the more visible win), Phase 1
> holds at drift_flutter 0.2.8 and bumps to 0.3 once Riverpod publishes
> analyzer-^10/^12-compatible {generator, lint} pair (3.1.4-dev.1 already
> targets analyzer ^12 — should be quick). The "no direct sqlite3_flutter_libs"
> intent of D-06 is preserved.

### Project Layout (Feature-First with Peer mechanics/)

- **D-07:** Create the full layout skeleton in Phase 1 even though most folders are stubs:
  ```
  lib/
    app/                    # MaterialApp, router (Navigator 1.0)
    core/
      audio/                # placeholder for AudioEngine (Phase 4)
      db/                   # AppDatabase, child_profiles_dao
      parent_gate/          # ParentGate widget primitive (this phase)
      manifest/             # placeholder for AudioManifest (Phase 2)
    features/
      stafir/               # placeholder room (Phase 2-7)
      tolur/                # placeholder room (Phase 8-9)
      parent_settings/      # ParentSettingsScreen stub (Phase 4 fills it)
    mechanics/              # placeholder for tap-to-hear etc. (Phase 4+)
    gen/                    # generated audio_manifest.g.dart placeholder
  test/
    core/
    features/
  integration_test/
    smoke_test.dart         # no-network test, app-launch test
  marionette/
    smoke.marionette.dart   # E2E smoke
  tools/
    check-no-tracking.sh    # CI guard for analytics/ads/IAP
  ```
- **D-08:** Domain layer (anything in `core/db/models/`, `core/manifest/types/`) is pure Dart — no Flutter imports. Enforced by a `flutter analyze` custom rule via `analysis_options.yaml`.

### Marionette E2E Setup

- **D-09:** Install Marionette as a `dev_dependency` (latest stable from pub.dev — verify name and version at install time; if naming differs from `marionette`, document in CONTEXT or escalate). Marionette is the user's mandated E2E framework (project-level constraint).
- **D-10:** Phase 1 smoke test script asserts: (a) app launches without exceptions, (b) home screen renders both Stafir and Tölur entry points with tap targets ≥2 cm physical, (c) tapping each room navigates to its placeholder screen, (d) parent gate primitive exists and the ring-fill animation completes after a 3s sustained press, (e) no network requests fire during the test session.
- **D-11:** Marionette runs on both iOS Simulator (iPad Air) and Android Emulator (Pixel Tablet) in CI. Local dev can run on either.

> **Resolved (remediation 2026-05-02):** the user-confirmed package is
> `marionette_flutter ^0.5.0` (leancode.co — pub.dev verified publisher).
> It is NOT a scripted-assertion E2E framework; it is the in-app side of
> the Marionette MCP toolkit, which lets an external AI agent
> (Claude Code / Cursor / Copilot / Gemini CLI) drive the running app via
> the Model Context Protocol. The package therefore appears in
> `dependencies:` (not dev_dependencies) because `lib/main.dart` imports
> `MarionetteBinding.ensureInitialized()` (debug-only — release builds use
> the default `WidgetsFlutterBinding`). Phase 1 ships TWO complementary
> E2E paths covering the same D-10 invariants:
>
>   1. **Scripted variant** at `integration_test/marionette_smoke_test.dart`
>      (driven by `flutter drive` + `IntegrationTestWidgetsFlutterBinding`).
>      Fast, deterministic, runs in CI on macOS-latest. Asserts D-10
>      criteria a, b, c, d.
>   2. **MCP variant** at `marionette/smoke.marionette.dart` — reference
>      doc for the AI agent. Driven via `tools/run-marionette.sh mcp ios`
>      which launches the app with MarionetteBinding initialized. NOT in
>      CI; pre-merge interactive verification only.
>
> CONTEXT D-11's "in CI" qualifier applies to the SCRIPTED variant only.
> The MCP variant requires an interactive AI agent and lives outside CI.

### CI Provider

- **D-12:** GitHub Actions. `.github/workflows/ci.yml` with three jobs:
  1. `analyze-and-test` (Ubuntu): `flutter pub get`, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, `tools/check-no-tracking.sh`.
  2. `integration-no-network` (Ubuntu): runs `integration_test/smoke_test.dart` with HttpOverrides set to throw on any outbound HTTP.
  3. `marionette-e2e` (macOS): runs Marionette smoke against iOS Simulator + Android Emulator.
- **D-13:** Workflow triggers on push to `main` and on pull request. Solo dev for now, but PR-trigger keeps muscle memory if/when collaborators arrive.

### Flutter SDK Pinning

- **D-14:** `.fvmrc` committed pinning Flutter to the current stable channel version (verify exact version at execution time — research suggested 3.41.5 but that may have moved). Local fvm not yet installed (`brew install fvm` is a follow-up); CI installs fvm and uses it. Local dev unblocked using system Flutter.
- **D-15:** A `tools/check-flutter-version.sh` script that compares `flutter --version` against `.fvmrc` and warns (does not fail) if mismatched — guides user toward installing fvm without blocking work.

### TDD Workflow

- **D-16:** Every plan in this phase sequences tasks as: (1) write failing test, (2) run and confirm red, (3) implement minimum to pass, (4) run and confirm green, (5) refactor with tests still green. Atomic commits per cycle.
- **D-17:** Test layers: `flutter_test` for unit + widget, `integration_test` for app-level flows, `marionette` for E2E. Coverage target tracked but not gated for solo dev (no minimum threshold yet — revisit in Phase 4 once MVP exists).

### No-Network Enforcement

- **D-18:** A test-only `NoNetworkHttpOverrides` class throws on any outbound HTTP request. Installed in `setUp()` of `integration_test/smoke_test.dart`. The integration test runs the full Stafir entry → tap → home flow and fails if any request is attempted.
- **D-19:** Pubspec is locked to dependencies with no inherent network requirement (Riverpod, Drift, just_audio are all local). Any future PR adding `http`, `dio`, `web_socket_channel`, etc. should be flagged in code review.

### Analytics/Ads/IAP Guard

- **D-20:** `tools/check-no-tracking.sh` reads `pubspec.lock` and fails on any of: `firebase_analytics`, `firebase_crashlytics`, `sentry_flutter`, `mixpanel_flutter`, `amplitude_flutter`, `google_mobile_ads`, `in_app_purchase`, `app_tracking_transparency`, `flutter_facebook_audience_network`. Block-list, not allow-list (allow-list would be too restrictive for legitimate dev_dependencies).
- **D-21:** Crash reporting in v2 release path will use iOS MetricKit / Android Play Console crash reports — NOT Firebase Crashlytics or Sentry — because Apple Kids Category restricts third-party crash SDKs (research Finding 11). For now, no crash reporting in v1.

### Parent Gate Primitive

- **D-22:** `ParentGate` widget in `lib/core/parent_gate/parent_gate.dart`. Wraps any child widget; a long-press anywhere on the wrapped surface starts a 3-second timer; a circular ring fills synchronously around the touch point as the timer progresses; releasing before 3s aborts; completing 3s navigates to the wrapped target screen.
- **D-23:** No haptic feedback in v1 (haptic on iOS+Android is a small consistency rabbit hole; defer). Visual ring + subtle scale animation is enough.
- **D-24:** Phase 1 ships with a `ParentSettingsScreen` placeholder containing only a centered "Coming soon" Icelandic string `Stillingar`. Phase 4 fills it (child name, etc.).

### Routing

- **D-25:** Navigator 1.0 with `MaterialPageRoute`. Two screens (Home → ParentSettings, Home → StafirRoom, Home → TolurRoom). `go_router` is overkill (research Finding) and adds reset-semantics complexity not needed at this size.

### Claude's Discretion

- Exact Flutter SDK version number in `.fvmrc` (verify current stable at execution).
- Exact Marionette package version (verify at install).
- Color palette / visual styling for placeholder rooms — keep neutral, not childish; design comes in Phase 4 via `/gsd-ui-phase`.
- Specific lints in `analysis_options.yaml` beyond `flutter_lints` — Claude picks a sensible set; user can override.
- File naming convention details (snake_case for files is Flutter idiomatic; PascalCase for class names).

### Folded Todos

(None — no pre-existing todos; this is a greenfield init.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — overall project context, constraints (TDD + Marionette, Riverpod, Drift, just_audio, Tiro-only TTS, no analytics/ads/IAP, no network during play)
- `.planning/REQUIREMENTS.md` — Phase 1 covers FOUND-01, 02, 03, 06, 07, 08, 09, 10, 11
- `.planning/ROADMAP.md` § Phase 1 — phase goal and 5 success criteria
- `.planning/STATE.md` — current project state

### Research (read all before planning)
- `.planning/research/STACK.md` — exact pubspec versions, Riverpod 3.x vs 4.x guidance, drift_flutter vs sqlite3_flutter_libs, fvm pinning, what NOT to use
- `.planning/research/ARCHITECTURE.md` — feature-first + peer mechanics/ layout, three-tier Riverpod scoping, Drift stepByStep migrations, manifest contract pattern
- `.planning/research/PITFALLS.md` — Riverpod scope leaks, Drift migration foot-guns, Apple Kids Category SDK restrictions, asset case-sensitivity (note relevance grows in later phases; for Phase 1 the relevant pitfalls are #6, #7, #8, #11, #20)
- `.planning/research/SUMMARY.md` — 11 critical findings consolidated; Findings 6, 7, 8, 9, 11 are directly relevant to Phase 1

### External docs
- https://riverpod.dev — confirm 4.x stable status and codegen syntax at install time
- https://drift.simonbinder.eu — Drift docs, migration patterns, schema versioning
- https://docs.flutter.dev/release/release-notes — current stable Flutter SDK version
- https://pub.dev/packages/marionette — verify Marionette package name + version (research did not lock this — escalate if package not found under this name)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

Greenfield — no existing code. All assets created from scratch in this phase.

### Established Patterns

Project-level patterns established in PROJECT.md and the research SUMMARY.md:
- Pre-baked audio assets (no runtime TTS) — Phase 1 establishes the asset folder convention but no audio yet
- Generated `audio_manifest.g.dart` (committed to git) — Phase 1 creates the empty `lib/gen/` folder and a stub file Phase 2 will replace
- Three-tier Riverpod scoping — root providers established here (DB, future audio engine); room/activity scopes come in Phase 4+
- TDD red-green-refactor — Phase 1 establishes the cycle for every subsequent phase

### Integration Points

This is the foundation phase. Future phases integrate via:
- `lib/core/db/` — Phase 10 will add `photo_tags` table; v1 schema must support migration
- `lib/core/audio/` — Phase 3 generates audio assets, Phase 4 implements `AudioEngine` here
- `lib/core/manifest/` — Phase 2 hand-writes the manifest stub, Phase 3 generates it via Python
- `lib/features/stafir/` — Phase 4 builds the 32-letter grid, Phases 5/6/7 add activities
- `lib/features/tolur/` — Phases 8/9 build the numbers room
- `lib/features/parent_settings/` — Phase 4 wires child name; Phase 10 wires photo upload
- `lib/mechanics/` — Phase 4 starts adding TapToHearTile; Phase 5+ add Matching, Sequencing; Phase 7 adds Tracing

</code_context>

<specifics>
## Specific Ideas

- App name displayed in the launcher and the app: **Hugrún** (the child's name)
- App ID / bundle: `is.hugrun.app` (suggested; user can override during planning)
- Icelandic locale targeted from day one — `MaterialApp(supportedLocales: [Locale('is')])` and ARB-based parent UI strings; child UI never has text
- Default tablet test devices in `.metadata`: iPad Air (latest gen) for iOS Simulator, Pixel Tablet for Android Emulator

</specifics>

<deferred>
## Deferred Ideas

- **Custom app icon and splash screen** — kid-friendly artwork comes in Phase 4 polish; Phase 1 ships default Flutter icon
- **Custom font selection** — child UI has no text so this is purely for parent screens; defer to Phase 4 UI-SPEC
- **Localization beyond Icelandic for parent UI** — explicitly out of scope per PROJECT.md
- **Crash reporting** — defer to v2 (REL-03); v1 has none
- **Privacy policy** — defer to v2 (REL-01)
- **Coverage thresholds in CI** — revisit after Phase 4 once MVP exists; gating coverage too early discourages exploratory commits
- **Pre-commit hooks** (lefthook/husky) — nice-to-have but not blocking; revisit if commit hygiene degrades
- **Multi-flavor builds** (dev/prod) — single flavor is enough; defer until / unless v2 release path

### Reviewed Todos (not folded)

None — no pre-existing todos.

</deferred>

---

*Phase: 1 — Skeleton & Drift Schema*
*Context gathered: 2026-05-02*
