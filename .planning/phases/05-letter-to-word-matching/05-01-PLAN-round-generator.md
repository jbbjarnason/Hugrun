---
phase: 05-letter-to-word-matching
plan: 01
type: tdd
wave: 1
depends_on: []
files_modified:
  - lib/core/matching/matching_round.dart
  - lib/core/matching/photo_override_source.dart
  - lib/core/matching/round_generator.dart
  - test/core/matching/matching_round_test.dart
  - test/core/matching/round_generator_test.dart
autonomous: true
requirements:
  - MATCH-01
  - MATCH-04
tags: [matching, pure-dart, round-generation]

must_haves:
  truths:
    - "A round consists of one target word + 4 letter options + 1 correct option"
    - "The correct option is always present in the options list"
    - "The 4 options are distinct (no duplicate letters)"
    - "Distractors are drawn from kIcelandicAlphabet excluding the correct letter"
    - "Visually-similar pairs (e.g. o/ó, u/ú) are not both placed in the same round"
    - "A deterministic seed produces identical rounds (testability)"
    - "A photo override source can be queried; when empty, generator uses default placeholder"
    - "When photo overrides exist, ~40% of generated rounds are routed to a photo (MATCH-04)"
    - "The round generator imports zero Flutter packages (pure Dart, lib/core/)"
  artifacts:
    - path: "lib/core/matching/matching_round.dart"
      provides: "MatchingRound value class (target word, options, correct option, image source)"
      contains: "class MatchingRound"
    - path: "lib/core/matching/photo_override_source.dart"
      provides: "Abstract PhotoOverrideSource interface + EmptyPhotoOverrideSource stub for MATCH-04"
      contains: "abstract class PhotoOverrideSource"
    - path: "lib/core/matching/round_generator.dart"
      provides: "RoundGenerator that builds MatchingRound from manifest + alphabet + photo source"
      contains: "class RoundGenerator"
    - path: "test/core/matching/matching_round_test.dart"
      provides: "Tests for MatchingRound value semantics"
    - path: "test/core/matching/round_generator_test.dart"
      provides: "Exhaustive tests for distractor selection, similar-pair exclusion, photo Bernoulli, determinism"
  key_links:
    - from: "lib/core/matching/round_generator.dart"
      to: "lib/core/alphabet/alphabet.dart"
      via: "import for kIcelandicAlphabet (distractor pool)"
      pattern: "import.*core/alphabet/alphabet"
    - from: "lib/core/matching/round_generator.dart"
      to: "lib/gen/audio_manifest.g.dart"
      via: "iterates kAudioManifest keys to find example-word entries"
      pattern: "kAudioManifest"
    - from: "lib/core/matching/round_generator.dart"
      to: "lib/core/matching/photo_override_source.dart"
      via: "constructor-injected dependency for ~40% photo routing (MATCH-04)"
      pattern: "PhotoOverrideSource"
---

<objective>
Build the pure-Dart round generation core for the Letter-to-Word Matching activity. Produces a `MatchingRound` value object containing one target word, 4 letter options (correct + 3 distractors), and an image source descriptor.

Purpose:
- Decouple round logic from Flutter so it is unit-testable exhaustively (D-05, D-16).
- Establish the photo override hook that Phase 10 will fill (D-13, MATCH-04) — Phase 5 ships a stub returning empty.
- Lock the distractor exclusion rule (D-04) so visually-similar letter pairs (a/á, o/ó, u/ú, y/ý, e/é, i/í) never both appear in the same round.

Output:
- `lib/core/matching/matching_round.dart` — value class with named ctor + equality.
- `lib/core/matching/photo_override_source.dart` — abstract interface + empty stub.
- `lib/core/matching/round_generator.dart` — pure-Dart generator with seeded `Random`.
- 2 test files covering value semantics + generator invariants exhaustively.

This plan runs first (Wave 1, no deps). Plan 05-02 consumes the artifacts here.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/05-letter-to-word-matching/05-CONTEXT.md
@.planning/phases/04-stafir-tap-to-hear-mvp/04-SUMMARY.md

@lib/core/alphabet/alphabet.dart
@lib/core/alphabet/icelandic_letter.dart
@lib/core/manifest/utterance_key.dart
@lib/gen/audio_manifest.g.dart
@lib/features/stafir/example_word_resolver.dart

<interfaces>
<!-- Existing contracts the round generator consumes. Do not re-explore. -->

From lib/core/alphabet/alphabet.dart:
```dart
const List<IcelandicLetter> kIcelandicAlphabet = <IcelandicLetter>[ /* 32 entries, MMS order */ ];
```

