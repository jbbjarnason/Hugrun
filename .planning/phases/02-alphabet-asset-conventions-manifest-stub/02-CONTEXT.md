# Phase 2: Alphabet, Asset Conventions & Manifest Stub - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto` (Claude picked recommended option for each gray area; decisions logged inline)

<domain>
## Phase Boundary

Lock the three decisions every later phase depends on:
1. The canonical 32-letter Icelandic alphabet (`kIcelandicAlphabet`) with a unit test asserting MMS school order and the absence of C/Q/W/Z.
2. Lowercase, ASCII-safe asset path conventions (e.g. `eth.aac` for ð, `ae.aac` for æ) with a CI check that fails the build on any non-ASCII or uppercase asset filename.
3. A hand-written `audio_manifest.g.dart` stub with at least 3 placeholder entries + matching placeholder AAC files, so AudioEngine and Stafir UI work can compile and reference real `UtteranceKey`s before Phase 3's Python pipeline exists.

This phase **decouples Flutter widget/audio work from the Python TTS pipeline** — the highest-leverage architectural unblock per research SUMMARY.md.

**Requirements covered:** FOUND-04, FOUND-05 (2 of 11 Foundation requirements; rest are Phase 1)

</domain>

<decisions>
## Implementation Decisions

### kIcelandicAlphabet Constant (FOUND-04)

- **D-01:** Constant lives at `lib/core/alphabet/alphabet.dart`. Type: `const List<IcelandicLetter> kIcelandicAlphabet = [...]` where `IcelandicLetter` is a class (or freezed model now that freezed is restored) with fields: `glyph: String` (the actual Unicode letter, e.g. `'a'`, `'á'`, `'ð'`), `name: String` (Icelandic letter name, e.g. `'a'`, `'á'`, `'eð'` — used for letter-name audio key lookup), `assetSlug: String` (lowercase ASCII-safe filename slug, e.g. `'a'`, `'a_acute'` or `'a-acute'`, `'eth'`, `'ae'`, `'thorn'`, `'o_umlaut'`).
- **D-02:** Order: `a á b d ð e é f g h i í j k l m n o ó p r s t u ú v x y ý þ æ ö` — exactly 32 letters, in MMS school order. No C, Q, W, Z. Source: current Icelandic primary-school textbook convention (Menntamálastofnun materials).
- **D-03:** ASCII slug mapping (lowercase, single-token-per-letter, no diacritics in filenames):
  | Glyph | Slug |
  |-------|------|
  | a | `a` |
  | á | `a_acute` |
  | b | `b` |
  | d | `d` |
  | ð | `eth` |
  | e | `e` |
  | é | `e_acute` |
  | f | `f` |
  | g | `g` |
  | h | `h` |
  | i | `i` |
  | í | `i_acute` |
  | j | `j` |
  | k | `k` |
  | l | `l` |
  | m | `m` |
  | n | `n` |
  | o | `o` |
  | ó | `o_acute` |
  | p | `p` |
  | r | `r` |
  | s | `s` |
  | t | `t` |
  | u | `u` |
  | ú | `u_acute` |
  | v | `v` |
  | x | `x` |
  | y | `y` |
  | ý | `y_acute` |
  | þ | `thorn` |
  | æ | `ae` |
  | ö | `o_umlaut` |

  Use **underscore separator** (e.g. `a_acute`), not hyphen — Dart symbols/identifiers convert from underscore-snake easily; flutter_gen handles both but underscore-snake is more conventional. (Hyphen is also fine; pick one and stick to it.)
- **D-04:** Unit test at `test/core/alphabet/alphabet_test.dart` asserts:
  - `kIcelandicAlphabet.length == 32`
  - The exact glyph order matches the MMS list above
  - Set comparison: no C, Q, W, Z anywhere (`kIcelandicAlphabet.every((l) => !{'c', 'q', 'w', 'z'}.contains(l.glyph))`)
  - Each letter's `assetSlug` matches the D-03 table (data-driven test from a fixture map in the test file)
  - All slugs are unique (`Set.from(slugs).length == kIcelandicAlphabet.length`)
  - All slugs match `^[a-z][a-z0-9_]*$` (lowercase ASCII, alphanumerics + underscore only)

### Asset Path Conventions (FOUND-05)

- **D-05:** Asset folder structure:
  ```
  assets/
    audio/
      letters/
        names/         # letter-name clips: e.g. names/eth.aac
        words/         # example-word clips: e.g. words/hundur.aac
        phonemes/      # phoneme clips (Phase 6): e.g. phonemes/h.aac
      numbers/
        masculine/     # e.g. masculine/einn.aac
        feminine/      # e.g. feminine/ein.aac
        neuter/        # e.g. neuter/eitt.aac
      narration/       # narrator phrases: e.g. narration/welcome_hugrun.aac
    images/
      letters/
        words/         # default stock images for example words
      numbers/
      ui/              # parent gate, room icons, etc.
  ```
