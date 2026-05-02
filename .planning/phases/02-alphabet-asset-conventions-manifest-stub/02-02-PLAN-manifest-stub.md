---
phase: 02-alphabet-asset-conventions-manifest-stub
plan: 02
type: execute
wave: 2
depends_on:
  - 01
files_modified:
  - lib/gen/audio_manifest.g.dart
  - lib/gen/assets.gen.dart
  - lib/core/manifest/utterance_key.dart
  - lib/core/manifest/audio_asset.dart
  - assets/audio/letters/names/a.aac
  - assets/audio/letters/names/eth.aac
  - assets/audio/letters/names/thorn.aac
  - assets/audio/letters/words/hundur.aac
  - assets/audio/narration/welcome_hugrun.aac
  - assets/audio/letters/phonemes/.gitkeep
  - assets/audio/numbers/masculine/.gitkeep
  - assets/audio/numbers/feminine/.gitkeep
  - assets/audio/numbers/neuter/.gitkeep
  - assets/images/letters/words/.gitkeep
  - assets/images/numbers/.gitkeep
  - assets/images/ui/.gitkeep
  - pubspec.yaml
  - test/core/manifest/audio_manifest_test.dart
  - tools/check-domain-purity.sh
autonomous: true
requirements:
  - FOUND-05
user_setup: []

must_haves:
  truths:
    - "lib/gen/audio_manifest.g.dart compiles and exports an enum UtteranceKey with exactly the 5 entries from D-08: letterA, letterEth, letterThorn, wordHundur, narrationWelcome"
    - "kAudioManifest maps every UtteranceKey to a non-null AudioAsset"
    - "Each AudioAsset.path resolves to a real file on disk under assets/audio/ following the D-05 folder layout"
    - "getAudioAsset(UtteranceKey.X) returns the correct AudioAsset for every key (exhaustive switch coverage)"
    - "Every manifest path passes the D-06 conventions (lowercase ASCII alphanumerics + underscore + hyphen + slash + .aac)"
    - "pubspec.yaml flutter.assets enumerates the new audio + image folders so flutter bundles them"
    - "lib/core/manifest/ stays pure Dart (no package:flutter imports), tracked in tools/check-domain-purity.sh"
  artifacts:
    - path: "lib/core/manifest/utterance_key.dart"
      provides: "enum UtteranceKey with the 5 D-08 entries"
      contains: "enum UtteranceKey"
    - path: "lib/core/manifest/audio_asset.dart"
      provides: "AudioAsset value class (path + approximateDuration)"
      contains: "class AudioAsset"
    - path: "lib/gen/audio_manifest.g.dart"
      provides: "kAudioManifest map + getAudioAsset(key) lookup"
      contains: "const Map<UtteranceKey, AudioAsset> kAudioManifest"
    - path: "assets/audio/letters/names/a.aac"
      provides: "Placeholder AAC for UtteranceKey.letterA"
    - path: "assets/audio/letters/names/eth.aac"
      provides: "Placeholder AAC for UtteranceKey.letterEth"
    - path: "assets/audio/letters/names/thorn.aac"
      provides: "Placeholder AAC for UtteranceKey.letterThorn"
    - path: "assets/audio/letters/words/hundur.aac"
      provides: "Placeholder AAC for UtteranceKey.wordHundur"
    - path: "assets/audio/narration/welcome_hugrun.aac"
      provides: "Placeholder AAC for UtteranceKey.narrationWelcome"
    - path: "test/core/manifest/audio_manifest_test.dart"
      provides: "D-11 manifest tests (key coverage, file existence, path conventions, getAudioAsset lookup)"
  key_links:
    - from: "lib/gen/audio_manifest.g.dart"
      to: "lib/core/manifest/utterance_key.dart"
      via: "import"
      pattern: "import 'package:hugrun/core/manifest/utterance_key.dart'"
    - from: "lib/gen/audio_manifest.g.dart"
      to: "lib/core/manifest/audio_asset.dart"
      via: "import"
      pattern: "import 'package:hugrun/core/manifest/audio_asset.dart'"
    - from: "lib/gen/audio_manifest.g.dart"
      to: "assets/audio/"
      via: "string path values in kAudioManifest"
      pattern: "assets/audio/"
    - from: "pubspec.yaml"
      to: "assets/audio/, assets/images/"
      via: "flutter.assets list"
      pattern: "assets/audio/"
