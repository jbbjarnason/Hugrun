---
phase: 04-stafir-tap-to-hear-mvp
plan: 04
type: execute
wave: 3
depends_on:
  - 04-01
  - 04-02
  - 04-03
files_modified:
  - lib/features/stafir/stafir_room.dart
  - lib/features/stafir/widgets/letter_grid.dart
  - lib/features/stafir/example_word_resolver.dart
  - lib/features/stafir/widgets/example_word_overlay.dart
  - test/features/stafir/stafir_room_test.dart
  - test/features/stafir/widgets/letter_grid_test.dart
  - test/features/stafir/widgets/example_word_overlay_test.dart
  - test/features/stafir/example_word_resolver_test.dart
autonomous: true
requirements:
  - STAFIR-01  # all 32 letters in MMS order, ≥2cm tap targets
  - STAFIR-02  # tapping plays letter name (≤50ms is QA in 04-07)
  - STAFIR-03  # example word + matching image after letter name
  - STAFIR-04  # re-tap cancels and restarts (uses 04-02 AudioEngine)
  - STAFIR-05  # different letter cancels (uses 04-02 AudioEngine)
  - STAFIR-06  # synchronous visual feedback (LetterTile from 04-03)
  - STAFIR-07  # no failure UI
  - STAFIR-08  # no text instructions visible to child
  - STAFIR-10  # 32 letters each have an example-word slot + matching image (placeholder fallback for stub manifest)
tags:
  - flutter
  - widget
  - phase-4

must_haves:
  truths:
    - "StafirRoom replaces the Phase 1 placeholder and renders all 32 letters from kIcelandicAlphabet in MMS order"
    - "The grid uses 4 rows × 8 columns in landscape (the locked orientation per D-15)"
    - "Tapping any letter calls AudioEngine.play(letterKey) — even letters whose audio doesn't exist in the stub manifest (graceful no-op per D-23)"
    - "After the letter name plays, the example word image fades in for ~3 seconds, then fades out"
    - "Letters that have NO real audio in the stub manifest still respond visually (LetterTile scale animation) — silent on audio side, debug warning logged"
    - "AppBar contains NO text labels visible to child (currently 'Stafir' is shown — change must remove for STAFIR-08; see action below)"
    - "There is no 'progress' indicator, no 'recently seen' tracking, no score, no timer (D-13, STAFIR-07)"
    - "The grid is keyboard-only-tested (golden + widget tests)"
  artifacts:
    - path: "lib/features/stafir/stafir_room.dart"
      provides: "ConsumerWidget that hosts the letter grid + example-word overlay"
      min_lines: 60
    - path: "lib/features/stafir/widgets/letter_grid.dart"
      provides: "Grid laying out 32 LetterTile widgets in a 4×8 (landscape) GridView"
      min_lines: 40
    - path: "lib/features/stafir/example_word_resolver.dart"
      provides: "Pure function letterIndex → (UtteranceKey wordKey?, String imagePath?) using kLetterToWord + asset path conventions; placeholder fallback for stub"
      min_lines: 40
    - path: "lib/features/stafir/widgets/example_word_overlay.dart"
      provides: "Stateful overlay that fades in an image (or placeholder text-on-color tile) for ~3 s then fades out"
      min_lines: 60
  key_links:
    - from: "lib/features/stafir/stafir_room.dart"
      to: "lib/core/audio/audio_engine_provider.dart"
      via: "ref.read(audioEngineProvider).play(letterKey) on tap"
      pattern: "ref\\.read\\(audioEngineProvider\\)\\.play"
    - from: "lib/features/stafir/stafir_room.dart"
      to: "lib/features/stafir/widgets/letter_grid.dart"
      via: "LetterGrid composes 32 LetterTile widgets"
      pattern: "LetterGrid"
    - from: "lib/features/stafir/widgets/letter_grid.dart"
      to: "lib/core/alphabet/alphabet.dart"
      via: "kIcelandicAlphabet iterated to build 32 LetterTile children"
      pattern: "kIcelandicAlphabet"
    - from: "lib/features/stafir/stafir_room.dart"
      to: "lib/features/stafir/widgets/example_word_overlay.dart"
      via: "Tap fires showOverlay(letter); overlay fades in for ~3s then fades out"
      pattern: "ExampleWordOverlay"
---

