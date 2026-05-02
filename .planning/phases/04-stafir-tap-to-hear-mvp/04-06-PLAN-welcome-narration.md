---
phase: 04-stafir-tap-to-hear-mvp
plan: 06
type: execute
wave: 3
depends_on:
  - 04-02   # AudioEngine.play queue
  - 04-05   # childNameProvider
files_modified:
  - lib/features/home/welcome_narration_controller.dart
  - lib/features/home/welcome_narration_controller.g.dart
  - lib/features/home/home_page.dart
  - test/features/home/welcome_narration_controller_test.dart
  - test/features/home/home_page_welcome_test.dart
autonomous: true
requirements:
  - PERS-03  # child's name used in at least one voice-over
tags:
  - flutter
  - riverpod
  - audio
  - phase-4

must_haves:
  truths:
    - "On HomePage mount, the welcome narration plays exactly once per app session"
    - "If the current child name is 'Hugrún', AudioEngine.play(UtteranceKey.narrationWelcome) fires"
    - "If the current child name is anything else (e.g. 'Anna'), AudioEngine.play(UtteranceKey.narrationWelcomeGeneric) fires (the name-less fallback)"
    - "If neither narration clip exists in the active manifest (Phase 2 stub state — narrationWelcomeGeneric isn't in the stub), the controller logs a debug warning and does NOT throw"
    - "Re-mounting HomePage in the same session (e.g. after popping from StafirRoom) does NOT re-play the welcome (D-19)"
    - "Changing the child name in settings during a session does NOT re-trigger the welcome — D-21 says 'no mid-session re-narration'"
    - "The welcome narration is fire-and-forget — HomePage build does NOT await it"
  artifacts:
    - path: "lib/features/home/welcome_narration_controller.dart"
      provides: "Riverpod (keepAlive) controller that fires the welcome exactly once per app session, name-aware"
      contains: "@Riverpod(keepAlive: true)"
    - path: "test/features/home/welcome_narration_controller_test.dart"
      provides: "Tests covering once-per-session, name 'Hugrún' → narrationWelcome, other → narrationWelcomeGeneric, missing-clip fallback, no re-trigger on name change"
      min_lines: 60
  key_links:
    - from: "lib/features/home/welcome_narration_controller.dart"
      to: "lib/features/parent_settings/child_name_provider.dart"
      via: "ref.read(childNameProvider.future) — single-shot lookup, NOT ref.watch (D-21)"
      pattern: "childNameProvider"
    - from: "lib/features/home/welcome_narration_controller.dart"
      to: "lib/core/audio/audio_engine_provider.dart"
      via: "ref.read(audioEngineProvider).play(narrationKey)"
      pattern: "audioEngineProvider"
    - from: "lib/features/home/home_page.dart"
      to: "lib/features/home/welcome_narration_controller.dart"
      via: "ref.read(welcomeNarrationControllerProvider).maybeFireOnce() in initState"
      pattern: "welcomeNarrationController"
---

<objective>
Hugrún opens the app and hears "Halló Hugrún" once. If a different child uses the device, they hear the name-less "Halló". This is the personalization payoff (PERS-03) — the moment that makes the app feel built for THIS child.

Implementation:
- A keep-alive Riverpod controller (`welcomeNarrationController`) holds a `bool _firedThisSession` flag. App-scoped, never autoDispose, so it survives navigation between rooms.
- HomePage's initState calls `controller.maybeFireOnce()` exactly once. If the flag is already set, no-op.
- The controller reads `childNameProvider` ONCE (using `.future` for a single-shot snapshot, NOT `.watch` which would re-fire on changes). Per D-21: name changes mid-session do NOT re-trigger the welcome.
- Selects narration variant based on name == 'Hugrún':
  - 'Hugrún' → UtteranceKey.narrationWelcome (the pre-baked "Halló Hugrún" clip — exists in Phase 2 stub).
  - other → UtteranceKey.narrationWelcomeGeneric (the name-less "Halló" clip — does NOT exist in stub yet; lands when Phase 3 ships).