---

<objective>
Land the hand-written `lib/gen/audio_manifest.g.dart` stub that lets Phase 4
AudioEngine + Stafir UI compile against real `UtteranceKey` symbols before
Phase 3's Python TTS pipeline exists. Includes 5 placeholder AAC files (silent
100ms clips) under the canonical `assets/audio/` folder layout, the
`UtteranceKey` enum + `AudioAsset` value class, and `pubspec.yaml` `flutter:
assets:` entries so the bundle picks them up.

Purpose: This is the highest-leverage architectural unblock per RESEARCH
SUMMARY ("manifest contract pattern is highest-leverage early unblock"). With
this in place, Phase 3 (Python pipeline) and Phase 4 (Stafir) can develop in
parallel — Phase 3 regenerates `audio_manifest.g.dart` against the same enum
keys, Phase 4 imports `kAudioManifest` and starts wiring AudioEngine.

Output: A pure-Dart manifest types package (`lib/core/manifest/`), a
hand-written generated-file (`lib/gen/audio_manifest.g.dart`), 5 placeholder
AAC clips committed under `assets/audio/`, the canonical asset folder skeleton
with `.gitkeep` placeholders for Phase 3/6/8/9 destinations, updated
`pubspec.yaml` asset entries, and exhaustive D-11 tests.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-CONTEXT.md
@.planning/phases/01-skeleton-drift-schema/01-SUMMARY.md
@.planning/research/PITFALLS.md
@.planning/research/SUMMARY.md

<interfaces>
The five UtteranceKey entries this plan introduces (per D-08):

  UtteranceKey.letterA           -> assets/audio/letters/names/a.aac
  UtteranceKey.letterEth         -> assets/audio/letters/names/eth.aac
  UtteranceKey.letterThorn       -> assets/audio/letters/names/thorn.aac
  UtteranceKey.wordHundur        -> assets/audio/letters/words/hundur.aac
  UtteranceKey.narrationWelcome  -> assets/audio/narration/welcome_hugrun.aac

The 3-letter choice (a, eth, thorn) deliberately exercises the D-03 slug
mapping for the simplest case plus two diacritic cases. wordHundur covers
example-word (Phase 4). narrationWelcome covers the open-app greeting Phase 4
needs for PERS-03.

AudioAsset is a small value class with `path` (project-relative String) and
`approximateDuration` (Duration). Path is project-relative (e.g.
"assets/audio/letters/names/a.aac"), matching the form Flutter uses internally
for asset lookups via `rootBundle.load(...)`.

D-08 file header (verbatim):
  // GENERATED FILE -- DO NOT EDIT MANUALLY
  // Hand-written stub for Phase 2; Phase 3 Python pipeline will regenerate this.

D-08 lookup helper:
  AudioAsset getAudioAsset(UtteranceKey key) => kAudioManifest[key]!;
The bang operator is intentional — manifest is exhaustive at compile time;
adding a new UtteranceKey without a manifest entry should throw.

D-05 folder layout (exhaustive):
  assets/audio/letters/names/         <-- 3 placeholder clips this plan
  assets/audio/letters/words/         <-- 1 placeholder clip this plan
  assets/audio/letters/phonemes/      <-- empty .gitkeep, Phase 6 owns
  assets/audio/numbers/masculine/     <-- empty .gitkeep, Phase 8/9 own
  assets/audio/numbers/feminine/      <-- empty .gitkeep, Phase 8/9 own
  assets/audio/numbers/neuter/        <-- empty .gitkeep, Phase 8/9 own
  assets/audio/narration/             <-- 1 placeholder clip this plan
  assets/images/letters/words/        <-- empty .gitkeep, Phase 4 owns
  assets/images/numbers/              <-- empty .gitkeep, Phase 8 owns
  assets/images/ui/                   <-- empty .gitkeep, Phase 4 owns

D-09 placeholder AAC pipeline:
  ffmpeg -y -f lavfi -i 'anullsrc=r=48000:cl=mono' -t 0.1 \
    -c:a aac -b:a 96k -movflags +faststart <path>
