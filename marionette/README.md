# Marionette E2E

**Package:** `marionette_flutter ^0.5.0` (leancode.co, pub.dev verified publisher; resolved 2026-05-02)
**Coverage:** Phase 1 smoke — home + rooms + parent gate (D-10 / FOUND-07).

## What this is — and isn't

`marionette_flutter` is **not** a scripted test framework. It is the runtime
half of the [Marionette MCP](https://pub.dev/packages/marionette_mcp) toolkit:
an in-app binding (`MarionetteBinding`) that exposes VM-service extensions an
**external AI agent** drives via the Model Context Protocol. The agent
(Claude Code, Cursor, Copilot, Gemini CLI) connects to a `marionette_mcp`
server, which in turn attaches to the Flutter VM, and the agent then taps,
scrolls, types, and screenshots the app to verify behavior.

Hugrún therefore ships **two** complementary E2E paths:

| Path | What | When |
|---|---|---|
| `integration_test/marionette_smoke_test.dart` | Scripted assertions via `flutter drive` (no AI agent) | CI; quick deterministic regression check |
| `marionette/smoke.marionette.dart` | Reference scenarios for an AI agent driving the live app | Pre-merge human/agent verification; richer than scripted |

Both variants assert the same five Phase 1 invariants (D-10):

1. App launches without exception.
2. HomePage renders both rooms (Stafir + Tölur).
3. Tapping each room navigates to its placeholder.
4. Long-pressing the gear icon for 3 s shows the ring-fill and navigates to
   `ParentSettingsScreen` ("Stillingar").
5. Each `RoomButton` is ≥2 cm × 2 cm physically at the device's reported DPI.

## Run locally — scripted variant

Prereqs:

- iPad Air simulator (iOS): `xcrun simctl list devices available | grep "iPad Air"`
- Pixel Tablet AVD (Android): `emulator -list-avds | grep "Pixel.*Tablet"`

```sh
tools/run-marionette.sh ios       # boots iPad Air simulator + runs flutter drive
tools/run-marionette.sh android   # boots Pixel Tablet AVD + runs flutter drive
```

The scripted variant uses `IntegrationTestWidgetsFlutterBinding` and is
**incompatible with `MarionetteBinding`** (Flutter allows only one
`WidgetsBinding` per process — see the marionette_flutter README). That's
why `lib/main.dart`'s call to `MarionetteBinding.ensureInitialized()` is
guarded by `kDebugMode` AND why `integration_test/marionette_smoke_test.dart`
pumps `HugrunApp` directly rather than calling `lib/main.dart#main`.

## Run locally — MCP variant (AI-agent-driven)

```sh
tools/run-marionette.sh mcp ios       # flutter run -d <iPad-Air> --debug
tools/run-marionette.sh mcp android   # flutter run -d <Pixel-Tablet> --debug
```

After the app launches, the Flutter VM-service URI is printed in the run
output. Hand that URI to your Marionette MCP server (separately installed —
`dart pub global activate marionette_mcp` or set up via your AI tool's
MCP-server configuration). Then ask your AI agent to drive the scenarios
documented in `smoke.marionette.dart`.

The MCP server itself is **not** a project dependency. It is per-developer
tooling, like `dart` or `flutter` itself. We deliberately don't pin a
version: the MCP server's stability bar is "the AI agent succeeds in driving
the scenarios," which is qualitative and tracked outside this repo.

## CI

`.github/workflows/ci.yml` job `marionette-e2e` runs the **scripted** variant
on macOS-latest. It boots an iPad Air simulator and a Pixel Tablet AVD
sequentially. The MCP variant is **not** wired into CI because it requires
an interactive AI agent — that pre-merge check is a human-verification step.

## Phase 1 verification log

When the user runs the scripted variant, capture the timestamps + device
versions in this section so a future Phase-N executor knows what the green
baseline was. Plan 04 leaves this empty intentionally; the user fills it in
during the post-Phase-1 acceptance pass.

| Date | Platform | Device version | Result | Notes |
|---|---|---|---|---|
| (pending) | iOS | (e.g. iPad Air, iOS 17.x) | (pending) | scripted |
| (pending) | Android | (e.g. Pixel Tablet, API 34) | (pending) | scripted |

## Why we don't ship MarionetteBinding to release

`MarionetteBinding` registers VM-service extensions that any process talking
to the Flutter VM can invoke. In debug it's a development convenience; in
release it would be a security hole and a violation of PROJECT.md "no
analytics, no telemetry" — so `lib/main.dart` falls back to the default
`WidgetsFlutterBinding` when `kDebugMode == false`.
