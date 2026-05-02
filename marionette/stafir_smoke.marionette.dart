// =============================================================================
// Hugrún Phase 4 Marionette MCP smoke harness — Stafir Tap-to-Hear MVP
// =============================================================================
//
// Execution model: identical to Phase 1's smoke.marionette.dart. Run the
// app in debug mode (`flutter run`), point an AI agent's Marionette MCP
// server at the Flutter VM, and have the agent drive the scenarios below.
//
// =============================================================================
//
// ## Scenario 1: app launches + welcome narration fires
//   - Action: launch app on target device.
//   - Assert (logs): "[AudioEngine] play(narrationWelcome)" appears in
//     debug output within ~3 s of launch (or
//     "narrationWelcomeGeneric" once Phase 3 ships the variant).
//   - Assert (audio, optional): the device produces audible sound (manual
//     verification — MCP can't directly observe audio).
//
// ## Scenario 2: home → Stafir → grid renders 32 letters
//   - Action: tap Key('home-room-stafir').
//   - Assert: route stack contains StafirRoom.
//   - Assert: 32 widgets with Key matching r"letter-tile-\d+-[\w_]+" exist.
//   - Assert: AppBar text "Stafir" visible.
//
// ## Scenario 3: tap each letter, observe audio + visual feedback
//   - For each i in 0..31:
//     - Action: tap Key('letter-tile-${i}-{slug}').
//     - Assert (visual): screenshot shows tile in mid-scale (~0.95) within 50 ms.
//     - Assert (logs): if the letter has a real clip in the active manifest,
//       expect a "[AudioEngine] play(letter${slug})" log line. Phase 2 stub
//       state: only a, eth, thorn play; rest log "no clip for letter..."
//     - Action: wait 100 ms.
//
// ## Scenario 4: example word overlay appears for letters with paired words
//   - Phase 2 stub: kLetterToWord is empty, so zero overlays.
//   - Phase 3 (post-manifest swap-in): expect 32 overlays — fade-in,
//     ~3 s visible, fade-out.
//
// ## Scenario 5: parent gate → settings → change name → restart
//   - Action: long-press Key('parent-gate-ring') host (settings icon).
//   - Assert: ring-fill animates over 3 s.
//   - Action: clear TextField, type "Anna", tap Key('parent-settings-vista').
//   - Assert: "Vistað ✓" briefly visible.
//   - Action: kill + relaunch app.
//   - Assert (logs): on next launch, narrationWelcomeGeneric (or
//     narrationWelcome with Phase 2 stub-fallback warning) plays — NOT
//     narrationWelcome with name 'Hugrún'.
//
// ## Scenario 6: cancel-on-retap (manual hearing test)
//   - Action: tap letterA, then within ~50 ms tap letterA again.
//   - Assert (audio): no overlap — second tap cancels first, name plays
//     once cleanly. (240fps camera not required for this; ear-test is
//     sufficient.)
//
// =============================================================================
//
// Widget-finding contract additions (Phase 4):
//
//   | Widget                   | Find by                              | Source |
//   |--------------------------|--------------------------------------|--------|
//   | LetterTile (32 of)       | Key('letter-tile-N-slug')            | features/stafir/widgets/letter_tile.dart |
//   | LetterGrid               | Type LetterGrid                      | features/stafir/widgets/letter_grid.dart |
//   | ExampleWordOverlay       | Type ExampleWordOverlay              | features/stafir/widgets/example_word_overlay.dart |
//   | Vista save button        | Key('parent-settings-vista')         | features/parent_settings/parent_settings_screen.dart |
//   | Save confirmation        | Key('parent-settings-saved-confirm') | features/parent_settings/parent_settings_screen.dart |
//
// =============================================================================

/// Marker symbol for `tools/run-marionette.sh` to grep against — confirms
/// this file exists and is the canonical Phase 4 smoke reference.
const String hugrunPhase4MarionetteSmokeReference = '04-07';