If ffmpeg is missing locally: copy a single tiny AAC fixture to all 5 target
paths. Phase 3 owns ffmpeg formally — do NOT block this plan on installing it.

pubspec.yaml flutter.assets — replace the current single `- assets/` entry
with the explicit 10-folder allowlist matching D-05 (audio: 7 folders, images:
3 folders).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED -- failing manifest tests + D-05 folder skeleton + pubspec asset wiring</name>
  <files>test/core/manifest/audio_manifest_test.dart, assets/audio/letters/names/.gitkeep, assets/audio/letters/words/.gitkeep, assets/audio/letters/phonemes/.gitkeep, assets/audio/numbers/masculine/.gitkeep, assets/audio/numbers/feminine/.gitkeep, assets/audio/numbers/neuter/.gitkeep, assets/audio/narration/.gitkeep, assets/images/letters/words/.gitkeep, assets/images/numbers/.gitkeep, assets/images/ui/.gitkeep, pubspec.yaml</files>
  <behavior>
    Three preparatory moves before any source code lands:

    (a) Create the full D-05 folder skeleton with `.gitkeep` files. Folders:
      - assets/audio/letters/names/
      - assets/audio/letters/words/
      - assets/audio/letters/phonemes/   (empty until Phase 6)
      - assets/audio/numbers/masculine/  (empty until Phase 8)
      - assets/audio/numbers/feminine/   (empty until Phase 8)
      - assets/audio/numbers/neuter/     (empty until Phase 8)
      - assets/audio/narration/
      - assets/images/letters/words/     (empty until Phase 4)
      - assets/images/numbers/           (empty until Phase 8)
      - assets/images/ui/                (empty until Phase 4)
    Each gets an empty `.gitkeep`. Remove the legacy top-level `assets/.gitkeep`
    if present (replaced by per-folder `.gitkeep`s).

    (b) Update `pubspec.yaml` `flutter.assets:` block to enumerate the 10 new
    folders explicitly with trailing slashes (Flutter convention for "include
    every file at this depth"). Replace the single `- assets/` line with:

      assets:
        - assets/audio/letters/names/
        - assets/audio/letters/words/
        - assets/audio/letters/phonemes/
        - assets/audio/numbers/masculine/
        - assets/audio/numbers/feminine/
        - assets/audio/numbers/neuter/
        - assets/audio/narration/
        - assets/images/letters/words/
        - assets/images/numbers/
        - assets/images/ui/

    Trailing slash matters — flutter_gen_runner uses it to emit folder-grouped
    typed paths (D-10). After edit, run `flutter pub get` to confirm pubspec
    parses.

    (c) Create `test/core/manifest/audio_manifest_test.dart` with the D-11
    assertions. Imports:
      - package:hugrun/core/manifest/utterance_key.dart
      - package:hugrun/core/manifest/audio_asset.dart
      - package:hugrun/gen/audio_manifest.g.dart
      - dart:io (for `File.existsSync`)
    None of those packages exist yet, so the test run MUST fail at compile.

    D-11 assertions:
      - UtteranceKey.values.length equals 5
      - UtteranceKey.values.toSet() equals {letterA, letterEth, letterThorn, wordHundur, narrationWelcome}
      - For every key: kAudioManifest[key] is non-null AND its path is non-empty
      - For every entry: File(kAudioManifest[key]!.path).existsSync() is true
        (paths are project-relative; tests run from project root)
      - For every entry: path matches RegExp(r'^[a-z0-9_./-]+\.aac$')
        AND does not contain '..' AND does not contain '//' AND does not start with '/'
      - Spot-check exact paths:
          letterA          -> 'assets/audio/letters/names/a.aac'
          letterEth        -> 'assets/audio/letters/names/eth.aac'
          letterThorn      -> 'assets/audio/letters/names/thorn.aac'
          wordHundur       -> 'assets/audio/letters/words/hundur.aac'
          narrationWelcome -> 'assets/audio/narration/welcome_hugrun.aac'
      - getAudioAsset(UtteranceKey.letterA) returns the same instance (same path) as kAudioManifest[UtteranceKey.letterA]!
      - Exhaustive switch sanity: a switch over UtteranceKey returns a non-empty
        path for every value (this is the contract Phase 3 needs — adding a new
        enum value without a manifest entry surfaces fast).

    Run `flutter test test/core/manifest/`. Expected: compile failure (imports
    don't resolve). Acceptable RED: failing assertions on a test that compiles
    but fails because manifest types don't exist yet.
  </behavior>
  <action>
    Make the three changes above. Do NOT create any files under
    `lib/core/manifest/` or `lib/gen/audio_manifest.g.dart` in this task.

    Commit message: `test(02-02): scaffold assets/ folder skeleton + pubspec asset list + failing audio_manifest tests (RED)`
  </action>
  <verify>
    <automated>flutter pub get &amp;&amp; (flutter test test/core/manifest/ 2>&amp;1 | tee /tmp/red.log; grep -E "Could not find|Undefined name|error:|compilation failed|Some tests failed" /tmp/red.log)</automated>
  </verify>
  <done>10 `.gitkeep` files committed forming the D-05 folder skeleton; `pubspec.yaml` `flutter.assets` enumerates the 10 folders; `test/core/manifest/audio_manifest_test.dart` exists with D-11 assertions; `flutter test test/core/manifest/` fails (compile or assertion); commit landed with `test(02-02):` prefix.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN -- manifest types + 5 placeholder AAC clips + lib/gen/audio_manifest.g.dart</name>
  <files>lib/core/manifest/utterance_key.dart, lib/core/manifest/audio_asset.dart, lib/gen/audio_manifest.g.dart, lib/gen/assets.gen.dart, assets/audio/letters/names/a.aac, assets/audio/letters/names/eth.aac, assets/audio/letters/names/thorn.aac, assets/audio/letters/words/hundur.aac, assets/audio/narration/welcome_hugrun.aac, tools/check-domain-purity.sh</files>
  <behavior>
    Make the Task 1 tests pass by landing the manifest contract + the 5
    placeholder AAC files.

    (a) Create `lib/core/manifest/utterance_key.dart` per D-08 — `enum
    UtteranceKey { letterA, letterEth, letterThorn, wordHundur,
    narrationWelcome }` with a docstring explaining each entry and the
    contract that Phase 3's Python pipeline regenerates the manifest but
    keeps this enum stable across regenerations. Pure Dart; no
    `package:flutter` imports.

    (b) Create `lib/core/manifest/audio_asset.dart` per D-08 — `AudioAsset`
    value class with `final String path` and `final Duration
    approximateDuration`, `const` constructor with both required. Add manual
    `==`/`hashCode`/`toString` overrides (NOT freezed — this 4-field value
    class doesn't justify dragging the codegen part-file machinery). Pure Dart.

    (c) Generate the 5 placeholder AAC files per D-09. Try ffmpeg first:
      for path in <5 target paths>; do
        ffmpeg -y -f lavfi -i 'anullsrc=r=48000:cl=mono' -t 0.1 \
          -c:a aac -b:a 96k -movflags +faststart "$path"
      done
    If ffmpeg isn't installed and `brew install ffmpeg` would be slow or
    awkward, fall back: copy any one tiny pre-existing AAC byte-stream to
    all 5 paths (or use the `dart_aac_silence` trick — write the minimum
    valid AAC header by hand). The D-11 tests only check `File.existsSync()`
    + path conventions, not audio content.

    (d) Create `lib/gen/audio_manifest.g.dart`. Required content (D-08):
      - File header: `// GENERATED FILE -- DO NOT EDIT MANUALLY` then a
        second line `// Hand-written stub for Phase 2; Phase 3 Python
        pipeline will regenerate this.`
      - Two imports: utterance_key.dart and audio_asset.dart from
        package:hugrun/core/manifest/.
      - `const Map<UtteranceKey, AudioAsset> kAudioManifest = <UtteranceKey, AudioAsset>{ ... };`
        with the 5 entries, each with `approximateDuration: Duration(milliseconds: 100)`
        (placeholder clips are 100 ms per D-09).
      - `AudioAsset getAudioAsset(UtteranceKey key) => kAudioManifest[key]!;`

    (e) Run `dart run build_runner build --delete-conflicting-outputs` to
    refresh `lib/gen/assets.gen.dart` against the new asset folder layout.
    Commit the regenerated file.

    (f) Append `"lib/core/manifest"` to `tools/check-domain-purity.sh`
    `DOMAIN_PATHS` array. Replace the existing inline TODO comment about
    `lib/core/manifest/types/` with the actual entry. The existing
    `*.g.dart` / `*.freezed.dart` exclusion in the script handles
    `audio_manifest.g.dart` if it ever lived under `lib/core/manifest/` —
    but per D-10 it lives in `lib/gen/`, outside the domain check entirely.

    All Task 1 tests pass. `flutter analyze` clean. `dart format
    --set-exit-if-changed .` clean. `tools/check-domain-purity.sh` exits 0.
    All 5 AAC files exist on disk (non-zero size).
  </behavior>
  <action>
    Land all artifacts as a single GREEN commit. Order:
      1. Create the two `lib/core/manifest/*.dart` types.
      2. Generate (or copy-fixture) the 5 placeholder AAC files.
      3. Create `lib/gen/audio_manifest.g.dart`.
      4. Run `dart run build_runner build --delete-conflicting-outputs`.
      5. Update `tools/check-domain-purity.sh`.
      6. Run all verification gates.

    Watch out for:
      - PITFALL #20 (asset case-sensitivity): manifest paths are lowercase
        ASCII per D-06. `eth.aac` not `ð.aac`, `thorn.aac` not `þ.aac`.
        Plan 02-03 ships the CI guard that enforces this; until then the
        D-11 path-regex test is the safety net.
      - ffmpeg fallback: 5x byte-identical AAC copies are fine. Don't burn
        more than ~5 minutes on Homebrew install — Phase 3 owns ffmpeg.
      - The bang `kAudioManifest[key]!` is intentional (D-08 says manifest
        is exhaustive at compile time). Do NOT soften this to a default.
      - `lib/core/manifest/*.dart` must stay Flutter-free — no import of
        `package:flutter/foundation.dart` for `@immutable` etc. If you want
        `@immutable` use `package:meta/meta.dart` (transitive dep already).

    Commit message: `feat(02-02): hand-write audio_manifest.g.dart stub + 5 placeholder AAC clips + manifest types (GREEN)`
  </action>
  <verify>
    <automated>flutter test test/core/manifest/ &amp;&amp; flutter analyze &amp;&amp; bash tools/check-domain-purity.sh &amp;&amp; dart format --set-exit-if-changed . &amp;&amp; for f in assets/audio/letters/names/a.aac assets/audio/letters/names/eth.aac assets/audio/letters/names/thorn.aac assets/audio/letters/words/hundur.aac assets/audio/narration/welcome_hugrun.aac; do test -s "$f" || { echo "MISSING: $f"; exit 1; }; done</automated>
  </verify>
  <done>5 placeholder AAC files exist on disk; manifest types compile; D-11 tests pass; `flutter analyze` clean; `tools/check-domain-purity.sh` confirms `lib/core/manifest/` is Flutter-free; commit landed with `feat(02-02):` prefix.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: REFACTOR -- docs, format, full-suite green</name>
  <files>lib/gen/audio_manifest.g.dart, lib/core/manifest/utterance_key.dart, lib/core/manifest/audio_asset.dart, test/core/manifest/audio_manifest_test.dart</files>
  <behavior>
    Polish the Task 2 output:

    - Strengthen docstrings in `utterance_key.dart` to describe what each
      placeholder represents AND that Phase 3 will replace
      `audio_manifest.g.dart` (but NOT this enum file) when the Python
      pipeline ships.
    - Add a docstring on `kAudioManifest` and `getAudioAsset` summarising
      the contract: exhaustive at compile time, regenerated by Phase 3,
      paths match D-06 conventions.
    - In the test file, factor the 5 spot-check expectations into a single
      `const Map<UtteranceKey, String> kExpectedPaths = {...}` and iterate.
    - Confirm `dart format --set-exit-if-changed .` is clean across all
      Phase 2 files (alphabet from 02-01 + manifest from this plan).
    - Run the FULL test suite (`flutter test`) — all Phase 1 (66) + Phase 2
      alphabet (Plan 01) + Phase 2 manifest tests must be green together.

    No-op REFACTOR is acceptable if the Task 2 output is already polished;
    in that case commit a docs-only touch noting "REFACTOR: no behavior
    changes; manifest stub already minimal."
  </behavior>
  <action>
    Read the Task 2 output, add docstrings, refactor any duplicate
    expectation literals in the test, run all gates.

    Commit message: `refactor(02-02): document manifest contract + tighten audio_manifest_test fixtures`
    (or `chore(02-02): no-op REFACTOR pass — manifest stub already minimal` if literally nothing to change)
  </action>
  <verify>
    <automated>flutter test &amp;&amp; flutter analyze &amp;&amp; dart format --set-exit-if-changed . &amp;&amp; bash tools/check-domain-purity.sh</automated>
  </verify>
  <done>3 atomic commits exist (RED -> GREEN -> REFACTOR) on the current branch covering plan 02-02; all Phase 1 + Phase 2 tests green together; full repo `flutter analyze` clean.</done>
</task>

</tasks>

<verification>
After all 3 tasks complete:

```bash
# Full test pass (Phase 1 + Phase 2 alphabet + Phase 2 manifest)
flutter test                                # all green

# Static checks
flutter analyze                              # 0 issues
dart format --set-exit-if-changed .          # 0 changes

# Domain purity (extended)
bash tools/check-domain-purity.sh            # passes; lib/core/alphabet AND lib/core/manifest in DOMAIN_PATHS

# Asset file existence (project-relative paths from manifest)
for f in assets/audio/letters/names/a.aac \
         assets/audio/letters/names/eth.aac \
         assets/audio/letters/names/thorn.aac \
         assets/audio/letters/words/hundur.aac \
         assets/audio/narration/welcome_hugrun.aac; do
  test -s "$f" || { echo "MISSING: $f"; exit 1; }
done

# Pubspec sanity (all 10 folders enumerated)
grep -E "assets/(audio|images)/" pubspec.yaml | wc -l   # expect >= 10

# Atomic commit count for this plan
git log --oneline -- lib/gen/audio_manifest.g.dart lib/core/manifest/ assets/ test/core/manifest/ tools/check-domain-purity.sh \
  | wc -l   # expect >= 3 (RED, GREEN, REFACTOR — may show more if Task 2 broke into sub-commits, that's fine)

# Sanity: app still builds
flutter build apk --debug                    # succeeds (Phase 1 build artifact still works with new assets)
```
</verification>

<success_criteria>
- `lib/gen/audio_manifest.g.dart` is committed with the D-08 header, 5
  `UtteranceKey` entries, `kAudioManifest` map, and `getAudioAsset` helper.
- 5 placeholder AAC files exist under `assets/audio/` matching the manifest
  paths (silent ~100 ms clips OR copy-fixture stand-ins).
- `pubspec.yaml` `flutter.assets` enumerates 10 folders (7 audio + 3 images)
  per D-05.
- D-11 tests cover: enum count + identity, manifest non-null, file existence,
  path-convention regex, exact path spot-checks, `getAudioAsset` lookup,
  exhaustive switch.
- `lib/core/manifest/` is pure Dart (no `package:flutter/` imports), enforced
  by an updated `tools/check-domain-purity.sh`.
- The `assets/audio/letters/phonemes/`, `assets/audio/numbers/{m,f,n}/`,
  `assets/images/{letters/words,numbers,ui}/` folders exist with `.gitkeep`s
  so Phases 4 / 6 / 8 / 9 / 10 land into a known structure.
- 3 atomic commits land: RED (failing tests + folder skeleton + pubspec) -> GREEN (impl + AAC + manifest) -> REFACTOR (docs/format).
- Phase 2 success criterion 3 (FOUND-05's hand-written manifest stub) is met.
</success_criteria>

<output>
After completion, create
`.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-02-SUMMARY.md`
covering: commits landed, AAC generation strategy used (ffmpeg vs copy-fixture),
file sizes for the 5 placeholder clips, test count delta, any deviations from
D-05 / D-06 / D-08 / D-09 / D-10 / D-11, and explicit confirmation that
`lib/core/manifest/` is now in `tools/check-domain-purity.sh`'s `DOMAIN_PATHS`.
</output>
