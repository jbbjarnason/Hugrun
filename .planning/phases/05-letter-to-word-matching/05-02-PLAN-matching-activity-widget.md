---
phase: 05-letter-to-word-matching
plan: 02
type: tdd
wave: 2
depends_on:
  - 05-01
files_modified:
  - lib/features/stafir/matching/matching_activity.dart
  - lib/features/stafir/matching/matching_round_image.dart
  - lib/features/stafir/matching/matching_celebration.dart
  - lib/features/stafir/matching/matching_providers.dart
  - test/features/stafir/matching/matching_activity_test.dart
  - test/features/stafir/matching/matching_round_image_test.dart
  - test/features/stafir/matching/matching_celebration_test.dart
autonomous: true
requirements:
  - MATCH-01
  - MATCH-02
  - MATCH-03
  - MATCH-04
tags: [matching, widget, stafir, riverpod]

must_haves:
  truths:
    - "MatchingActivity renders one image (upper 60%) + 4 LetterTile options (row below)"
    - "Wrong tap is a complete no-op: no audio fires, no celebration, no error UI, no shake, no color change beyond LetterTile's intrinsic onTapDown squeeze (D-07, MATCH-02)"
    - "Correct tap fires AudioEngine.play with the round's targetWordKey (example-word audio as celebration cue per D-21)"
    - "Correct tap shows a tasteful celebration overlay (checkmark + scale-up, no stars/points)"
    - "After ~1.5s celebration, the activity advances to a new round automatically (D-09)"
    - "No round counter, no score, no streak, no timer is rendered anywhere (D-10)"
    - "MatchingActivity reuses LetterTile from Phase 4 directly (no duplicate widget)"
    - "MatchingActivity reuses AudioEngine via audioEngineProvider (no new audio plumbing)"
    - "Image area shows StockPlaceholder (text-on-color tile) for ImageSource.stockPlaceholder; PhotoOverride is wired to an asset-path probe stub for Phase 10"
  artifacts:
    - path: "lib/features/stafir/matching/matching_activity.dart"
      provides: "MatchingActivity ConsumerStatefulWidget — main screen for Match mode"
      contains: "class MatchingActivity"
    - path: "lib/features/stafir/matching/matching_round_image.dart"
      provides: "Renders MatchingRound.imageSource — placeholder text-on-color or photo stub"
      contains: "class MatchingRoundImage"
    - path: "lib/features/stafir/matching/matching_celebration.dart"
      provides: "Celebration overlay (checkmark + scale-up + fade) shown on correct tap"
      contains: "class MatchingCelebration"
    - path: "lib/features/stafir/matching/matching_providers.dart"
      provides: "roundGeneratorProvider (keepAlive) + photoOverrideSourceProvider (overridable for tests/Phase 10)"
      contains: "roundGeneratorProvider"
    - path: "test/features/stafir/matching/matching_activity_test.dart"
      provides: "Widget tests covering layout, wrong-tap no-op, correct-tap celebration + auto-advance"
    - path: "test/features/stafir/matching/matching_round_image_test.dart"
      provides: "Widget tests for stock placeholder vs photo override rendering"
    - path: "test/features/stafir/matching/matching_celebration_test.dart"
      provides: "Widget tests for celebration overlay timing + structure"
  key_links:
    - from: "lib/features/stafir/matching/matching_activity.dart"
      to: "lib/features/stafir/widgets/letter_tile.dart"
      via: "import + direct widget reuse for the 4 letter options"
      pattern: "import.*widgets/letter_tile"
    - from: "lib/features/stafir/matching/matching_activity.dart"
      to: "lib/core/audio/audio_engine_provider.dart"
      via: "ref.read(audioEngineProvider).play on correct tap only"
      pattern: "audioEngineProvider"
    - from: "lib/features/stafir/matching/matching_activity.dart"
      to: "lib/core/matching/round_generator.dart"
      via: "consumes roundGeneratorProvider for next-round generation"
      pattern: "roundGeneratorProvider"
    - from: "lib/features/stafir/matching/matching_providers.dart"
      to: "lib/core/matching/photo_override_source.dart"
      via: "photoOverrideSourceProvider returns EmptyPhotoOverrideSource in Phase 5"
      pattern: "EmptyPhotoOverrideSource"
