---
phase: 04-stafir-tap-to-hear-mvp
plan: 07
type: execute
wave: 4
depends_on:
  - 04-01
  - 04-02
  - 04-03
  - 04-04
  - 04-05
  - 04-06
files_modified:
  - integration_test/stafir_flow_test.dart
  - integration_test/test_helpers/fake_audio_engine.dart
  - marionette/stafir_smoke.marionette.dart
  - marionette/README.md
  - .planning/phases/04-stafir-tap-to-hear-mvp/LATENCY-VERIFICATION.md
autonomous: false   # Task 4 is a checkpoint:human-verify (240fps latency on real hardware)
requirements:
  - STAFIR-02  # ≤50ms perceived latency (this plan owns the verification gate)
  - STAFIR-09  # warm pool — verified end-to-end via integration test
tags:
  - flutter
  - integration-test
  - marionette
  - phase-4

must_haves:
  truths:
    - "An integration test exercises the full Stafir flow: open app → see HomePage → tap Stafir → see 32-letter grid → tap 5 different letters → assert AudioEngine got 5 .play calls in order → no exceptions"
    - "The integration test runs on iOS Simulator + Android Emulator under the same Phase 1 CI infrastructure"
    - "The Marionette MCP harness has a Phase-4 reference document (`marionette/stafir_smoke.marionette.dart`) describing the scenarios an AI agent / human can drive interactively"
    - "A LATENCY-VERIFICATION.md document specifies the 240fps camera test: setup, what to record, what to measure, what counts as PASS (<50ms tap-to-audio-onset)"
    - "A checkpoint:human-verify task surfaces this latency-verification step to the user for sign-off — Phase 4 / MVP cannot be marked complete until Jon runs the test on Hugrún's actual tablet"
    - "All Phase 4 success criteria are evaluated and reported in 04-VERIFICATION.md (orchestrator-owned; this plan generates the inputs)"
  artifacts:
    - path: "integration_test/stafir_flow_test.dart"
      provides: "End-to-end test of HomePage → StafirRoom → 5 letter taps → assertion on audio dispatch"
      min_lines: 80
    - path: "integration_test/test_helpers/fake_audio_engine.dart"
      provides: "Test-double AudioEngine that records play() calls; reusable across integration tests"
      min_lines: 30
    - path: "marionette/stafir_smoke.marionette.dart"
      provides: "Documentation-as-code reference for AI-agent driven Stafir smoke (extends Phase 1's smoke.marionette.dart pattern)"
      min_lines: 80
    - path: ".planning/phases/04-stafir-tap-to-hear-mvp/LATENCY-VERIFICATION.md"
      provides: "240fps camera test procedure + measurement worksheet + PASS criterion"
      min_lines: 60
  key_links:
    - from: "integration_test/stafir_flow_test.dart"
      to: "lib/features/home/home_page.dart"
      via: "pumpWidget(ProviderScope(overrides: [audioEngineProvider.overrideWith(...)], child: HugrunApp()))"
      pattern: "audioEngineProvider\\.overrideWith"
    - from: "integration_test/stafir_flow_test.dart"
      to: "integration_test/test_helpers/fake_audio_engine.dart"
      via: "FakeAudioEngine records play(UtteranceKey) calls in a list"
      pattern: "FakeAudioEngine"
    - from: ".planning/phases/04-stafir-tap-to-hear-mvp/LATENCY-VERIFICATION.md"
      to: "STAFIR-02 acceptance"
      via: "Manual 240fps verification on Hugrún's tablet — ONLY way to satisfy STAFIR-02 per D-28"
      pattern: "240fps"
---

<objective>
The MVP isn't shipped until Hugrún can pick up her tablet and have it feel right. This plan closes Phase 4:

1. **Integration test** that runs the full flow under CI: open the app → land on HomePage → tap Stafir → see the grid → tap 5 letters → confirm AudioEngine received 5 play calls in the right order with no exceptions. This is D-26.