From lib/core/alphabet/icelandic_letter.dart (Freezed; const ctor; value equality):
```dart
@freezed
abstract class IcelandicLetter with _$IcelandicLetter {
  const factory IcelandicLetter({
    required String glyph,        // 'a', 'á', 'ð', ...
    required String name,         // 'a', 'á', 'eð', ...
    required String assetSlug,    // 'a', 'a_acute', 'eth', ...
  }) = _IcelandicLetter;
}
```

From lib/core/manifest/utterance_key.dart (current Phase 2 stub — Phase 3 will extend):
```dart
enum UtteranceKey {
  letterA, letterEth, letterThorn, wordHundur, narrationWelcome,
}
```

From lib/gen/audio_manifest.g.dart:
```dart
const Map<UtteranceKey, AudioAsset> kAudioManifest = <UtteranceKey, AudioAsset>{ /* ... */ };
```

From lib/features/stafir/example_word_resolver.dart:
```dart
String slugFromWordKey(UtteranceKey k);          // wordHundur -> 'hundur'
String exampleWordImagePath(String wordSlug);    // 'assets/images/letters/words/hundur.webp'
String exampleWordPlaceholderText(String wordSlug);
```

CONSTRAINT: All files this plan creates live under `lib/core/matching/`. The
domain-purity check (`tools/check-domain-purity.sh`) forbids `package:flutter`
imports anywhere under `lib/core/`. Use `dart:math` (`Random`) not Flutter math.
</interfaces>
</context>

<tasks>