- **D-06:** Path naming rules, enforced by `tools/check-asset-paths.sh`:
  - Lowercase only
  - ASCII letters, digits, underscores, hyphens, slashes only — no diacritics or non-ASCII characters in filenames
  - File extensions: `.aac` for audio, `.webp` (preferred) or `.png` for images, `.svg` for vector
  - No spaces in filenames
- **D-07:** `tools/check-asset-paths.sh` script:
  - Walks `assets/`
  - Fails CI build with non-zero exit if any filename violates D-06
  - Self-tests with intentional bad fixtures in `tools/test-fixtures/bad-asset-paths/` (e.g. `Foo.aac`, `þrír.aac`, `with space.aac`, `áli.aac`)
  - Wired into CI `analyze-and-test` job (extends Phase 1's existing checks)

### Audio Manifest Stub (D-07 from Phase 1 + FOUND-05)

- **D-08:** Hand-written `lib/gen/audio_manifest.g.dart` with:
  - `enum UtteranceKey { letterA, letterEth, letterThorn, wordHundur, narrationWelcome }` — at least 3 letter entries + 1 word entry + 1 narrator entry. The 3 letters chosen are `a`, `eth`, `thorn` because they exercise the slug mapping for the simplest case + two diacritic cases.
  - `class AudioAsset { final String path; final Duration approximateDuration; const AudioAsset({...}); }`
  - `const Map<UtteranceKey, AudioAsset> kAudioManifest = {...}` mapping each `UtteranceKey` to an `AudioAsset` with the correct path under `assets/audio/`
  - `// GENERATED FILE — DO NOT EDIT MANUALLY` header comment + `// Hand-written stub for Phase 2; Phase 3 Python pipeline will regenerate this.` second line.
  - Type-safe lookup: `AudioAsset getAudioAsset(UtteranceKey key) => kAudioManifest[key]!;` (throws on missing key — this is intentional; the manifest is exhaustive at compile time)
- **D-09:** Placeholder AAC files: 5 silent 100 ms AAC-LC mono 96 kbps 48 kHz M4A files (one per `UtteranceKey`), generated using `ffmpeg -f lavfi -i 'anullsrc=r=48000:cl=mono' -t 0.1 -c:a aac -b:a 96k -movflags +faststart <path>`. Files committed to `assets/audio/` per the D-05 layout.
  - **If ffmpeg isn't installed locally yet** (user confirmed it's missing), use Dart-side or copy a single tiny pre-existing AAC file in 5 places. Don't block Phase 2 on ffmpeg — Phase 3 installs it formally.
- **D-10:** Both flutter_gen_runner (newly available post-remediation) AND the hand-written manifest coexist. The `lib/gen/assets.gen.dart` from `flutter_gen_runner` provides typed asset *paths* (e.g. `Assets.audio.letters.names.eth`); the `lib/gen/audio_manifest.g.dart` provides typed `UtteranceKey` → `AudioAsset` *mapping* (path + metadata). Phase 3's Python pipeline regenerates `audio_manifest.g.dart` only.
- **D-11:** Tests at `test/core/manifest/audio_manifest_test.dart`:
  - All `UtteranceKey` values map to a non-null `AudioAsset`
  - All paths exist on disk (`File(path).existsSync()`)
  - All paths conform to D-06 conventions
  - `getAudioAsset` returns the right asset for each key

### IcelandicLetter Model

- **D-12:** Use `freezed` (now restored post-remediation) for the `IcelandicLetter` model — gives `==`, `hashCode`, `toString`, `copyWith` for free, and matches the restored stack.
- **D-13:** Model lives in `lib/core/alphabet/icelandic_letter.dart` (separate file from the constant list). `kIcelandicAlphabet` imports the model and references it.

### CI Wiring

- **D-14:** Phase 2 extends Phase 1's CI by adding two checks to the `analyze-and-test` job:
  1. `tools/check-asset-paths.sh`
  2. New unit + widget tests (alphabet, manifest) included in `flutter test` automatically — no CI config change needed beyond ensuring tests are discovered
- **D-15:** No new CI jobs. Phase 2 is purely additive within existing jobs.

### Claude's Discretion

- Exact `IcelandicLetter` field set beyond glyph/name/slug (Claude can add e.g. `displayCase: LetterCase.lowercase` if useful)
- Whether placeholder AAC files use 100 ms silence or copy a single template — pick whichever works fastest given local tooling (ffmpeg may not be installed)
- Whether to use underscore or hyphen in slugs — D-03 says underscore; if convention conflicts arise, swap consistently with all tests updated

### Folded Todos