<objective>
Compose the MVP screen. Plans 01-03 built the primitives:
- 01: Orientation lock + AudioEngine warm pool
- 02: AudioEngine.play queue (gapless letter→word; cancel-on-retap)
- 03: LetterTile leaf widget with synchronous tap feedback

This plan ties them together into the actual room the child sees. Replaces the Phase 1 StafirRoom placeholder with a 32-tile grid that:
- Reads `kIcelandicAlphabet` (32 letters MMS order, locked Phase 2)
- Lays out 4 rows × 8 columns (landscape — orientation locked Plan 01)
- Each tile is a LetterTile (Plan 03) with `onLetterTap = (letter) => audioEngine.play(_keyForLetter(letter))`
- Shows an example-word overlay (image or placeholder) after the letter name plays (~3 s on screen, then fade out)

Critical contract: **graceful fallback for the Phase 2 stub manifest (D-22, D-23)**.
- Stub has only letterA, letterEth, letterThorn for letter names; no real letter→word pairings; only wordHundur for example words.
- The grid must STILL render all 32 letters and respond to taps, just silently for letters whose clips don't exist.
- When Phase 3 ships the regenerated `audio_manifest.g.dart` with all 64 letter+word entries + the populated `kLetterToWord` table, the grid lights up automatically with no code change.
- The "manifest swap-in" is documented at the bottom of stafir_room.dart as a reference for the developer doing the post-Phase-3 cutover.

Output: A working Stafir room. Hugrún can pick up the tablet, open Stafir, and tap any letter. Letters with real audio (a, ð, þ) play; letters without are visually responsive but silent. Plans 05 + 06 + 07 finish the room with name flow + welcome narration + Marionette E2E.
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

@lib/core/alphabet/alphabet.dart
@lib/core/manifest/utterance_key.dart
@lib/gen/audio_manifest.g.dart
@lib/core/audio/audio_engine.dart
@lib/core/audio/audio_engine_provider.dart
@lib/core/audio/utterance_resolver.dart
@lib/features/stafir/stafir_room.dart
@lib/features/stafir/widgets/letter_tile.dart
@lib/features/home/home_page.dart

<interfaces>
<!-- Carry-forward from Plans 01-03. -->

From Plan 01 lib/core/audio/audio_engine_provider.dart:
```dart
@Riverpod(keepAlive: true)
AudioEngine audioEngine(Ref ref); // generated symbol: audioEngineProvider
```

From Plan 02 lib/core/audio/audio_engine.dart:
```dart
class AudioEngine {
  Future<void> play(UtteranceKey key);  // cancel-on-new-tap, fallback on missing
  Future<void> stop();
}
```

From Plan 02 lib/core/audio/utterance_resolver.dart:
```dart
const Map<UtteranceKey, UtteranceKey> kLetterToWord; // empty in stub; Phase 3 populates
```

From Plan 03 lib/features/stafir/widgets/letter_tile.dart:
```dart
class LetterTile extends StatefulWidget {
  const LetterTile({required IcelandicLetter letter, required int letterIndex,
                    required ValueChanged<IcelandicLetter> onLetterTap, double minSize = 200});
}
```

From Phase 2 lib/core/alphabet/alphabet.dart:
```dart
const List<IcelandicLetter> kIcelandicAlphabet; // 32 entries, MMS order
// Slugs: 'a', 'a_acute', 'b', 'd', 'eth', 'e', 'e_acute', 'f', 'g', 'h', 'i',
// 'i_acute', 'j', 'k', 'l', 'm', 'n', 'o', 'o_acute', 'p', 'r', 's', 't', 'u',
// 'u_acute', 'v', 'x', 'y', 'y_acute', 'thorn', 'ae', 'o_umlaut'
```

From Phase 2 lib/core/manifest/utterance_key.dart:
```dart
enum UtteranceKey {
  letterA,           // exists in stub
  letterEth,         // exists in stub
  letterThorn,       // exists in stub
  wordHundur,        // exists in stub
  narrationWelcome,  // exists in stub
}
```

Phase 4 enum extension contract: Phase 3's regenerator is expected to extend
this enum with letterAAcute, letterB, letterD, letterE, letterEAcute,
letterF, letterG, letterH, letterI, letterIAcute, letterJ, letterK, letterL,
letterM, letterN, letterO, letterOAcute, letterP, letterR, letterS, letterT,
letterU, letterUAcute, letterV, letterX, letterY, letterYAcute, letterAe,
letterOUmlaut and the 32 wordX counterparts. Plan 04 anticipates these
identifiers exist in production but MUST handle the case where they do NOT
(Phase 2 stub) — see the slug→key mapping function in
example_word_resolver.dart below.