---

<objective>
Build the Flutter widget layer for the matching activity. Renders one round at a time, handles wrong-tap silent no-op (MATCH-02 / D-07), correct-tap celebration (MATCH-03 / D-08), and auto-advance to the next round (D-09). Reuses Phase 4's `LetterTile` and `AudioEngine` without duplication (D-15).

Purpose:
- Deliver the visible activity surface that the child interacts with (MATCH-01).
- Lock the wrong-tap silent contract (MATCH-02) into a widget test that asserts zero AudioEngine.play calls on wrong taps — this is the most important behavioral test in Phase 5.
- Wire the round generator's photo override hook through a Riverpod provider so Phase 10 can override the binding without touching this code (MATCH-04).

Output:
- `MatchingActivity` widget — composes image + 4 tiles + celebration overlay.
- `MatchingRoundImage` — small widget that renders the current round's imageSource.
- `MatchingCelebration` — overlay (checkmark + scale + fade) shown on correct tap.
- `matching_providers.dart` — Riverpod providers for round generator + photo source.
- 3 widget test files exhaustively covering layout, tap behavior, celebration timing.

Depends on Plan 05-01. Plan 05-03 wires this widget into StafirRoom.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/05-letter-to-word-matching/05-CONTEXT.md
@.planning/phases/05-letter-to-word-matching/05-01-PLAN-round-generator.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-SUMMARY.md

@lib/features/stafir/widgets/letter_tile.dart
@lib/features/stafir/widgets/letter_tile_palette.dart
@lib/features/stafir/widgets/example_word_overlay.dart
@lib/features/stafir/example_word_resolver.dart
@lib/core/audio/audio_engine.dart
@lib/core/audio/audio_engine_provider.dart
@integration_test/test_helpers/fake_audio_engine.dart
@test/core/audio/_fakes/fake_audio_player.dart

<interfaces>
<!-- Contracts the matching widget consumes. Use these directly. -->

From lib/features/stafir/widgets/letter_tile.dart:
```dart
class LetterTile extends StatefulWidget {
  const LetterTile({
    super.key,
    required this.letter,           // IcelandicLetter
    required this.letterIndex,      // int — drives palette color
    required this.onLetterTap,      // ValueChanged<IcelandicLetter>
    this.minSize = 200,
  });
}
```
NOTE: LetterTile fires onLetterTap synchronously on TAP-DOWN. The matching
activity callback is also synchronous. The intrinsic squeeze animation
applies to all taps — wrong AND right — and that is the SOLE feedback for
wrong taps (D-07).

From lib/core/audio/audio_engine_provider.dart:
```dart
@Riverpod(keepAlive: true)
AudioEngine audioEngine(Ref ref);  // Plan 05-02 calls .play(UtteranceKey) on correct tap
```

From lib/core/audio/audio_engine.dart:
```dart
class AudioEngine {
  AudioEngine({ AudioPlayerLike Function()? playerFactory, ... });
  Future<void> play(UtteranceKey key);
  Future<void> stop();
}
```

From integration_test/test_helpers/fake_audio_engine.dart (REUSED in widget tests):
```dart
class FakeAudioEngine extends AudioEngine {
  final List<UtteranceKey> playCalls;
  int stopCallCount;
}
```
The widget tests construct a FakeAudioEngine, override audioEngineProvider via
ProviderScope.overrides = [ audioEngineProvider.overrideWithValue(fakeEngine) ]
and assert on `fakeEngine.playCalls`. Same pattern as Phase 4
test/features/stafir/stafir_room_test.dart — copy that test's setup.

From lib/core/matching/round_generator.dart (Plan 05-01 output):
```dart
class RoundGenerator {
  RoundGenerator({ int? seed, Map<UtteranceKey, AudioAsset>? manifestOverride,
                   PhotoOverrideSource photoSource, double photoFrequency });
  MatchingRound generate();
}
```