(None — no pre-existing todos.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — overall project context
- `.planning/REQUIREMENTS.md` — Phase 2 covers FOUND-04, FOUND-05
- `.planning/ROADMAP.md` § Phase 2 — phase goal and 3 success criteria
- `.planning/phases/01-skeleton-drift-schema/01-SUMMARY.md` — what Phase 1 delivered (skeleton, Drift, Riverpod codegen, parent gate, two-room shell, Marionette, CI)
- `.planning/phases/01-skeleton-drift-schema/01-CONTEXT.md` — Phase 1 decisions, especially D-07 (project layout — `lib/gen/` already exists as a stub)

### Research
- `.planning/research/SUMMARY.md` — Finding 3 (Icelandic alphabet 32 letters in MMS order; no C/Q/W/Z), Finding 7 (drift_flutter not sqlite3_flutter_libs), Architecture finding (manifest contract pattern is highest-leverage early unblock)
- `.planning/research/STACK.md` — flutter_gen_runner, freezed, build_runner versions
- `.planning/research/ARCHITECTURE.md` — generated audio manifest pattern, asset folder layout
- `.planning/research/PITFALLS.md` — Pitfall #20 (asset case-sensitivity differences iOS vs Android), Pitfall #2 (alphabet order errors)
- `.planning/research/FEATURES.md` — letter names vs phonemes (different audio sets — Phase 6 uses phonemes)

### External docs
- https://en.wikipedia.org/wiki/Icelandic_orthography — for cross-checking the 32-letter set (current MMS school convention is the authoritative source)
- https://pub.dev/packages/flutter_gen_runner — typed asset references

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phase 1)

- `lib/gen/` directory exists with placeholder `audio_manifest.g.dart` from Phase 1 — this phase replaces it with a real (still-handwritten) version
- `pubspec.yaml` already has `flutter_gen_runner` post-remediation (Phase 1 chore commit dc507e8)
- `flutter_lints` + analysis_options strict mode already enforced
- `tools/check-no-tracking.sh` and `tools/check-flutter-version.sh` exist as templates for new CI guard scripts (Phase 2 follows the same pattern for `tools/check-asset-paths.sh`)
- TDD harness with widget/unit/integration test layers already in place
- `freezed` restored, can be used for IcelandicLetter

### Established Patterns

- TDD red→green→refactor (project-level constraint, enforced in Phase 1)
- Atomic commits per cycle
- Domain layer in `lib/core/` is pure Dart, no Flutter imports — `IcelandicLetter` and `kIcelandicAlphabet` should be Flutter-import-free
- Riverpod 4.x codegen pattern: `@Riverpod(keepAlive: true)` on database provider; Phase 2 doesn't need new providers
- Generated code in `lib/gen/` is committed to git for reproducible builds (no CI codegen step required for the manifest stub)

### Integration Points

- `lib/core/alphabet/` — new directory for the alphabet constant + IcelandicLetter model
- `lib/gen/audio_manifest.g.dart` — replace Phase 1's placeholder
- `assets/audio/` — new top-level asset folder (Phase 1's `assets/` may be empty or absent; create the structure)
- `pubspec.yaml` — add `flutter:` `assets:` entries pointing to the new asset folders
- `tools/check-asset-paths.sh` — new guard script
- Phase 4 (MVP) will consume `kIcelandicAlphabet` to render the 32-letter grid
- Phase 3 (TTS pipeline) will overwrite `audio_manifest.g.dart` with the Python-generated version

</code_context>

<specifics>
## Specific Ideas

- The 3-letter-stub choice (a, eth, thorn) is deliberate — it covers the simplest case (`a` → `a.aac`) plus two diacritic cases the Python pipeline will need to handle correctly (`ð → eth.aac`, `þ → thorn.aac`)
- Placeholder AAC files are silent 100ms clips so they don't surprise anyone if accidentally played during dev
- Asset path convention applies retroactively: Phase 1 generated nothing under `assets/`, so no migration needed

</specifics>

<deferred>
## Deferred Ideas

- **Phoneme audio set** — Phase 6 (CVC blending). The asset folder convention `assets/audio/letters/phonemes/` is established now, but no clips ship until Phase 6.
- **Number audio matrix (gendered)** — Phase 8 / 9. The folder structure under `assets/audio/numbers/` is established now, no clips yet.
- **Real example-word clips for all 32 letters** — Phase 3 (Python TTS pipeline). Phase 2 ships the manifest stub with one example word (`hundur`).
- **Image assets** — Phase 4 generates / sources images for the example words. Phase 2 ships the folder structure only.
- **Unicode-aware alphabet sort comparator** (`compareIcelandic`) — only needed if we ever sort user-input strings; not in Phase 2 scope.

### Reviewed Todos (not folded)

None.

</deferred>

---

*Phase: 2 — Alphabet, Asset Conventions & Manifest Stub*
*Context gathered: 2026-05-02*