slug → UtteranceKey mapping convention (case-by-case lowercased camelCase prefixed `letter`/`word`):
- 'a' → letterA
- 'a_acute' → letterAAcute
- 'eth' → letterEth
- 'e_acute' → letterEAcute
- 'thorn' → letterThorn
- 'ae' → letterAe
- 'o_umlaut' → letterOUmlaut
- ... etc.
</interfaces>

<reference_decisions>
- D-09: StafirRoom shows all 32 letters in MMS order in a single grid. Tap target ≥2cm × 2cm physical via MediaQuery + responsive column count.
- D-10: LetterTile (Plan 03) consumed here. Tap handler: AudioEngine.play(...) on onTapDown.
- D-12: Example word image fades in centered for ~3 seconds while example-word audio plays, then fades out. Image at `assets/images/letters/words/{slug}.webp` with `.png` fallback. Phase 4 ships placeholder text-on-color tiles for letters whose images aren't authored yet.
- D-13: NO selected state, NO progress UI, NO scores.
- D-14: Empty state on first launch — nothing special. Grid shows. Child taps. Done.
- D-22, D-23: Plan against Phase 2 stub manifest. Letters without clips fail gracefully (visual feedback only). Document the manifest swap-in step.
- STAFIR-08: Zero text instructions visible to child. AppBar text 'Stafir' is parent-facing chrome and acceptable IF immersive mode hides AppBar; we keep it for navigation parity with Phase 1 but it sits behind the immersive system-UI mode.

  Decision deferred to executor: keep the AppBar with title 'Stafir' (Phase 1 parity, parent-facing) OR remove it entirely (true full-bleed, child-only). RECOMMEND keeping it for now — child can't read 'Stafir' anyway, and removing the back button removes the way out of the room. Document in SUMMARY.