<task type="tdd" tdd="true">
  <name>Task 1: MatchingRound value class (RED + GREEN + REFACTOR)</name>
  <files>
    lib/core/matching/matching_round.dart,
    test/core/matching/matching_round_test.dart
  </files>
  <behavior>
    Test 1: MatchingRound exposes targetWordKey (UtteranceKey starting with 'word'), targetWordSlug (String, derived from key), correctLetter (IcelandicLetter), options (List&lt;IcelandicLetter&gt; length 4), and imageSource (an `ImageSource` sealed type with two cases: `StockPlaceholder(slug)` and `PhotoOverride(photoId)`).
    Test 2: `correctLetter` is always present in `options`. (Constructor asserts; throws AssertionError when violated.)
    Test 3: `options` length is exactly 4 (constructor asserts; throws AssertionError when violated).
    Test 4: `options` contains no duplicate letters (constructor asserts via Set length check; throws AssertionError when violated).
    Test 5: Two MatchingRound instances with the same fields are equal and hashable (use Freezed for value equality).
    Test 6: `ImageSource.stockPlaceholder('hundur')` and `ImageSource.photoOverride('photo-uuid-1')` are equal to identically-constructed peers.
    Test 7: NO Flutter imports — `tools/check-domain-purity.sh` is grepped against this file as a sanity invariant in the test suite (or a simple `grep -L 'package:flutter'` check in the test file's setUp).
  </behavior>
  <action>
    RED: Create `test/core/matching/matching_round_test.dart` with the 7 tests above.
    Run `flutter test test/core/matching/matching_round_test.dart` — must fail (no production file yet).
    Commit: `test(05-01): add failing tests for MatchingRound value class`.

    GREEN: Create `lib/core/matching/matching_round.dart`.
    - Use Freezed (already in pubspec from Phase 1) for value equality + immutability — same pattern as `lib/core/alphabet/icelandic_letter.dart`.
    - Define `sealed class ImageSource` with two `@freezed` subtypes: `StockPlaceholder({required String wordSlug})` and `PhotoOverride({required String photoId})`. (Use Freezed's union types: `factory ImageSource.stockPlaceholder(...) = StockPlaceholder; factory ImageSource.photoOverride(...) = PhotoOverride;`)
    - Define `class MatchingRound` (Freezed) with fields: `UtteranceKey targetWordKey`, `String targetWordSlug`, `IcelandicLetter correctLetter`, `List<IcelandicLetter> options`, `ImageSource imageSource`.
    - Override Freezed's generated ctor with a `MatchingRound._()` private ctor and a public factory that runs assertions (per Freezed assertion pattern):
      `assert(options.length == 4)`, `assert(options.toSet().length == 4)`, `assert(options.contains(correctLetter))`.
    - Run build_runner: `dart run build_runner build --delete-conflicting-outputs`. Commit the generated `.freezed.dart` files.
    - Run `flutter test test/core/matching/matching_round_test.dart` — all 7 must pass.
    - Run `bash tools/check-domain-purity.sh` — must pass (no Flutter imports).
    Commit: `feat(05-01): MatchingRound + ImageSource value types`.

    REFACTOR (only if needed): tighten asserts, doc comments, no behavior changes. If skipped, omit this commit.
  </action>
  <verify>
    <automated>flutter test test/core/matching/matching_round_test.dart &amp;&amp; bash tools/check-domain-purity.sh</automated>
  </verify>
  <done>
    - File `lib/core/matching/matching_round.dart` exists, exports MatchingRound + ImageSource (sealed, two cases).
    - 7 tests pass.
    - Domain-purity check passes (no `package:flutter` imports anywhere in lib/core/matching/).
    - Freezed-generated `.freezed.dart` files committed.
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 2: PhotoOverrideSource interface + EmptyPhotoOverrideSource stub (RED + GREEN)</name>
  <files>
    lib/core/matching/photo_override_source.dart,
    test/core/matching/round_generator_test.dart
  </files>
  <behavior>
    Test 1: `PhotoOverrideSource` is an abstract class with `List&lt;String&gt; photosForWordSlug(String wordSlug)` returning a list of photo IDs (empty list = no overrides).
    Test 2: `EmptyPhotoOverrideSource` (concrete, ships with Phase 5) returns `[]` for every query — implements MATCH-04 forward-compatibility stub (D-13).
    Test 3: A `FixedPhotoOverrideSource(Map&lt;String, List&lt;String&gt;&gt;)` test-double (defined inline in the test file, NOT in production code) returns the configured list per slug; used in Task 3 to verify the 40% Bernoulli routing.
  </behavior>
  <action>
    RED: In `test/core/matching/round_generator_test.dart`, add Tests 1 and 2 above (define a `group('PhotoOverrideSource', ...)` block). Define the inline `_FixedPhotoOverrideSource` test-double (private, file-local) as fixture for Task 3.
    Run `flutter test test/core/matching/round_generator_test.dart` — must fail (interface doesn't exist).
    Commit: `test(05-01): add failing tests for PhotoOverrideSource interface`.

    GREEN: Create `lib/core/matching/photo_override_source.dart`:
    ```dart
    /// Abstract source of photo overrides for matching rounds.
    /// Phase 5 ships [EmptyPhotoOverrideSource]; Phase 10 (PHOTO-*) replaces
    /// the binding with a Drift-backed implementation that returns parent-
    /// uploaded photo IDs tagged with [wordSlug] (MATCH-04 / D-13).
    abstract class PhotoOverrideSource {
      const PhotoOverrideSource();
      /// Returns photo IDs (opaque strings) tagged with [wordSlug].
      /// Empty list = no overrides; round generator falls back to stock placeholder.
      List<String> photosForWordSlug(String wordSlug);
    }

    /// Phase 5 default. Returns empty list for every slug. Phase 10 swaps this.
    class EmptyPhotoOverrideSource extends PhotoOverrideSource {
      const EmptyPhotoOverrideSource();
      @override
      List<String> photosForWordSlug(String wordSlug) => const <String>[];
    }
    ```
    Run `flutter test test/core/matching/round_generator_test.dart` — Tests 1 + 2 must pass.
    Run `bash tools/check-domain-purity.sh` — must pass.
    Commit: `feat(05-01): PhotoOverrideSource interface + empty Phase 5 stub`.
  </action>
  <verify>
    <automated>flutter test test/core/matching/round_generator_test.dart -N "PhotoOverrideSource" &amp;&amp; bash tools/check-domain-purity.sh</automated>
  </verify>
  <done>
    - `PhotoOverrideSource` abstract class exported.
    - `EmptyPhotoOverrideSource` const ctor available (used as default arg in Task 3 + Plan 05-02).
    - PhotoOverrideSource tests pass.
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 3: RoundGenerator with seeded Random + similar-pair exclusion + 40% photo Bernoulli (RED + GREEN + REFACTOR)</name>
  <files>
    lib/core/matching/round_generator.dart,
    test/core/matching/round_generator_test.dart
  </files>
  <behavior>
    Test G1 (target word selection): `RoundGenerator` iterates `kAudioManifest` (or an injected map override for tests) and selects only entries whose `UtteranceKey.name` starts with `word` as round candidates. (Phase 5 ships against the Phase 2 stub which has `wordHundur`; the test injects a fake manifest with multiple `word*` entries to exercise selection over a non-trivial pool.)
    Test G2 (correct option present): for 100 generated rounds (deterministic seed), `round.options.contains(round.correctLetter)` is always true.
    Test G3 (4 distinct options): for 100 rounds, `round.options.length == 4` and `round.options.toSet().length == 4`.
    Test G4 (correct letter starts target word): the slug derived from `round.targetWordKey` (via `slugFromWordKey`) starts with the same character as `round.correctLetter.glyph`. (e.g. `wordHundur` -&gt; 'hundur' -&gt; correctLetter.glyph == 'h'.)
    Test G5 (similar-pair exclusion): the generator's `kSimilarPairs` constant is a `Set&lt;Set&lt;String&gt;&gt;` of glyph pairs `{a,á}, {e,é}, {i,í}, {o,ó}, {u,ú}, {y,ý}`. For 200 rounds spanning all six pair members as the correct letter, the round NEVER contains both members of a pair simultaneously (i.e. if correct is `a`, no distractor is `á`; if correct is `o`, no distractor is `ó`; and no two distractors are themselves a similar pair). Asserted via exhaustive iteration.
    Test G6 (determinism): `RoundGenerator(seed: 42, ...)` produces the same first 10 rounds on two independent constructions (deep equality on MatchingRound list).
    Test G7 (no Flutter imports): file contains no `package:flutter` substring (grep-style invariant in test setUp; or rely on `tools/check-domain-purity.sh` in CI).
    Test G8 (photo Bernoulli — empty source): with `EmptyPhotoOverrideSource`, 100 rounds all have `imageSource is StockPlaceholder` (zero photo overrides).
    Test G9 (photo Bernoulli — populated source): with a `_FixedPhotoOverrideSource({'hundur': ['photo-1', 'photo-2']})` and a manifest containing only `wordHundur`, generate 1000 rounds with `seed: 7`. Count `imageSource is PhotoOverride` — assert count is in `[350, 450]` range (i.e. 40% ± 5%, generous tolerance for a 1000-trial Bernoulli at p=0.40 — the 95% CI is roughly ±3% so ±5% is comfortably wide; if the seeded run drifts outside, lower the seed-fixed expected count to a documented range from a one-time pre-run).
    Test G10 (photo override picks from list): when overrides exist for the slug, the chosen `PhotoOverride.photoId` is one of the configured IDs (membership check across 100 rounds).
    Test G11 (insufficient `word*` entries): if the injected manifest has zero `word*` entries, `generate()` throws a `StateError` with a message naming the constraint. (Phase 5 will not encounter this in production because Phase 3 ships ≥1 word entry; this test guards against silent breakage if a future regression strips them.)
  </behavior>
  <action>
    RED: Add Tests G1–G11 to `test/core/matching/round_generator_test.dart` (alongside the PhotoOverrideSource tests from Task 2). Define a private `_FixedPhotoOverrideSource` and a small `_buildFakeManifest({required Map&lt;UtteranceKey, AudioAsset&gt; entries})` helper at the bottom of the test file for fixture composition.
    Run `flutter test test/core/matching/round_generator_test.dart` — must fail.
    Commit: `test(05-01): add failing tests for RoundGenerator`.

    GREEN: Create `lib/core/matching/round_generator.dart`:
    - Imports: `dart:math`, `../alphabet/alphabet.dart`, `../alphabet/icelandic_letter.dart`, `../manifest/audio_asset.dart`, `../manifest/utterance_key.dart`, `../../gen/audio_manifest.g.dart`, `matching_round.dart`, `photo_override_source.dart`. NO Flutter imports.
    - Pull `slugFromWordKey` logic INTO this file as a private helper `String _slugFromWordKey(UtteranceKey k)` — mirror the existing Phase 4 implementation in `lib/features/stafir/example_word_resolver.dart`. Do NOT import the Phase 4 file (it lives under `lib/features/`, which `lib/core/` is forbidden from depending on per the layering invariant). The duplication is intentional and small; document it in a doc comment.
    - Define top-level constant:
      ```dart
      /// Visually-similar letter pairs that must not co-occur in a round (D-04).
      /// Each inner set has size 2; outer set is iterated to filter distractors.
      const Set<Set<String>> kSimilarPairs = <Set<String>>{
        {'a', 'á'}, {'e', 'é'}, {'i', 'í'},
        {'o', 'ó'}, {'u', 'ú'}, {'y', 'ý'},
      };
      ```
    - Define helper `bool _formsSimilarPair(String glyphA, String glyphB)` that returns true iff `{glyphA, glyphB}` appears in `kSimilarPairs`.
    - Define `class RoundGenerator`:
      ```dart
      class RoundGenerator {
        RoundGenerator({
          int? seed,
          Map<UtteranceKey, AudioAsset>? manifestOverride,
          PhotoOverrideSource photoSource = const EmptyPhotoOverrideSource(),
          double photoFrequency = 0.40,  // D-13
        }) : _random = seed != null ? Random(seed) : Random(),
             _manifest = manifestOverride ?? kAudioManifest,
             _photoSource = photoSource,
             _photoFrequency = photoFrequency;

        final Random _random;
        final Map<UtteranceKey, AudioAsset> _manifest;
        final PhotoOverrideSource _photoSource;
        final double _photoFrequency;

        MatchingRound generate() { /* ... */ }
      }
      ```
    - `generate()` algorithm:
      1. Filter `_manifest.keys` to those whose `name.startsWith('word')`. If the result is empty, throw `StateError('RoundGenerator: manifest has no word* entries')`.
      2. Pick a random `targetWordKey` from the filtered list.
      3. Compute `targetWordSlug = _slugFromWordKey(targetWordKey)`.
      4. Compute `correctLetter` = the entry in `kIcelandicAlphabet` whose `glyph == targetWordSlug[0]`. If none (defensive), throw `StateError`.
      5. Build `distractorPool` = `kIcelandicAlphabet` minus `correctLetter` minus any letter that forms a similar pair with `correctLetter`.
      6. Shuffle `distractorPool` with `_random`. Select distractors greedily, skipping any candidate that forms a similar pair with an already-selected distractor. Stop at 3.
      7. `options` = `[correctLetter, ...3 distractors]` shuffled with `_random`.
      8. Image source: query `_photoSource.photosForWordSlug(targetWordSlug)`. If empty, `imageSource = ImageSource.stockPlaceholder(wordSlug: targetWordSlug)`. If non-empty AND `_random.nextDouble() &lt; _photoFrequency`, pick a photoId from the list and return `ImageSource.photoOverride(photoId: id)`. Otherwise stock placeholder.
      9. Construct and return MatchingRound.
    - Add doc comment block at top: link to D-03..D-06, D-13, MATCH-01, MATCH-04. Note the `_slugFromWordKey` duplication-on-purpose.
    - Run `flutter test test/core/matching/round_generator_test.dart` — all G1..G11 must pass.
    - Run `bash tools/check-domain-purity.sh` — must pass.
    Commit: `feat(05-01): RoundGenerator with similar-pair exclusion + photo Bernoulli`.

    REFACTOR (if needed): extract similar-pair check into a small private function with its own micro-test if not already; tighten doc comments. If nothing to clean up, skip this commit.
    Commit (optional): `refactor(05-01): tighten RoundGenerator helpers`.
  </action>
  <verify>
    <automated>flutter test test/core/matching/round_generator_test.dart &amp;&amp; bash tools/check-domain-purity.sh &amp;&amp; flutter analyze lib/core/matching test/core/matching</automated>
  </verify>
  <done>
    - `RoundGenerator` produces deterministic rounds under a seed (G6).
    - Similar-pair exclusion verified across all six pair members (G5).
    - 40% photo Bernoulli verified within tolerance (G9).
    - Photo override falls back to stock placeholder when source returns empty (G8).
    - All 11 generator tests pass.
    - `flutter analyze` reports zero new warnings/errors for the new files.
    - Domain-purity check passes (no Flutter imports under lib/core/matching/).
  </done>
</task>

</tasks>

<verification>
- All MATCH-01 round-generation primitives exist as pure-Dart artifacts.
- MATCH-04 photo override hook exists with empty stub + Bernoulli routing wired.
- D-03, D-04, D-05, D-13, D-16 are exercised by tests.
- `flutter test` passes for the new files.
- `flutter analyze` clean for new files.
- `tools/check-domain-purity.sh` passes.
- No Flutter imports under `lib/core/matching/`.
</verification>

<success_criteria>
- 3 tasks complete with TDD red→green commits (≥3 commits, optionally +2 refactors = up to 5).
- Plan 05-02 can import `MatchingRound`, `RoundGenerator`, `EmptyPhotoOverrideSource` and `ImageSource` directly without further changes to lib/core/matching/.
- Test count grows by ≥18 (Task 1: 7, Task 2: 2, Task 3: 11 — total +20 expected; +18 floor allows for one or two tests being merged or split during implementation).
- All tests in the project still pass (no regressions to Phase 1–4 suite).
</success_criteria>

<output>
After completion, create `.planning/phases/05-letter-to-word-matching/05-01-SUMMARY.md` listing:
- Files created (lib + test).
- Test count delta.
- Decisions exercised (D-03, D-04, D-05, D-13, D-16; MATCH-01, MATCH-04 forward-compat).
- Notes on `_slugFromWordKey` duplication (intentional layering choice).
- Any refactor commits added beyond the minimum 3.
</output>