From lib/core/matching/matching_round.dart (Plan 05-01 output):
```dart
class MatchingRound {
  final UtteranceKey targetWordKey;
  final String targetWordSlug;
  final IcelandicLetter correctLetter;
  final List<IcelandicLetter> options;  // length 4, contains correctLetter
  final ImageSource imageSource;        // sealed: StockPlaceholder | PhotoOverride
}
sealed class ImageSource { /* StockPlaceholder(wordSlug), PhotoOverride(photoId) */ }
```

From lib/features/stafir/example_word_resolver.dart:
```dart
String exampleWordImagePath(String wordSlug);          // 'assets/images/letters/words/<slug>.webp'
String exampleWordPlaceholderText(String wordSlug);    // returns the slug as-is
```
</interfaces>
</context>

<tasks>

<task type="tdd" tdd="true">
  <name>Task 1: matching_providers.dart + MatchingRoundImage widget (RED + GREEN)</name>
  <files>
    lib/features/stafir/matching/matching_providers.dart,
    lib/features/stafir/matching/matching_round_image.dart,
    test/features/stafir/matching/matching_round_image_test.dart
  </files>
  <behavior>
    PROVIDER tests (in matching_round_image_test.dart's `group('providers', ...)`):
    P1: `photoOverrideSourceProvider` returns an `EmptyPhotoOverrideSource` by default in Phase 5 (D-13).
    P2: `roundGeneratorProvider` is `keepAlive: true` and constructs a RoundGenerator wired to the photo source.

    IMAGE tests:
    Test I1: Given a `MatchingRound` with `ImageSource.stockPlaceholder(wordSlug: 'hundur')`, `MatchingRoundImage` renders a Container with `Text('hundur')` (placeholder per D-12 — text-on-color, consistent with example_word_overlay).
    Test I2: Given `ImageSource.photoOverride(photoId: 'photo-1')`, `MatchingRoundImage` renders a placeholder labeled by photoId for now (Phase 5 ships the routing wired but no actual photo loading — Phase 10 fills the asset path resolution per D-13). The widget displays a Container with `Text` containing the photoId (or a `Key('matching-photo-override-photo-1')` marker — assertion-friendly).
    Test I3: The widget centers content in its parent and fills available width — wrap in `LayoutBuilder` to verify it expands.
    Test I4: NO Text instructions, NO score chip, NO timer — `find.byType(Text)` count is exactly 1 (the placeholder/photoId label).
  </behavior>
  <action>
    RED: Create `test/features/stafir/matching/matching_round_image_test.dart` with 4 image tests + 2 provider tests. Tests construct a `ProviderScope` and pump a `MaterialApp` containing `MatchingRoundImage(round: ...)`.
    Run `flutter test test/features/stafir/matching/matching_round_image_test.dart` — must fail.
    Commit: `test(05-02): add failing tests for MatchingRoundImage + matching providers`.

    GREEN — Step A: `lib/features/stafir/matching/matching_providers.dart`:
    ```dart
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:riverpod_annotation/riverpod_annotation.dart';
    import '../../../core/matching/photo_override_source.dart';
    import '../../../core/matching/round_generator.dart';

    part 'matching_providers.g.dart';

    /// Phase 5 default. Phase 10 will override this provider with a Drift-backed
    /// implementation. Marked keepAlive so the same source persists across
    /// navigation between Match and Letters modes.
    @Riverpod(keepAlive: true)
    PhotoOverrideSource photoOverrideSource(Ref ref) =>
        const EmptyPhotoOverrideSource();

    /// Round generator. keepAlive so the seeded `Random` (when used in tests)
    /// produces a stable sequence across the activity's lifetime. Production
    /// uses an unseeded Random.
    @Riverpod(keepAlive: true)
    RoundGenerator roundGenerator(Ref ref) =>
        RoundGenerator(photoSource: ref.watch(photoOverrideSourceProvider));
    ```
    Run build_runner: `dart run build_runner build --delete-conflicting-outputs`.

    GREEN — Step B: `lib/features/stafir/matching/matching_round_image.dart`:
    ```dart
    import 'package:flutter/material.dart';
    import '../../../core/matching/matching_round.dart';

    /// Renders the image area of a matching round (D-12, MATCH-04).
    /// Phase 5: stock placeholder = text-on-color tile (consistent with
    /// example_word_overlay's placeholder pattern). Photo override =
    /// labeled placeholder for now; Phase 10 fills in real photo loading.
    class MatchingRoundImage extends StatelessWidget {
      const MatchingRoundImage({super.key, required this.round});
      final MatchingRound round;

      @override
      Widget build(BuildContext context) {
        final src = round.imageSource;
        final label = switch (src) {
          StockPlaceholder(wordSlug: final slug) => slug,
          PhotoOverride(photoId: final id) => id,
        };
        final markerKey = switch (src) {
          StockPlaceholder() => Key('matching-stock-placeholder-${round.targetWordSlug}'),
          PhotoOverride(photoId: final id) => Key('matching-photo-override-$id'),
        };
        return LayoutBuilder(
          builder: (context, constraints) => Center(
            child: Container(
              key: markerKey,
              width: constraints.maxWidth * 0.8,
              constraints: const BoxConstraints(minHeight: 240),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4A6), // soft warm placeholder color
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        );
      }
    }
    ```
    Run `flutter test test/features/stafir/matching/matching_round_image_test.dart` — all 6 tests must pass.
    Commit: `feat(05-02): MatchingRoundImage + matching_providers (Phase 5 stub)`.
  </action>
  <verify>
    <automated>flutter test test/features/stafir/matching/matching_round_image_test.dart &amp;&amp; flutter analyze lib/features/stafir/matching test/features/stafir/matching</automated>
  </verify>
  <done>
    - `photoOverrideSourceProvider` and `roundGeneratorProvider` exist as keepAlive providers.
    - `MatchingRoundImage` renders both ImageSource variants with assertion-friendly Keys.
    - Exactly one Text widget per render (no labels/instructions; D-10 / STAFIR-08 spirit preserved).
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 2: MatchingCelebration overlay widget (RED + GREEN + REFACTOR)</name>
  <files>
    lib/features/stafir/matching/matching_celebration.dart,
    test/features/stafir/matching/matching_celebration_test.dart
  </files>
  <behavior>
    Test C1: When `visible: false`, the overlay renders nothing tappable, occupies zero painted area (use `IgnorePointer` with `child: SizedBox.shrink()` or similar — `find.byKey(Key('matching-celebration-active'))` returns nothing).
    Test C2: When `visible: true`, the overlay renders an Icon (checkmark — `Icons.check_circle_rounded` or similar) inside a fade+scale Tween.
    Test C3: Visibility transitions trigger the animation: pump `visible: true`, then pump animation duration (~600ms), assert opacity reaches 1.0 and scale reaches 1.0.
    Test C4: NO star icons, NO trophy icons, NO point counters — assert via `find.byIcon(Icons.star)` returning zero, `find.text(RegExp(r'\d'))` returning zero (no digits visible to the child).
    Test C5: The overlay is positioned via `Positioned.fill` (covers the activity area) and `IgnorePointer` (does not capture taps — child can still tap a tile underneath if they want; auto-advance will fire either way).
    Test C6: Total reserved animation duration constant exposed as `MatchingCelebration.duration = const Duration(milliseconds: 1500)` (D-09 — auto-advance ~1.5s after correct tap).
  </behavior>
  <action>
    RED: Create `test/features/stafir/matching/matching_celebration_test.dart` with the 6 tests above. Use `tester.pump(const Duration(milliseconds: 800))` and similar to step animation.
    Run `flutter test test/features/stafir/matching/matching_celebration_test.dart` — must fail.
    Commit: `test(05-02): add failing tests for MatchingCelebration overlay`.

    GREEN: Create `lib/features/stafir/matching/matching_celebration.dart`:
    - `class MatchingCelebration extends StatefulWidget` with `final bool visible;`.
    - Static `static const Duration duration = Duration(milliseconds: 1500);` — total reserved time D-09.
    - Internal `AnimationController` with duration ~600ms ease-out, drives a scale tween 0.6→1.0 and an opacity tween 0.0→1.0.
    - On `didUpdateWidget`, when `visible` toggles false→true: `controller.forward(from: 0)`. When true→false: `controller.reset()`.
    - `build`: returns `Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(...)))`.
      If `!visible`, return `const SizedBox.shrink()`.
      If visible, render a centered checkmark Icon inside `Opacity` + `Transform.scale`.
      Add `Key('matching-celebration-active')` on the active container.
    - Tasteful palette: green-soft `Color(0xFF66BB6A)` for the check; large size (~160 logical px); single Icon, no decorations.
    - NO star/trophy/burst iconography (D-08 narrative).
    Run `flutter test test/features/stafir/matching/matching_celebration_test.dart` — all 6 tests must pass.
    Commit: `feat(05-02): MatchingCelebration overlay (checkmark + scale fade)`.

    REFACTOR (if needed): extract animation curves into named constants; tighten the duration constants. If skipped, omit commit.
  </action>
  <verify>
    <automated>flutter test test/features/stafir/matching/matching_celebration_test.dart &amp;&amp; flutter analyze lib/features/stafir/matching test/features/stafir/matching</automated>
  </verify>
  <done>
    - MatchingCelebration responds to `visible` prop changes with a forward animation.
    - Zero stars/trophies/numbers/points per D-08 + D-10.
    - `MatchingCelebration.duration = 1500ms` exported (consumed by Task 3).
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 3: MatchingActivity widget — wrong-tap no-op + correct-tap celebrate + auto-advance (RED + GREEN + REFACTOR)</name>
  <files>
    lib/features/stafir/matching/matching_activity.dart,
    test/features/stafir/matching/matching_activity_test.dart
  </files>
  <behavior>
    Test A1 (layout): MatchingActivity renders exactly one `MatchingRoundImage`, exactly four `LetterTile`s, and one `MatchingCelebration` overlay (initially `visible: false`).
    Test A2 (tile palette indices): Each LetterTile receives a `letterIndex` corresponding to that letter's position in `kIcelandicAlphabet` (so palette colors stay consistent with Stafir grid). Asserted by inspecting the rendered LetterTile widgets.
    Test A3 (no audio plays on mount): Mount the widget under a ProviderScope with a `FakeAudioEngine` overriding `audioEngineProvider`. Pump. Assert `fakeEngine.playCalls.isEmpty`.
    Test A4 (WRONG TAP IS SILENT — the critical MATCH-02 test): Inject a `RoundGenerator` override with a deterministic seed AND a manifest containing `wordHundur` only (correct = `h`). Tap any LetterTile whose letter is NOT `h` (e.g. tap glyph `b`). Pump. Assert: `fakeEngine.playCalls.isEmpty`, `fakeEngine.stopCallCount == 0`, the celebration overlay is still `visible: false`, the activity is still on the SAME round (same target word, same options). Then tap another wrong letter — same assertions hold. The child can tap wrong letters indefinitely with zero side effects.
    Test A5 (CORRECT TAP — celebration + audio fires): Same setup as A4. Tap the LetterTile with glyph `h`. Pump one frame. Assert: `fakeEngine.playCalls == [UtteranceKey.wordHundur]` (D-21 — example word audio used as celebration cue). Pump 100ms; assert celebration overlay is `visible: true`. (The example-word audio is the ONLY audio fired — there is no separate `narrationCelebrationCorrect` clip in Phase 5 per D-21.)
    Test A6 (auto-advance): Continue from A5. Pump `MatchingCelebration.duration` (1.5s). Assert: a NEW round is now displayed (different `targetWordSlug` OR if the manifest only has `wordHundur`, a fresh MatchingRound instance — assert via the round provider state OR by checking that the celebration overlay has reset to `visible: false`). For a more robust check, use a manifest with TWO `word*` entries (`wordHundur` and a fake `wordSol`) and a seed that produces them in sequence. Assert second round's `targetWordSlug` differs from first.
    Test A7 (no fail UI): After 5 wrong taps in a row, `find.byIcon(Icons.error)` finds nothing, `find.byIcon(Icons.close)` finds nothing, `find.text(RegExp(r'wrong|nope|try'))` finds nothing.
    Test A8 (no score/streak/timer): At any point in the test, `find.text(RegExp(r'\\d+'))` returns nothing visible (no numbers shown to the child). No widget with `Key` containing 'score', 'streak', 'timer', 'count'.
    Test A9 (cancellation on rapid wrong tap then correct tap): Tap wrong letter, immediately (0ms pump) tap correct letter. Assert `fakeEngine.playCalls == [UtteranceKey.wordHundur]` (only correct tap fired audio; wrong tap was a no-op so there was nothing to cancel).
    Test A10 (LetterTile reuse): `find.byType(LetterTile)` returns exactly 4 widgets. (Confirms D-15 reuse: no duplicate tile widget.)
    Test A11 (auto-advance scheduling is robust to widget unmount): Tap correct letter, then immediately unmount widget (e.g. wrap in a `StatefulBuilder` that swaps in another widget). The pending auto-advance Timer must not throw or call setState on an unmounted widget. Pump 2s — no exceptions.
  </behavior>
  <action>
    RED: Create `test/features/stafir/matching/matching_activity_test.dart` with all 11 tests. Use the same ProviderScope override pattern as `test/features/stafir/stafir_room_test.dart` (Phase 4) — copy its setUp helpers including FakeAudioEngine wiring. For RoundGenerator override, override `roundGeneratorProvider` with a function returning `RoundGenerator(seed: 42, manifestOverride: { ... }, photoSource: const EmptyPhotoOverrideSource())`.
    Run `flutter test test/features/stafir/matching/matching_activity_test.dart` — must fail.
    Commit: `test(05-02): add failing tests for MatchingActivity (wrong-tap silent, correct-tap celebrate)`.

    GREEN: Create `lib/features/stafir/matching/matching_activity.dart`:
    - `class MatchingActivity extends ConsumerStatefulWidget` with optional `Key key`.
    - State holds: `MatchingRound? _currentRound`, `bool _celebrationVisible = false`, `Timer? _advanceTimer`.
    - `initState`: schedule first round generation after first frame: `WidgetsBinding.instance.addPostFrameCallback((_) => _generateRound())`. (Don't call provider methods inside initState directly — use post-frame to ensure ProviderScope is ready, mirroring Phase 4 WelcomeNarrationController pattern.)
    - `_generateRound()`:
      ```dart
      setState(() {
        _currentRound = ref.read(roundGeneratorProvider).generate();
        _celebrationVisible = false;
      });
      ```
    - `_onLetterTap(IcelandicLetter tapped)`:
      ```dart
      final round = _currentRound;
      if (round == null) return;
      if (tapped == round.correctLetter) {
        // CORRECT (D-08, D-09, D-21): play target word as celebration cue,
        // show overlay, schedule auto-advance.
        unawaited(ref.read(audioEngineProvider).play(round.targetWordKey));
        setState(() => _celebrationVisible = true);
        _advanceTimer?.cancel();
        _advanceTimer = Timer(MatchingCelebration.duration, () {
          if (mounted) _generateRound();
        });
      }
      // WRONG (D-07, MATCH-02): completely silent. NO audio, NO celebration,
      // NO state change. The intrinsic LetterTile squeeze animation is the
      // sole feedback. Do not even log — keep it pure no-op.
      ```
    - `dispose`: `_advanceTimer?.cancel()`.
    - `build`:
      ```dart
      final round = _currentRound;
      if (round == null) {
        // Pre-first-round empty state. No spinner, no text — just blank.
        return const SizedBox.expand();
      }
      return LayoutBuilder(builder: (context, constraints) {
        final imageHeight = constraints.maxHeight * 0.60;  // D-14
        return Stack(children: <Widget>[
          Column(children: <Widget>[
            SizedBox(height: imageHeight, child: MatchingRoundImage(round: round)),
            const SizedBox(height: 16),
            Expanded(child: _buildOptionsRow(round)),
          ]),
          MatchingCelebration(visible: _celebrationVisible),
        ]);
      });
      ```
    - `_buildOptionsRow(MatchingRound round)`:
      ```dart
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: round.options.map((letter) {
          final idx = kIcelandicAlphabet.indexOf(letter);
          return SizedBox(
            width: 160,
            child: LetterTile(
              key: Key('matching-option-${letter.assetSlug}'),
              letter: letter,
              letterIndex: idx,
              minSize: 0,
              onLetterTap: _onLetterTap,
            ),
          );
        }).toList(),
      );
      ```
    - Doc comment header: cite D-02, D-07, D-08, D-09, D-14, D-15, D-21; cite MATCH-01..04.

    Run `flutter test test/features/stafir/matching/matching_activity_test.dart` — all 11 must pass.
    Commit: `feat(05-02): MatchingActivity widget with silent wrong-tap + celebrate-on-correct + auto-advance`.

    REFACTOR (likely needed): extract the post-frame round-generation into a helper; consolidate the `_advanceTimer` cancel into a single `_clearPending()` method; add a small assertion `assert(round.options.length == 4)` in build for safety. If nothing meaningful, skip.
    Commit (optional): `refactor(05-02): tighten MatchingActivity timer + helpers`.
  </action>
  <verify>
    <automated>flutter test test/features/stafir/matching/ &amp;&amp; flutter analyze lib/features/stafir/matching test/features/stafir/matching</automated>
  </verify>
  <done>
    - All 11 widget tests pass, including the critical wrong-tap silence test (A4).
    - `flutter test` runs the entire suite without regression.
    - `flutter analyze` is clean for new files (modulo any pre-existing project-level riverpod_lint warnings).
    - The activity correctly renders + responds to taps + advances rounds without ever showing a fail/error/score/timer indicator.
  </done>
</task>

</tasks>

<verification>
- MATCH-01 (matching activity in Stafir): widget renders image + 4 options.
- MATCH-02 (silent wrong taps): Test A4 + A7 prove no audio + no error UI fires on wrong taps.
- MATCH-03 (celebrate on correct): Test A5 proves audio + animation fires; Test A8 proves no points/stars/score visible.
- MATCH-04 (photo abstraction wired for ~40%): MATCH-04 is split — generator side covered by Plan 05-01 G8/G9/G10; widget side covered by I1/I2 + the `photoOverrideSourceProvider` exists with the empty stub default. Phase 10 will swap the provider override; widget code does not change.
- D-02, D-07, D-08, D-09, D-10, D-12, D-14, D-15, D-17, D-21 exercised.
- LetterTile reuse confirmed (Test A10 — exactly 4 LetterTile widgets, no duplicate tile class created).
- AudioEngine reuse confirmed (Test A3, A5, A9 — uses audioEngineProvider, FakeAudioEngine intercepts).
</verification>

<success_criteria>
- 3 tasks complete with TDD red→green commits (3 minimum, optionally +2 refactors).
- Test count grows by ≥17 (Task 1: 6, Task 2: 6, Task 3: 11 — total +23 expected; +17 floor).
- No new fail-state UI primitives anywhere in the diff.
- `tools/check-domain-purity.sh` passes (this plan's files are under `lib/features/`, so it has no constraint on Flutter imports — but lib/core/matching/ from Plan 05-01 must remain pure).
- `roundGeneratorProvider` and `photoOverrideSourceProvider` exported and ready for Plan 05-03 wiring.
</success_criteria>

<output>
After completion, create `.planning/phases/05-letter-to-word-matching/05-02-SUMMARY.md` listing:
- Files created (lib + test).
- Test count delta.
- Decisions exercised (D-02, D-07, D-08, D-09, D-10, D-12, D-14, D-15, D-17, D-21; MATCH-01, MATCH-02, MATCH-03, MATCH-04 widget side).
- Confirmation that LetterTile + AudioEngine were reused, not duplicated.
- Notes on FakeAudioEngine reuse from integration_test/test_helpers.
</output>