</reference_decisions>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — write failing tests for LetterGrid + ExampleWordResolver + ExampleWordOverlay + StafirRoom integration</name>
  <files>
    test/features/stafir/widgets/letter_grid_test.dart,
    test/features/stafir/example_word_resolver_test.dart,
    test/features/stafir/widgets/example_word_overlay_test.dart,
    test/features/stafir/stafir_room_test.dart
  </files>
  <behavior>
    test/features/stafir/example_word_resolver_test.dart (pure unit):
    - "letterToUtteranceKey('a') returns UtteranceKey.letterA"
    - "letterToUtteranceKey('eth') returns UtteranceKey.letterEth"
    - "letterToUtteranceKey('thorn') returns UtteranceKey.letterThorn"
    - "letterToUtteranceKey('h') returns null when letterH is not in the enum (Phase 2 stub state)" — accept this as "documented Phase 2 behavior; Phase 3 will fix"
    - "exampleWordImagePath('hundur') returns 'assets/images/letters/words/hundur.webp'"
    - "exampleWordPlaceholderText returns the slug of the example word" — for displaying "hundur" on a placeholder tile when no image exists

    test/features/stafir/widgets/letter_grid_test.dart (widget):
    - "LetterGrid renders exactly 32 LetterTile widgets" — `find.byType(LetterTile)` returns 32
    - "LetterGrid uses 8 columns in a 800×600 (landscape) viewport" — count tiles in the first row using row-position assertions (or just assert grid columns property if SliverGridDelegateWithFixedCrossAxisCount is used; assert crossAxisCount == 8)
    - "LetterGrid uses 4 columns in a 600×800 (portrait) viewport" — defensive; orientation is locked but the responsive code defends against test env
    - "LetterGrid renders glyphs in MMS order" — extract Text content of all LetterTiles in left-to-right top-to-bottom order; assert it equals the kIcelandicAlphabet glyph list

    test/features/stafir/widgets/example_word_overlay_test.dart (widget):
    - "ExampleWordOverlay starts hidden (opacity 0) when not triggered"
    - "Calling controller.show(letter) fades in over ~300ms"
    - "After ~3 s on screen, ExampleWordOverlay fades out"
    - "When the example word image asset doesn't exist, ExampleWordOverlay renders a placeholder text tile with the slug" — use a non-existent asset path; assert Text widget shows the slug

    test/features/stafir/stafir_room_test.dart (widget — replaces the Phase 1 placeholder tests):
    - "StafirRoom renders LetterGrid with 32 LetterTiles" (replaces the placeholder 'Stafir' Text test from Phase 1; keep AppBar test if AppBar is kept)
    - "Tapping a LetterTile (e.g. 'a') invokes audioEngine.play(UtteranceKey.letterA)" — use a `FakeAudioEngine` injected via a `ProviderScope.overrides` on `audioEngineProvider`; assert fake.calls contains UtteranceKey.letterA after a tap
    - "Tapping a letter that's NOT in the stub manifest does NOT throw" — tap 'h' (not in stub); test passes if no exception
    - "StafirRoom contains zero failure-state Icons and exactly 0 'progress' indicators" — `find.byIcon(Icons.error)`, `find.byIcon(Icons.check)`, `find.byType(LinearProgressIndicator)`, `find.byType(CircularProgressIndicator)` all findsNothing
    - "StafirRoom can be popped without crashing" — preserved from Phase 1's test

    Use a `FakeAudioEngine` (subclass AudioEngine, override play/stop, record calls) injected via the provider override pattern:
    ```dart
    ProviderScope(overrides: [audioEngineProvider.overrideWith((ref) => FakeAudioEngine())], ...)
    ```
    NOTE: Riverpod codegen exposes `audioEngineProvider` from the `.g.dart`; `overrideWith` works on it normally.
  </behavior>
  <action>
    Write all four failing test files. Tests should fail with:
    - `letterToUtteranceKey` undefined
    - `LetterGrid` undefined
    - `ExampleWordOverlay` undefined
    - StafirRoom doesn't render any LetterTile yet (still Phase 1 placeholder)

    The Phase 1 `stafir_room_test.dart` ("StafirRoom Scaffold has AppBar with title 'Stafir'") will likely still pass after rewrite if AppBar is kept; if removed, update the test to assert AppBar absence.

    Atomic commit: `test(04-04): add failing tests for LetterGrid + ExampleWord overlay + StafirRoom integration`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test test/features/stafir/ 2>&amp;1 | tail -25</automated>
  </verify>
  <done>
    - 13+ new failing tests across the 4 files
    - Pre-existing tests still pass (other than the Phase 1 stafir_room placeholder tests which will be rewritten in GREEN — count those as "evolving" not "failing")
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — implement example_word_resolver + LetterGrid + ExampleWordOverlay + rewrite StafirRoom</name>
  <files>
    lib/features/stafir/example_word_resolver.dart,
    lib/features/stafir/widgets/letter_grid.dart,
    lib/features/stafir/widgets/example_word_overlay.dart,
    lib/features/stafir/stafir_room.dart
  </files>
  <action>
    1. `lib/features/stafir/example_word_resolver.dart`:
       ```dart
       import 'package:hugrun/core/manifest/utterance_key.dart';

       /// Slug → UtteranceKey resolver. Returns null when the enum doesn't yet
       /// have an entry for this letter (Phase 2 stub state — only letterA,
       /// letterEth, letterThorn, wordHundur, narrationWelcome are defined).
       /// Phase 3's regenerated audio_manifest.g.dart extends UtteranceKey;
       /// once it does, this function resolves all 32 slugs.
       UtteranceKey? letterToUtteranceKey(String slug) {
         // Maintained as a dense map. Phase 3 manifest writer regenerates
         // utterance_key.dart but does NOT touch this file; if a slug is
         // listed here but the enum value doesn't exist (Phase 2 stub state),
         // dart will fail to compile — caught immediately.
         //
         // To stay compile-safe in the stub state, return enum values via
         // a switch that only references symbols that exist in the stub.
         switch (slug) {
           case 'a': return UtteranceKey.letterA;
           case 'eth': return UtteranceKey.letterEth;
           case 'thorn': return UtteranceKey.letterThorn;
           default: return null; // Phase 3 will fill in the rest
         }
       }

       String exampleWordImagePath(String wordSlug) =>
           'assets/images/letters/words/$wordSlug.webp';

       String exampleWordPlaceholderText(String wordSlug) =&gt; wordSlug;
       ```

       NOTE for executor: when Phase 3 regenerates the manifest and adds 29 more letterX enum values, this file gets a 32-arm switch. The Phase-2 → Phase-3 swap is mechanical — extend the switch, drop the placeholder paths.

    2. `lib/features/stafir/widgets/letter_grid.dart`:
       ```dart
       import 'package:flutter/material.dart';
       import 'package:hugrun/core/alphabet/alphabet.dart';
       import 'package:hugrun/core/alphabet/icelandic_letter.dart';
       import 'letter_tile.dart';

       /// 32-tile grid in MMS order. Landscape: 4 rows × 8 cols (D-09).
       /// Portrait fallback: 8 rows × 4 cols (orientation is LOCKED to landscape
       /// by Plan 01, but tests run portrait — defensive responsive code).
       class LetterGrid extends StatelessWidget {
         const LetterGrid({super.key, required this.onLetterTap});

         final ValueChanged&lt;IcelandicLetter&gt; onLetterTap;

         @override
         Widget build(BuildContext context) {
           return LayoutBuilder(builder: (context, constraints) {
             final isLandscape = constraints.maxWidth &gt; constraints.maxHeight;
             final crossAxisCount = isLandscape ? 8 : 4;
             return GridView.builder(
               padding: const EdgeInsets.all(16),
               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                 crossAxisCount: crossAxisCount,
                 crossAxisSpacing: 12,
                 mainAxisSpacing: 12,
                 childAspectRatio: 1.0,
               ),
               itemCount: kIcelandicAlphabet.length,
               itemBuilder: (context, index) {
                 final letter = kIcelandicAlphabet[index];
                 return LetterTile(
                   key: Key('letter-tile-$index-${letter.assetSlug}'),
                   letter: letter,
                   letterIndex: index,
                   onLetterTap: onLetterTap,
                   minSize: 0, // grid handles sizing
                 );
               },
             );
           });
         }
       }
       ```

       NOTE: D-09's "≥2cm × 2cm physical" assertion is the integration test in 04-07. The grid math at landscape on a typical 10" tablet (1280×800 logical, DPR 2.0) is: 1280 / 8 = 160 logical px per tile minus padding/spacing → ~140 logical px → ~140/37.8 cm = ~3.7 cm physical. WELL above 2 cm. If a smaller-screen device fails this, Plan 04-07 catches it.

    3. `lib/features/stafir/widgets/example_word_overlay.dart`:
       ```dart
       import 'package:flutter/material.dart';
       import 'package:flutter/services.dart';
       import '../example_word_resolver.dart';

       /// Controller surface — Plan 04 needs this so StafirRoom can call
       /// .show(letterSlug, wordSlug) from the LetterTile tap callback.
       class ExampleWordOverlayController extends ChangeNotifier {
         String? _wordSlug; // null = hidden
         String? get wordSlug =&gt; _wordSlug;

         void show(String wordSlug) { _wordSlug = wordSlug; notifyListeners(); }
         void hide() { _wordSlug = null; notifyListeners(); }
       }

       class ExampleWordOverlay extends StatefulWidget {
         const ExampleWordOverlay({
           super.key,
           required this.controller,
           this.visibleDuration = const Duration(seconds: 3),
           this.fadeDuration = const Duration(milliseconds: 300),
         });
         final ExampleWordOverlayController controller;
         final Duration visibleDuration;
         final Duration fadeDuration;

         @override State&lt;ExampleWordOverlay&gt; createState() =&gt; _ExampleWordOverlayState();
       }

       class _ExampleWordOverlayState extends State&lt;ExampleWordOverlay&gt; {
         double _opacity = 0;
         String? _slug;
         // ... wire controller listener: on show(slug), set _slug + opacity=1.0;
         //     after visibleDuration, opacity=0; after fadeDuration, _slug=null.
         //     Use rootBundle.load(path) probe to decide image-vs-placeholder.

         @override Widget build(BuildContext context) {
           if (_slug == null) return const SizedBox.shrink();
           return AnimatedOpacity(
             opacity: _opacity,
             duration: widget.fadeDuration,
             child: Center(
               child: FutureBuilder&lt;bool&gt;(
                 future: _imageExists(_slug!),
                 builder: (ctx, snap) {
                   if (snap.data == true) {
                     return Image.asset(exampleWordImagePath(_slug!), width: 320, height: 320);
                   }
                   // Placeholder: text-on-pastel tile (D-12 fallback).
                   return Container(
                     width: 320, height: 320,
                     decoration: BoxDecoration(
                       color: const Color(0xFFFFF1B8),
                       borderRadius: BorderRadius.circular(24),
                     ),
                     alignment: Alignment.center,
                     child: Text(
                       exampleWordPlaceholderText(_slug!),
                       style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w600),
                     ),
                   );
                 },
               ),
             ),
           );
         }

         Future&lt;bool&gt; _imageExists(String slug) async {
           try {
             await rootBundle.load(exampleWordImagePath(slug));
             return true;
           } catch (_) {
             return false;
           }
         }
       }
       ```

       NOTE on STAFIR-08: the placeholder TILE shows the wordSlug text ('hundur'). This is a child-visible Text. STAFIR-08 says zero text instructions; the slug isn't an instruction, it's an identifier of what's depicted. Document this carefully — if Jon decides this is too much text, the placeholder can be a colored square with NO text (the audio still narrates "hundur"). Default ships text; SUMMARY records the choice for review.

    4. `lib/features/stafir/stafir_room.dart` — REWRITE to compose Plan 01-03 primitives:
       ```dart
       import 'package:flutter/material.dart';
       import 'package:flutter_riverpod/flutter_riverpod.dart';
       import 'package:hugrun/core/alphabet/icelandic_letter.dart';
       import 'package:hugrun/core/audio/audio_engine_provider.dart';
       import 'package:hugrun/core/audio/utterance_resolver.dart';
       import 'package:hugrun/core/manifest/utterance_key.dart';
       import 'example_word_resolver.dart';
       import 'widgets/letter_grid.dart';
       import 'widgets/example_word_overlay.dart';

       /// Phase 4 D-09 / D-10 / D-13 / STAFIR-01..10. Replaces the Phase 1
       /// placeholder.
       ///
       /// MANIFEST SWAP-IN NOTE (D-22, D-23):
       ///   Phase 4 ships against the Phase 2 stub manifest (5 clips).
       ///   When Phase 3 ships the regenerated audio_manifest.g.dart with all
       ///   32 letter-name + 32 example-word entries:
       ///     1. Phase 3 commits the new audio_manifest.g.dart + assets.
       ///     2. Open lib/features/stafir/example_word_resolver.dart.
       ///     3. Extend the switch in letterToUtteranceKey to return the new
       ///        enum values for all 32 slugs.
       ///     4. Populate kLetterToWord in lib/core/audio/utterance_resolver.dart
       ///        with the 32 (letterX → wordY) pairings.
       ///     5. Run `flutter test` to confirm. Run on a device and tap each letter.
       ///   No StafirRoom code changes required.
       class StafirRoom extends ConsumerStatefulWidget {
         const StafirRoom({super.key});
         @override
         ConsumerState&lt;StafirRoom&gt; createState() =&gt; _StafirRoomState();
       }

       class _StafirRoomState extends ConsumerState&lt;StafirRoom&gt; {
         final _overlayCtl = ExampleWordOverlayController();

         @override
         void dispose() {
           _overlayCtl.dispose();
           super.dispose();
         }

         void _onLetterTap(IcelandicLetter letter) {
           final key = letterToUtteranceKey(letter.assetSlug);
           if (key == null) {
             // Phase 2 stub: enum entry doesn't exist for this letter.
             // Visual feedback already happened via LetterTile onTapDown.
             // No audio. Phase 3 fixes.
             return;
           }
           // Fire-and-forget. AudioEngine.play handles cancel-on-retap.
           // ignore: unawaited_futures
           ref.read(audioEngineProvider).play(key);
           // Show example-word overlay only if a paired word exists in the active manifest.
           // Resolver returns null wordKey if no pairing or pairing target absent.
           final resolved = resolveLetterToClips(key);
           if (resolved.wordKey != null) {
             // Word slug derived by stripping the 'word' prefix and lowercasing.
             // For the enum convention 'wordHundur' → 'hundur'.
             final wordSlug = _slugFromWordKey(resolved.wordKey!);
             _overlayCtl.show(wordSlug);
           }
         }

         String _slugFromWordKey(UtteranceKey k) {
           // Convention: enum is wordX where X is PascalCase of the slug.
           // e.g. wordHundur → 'hundur'. Phase 3 manifest writer enforces this.
           final name = k.name; // 'wordHundur'
           if (!name.startsWith('word')) return name; // defensive
           return name.substring(4).toLowerCase();
         }

         @override
         Widget build(BuildContext context) {
           return Scaffold(
             // AppBar kept for nav parity with Phase 1 (back button); behind
             // immersive system UI mode (Plan 01) so chrome is minimal.
             appBar: AppBar(title: const Text('Stafir')),
             body: SafeArea(
               child: Stack(
                 children: [
                   LetterGrid(onLetterTap: _onLetterTap),
                   IgnorePointer(
                     child: ExampleWordOverlay(controller: _overlayCtl),
                   ),
                 ],
               ),
             ),
           );
         }
       }
       ```

    Run `flutter test test/features/stafir/`; all should pass.

    Atomic commit: `feat(04-04): rewrite StafirRoom to render 32-letter grid + AudioEngine wiring + example-word overlay (D-09, D-10, D-12, D-22, D-23, STAFIR-01..05, STAFIR-10)`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - 13+ new tests green
    - Pre-existing tests still green (Phase 1 stafir_room_test "AppBar title Stafir" still passes since AppBar is kept)
    - `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: REFACTOR + golden — verify grid layout regression protection</name>
  <files>
    test/features/stafir/widgets/letter_grid_test.dart,
    test/features/stafir/widgets/goldens/letter_grid_landscape.png
  </files>
  <action>
    Add a single golden test for the 32-letter grid in landscape:
    ```dart
    testWidgets('LetterGrid golden — 32 letters in 8×4 landscape layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800)); // typical iPad landscape
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LetterGrid(onLetterTap: (_) {})),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LetterGrid),
        matchesGoldenFile('goldens/letter_grid_landscape.png'),
      );
    });
    ```

    Run `flutter test --update-goldens test/features/stafir/widgets/letter_grid_test.dart` to generate the PNG; commit it.

    Refactor StafirRoom: extract the `_slugFromWordKey` helper to `example_word_resolver.dart` so it's pure-Dart-testable.

    Atomic commit: `refactor(04-04): extract slug helper + golden snapshot for letter grid landscape`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test test/features/stafir/widgets/letter_grid_test.dart</automated>
  </verify>
  <done>
    - Golden committed
    - `flutter test` and `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user → StafirRoom | tap gestures cross into the widget tree |