- If the chosen UtteranceKey isn't in `kAudioManifest`, AudioEngine.play handles the fallback (Plan 02): logs warning, no audio, no error to user.

D-23 / D-22 stub-manifest reality:
- Phase 2 ships `narrationWelcome` (the "Halló Hugrún" placeholder).
- Phase 2 does NOT ship `narrationWelcomeGeneric`.
- Plan 06 must NOT add `narrationWelcomeGeneric` to the UtteranceKey enum — that's Phase 3's job. Plan 06 references the symbol via a guarded path: if the enum value doesn't exist YET (Phase 2 stub), the controller falls back to `narrationWelcome` for all names AND logs a debug warning explaining the temporary behavior.

Output: A working name-aware welcome narration that runs once on app start, and a clean upgrade path for when Phase 3 lands the generic narration clip.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md

@.planning/phases/04-stafir-tap-to-hear-mvp/04-CONTEXT.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-02-SUMMARY.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-05-SUMMARY.md

@lib/features/home/home_page.dart
@lib/core/audio/audio_engine.dart
@lib/core/audio/audio_engine_provider.dart
@lib/features/parent_settings/child_name_provider.dart
@lib/core/manifest/utterance_key.dart
@lib/gen/audio_manifest.g.dart

<interfaces>
<!-- Carry-forward from Plans 01, 02, 05. -->

From Plan 01:
```dart
@Riverpod(keepAlive: true) AudioEngine audioEngine(Ref ref);
```

From Plan 02:
```dart
class AudioEngine { Future<void> play(UtteranceKey key); }
```

From Plan 05:
```dart
@Riverpod(keepAlive: true) Stream<String?> childName(Ref ref); // generated symbol: childNameProvider
```

Phase 2 manifest entries:
- UtteranceKey.narrationWelcome → exists, plays "Halló Hugrún" (placeholder AAC)
- UtteranceKey.narrationWelcomeGeneric → DOES NOT EXIST in Phase 2 stub. Plan 06
  must reference it conditionally OR fall back to narrationWelcome.

Phase 1 lib/features/home/home_page.dart is currently a StatelessWidget. Plan 06
converts it to ConsumerStatefulWidget so initState can fire the welcome.
</interfaces>