2. **Marionette E2E reference** extending Phase 1's `smoke.marionette.dart` pattern with Phase-4 scenarios: home → Stafir → tap each row of letters → return → parent gate → settings → name change → restart and re-test welcome. This is D-27.

3. **Latency verification document** — D-28 says latency is NOT in CI (it's a 240fps camera test on real hardware). This plan ships a clear procedure for Jon to run the test, what counts as pass, what to do on fail.

4. **Checkpoint** that pauses for Jon to actually run the latency test on Hugrún's tablet AND tap each of the 32 letters to verify the room feels right end-to-end. This is the MVP signoff gate.

Why this is the last plan: it depends on every prior plan in Phase 4. It cannot start until 01-06 land.

Output: A green integration test in CI, a Marionette reference doc, a latency-verification procedure, and a checkpoint for human signoff. After this plan completes (and the checkpoint passes), Phase 4 is shippable.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/ROADMAP.md

@.planning/phases/04-stafir-tap-to-hear-mvp/04-CONTEXT.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-01-SUMMARY.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-02-SUMMARY.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-03-SUMMARY.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-04-SUMMARY.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-05-SUMMARY.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-06-SUMMARY.md

@.planning/phases/01-skeleton-drift-schema/01-04-SUMMARY.md
@.planning/research/PITFALLS.md

@integration_test/marionette_smoke_test.dart
@integration_test/no_network_test.dart
@integration_test/database_smoke_test.dart
@marionette/smoke.marionette.dart
@marionette/README.md

<interfaces>
<!-- Carry-forward from all Phase 4 plans. -->

From Plan 01:
```dart
@Riverpod(keepAlive: true) AudioEngine audioEngine(Ref ref);
```

From Plan 02:
```dart
class AudioEngine { Future<void> play(UtteranceKey key); Future<void> stop(); }
```

From Plan 04:
```dart
class StafirRoom extends ConsumerStatefulWidget; // 32-tile grid
```

Tile Keys exposed by Plan 04:
```
Key('letter-tile-$index-${letter.assetSlug}') // e.g. 'letter-tile-0-a', 'letter-tile-4-eth'
```

From Plan 06:
```dart
@Riverpod(keepAlive: true) class WelcomeNarrationController extends _$WelcomeNarrationController;
```

Phase 1 integration_test/marionette_smoke_test.dart established the pattern:
- IntegrationTestWidgetsFlutterBinding.ensureInitialized()
- pumpWidget(ProviderScope(child: HugrunApp()))
- pumpAndSettle()
- find by Key, tap, pumpAndSettle, assert
</interfaces>

<reference_decisions>
- D-26: Integration test — full Stafir flow — tap 5 different letters, verify audio fires, no exceptions, no audio overlap. Uses fake AudioPlayer (or fake AudioEngine — Plan 07 chooses fake AudioEngine for simpler assertion).
- D-27: Marionette E2E — scripted variant exercises home → Stafir → tap letter → return on iOS Sim + Android Emulator. MCP variant for interactive AI-agent / Jon driving.
- D-28: NO latency-measurement test in CI — that's a 240fps camera test on Hugrún's tablet, manual before MVP signoff. Document as checkpoint.
</reference_decisions>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — write the integration test (will fail until Task 2 lands FakeAudioEngine helper + provider override pattern)</name>
  <files>
    integration_test/stafir_flow_test.dart,
    integration_test/test_helpers/fake_audio_engine.dart
  </files>
  <behavior>
    integration_test/stafir_flow_test.dart:

    Scenario "Phase 4 MVP smoke — home + welcome + 5 letter taps + return":
    1. Pump `ProviderScope` with `audioEngineProvider` overridden by `FakeAudioEngine()` and a fresh in-memory Drift DB so tests don't conflict.
    2. `await tester.pumpAndSettle()` — let HomePage initState fire welcome.
    3. Assert `fakeEngine.playCalls.length == 1` (welcome narration fired exactly once)
    4. Assert `fakeEngine.playCalls[0]` ∈ {UtteranceKey.narrationWelcome, UtteranceKey.narrationWelcomeGeneric}
    5. Tap the Stafir room button (`Key('home-room-stafir')`); pumpAndSettle.
    6. Assert `find.byType(StafirRoom)` is present
    7. Assert `find.byType(LetterTile)` returns 32 widgets
    8. Tap 5 letters by Key in order: 'letter-tile-0-a', 'letter-tile-4-eth', 'letter-tile-29-thorn', 'letter-tile-9-h', 'letter-tile-30-ae'. (h and æ have no clip in stub — graceful no-op exercises Plan 04's null-key path.) After each tap, pump 100 ms (no pumpAndSettle — we want to see consecutive cancel-on-retap behavior).
    9. Assert that fakeEngine.playCalls now contains the welcome + the letter keys for tiles whose UtteranceKey resolves (a, eth, thorn). The h and æ taps are silent in stub — assert they are NOT in playCalls.
    10. Assert no exception was caught by tester.takeException().
    11. Pop back to HomePage. Pumping does NOT add another welcome call (Plan 06 once-per-session check).
    12. Assert fakeEngine.playCalls.length unchanged after the pop.

    Scenario "no audio overlap on rapid retap":
    1. Pump app + navigate to StafirRoom (same as scenario 1 setup).
    2. Tap letterA, then immediately (within 50 ms) tap letterA again.
    3. Assert fakeEngine.stopCalls.length >= 1 (cancel-on-retap fired) AND fakeEngine.playCalls now contains 2 entries for letterA (re-trigger).

    integration_test/test_helpers/fake_audio_engine.dart:
    Subclass AudioEngine. Override `warmUp` (no-op), `dispose` (no-op), `play(key)` (record), `stop()` (record). Expose `playCalls` and `stopCalls` lists for assertion.

    NOTE: Phase 1 integration_test/marionette_smoke_test.dart constructs HugrunApp directly via `pumpWidget(ProviderScope(child: HugrunApp()))` — Plan 07 follows the same pattern. The `ProviderScope.overrides` parameter takes the FakeAudioEngine override.
  </behavior>
  <action>
    Write the integration test + FakeAudioEngine helper. Tests fail because the helper doesn't exist + the integration_test pump path isn't yet wired with the override.

    Atomic commit: `test(04-07): integration test for full Stafir flow + 5 taps + cancel-on-retap`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test integration_test/stafir_flow_test.dart 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    - 2 failing scenarios in stafir_flow_test.dart
    - FakeAudioEngine helper created
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — make integration test pass + extend Marionette MCP reference doc</name>
  <files>
    integration_test/test_helpers/fake_audio_engine.dart,
    marionette/stafir_smoke.marionette.dart,
    marionette/README.md
  </files>
  <action>
    1. Finalize `integration_test/test_helpers/fake_audio_engine.dart`:
       ```dart
       import 'package:hugrun/core/audio/audio_engine.dart';
       import 'package:hugrun/core/manifest/utterance_key.dart';

       /// Test-double AudioEngine — records every play()/stop() call.
       /// No actual audio playback. Subclasses real AudioEngine to avoid
       /// re-implementing the just_audio surface.
       class FakeAudioEngine extends AudioEngine {
         FakeAudioEngine() : super(playerFactory: _NullPlayerFactory.create);
         final List&lt;UtteranceKey&gt; playCalls = [];
         final List&lt;void&gt; stopCalls = [];

         @override Future&lt;void&gt; warmUp() async { /* no-op */ }
         @override Future&lt;void&gt; dispose() async { /* no-op */ }
         @override Future&lt;void&gt; play(UtteranceKey key) async { playCalls.add(key); }
         @override Future&lt;void&gt; stop() async { stopCalls.add(null); }
       }
       ```
       (`_NullPlayerFactory` is a tiny helper that returns a NoOpAudioPlayer satisfying AudioPlayerLike — needed because the AudioEngine constructor allocates the pool. If the simpler approach is to just override warmUp to no-op + skip allocation, do that instead — record the choice.)

    2. Confirm the integration test runs green: `flutter test integration_test/stafir_flow_test.dart`. If any test still fails, debug — likely the welcome narration once-per-session may double-fire if multiple ProviderScope rebuilds happen during navigation. Adjust expectations or controller logic.

    3. `marionette/stafir_smoke.marionette.dart` — Phase 4 scenarios extending Phase 1's pattern:
       ```dart
       // =============================================================================
       // Hugrún Phase 4 Marionette MCP smoke harness — Stafir Tap-to-Hear MVP
       // =============================================================================
       //
       // Execution model: identical to Phase 1's smoke.marionette.dart. Run the
       // app in debug mode (`flutter run`), point an AI agent's Marionette MCP
       // server at the Flutter VM, and have the agent drive the scenarios below.
       //
       // ## Scenario 1: app launches + welcome narration fires
       //   - Action: launch app on target device.
       //   - Assert (logs): "[AudioEngine] play(narrationWelcome)" appears in
       //     debug output within ~3 s of launch.
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
       //     - Action: tap Key('letter-tile-${i}-...').
       //     - Assert (visual): screenshot shows tile in mid-scale (~0.95) within 50 ms.
       //     - Assert (logs): if the letter has a real clip, expect a
       //       "[AudioEngine] play(letter${assetSlug})" log line.
       //     - Action: wait 100 ms.
       //
       // ## Scenario 4: example word overlay appears for letters with paired words
       //   - Phase 2 stub: only triggers for letters whose pairing exists.
       //     In stub state, expect zero overlays. In post-Phase-3 state, expect 32.
       //
       // ## Scenario 5: parent gate → settings → change name → restart
       //   - Action: long-press Key('parent-gate-ring') host (settings icon).
       //   - Assert: ring-fill animates over 3 s.
       //   - Action: clear TextField, type "Anna", tap Key('parent-settings-vista').
       //   - Assert: "Vistað ✓" briefly visible.
       //   - Action: kill + relaunch app.
       //   - Assert (logs): on next launch, narrationWelcomeGeneric (or
       //     narrationWelcome with stub-fallback warning) plays — NOT
       //     narrationWelcome with name 'Hugrún'.
       //
       // Widget-finding contract additions (Phase 4):
       //
       //   | Widget                   | Find by                              | Source |
       //   |--------------------------|--------------------------------------|--------|
       //   | LetterTile (32 of)       | Key('letter-tile-N-slug')            | features/stafir/widgets/letter_tile.dart |
       //   | Vista save button        | Key('parent-settings-vista')         | features/parent_settings/parent_settings_screen.dart |
       //   | Save confirmation        | Key('parent-settings-saved-confirm') | features/parent_settings/parent_settings_screen.dart |
       //
       const String hugrunPhase4MarionetteSmokeReference = '04-07';
       ```

    4. Update `marionette/README.md` — add a "Phase 4 verification log" section pointing to `stafir_smoke.marionette.dart`, mirroring Phase 1's "Phase 1 verification log" pattern.

    Atomic commit: `feat(04-07): green stafir flow integration test + Marionette Phase-4 reference doc`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test integration_test/stafir_flow_test.dart &amp;&amp; flutter test &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - Both integration test scenarios green
    - All pre-existing tests still green
    - Marionette docs updated
    - Atomic commit landed
  </done>
</task>

<task type="auto">
  <name>Task 3: Document the 240fps latency verification procedure</name>
  <files>
    .planning/phases/04-stafir-tap-to-hear-mvp/LATENCY-VERIFICATION.md
  </files>
  <action>
    Write a complete, reproducible procedure for the manual 240fps latency test (D-28). This is the only path to satisfying STAFIR-02 ("≤50 ms perceived latency, measured via 240 fps camera test on real hardware").

    Document structure:

    ```markdown
    # STAFIR-02 Latency Verification — 240fps Camera Test

    **Owner:** Jon
    **Device under test:** Hugrún's actual tablet (note model + OS version)
    **Acceptance:** PASS if median tap-to-audio-onset across 10 trials ≤ 50 ms; FAIL otherwise

    ## Required equipment
    1. Hugrún's tablet (production hardware — NOT simulator).
    2. A second device that records video at 240 fps (recent iPhone via Camera app → "Slo-Mo" mode = 240fps; or any modern smartphone with a 240fps mode).
    3. Tripod or steady surface for the camera.
    4. The Hugrún app installed in release mode on the tablet (`flutter build apk --release` for Android; `flutter build ios --release` for iOS).

    ## Setup
    1. Plug tablet in (avoid thermal throttling on a low-battery device).
    2. Set tablet volume to ~50% (verify audio is audible).
    3. Position tablet flat on a table; position the 240fps camera looking down on the screen so:
       - The full 32-letter grid is visible
       - The tester's finger is visible approaching the screen
    4. Launch the Hugrún app fresh (kill any backgrounded copy first).
    5. Wait 5 seconds after launch before the first tap (let warm-up complete + welcome narration finish).

    ## Procedure (10 trials per cold start)
    1. Start 240fps recording.
    2. Tap a letter (use the same letter — letterA — for consistency across trials).
    3. Wait for the audio to finish.
    4. Wait 2 seconds. Tap again. Repeat for 10 trials.
    5. Stop recording. Repeat with a fresh app launch (kill + relaunch) twice more, for a total of 3 sessions × 10 trials = 30 measurements.

    ## Measurement
    For each trial, in the 240fps video (4.17 ms per frame):
    1. Identify the frame where the finger MAKES CONTACT with the screen (call it frame N_tap).
    2. Identify the frame where the audio onset is visible/audible. Two methods:
       - **Audio waveform:** import the video into a video editor (DaVinci Resolve free; iMovie). The waveform shows audio onset precisely. Frame number at first audio sample > -40 dBFS = N_audio.
       - **Visual cue (less reliable):** the LetterTile scale animation begins at frame N_tap regardless of audio. Use audio-onset.
    3. Latency = (N_audio - N_tap) × 4.17 ms.

    Record each trial:

    | Session | Trial | N_tap | N_audio | Latency (ms) | Pass (≤50)? |
    |---------|-------|-------|---------|--------------|-------------|
    | 1 | 1 | | | | |
    | 1 | 2 | | | | |
    | ... | ... | | | | |
    | 3 | 10 | | | | |

    ## Pass criterion
    - PASS: **median of 30 trials ≤ 50 ms** AND **no trial > 100 ms** (no outliers).
    - PASS WITH WARNING: median ≤ 50 ms but ≥1 trial in [50, 100] ms — investigate (likely first-tap cold path; D-08 silence pad may be missing).
    - FAIL: median > 50 ms — diagnose. Most likely causes:
      - Phase 3 silence-pad regression (D-08).
      - Warm pool not actually warming on this device (D-03).
      - Per-tap AudioPlayer creation slipped in (PITFALLS #4 #8).

    ## On FAIL
    Open `.planning/phases/04-stafir-tap-to-hear-mvp/04-VERIFICATION.md` and document the failing trials. Run `/gsd-plan-phase 4 --gaps` to create a remediation plan.

    ## On PASS
    Update `.planning/phases/04-stafir-tap-to-hear-mvp/04-VERIFICATION.md` STAFIR-02 row to "PASSED ({median} ms median, {min}-{max} range, N=30, on {device} {OS})".

    ## Why this is manual
    Latency below ~50 ms cannot be measured reliably from inside the app — Flutter's frame timing reports >16 ms granularity in best case, and audio-onset timing requires physical observation of the speaker output. PITFALLS #4 + research Finding 4 explicitly call out 240fps camera as the only reliable measurement.
    ```

    Atomic commit: `docs(04-07): document the 240fps STAFIR-02 latency verification procedure (D-28)`
  </action>
  <verify>
    <automated>test -f /Users/jonb/Projects/hugrun/.planning/phases/04-stafir-tap-to-hear-mvp/LATENCY-VERIFICATION.md &amp;&amp; wc -l /Users/jonb/Projects/hugrun/.planning/phases/04-stafir-tap-to-hear-mvp/LATENCY-VERIFICATION.md</automated>
  </verify>
  <done>
    - LATENCY-VERIFICATION.md exists, ≥ 60 lines, covers setup / procedure / measurement / pass / on-fail
    - Atomic commit landed
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 4: CHECKPOINT — Jon runs latency test on Hugrún's tablet AND end-to-end smoke</name>
  <what-built>
    All Phase 4 plans (01-06) complete. Integration test green. Marionette docs updated. LATENCY-VERIFICATION.md ready. The MVP is now ready for the human-only verification gate that closes Phase 4.

    What Claude has automated:
    - 32-letter Stafir grid + tap → AudioEngine.play wiring
    - Warm pool of 4 AudioPlayers initialized at app start
    - Cancel-on-retap + cancel-on-other-tap behavior
    - Welcome narration once-per-session, name-aware
    - Parent settings name field with Drift persistence
    - Integration test exercising the full flow
    - Marionette MCP reference for AI-agent / interactive verification

    What Claude CANNOT automate (per D-28):
    - 240fps camera latency measurement on real hardware
    - Subjective "does it feel right to a 5-year-old" verification
    - Audio quality on actual device speaker
  </what-built>
  <how-to-verify>
    Two parts. Both blocking.

    ### Part A: 240 fps latency measurement (STAFIR-02)
    Follow `.planning/phases/04-stafir-tap-to-hear-mvp/LATENCY-VERIFICATION.md` exactly. Run 30 trials (3 sessions × 10 taps) on Hugrún's tablet. Report:

    - Device + OS version
    - Median latency (ms)
    - Min / max latency (ms)
    - Number of trials > 50 ms

    Expected: median ≤ 50 ms, no trial > 100 ms.

    If FAIL: do NOT mark Phase 4 complete. Run `/gsd-plan-phase 4 --gaps` and add a remediation plan.

    ### Part B: End-to-end MVP smoke (subjective)
    On Hugrún's tablet, in release build (`flutter build apk --release` / `flutter build ios --release`):

    1. Launch app. Welcome "Halló Hugrún" plays once. ✓ / ✗
    2. Tap each of the 32 letters in the grid. Letters with Phase-2 stub clips (a, ð, þ) play letter name. Other letters are silent (visually responsive). ✓ / ✗
    3. Re-tap the same letter mid-playback. Audio cancels and restarts from letter name. No overlap. ✓ / ✗
    4. Tap a different letter mid-playback. Audio cancels and the new letter starts. No overlap. ✓ / ✗
    5. Tap targets feel ≥2 cm × 2 cm — easy to hit with a 5-year-old's finger. ✓ / ✗
    6. Visual feedback (scale animation) is instant on touch — does NOT wait for audio. ✓ / ✗
    7. No text instructions visible to child anywhere in Stafir. ✓ / ✗
    8. No failure / error / score / progress UI anywhere. ✓ / ✗
    9. Hold the settings icon for 3 seconds. Ring fills. Settings opens. ✓ / ✗
    10. Change name to a non-Hugrún name (e.g. "Anna"). Save. Kill app. Relaunch. Welcome plays the generic variant — OR plays the canonical narrationWelcome with a debug log warning if Phase 3 hasn't shipped yet. ✓ / ✗

    ### Part C: Phase 3 swap-in readiness
    Confirm the manifest swap-in instructions in `lib/features/stafir/stafir_room.dart` are clear. If Phase 3 has already shipped real audio, run the swap-in steps (extend `letterToUtteranceKey` switch + populate `kLetterToWord`) — Plan 07 does NOT require Phase 3 to be done.
  </how-to-verify>
  <resume-signal>
    Reply with one of:
    - "approved" — Phase 4 verified, mark MVP complete
    - "approved with notes: ..." — verified but with non-blocking observations
    - "fail: ..." — describe the failure; orchestrator will route to `/gsd-plan-phase 4 --gaps`
  </resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user → tablet | physical taps; the entire Phase 4 trust boundary |
| ProviderScope test override → real provider | integration tests inject FakeAudioEngine |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-24 | T (tampering) | integration test FakeAudioEngine drift from real | mitigate | FakeAudioEngine extends real AudioEngine and only overrides 4 methods; signature drift is a compile error |
| T-04-25 | I (info disclosure) | Marionette MCP harness in release build | accept | already mitigated in Phase 1 — `MarionetteBinding.ensureInitialized()` is gated on `kDebugMode`; release builds embed no MCP surface |
| T-04-26 | D (denial of service) | latency regression on tablet under thermal throttling | mitigate | LATENCY-VERIFICATION.md instructs the tester to plug in the tablet (avoid throttling) and run 3 sessions to detect outliers |
| T-04-27 | E (elevation) | child accidentally opens settings | mitigate | Phase 1 ParentGate (3-second hold) gates the settings entry; Phase 4 doesn't change this |
</threat_model>

<verification>
- `flutter test integration_test/stafir_flow_test.dart` — both scenarios green
- `flutter test` — all unit + widget tests green
- `flutter analyze` — 0 issues
- `flutter build apk --debug` — succeeds
- `flutter build ios --no-codesign --debug` — succeeds
- `LATENCY-VERIFICATION.md` exists with full procedure
- `marionette/stafir_smoke.marionette.dart` exists with Phase-4 scenarios
- `marionette/README.md` updated with Phase-4 verification log section
- Checkpoint Task 4: human-verify; resume signal received
</verification>

<success_criteria>
- Integration test exercises the full Phase-4 happy path + cancel-on-retap edge case
- FakeAudioEngine helper reusable for future phases
- Marionette MCP reference doc complete
- LATENCY-VERIFICATION.md complete and actionable
- Checkpoint signed off by Jon (or routed to gap-closure if FAIL)
- 3 atomic commits + 1 docs commit + (post-checkpoint) potential gap-closure plan
</success_criteria>

<output>
Create `.planning/phases/04-stafir-tap-to-hear-mvp/04-07-SUMMARY.md` with:
- Integration test scenarios + green status
- Marionette doc structure
- LATENCY-VERIFICATION.md outline
- Checkpoint outcome (after Jon resumes)
- Decisions exercised: D-26, D-27, D-28
- Requirements satisfied (gate-level): STAFIR-02 (PASS pending checkpoint), STAFIR-09 (warm pool verified end-to-end)
- Atomic commits + SHAs

Also create `.planning/phases/04-stafir-tap-to-hear-mvp/04-VERIFICATION.md` with the rubric for evaluating Phase 4 against the 5 ROADMAP success criteria. Mark each row's status based on the integration test + checkpoint outcome:

| # | Success criterion (verbatim from ROADMAP) | Status | Evidence |
|---|---|---|---|
| 1 | 32 letters in MMS order, ≥2cm × 2cm tap targets, synchronous visual feedback | TBD | letter_grid_test.dart + letter_tile_test.dart |
| 2 | Letter name plays in ≤50ms, then example word + image; no audio overlap | TBD | LATENCY-VERIFICATION.md (manual checkpoint) + audio_engine_play_test.dart |
| 3 | All 32 letters have ≥1 IPA-correct example word + matching image; AudioEngine warm pool of ≥2 | TBD | audio_engine_test.dart + Phase 3 manifest swap-in (post-Phase-3) |
| 4 | Zero text instructions, zero failure states, zero scores/timers/progress | TBD | letter_tile_test.dart + stafir_room_test.dart no-text/no-icon assertions |
| 5 | Child name persists, used in welcome with name-less fallback | TBD | parent_settings_db_test.dart + welcome_narration_keys_test.dart |
</output>
