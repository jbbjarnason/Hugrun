// =============================================================================
// Hugrún Phase 1 Marionette MCP smoke harness
// =============================================================================
//
// This file is NOT executed as a test runner. It is the authoritative reference
// document for the Marionette MCP smoke flow. The execution model is:
//
//   1. A developer (or the user's `marionette-verify` skill) runs the app
//      in debug mode on a target device:
//
//        flutter run -d <iPad-Air-simulator-or-Pixel-Tablet-AVD>
//
//      `lib/main.dart` initializes `MarionetteBinding` in debug builds, which
//      registers VM-service extensions the Marionette MCP server attaches to.
//
//   2. The user starts the Marionette MCP server (a separately-installed
//      dev_dependency in their CLI environment, NOT a project dep):
//
//        dart run marionette_mcp
//
//      The Flutter VM URI from step 1 is passed to the MCP server.
//
//   3. The user's AI agent (Claude Code / Cursor / Copilot / Gemini CLI) is
//      configured with the Marionette MCP server entry. The agent loads this
//      file's <scenario> blocks and drives the app through each scenario,
//      asserting on widget tree state, screenshots, or extracted text. The
//      agent reports pass/fail back to the human reviewer.
//
// This is fundamentally an AI-agent-driven exploratory verification loop, not
// a scripted-assertion E2E suite. The scripted-assertion variant lives at
// `integration_test/marionette_smoke_test.dart` and runs under
// `flutter drive`. Both variants assert the same five Phase 1 invariants;
// they coexist because:
//   - The scripted variant is fast, deterministic, and runs in CI without an
//     AI agent.
//   - The MCP variant catches issues that only manifest at runtime on real
//     simulators/emulators (rendering glitches, frame timing, real audio
//     pipeline behaviors in later phases).
//
// =============================================================================
//
// Phase 1 scenarios (D-10 + FOUND-07/08/09):
//
// ## Scenario 1: app launches without exception
//   - Action: launch the app on the target device.
//   - Assert (via MCP `widget_tree`): widget tree contains a `Scaffold` and
//     an `AppBar` with text "Hugrún".
//   - Assert (via MCP `logs`): no FlutterError-style stack traces in the
//     debug log within the first 5 s.
//
// ## Scenario 2: home screen renders both rooms
//   - Assert: a widget with `Key('home-room-stafir')` is visible.
//   - Assert: a widget with `Key('home-room-tolur')` is visible.
//   - Assert: visible text "Stafir" and "Tölur" are both present.
//   - Capture screenshot for visual review.
//
// ## Scenario 3: room navigation
//   - Action: tap `Key('home-room-stafir')`.
//   - Assert: the route stack now contains a `StafirRoom`. Visible text
//     "Stafir" appears twice (AppBar title + Center body).
//   - Action: navigate back (system back / pop).
//   - Action: tap `Key('home-room-tolur')`.
//   - Assert: the route stack now contains a `TolurRoom`. Visible text
//     "Tölur" appears twice (AppBar title + Center body).
//   - Action: navigate back.
//
// ## Scenario 4: parent gate (long-press settings icon)
//   - Action: locate the AppBar settings icon (`Icons.settings`).
//   - Action: long-press the icon for 3 000 ms (start_press, wait, release).
//   - Assert: during the hold (~1 500 ms in), `Key('parent-gate-ring')` is
//     visible AND the ring's `value` (CircularProgressIndicator) is roughly
//     proportional to the elapsed fraction of 3 s. (Marionette MCP can
//     screenshot mid-hold and the agent can compare visual progress.)
//   - Assert: after 3 s sustained press, `ParentSettingsScreen` is in the
//     route stack and text "Stillingar" is visible.
//
// ## Scenario 5: tap target physical size (D-10 ≥2 cm)
//   - Assert (via MCP `widget_tree` + screen DPI): each `RoomButton`
//     occupies ≥2 cm × 2 cm physically. The MCP server reports the device
//     pixel ratio and physical screen dimensions; the AI agent multiplies
//     the widget's logical size by the appropriate factors.
//
// =============================================================================
//
// Widget-finding contract (the keys/labels the MCP agent uses):
//
//   | Widget                   | Find by                              | Phase 1 source      |
//   |--------------------------|--------------------------------------|---------------------|
//   | Stafir room button       | Key('home-room-stafir')              | features/home/      |
//   | Tölur room button        | Key('home-room-tolur')               | features/home/      |
//   | Settings icon (gated)    | Icon(Icons.settings)                 | features/home/      |
//   | Parent gate ring         | Key('parent-gate-ring')              | core/parent_gate/   |
//   | Stafir room title        | Text('Stafir')                       | features/stafir/    |
//   | Tölur room title         | Text('Tölur')                        | features/tolur/     |
//   | Settings screen body     | Text('Stillingar')                   | features/parent_settings/ |
//
// Future phases will add Semantics labels (`Semantics(label: ...)`) for
// child-friendly accessibility AND to give the MCP agent richer hooks. Phase 1
// uses `Key` lookup because the keys already exist for `flutter_test`/
// `integration_test` and Marionette MCP can resolve them via
// `find_widgets_by_key`.
//
// =============================================================================

/// Marker symbol for `tools/run-marionette.sh` to grep against — confirms this
/// file exists and is the canonical Phase 1 smoke reference. Not consumed by
/// any Dart compiler; this file is documentation-as-code.
const String hugrunPhase1MarionetteSmokeReference = '01-04';