<reference_decisions>
- D-18: Welcome narration uses child's name. If name == 'Hugrún' → narrationWelcome. Otherwise → narrationWelcomeGeneric ("Halló"). Both pre-baked in Phase 3; Phase 2 stub has only narrationWelcome.
- D-19: Welcome plays once per app session, on home screen mount (not on every navigation back to home).
- D-20: childNameProvider exists (Plan 05). Watched by ParentSettingsScreen (current value) AND welcome narration logic (which is what Plan 06 builds).
- D-21: Updating name via settings invalidates childNameProvider but does NOT re-trigger welcome. NO mid-session re-narration.
- D-22, D-23: Phase 2 stub fallback. narrationWelcomeGeneric doesn't exist yet; controller logs warning + falls back to narrationWelcome (or no-op).
</reference_decisions>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — write failing tests for WelcomeNarrationController + HomePage initState wiring</name>
  <files>
    test/features/home/welcome_narration_controller_test.dart,
    test/features/home/home_page_welcome_test.dart
  </files>
  <behavior>
    test/features/home/welcome_narration_controller_test.dart:
    - "maybeFireOnce with name 'Hugrún' calls audioEngine.play(narrationWelcome)" — fake AudioEngine + override childNameProvider to emit 'Hugrún'; call controller.maybeFireOnce(); assert fake.playCalls == [narrationWelcome]
    - "maybeFireOnce with name 'Anna' attempts to play narrationWelcomeGeneric (or falls back to narrationWelcome with warning when generic isn't in enum/manifest)" — exact assertion: assert fake.playCalls.length == 1; assert played key is narrationWelcomeGeneric IF the symbol exists, ELSE narrationWelcome (test conditioned on the enum)
    - "maybeFireOnce called twice in same session fires only once" — call twice; assert fake.playCalls.length == 1
    - "maybeFireOnce when childNameProvider is still loading falls back gracefully (no audio fired, no exception)"
    - "Changing childNameProvider value AFTER first fire does NOT trigger a second fire" — fire once with 'Hugrún', then update provider to 'Anna', assert fake.playCalls.length still == 1
    - "maybeFireOnce when AudioEngine.play throws does NOT propagate the exception" — fake throws on play; assert no exception escapes maybeFireOnce

    test/features/home/home_page_welcome_test.dart:
    - "Mounting HomePage calls maybeFireOnce on the welcome controller" — pump with overridden welcomeNarrationControllerProvider returning a fake; assert fake.maybeFireOnceCalls == 1
    - "Popping back to HomePage from another route does NOT call maybeFireOnce a second time" — pump HomePage, push StafirRoom, pop, assert fake.maybeFireOnceCalls == 1 (controller's once-flag handles this; HomePage initState fires it both times but the controller deduplicates)
    - "Existing HomePage tests still pass (room buttons, parent gate, settings nav)" — re-run Phase 1 home_page_test.dart and assert no regression
  </behavior>
  <action>
    Write the two test files. Tests fail because:
    - WelcomeNarrationController doesn't exist
    - HomePage initState doesn't reference any controller

    Atomic commit: `test(04-06): add failing tests for welcome narration once-per-session controller`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test test/features/home/ 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    - 8+ new failing tests
    - Pre-existing home_page tests still pass
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — implement WelcomeNarrationController + wire HomePage</name>
  <files>
    lib/features/home/welcome_narration_controller.dart,
    lib/features/home/welcome_narration_controller.g.dart,
    lib/features/home/home_page.dart
  </files>
  <action>
    1. `lib/features/home/welcome_narration_controller.dart`:
       ```dart
       import 'package:flutter/foundation.dart';
       import 'package:riverpod_annotation/riverpod_annotation.dart';
       import 'package:hugrun/core/audio/audio_engine_provider.dart';
       import 'package:hugrun/core/manifest/utterance_key.dart';
       import 'package:hugrun/features/parent_settings/child_name_provider.dart';

       part 'welcome_narration_controller.g.dart';

       const String _kCanonicalChildName = 'Hugrún'; // D-18 — clip-coverage symbol

       /// App-scoped (D-19, D-20) — survives room navigation. The once-per-
       /// session flag lives on this object; HomePage's initState calls
       /// maybeFireOnce on every mount, but the second call is a no-op.
       @Riverpod(keepAlive: true)
       class WelcomeNarrationController extends _$WelcomeNarrationController {
         bool _fired = false;

         @override
         WelcomeNarrationController build() =&gt; this;

         /// Single-shot snapshot of childNameProvider — D-21: name changes
         /// mid-session do NOT re-trigger the welcome.
         Future&lt;void&gt; maybeFireOnce() async {
           if (_fired) return;
           _fired = true; // claim the slot before any await — defends against double-fire from rapid mounts

           try {
             final name = await ref.read(childNameProvider.future);
             final key = _selectKey(name);
             if (key == null) {
               debugPrint('[WelcomeNarration] no welcome variant available for name=$name; skipping.');
               return;
             }
             // Fire-and-forget through AudioEngine. Plan 02's play() handles
             // missing-clip fallback (Phase 2 stub manifest may not have the
             // generic variant yet).
             // ignore: unawaited_futures
             ref.read(audioEngineProvider).play(key);
           } catch (e) {
             debugPrint('[WelcomeNarration] error: $e');
             // Do NOT propagate. HomePage build must not crash because of audio.
           }
         }

         UtteranceKey? _selectKey(String? name) {
           if (name == _kCanonicalChildName) return UtteranceKey.narrationWelcome;
           // Phase 2 stub: narrationWelcomeGeneric is NOT in the enum yet.
           // Phase 3's manifest writer will extend the enum; until then, fall back
           // to the only narration we have, with a debug warning so it's
           // visible during development.
           return _genericKeyOrFallback();
         }

         UtteranceKey? _genericKeyOrFallback() {
           // Compile-time guard: try to reference the generic variant; if it
           // doesn't exist in the enum, this code won't compile and we'll know.
           // The pattern here is — try a switch on UtteranceKey.values where
           // we look up by name string. Phase 2 stub: the lookup returns null
           // and we log a warning + fall back to narrationWelcome.
           final maybeGeneric = UtteranceKey.values
               .where((k) =&gt; k.name == 'narrationWelcomeGeneric')
               .toList();
           if (maybeGeneric.isNotEmpty) return maybeGeneric.first;
           debugPrint('[WelcomeNarration] WARNING: narrationWelcomeGeneric not in stub manifest — '
               'falling back to narrationWelcome. Phase 3 will fix.');
           return UtteranceKey.narrationWelcome;
         }
       }
       ```

       Note: using `UtteranceKey.values.where(...)` to detect symbol presence at runtime keeps Phase 2 compilation working even though the generic-narration enum value doesn't exist. Phase 3's manifest writer adds the value; the same code at runtime starts returning the new key with no edit needed.

       Generate `welcome_narration_controller.g.dart` via `dart run build_runner build`.

    2. `lib/features/home/home_page.dart` — convert to ConsumerStatefulWidget:
       ```dart
       import 'package:flutter/material.dart';
       import 'package:flutter_riverpod/flutter_riverpod.dart';

       import '../../core/parent_gate/parent_gate.dart';
       import '../parent_settings/parent_settings_screen.dart';
       import '../stafir/stafir_room.dart';
       import '../tolur/tolur_room.dart';
       import 'room_button.dart';
       import 'welcome_narration_controller.dart';

       /// Two-room home shell + once-per-session welcome narration (D-19, PERS-03).
       class HomePage extends ConsumerStatefulWidget {
         const HomePage({super.key});
         @override
         ConsumerState&lt;HomePage&gt; createState() =&gt; _HomePageState();
       }

       class _HomePageState extends ConsumerState&lt;HomePage&gt; {
         @override
         void initState() {
           super.initState();
           // Schedule on next frame so build can render before audio fires.
           WidgetsBinding.instance.addPostFrameCallback((_) {
             // Fire-and-forget; controller deduplicates.
             // ignore: unawaited_futures
             ref.read(welcomeNarrationControllerProvider).maybeFireOnce();
           });
         }

         @override
         Widget build(BuildContext context) {
           // unchanged from Phase 1 — Scaffold, AppBar with parent-gate settings entry, _RoomGrid body
           return Scaffold(
             appBar: AppBar(
               title: const Text('Hugrún'),
               actions: &lt;Widget&gt;[
                 ParentGate(
                   onCompleted: () {
                     Navigator.of(context).push(
                       MaterialPageRoute&lt;void&gt;(builder: (_) =&gt; const ParentSettingsScreen()),
                     );
                   },
                   child: const Padding(
                     padding: EdgeInsets.all(12),
                     child: Icon(Icons.settings, size: 32),
                   ),
                 ),
               ],
             ),
             body: const SafeArea(child: Center(child: _RoomGrid())),
           );
         }
       }

       // _RoomGrid copied verbatim from Phase 1.
       ```

    Run `flutter test test/features/home/`; all should pass.

    Atomic commit: `feat(04-06): once-per-session welcome narration with name-aware variant selection (D-18, D-19, D-21, PERS-03)`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - 8+ new tests green
    - Pre-existing tests still green
    - `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: REFACTOR — extract narration-key selection into pure function for testability</name>
  <files>
    lib/features/home/welcome_narration_keys.dart,
    lib/features/home/welcome_narration_controller.dart,
    test/features/home/welcome_narration_keys_test.dart
  </files>
  <action>
    Pull the variant-selection out of the controller into a pure function:

    `lib/features/home/welcome_narration_keys.dart`:
    ```dart
    import 'package:hugrun/core/manifest/utterance_key.dart';

    const String kCanonicalChildName = 'Hugrún';

    /// Pure: name → UtteranceKey selection logic (D-18).
    /// Returns null when no narration is available for the input.
    /// Tests: feed 'Hugrún', 'Anna', null, '', 'HUGRÚN' (case-sensitive — assert distinct from 'Hugrún').
    UtteranceKey? selectWelcomeNarrationKey(String? name) {
      if (name == kCanonicalChildName) return UtteranceKey.narrationWelcome;
      // Generic variant — present in Phase 3, absent in Phase 2 stub.
      final generic = UtteranceKey.values.where((k) => k.name == 'narrationWelcomeGeneric').toList();
      if (generic.isNotEmpty) return generic.first;
      // Stub fallback: re-use the canonical narration. The Hugrún clip will play even when name doesn't match — acceptable for stub-only state.
      return UtteranceKey.narrationWelcome;
    }
    ```

    Add `test/features/home/welcome_narration_keys_test.dart` with 5 cases (canonical, other-name, null, empty, case-mismatch). Update `WelcomeNarrationController` to call `selectWelcomeNarrationKey`.

    Atomic commit: `refactor(04-06): extract pure selectWelcomeNarrationKey for unit-test coverage`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - All tests green (5 new pure tests + retained existing)
    - `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| childNameProvider → narration controller | DB-sourced name flows to audio dispatch |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-20 | T (tampering) | name change mid-session triggers re-narration | mitigate | controller reads childNameProvider via `.future` (single-shot) NOT `.watch`; once-flag set BEFORE await per D-21 |
| T-04-21 | I (info disclosure) | child name leaked to logs | mitigate | controller never logs the name itself; only logs "no narration variant available" with the generic key name |
| T-04-22 | D (DoS) | rapid HomePage re-mounts cause double-fire | mitigate | once-flag claimed BEFORE await; concurrent maybeFireOnce calls are deduplicated |
| T-04-23 | E (elevation) | AudioEngine.play exception bubbles up + crashes app | mitigate | maybeFireOnce wraps the call in try/catch + debugPrint; never rethrows |
</threat_model>

<verification>
- `flutter test` — all green (≥150 tests)
- `flutter analyze` — 0 issues
- `dart format --set-exit-if-changed .` — clean
- `flutter build apk --debug` — succeeds

Manual smoke (deferred to Plan 07): launch app on device, confirm "Halló Hugrún" plays once. Change name to "Anna" in settings. Reopen app (kill + relaunch). Confirm name-less "Halló" plays. (Or, in Phase 2 stub state: confirm narrationWelcome plays both times with debug warning logged.)
</verification>

<success_criteria>
- WelcomeNarrationController fires once per session, name-aware
- HomePage initState wires the trigger via post-frame callback
- Manifest swap-in is automatic — no code change needed when Phase 3 ships narrationWelcomeGeneric
- 8+ new tests
- 3 atomic commits (RED → GREEN → REFACTOR)
</success_criteria>

<output>
Create `.planning/phases/04-stafir-tap-to-hear-mvp/04-06-SUMMARY.md` with:
- Welcome narration flow (name → key → play, once per session, no mid-session re-fire)
- Decisions exercised: D-18, D-19, D-20, D-21
- Requirements satisfied: PERS-03 (with stub-manifest caveat documented)
- Test count delta
- Atomic commits + SHAs
- Phase 3 swap-in note: when narrationWelcomeGeneric is added to the enum, no Plan 06 code changes — `selectWelcomeNarrationKey` finds the new symbol via `UtteranceKey.values` reflection-style lookup
</output>