| StafirRoom → AudioEngine | Riverpod-mediated, no untrusted data |
| StafirRoom → asset bundle | `rootBundle.load` for image-existence probe |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-12 | T (tampering) | missing UtteranceKey enum value | mitigate | letterToUtteranceKey returns null → tap is silent no-op; no exception; widget test asserts no-throw |
| T-04-13 | I (info disclosure) | placeholder text on overlay shows wordSlug | accept | wordSlug is non-PII (e.g. 'hundur'); choice documented in SUMMARY for parent review |
| T-04-14 | D (DoS) | child rapid-taps 32 letters | mitigate | AudioEngine cancel-on-retap (Plan 02 D-04); LetterTile onTapDown fires synchronously; no queue grows |
| T-04-15 | T (tampering) | progress UI accidentally added later | mitigate | widget test asserts zero LinearProgressIndicator/CircularProgressIndicator/error icons |
</threat_model>

<verification>
- `flutter test` — all green (≥125 tests)
- `flutter analyze` — 0 issues
- `dart format --set-exit-if-changed .` — clean
- `flutter build apk --debug` — succeeds
- `flutter build ios --no-codesign --debug` — succeeds
- 1 new golden in test/features/stafir/widgets/goldens/letter_grid_landscape.png
</verification>

<success_criteria>
- StafirRoom replaces Phase 1 placeholder, renders 32 letters in MMS order, 4×8 landscape grid
- Tap → AudioEngine.play (graceful no-op for letters not in stub manifest)
- Example-word overlay fades in/out when paired word exists
- 13+ new tests + 1 grid golden
- 3 atomic commits (RED → GREEN → REFACTOR/golden)
- Manifest swap-in step documented inline in stafir_room.dart
</success_criteria>

<output>
Create `.planning/phases/04-stafir-tap-to-hear-mvp/04-04-SUMMARY.md` with:
- StafirRoom composition diagram (LetterGrid + ExampleWordOverlay + AudioEngine wiring)
- Decisions exercised: D-09, D-10, D-12, D-13, D-14, D-22, D-23
- Requirements satisfied at widget level: STAFIR-01, -02 (audio plumbing; latency QA in 04-07), -03, -04, -05, -06, -07, -08, -10
- Test count delta
- Atomic commits + SHAs
- Manifest swap-in checklist (5 steps from the inline doc)
- Note on AppBar 'Stafir' text retention vs STAFIR-08 — record the decision
- Note on placeholder text for example word overlay — record the decision
</output>
