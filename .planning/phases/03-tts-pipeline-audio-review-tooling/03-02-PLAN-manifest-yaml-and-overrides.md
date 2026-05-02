---
phase: 03-tts-pipeline-audio-review-tooling
plan: 02
type: execute
wave: 2
depends_on: ["03-01"]
files_modified:
  - manifest.yaml
  - pronunciation_overrides.yaml
  - reviewed.yaml
  - tools/tts/schema.py
  - tools/tts/validate_manifest.py
  - tools/tts/tests/test_schema.py
  - tools/tts/tests/test_validate_manifest.py
  - tools/tts/tests/fixtures/manifest_good.yaml
  - tools/tts/tests/fixtures/manifest_missing_field.yaml
  - tools/tts/tests/fixtures/manifest_duplicate_key.yaml
  - tools/tts/tests/fixtures/manifest_unknown_kind.yaml
  - tools/tts/tests/fixtures/manifest_bad_asset_path.yaml
autonomous: true
requirements:
  - AUDIO-01
  - AUDIO-07

must_haves:
  truths:
    - "manifest.yaml at the repo root contains exactly 65 utterance entries (32 letter_name + 32 example_word + 1 narration), each with a unique `key`, `text`, `asset`, and `kind`"
    - "manifest.yaml retains the 5 Phase 2 stub keys (letterA, letterEth, letterThorn, wordHundur, narrationWelcome) so existing Dart code still compiles after Phase 3 regenerates the manifest (D-22)"
    - "Every entry's `asset` path conforms to the D-06 lowercase-ASCII convention enforced by tools/check-asset-paths.sh"
    - "pronunciation_overrides.yaml exists at the repo root, conforms to the D-13 schema, and is empty (no overrides yet — populated during Plan 07's review pass)"
    - "reviewed.yaml exists at the repo root, conforms to the D-17 schema, and is empty (no entries yet — written by Plan 05's review server)"
    - "Running `python tools/tts/validate_manifest.py` against manifest.yaml + pronunciation_overrides.yaml + reviewed.yaml exits 0; running it against any of the bad fixtures exits non-zero with an actionable message"
  artifacts:
    - path: manifest.yaml
      provides: "Single source of truth for all Phase 3 utterances (65 entries) — the input the entire pipeline reads"
      contains: "letterA"
      min_lines: 200
    - path: pronunciation_overrides.yaml
      provides: "Per-utterance SSML or text-substitution override file (AUDIO-07; D-13)"
      contains: "version:"
    - path: reviewed.yaml
      provides: "Reviewer sign-off log (D-17) — empty schema until Plan 05's review server populates it"
      contains: "version:"
    - path: tools/tts/schema.py
      provides: "Pure-Python validators for manifest.yaml, pronunciation_overrides.yaml, reviewed.yaml schemas"
      exports: ["validate_manifest", "validate_overrides", "validate_reviewed", "ManifestEntry", "ManifestError"]
    - path: tools/tts/validate_manifest.py
      provides: "CLI entrypoint — `python tools/tts/validate_manifest.py [path]` validates all three YAML files"
      exports: ["main"]
  key_links:
    - from: manifest.yaml
      to: tools/tts/schema.py
      via: "import yaml; data = yaml.safe_load(...) ; validate_manifest(data)"
      pattern: "yaml\\.safe_load"
    - from: tools/tts/validate_manifest.py
      to: tools/check-asset-paths.sh
      via: "asset paths in manifest.yaml are subject to BOTH validate_manifest.py's regex check AND tools/check-asset-paths.sh after generation"
      pattern: "^assets/audio/"
    - from: manifest.yaml — letterA, letterEth, letterThorn, wordHundur, narrationWelcome
      to: lib/core/manifest/utterance_key.dart
      via: "Phase 2 stub UtteranceKey enum — these 5 keys MUST appear in manifest.yaml so the regenerated Dart manifest in Plan 04 keeps them"
      pattern: "letterA|letterEth|letterThorn|wordHundur|narrationWelcome"
---

<objective>
Author the three YAML source-of-truth files for the Phase 3 pipeline and ship a Python schema validator with pytest coverage:

1. **`manifest.yaml`** at the repo root — the single source of truth for ~65 utterances (32 letter_name + 32 example_word + welcome narration). This is what every later plan reads.
2. **`pronunciation_overrides.yaml`** at the repo root — empty schema-conforming file from day one (per AUDIO-07 / D-13). Populated entry-by-entry during Plan 07's review pass when the user finds a mispronunciation.
3. **`reviewed.yaml`** at the repo root — empty schema-conforming file from day one (per D-17). Plan 05's review UI writes entries here; Plan 04's manifest writer reads from here as the review gate.
4. **`tools/tts/schema.py`** + **`tools/tts/validate_manifest.py`** — pure-Python validators with pytest coverage and a small fixture set that exercises every failure mode.

Purpose: every later Phase 3 plan (Tiro client, normalize, manifest writer, review UI, CI guard) treats these YAML files as authoritative. Building plans 03+ before locking the schema and content means rewriting client code when fields change.

Output:
- 3 YAML files at the repo root with locked schemas (D-04 manifest, D-13 overrides, D-17 reviewed).
- 1 Python schema module + 1 CLI validator + ≥10 pytest cases over good and bad fixtures.
- Backward compatibility with Phase 2's 5 stub UtteranceKey identifiers (D-22) — verified by a dedicated test.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-CONTEXT.md
@.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-CONTEXT.md
@.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-SUMMARY.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-01-SUMMARY.md
@lib/core/alphabet/alphabet.dart
@lib/core/manifest/utterance_key.dart
@tools/check-asset-paths.sh

<interfaces>
<!-- Phase 2's locked alphabet + slug map drives the 65 manifest.yaml entries. Embedded so the executor does not re-derive. -->

D-03 ASCII slug map (Phase 2) — must be reused verbatim for asset filenames:

| Glyph | Slug    | UtteranceKey (letter)  | UtteranceKey (word)         |
|-------|---------|------------------------|------------------------------|
| a     | a       | letterA                | wordA                        |
| á     | a_acute | letterAAcute           | wordAAcute                   |
| b     | b       | letterB                | wordB                        |
| d     | d       | letterD                | wordD                        |
| ð     | eth     | letterEth              | wordEth                      |
| e     | e       | letterE                | wordE                        |
| é     | e_acute | letterEAcute           | wordEAcute                   |
| f     | f       | letterF                | wordF                        |
| g     | g       | letterG                | wordG                        |
| h     | h       | letterH                | wordH                        |
| i     | i       | letterI                | wordI                        |
| í     | i_acute | letterIAcute           | wordIAcute                   |
| j     | j       | letterJ                | wordJ                        |
| k     | k       | letterK                | wordK                        |
| l     | l       | letterL                | wordL                        |
| m     | m       | letterM                | wordM                        |
| n     | n       | letterN                | wordN                        |
| o     | o       | letterO                | wordO                        |
| ó     | o_acute | letterOAcute           | wordOAcute                   |
| p     | p       | letterP                | wordP                        |
| r     | r       | letterR                | wordR                        |
| s     | s       | letterS                | wordS                        |
| t     | t       | letterT                | wordT                        |
| u     | u       | letterU                | wordU                        |
| ú     | u_acute | letterUAcute           | wordUAcute                   |
| v     | v       | letterV                | wordV                        |
| x     | x       | letterX                | wordX                        |
| y     | y       | letterY                | wordY                        |
| ý     | y_acute | letterYAcute           | wordYAcute                   |
| þ     | thorn   | letterThorn            | wordThorn                    |
| æ     | ae      | letterAe               | wordAe                       |
| ö     | o_umlaut| letterOumlaut          | wordOumlaut                  |

Phase 2 stub keys that MUST remain in manifest.yaml (D-22 backward compat):
- letterA → assets/audio/letters/names/a.aac
- letterEth → assets/audio/letters/names/eth.aac
- letterThorn → assets/audio/letters/names/thorn.aac
- wordHundur → assets/audio/letters/words/hundur.aac
- narrationWelcome → assets/audio/narration/welcome_hugrun.aac

(letterA, letterEth, letterThorn map directly to the new letter_name keys above. wordHundur is the example word for `h` (i.e. it IS wordH) — see "Example word picks" below for the resolution.)

Manifest schema reminder (from D-04, kept here verbatim):
```yaml
version: 1
voice: dilja_v2
language: is-IS
utterances:
  - key: letterA
    text: "a"
    asset: assets/audio/letters/names/a.aac
    kind: letter_name
  - key: wordHundur
    text: "hundur"
    asset: assets/audio/letters/words/hundur.aac
    kind: example_word
    starts_with: h
```
- `kind` is one of: `letter_name`, `example_word`, `phoneme`, `numeral_masculine`, `numeral_feminine`, `numeral_neuter`, `narration`, `celebration`. Phase 3 only emits `letter_name`, `example_word`, `narration` — but the validator must accept all values from the union (so Phases 6 / 8 can extend without re-touching schema.py).
- Optional fields: `voice` (per-utterance override), `tempo`, `pitch`, `notes_for_reviewer`.
- `starts_with` is REQUIRED on `example_word` entries (so Plan 06 / Phase 4 can verify STAFIR-10 "example word starts with the target letter").

Pronunciation overrides schema (D-13):
```yaml
version: 1
overrides:
  letterEth:
    ssml: '<phoneme alphabet="x-sampa" ph="ED">eð</phoneme>'
  wordHundur:
    text: "hund-ur"   # text-substitution alternative if Tiro lacks SSML support (D-15)
```
Each override entry has EXACTLY ONE of {ssml, text} — never both. Tiro SSML support is verified in Plan 01's spike; if SSML was unsupported, validate_overrides MUST reject `ssml` entries until manually changed.

Reviewed schema (D-17):
```yaml
version: 1
entries: {}
# After Plan 07's review pass, entries gets populated like:
# entries:
#   letterA:
#     reviewed: true
#     reviewer: "Jon"
#     timestamp: "2026-05-02T14:30:00Z"
#     voice: "dilja_v2"
#     text_hash: "sha256:abc..."
#     notes: ""
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Author manifest.yaml + pronunciation_overrides.yaml + reviewed.yaml + schema validator (TDD RED)</name>
  <files>
    tools/tts/schema.py
    tools/tts/tests/test_schema.py
    tools/tts/tests/fixtures/manifest_good.yaml
    tools/tts/tests/fixtures/manifest_missing_field.yaml
    tools/tts/tests/fixtures/manifest_duplicate_key.yaml
    tools/tts/tests/fixtures/manifest_unknown_kind.yaml
    tools/tts/tests/fixtures/manifest_bad_asset_path.yaml
    tools/tts/tests/fixtures/overrides_good.yaml
    tools/tts/tests/fixtures/overrides_both_ssml_and_text.yaml
    tools/tts/tests/fixtures/reviewed_good.yaml
    tools/tts/tests/fixtures/reviewed_bad_timestamp.yaml
  </files>
  <behavior>
    Test 1 (RED): pytest collects `test_schema.py`; the import `from tools.tts.schema import validate_manifest` fails because the module does not exist.
    Test 2: `validate_manifest(yaml.safe_load(manifest_good.yaml))` returns `(ok=True, errors=[])` — fixture has 5 entries (the 5 Phase 2 stubs only) and valid schema.
    Test 3: `validate_manifest(missing_field)` returns `ok=False` and `errors[0]` mentions both the offending utterance key AND the missing field name (e.g. "wordHundur: missing required field 'asset'").
    Test 4: `validate_manifest(duplicate_key)` returns `ok=False` with an error mentioning both occurrences.
    Test 5: `validate_manifest(unknown_kind)` returns `ok=False` mentioning the invalid kind value AND the allowed-set.
    Test 6: `validate_manifest(bad_asset_path)` returns `ok=False` for a path that contains uppercase / non-ASCII / spaces (mirrors check-asset-paths.sh rules).
    Test 7: `validate_manifest` rejects `example_word` entries that are missing `starts_with`.
    Test 8: `validate_overrides(overrides_good)` returns `ok=True`. `validate_overrides(both_ssml_and_text)` rejects entries that set both `ssml` AND `text`.
    Test 9: `validate_reviewed(reviewed_good)` returns `ok=True`. `validate_reviewed(bad_timestamp)` rejects non-ISO-8601 timestamps.
    Test 10: `validate_manifest(yaml.safe_load(open('manifest.yaml')))` (the REAL repo file) returns `ok=True` once Task 2 has authored it. (This test is in test_validate_manifest.py — not test_schema.py — to keep schema unit tests independent of the live manifest. RED first if it tries to load before manifest.yaml exists.)
    Test 11: backward-compat assertion — every key in `{letterA, letterEth, letterThorn, wordHundur, narrationWelcome}` MUST appear in `manifest.yaml` (D-22) AND every key in `lib/core/manifest/utterance_key.dart` enum MUST be present in manifest.yaml (parsed by a tiny regex from the .dart file). This test guards against a future drop of the stub keys.
    Test 12: count assertion — `len(manifest.utterances) == 65` and the breakdown is exactly 32 letter_name + 32 example_word + 1 narration (per D-26).
  </behavior>
  <action>
    Per D-04 (manifest schema), D-13 (overrides schema), D-17 (reviewed schema), D-22 (Phase 2 stub keys preserved), D-26 (Phase 3 ships ~65 clips).

    **Step A — RED: write fixtures + schema tests** (one commit):
    Write the 8 fixture files under `tools/tts/tests/fixtures/`. `manifest_good.yaml` mirrors the Phase 2 stub (5 entries) so it stays small and focused. The "bad" fixtures each violate exactly one rule.

    Write `tools/tts/tests/test_schema.py` covering Tests 1–9 (Tests 10–12 go in Task 2's `test_validate_manifest.py`). Run pytest, confirm RED. Commit:
    `test(03-02): add failing schema validator tests + good/bad YAML fixtures`

    **Step B — GREEN: implement `tools/tts/schema.py`** (one commit):
    Pure-stdlib + pyyaml. No pydantic / no jsonschema — keep deps light. Suggested API:
    ```python
    from dataclasses import dataclass, field

    ALLOWED_KINDS = frozenset({
        "letter_name", "example_word", "phoneme",
        "numeral_masculine", "numeral_feminine", "numeral_neuter",
        "narration", "celebration",
    })

    ASSET_PATH_REGEX = re.compile(r"^assets/audio/[a-z0-9._/-]+\.aac$")
    KEY_REGEX = re.compile(r"^[a-z][A-Za-z0-9]*$")  # camelCase identifiers — match Dart enum convention

    @dataclass
    class ManifestEntry:
        key: str
        text: str
        asset: str
        kind: str
        starts_with: str | None = None
        voice: str | None = None
        tempo: float | None = None
        pitch: float | None = None
        notes_for_reviewer: str | None = None

    @dataclass
    class ValidationResult:
        ok: bool
        errors: list[str] = field(default_factory=list)

    def validate_manifest(data: dict) -> ValidationResult: ...
    def validate_overrides(data: dict) -> ValidationResult: ...
    def validate_reviewed(data: dict) -> ValidationResult: ...
    ```

    Implementation notes:
    - `validate_manifest` checks: `version == 1`, `voice` present + non-empty string, `language == "is-IS"`, `utterances` is a list of ≥ 1, each entry has `key/text/asset/kind`, `kind` ∈ ALLOWED_KINDS, `key` matches KEY_REGEX, `asset` matches ASSET_PATH_REGEX (this is a stricter check than `tools/check-asset-paths.sh` because it also requires the path to start with `assets/audio/`), keys are unique (case-sensitive set), and `example_word` entries have `starts_with` set to a single Icelandic glyph.
    - `validate_overrides`: `version == 1`, `overrides` is dict (possibly empty), each override has EXACTLY ONE of `{ssml, text}`. If Plan 01's README documented Tiro SSML as unsupported, also reject `ssml` overrides — read the README at validation time? No: that's brittle. Instead, accept both at schema level, and emit a WARNING to stdout when an `ssml` override is found and `tools/tts/README.md` does not say SSML works. (This is a pragmatic compromise; the executor decides whether to escalate.)
    - `validate_reviewed`: `version == 1`, `entries` is dict (empty allowed). Each entry has `reviewed: bool`, `reviewer: str`, `timestamp: ISO-8601` (use `datetime.fromisoformat` — Python 3.11 handles `Z` suffix), `voice: str`, `text_hash: str` (must start with `sha256:`).

    Run pytest. All Task 1 tests pass. Commit:
    `feat(03-02): add tools/tts/schema.py validators for manifest/overrides/reviewed`

    Atomic commit count for Task 1: 2 (RED + GREEN).
  </action>
  <verify>
    <automated>python3 -m pytest tools/tts/tests/test_schema.py -x</automated>
  </verify>
  <done>
    `pytest tools/tts/tests/test_schema.py` passes ≥9 tests covering schema happy path + every distinct error mode for all three YAML files.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Author manifest.yaml + pronunciation_overrides.yaml + reviewed.yaml + CLI validator (TDD RED→GREEN)</name>
  <files>
    manifest.yaml
    pronunciation_overrides.yaml
    reviewed.yaml
    tools/tts/validate_manifest.py
    tools/tts/tests/test_validate_manifest.py
  </files>
  <behavior>
    Test 10 (RED): `pytest tools/tts/tests/test_validate_manifest.py::test_repo_manifest_valid` fails because manifest.yaml does not exist (or is empty).
    Test 11: `test_phase2_stub_keys_preserved` — parse `lib/core/manifest/utterance_key.dart` with a regex like `r'^\s*([a-z][A-Za-z0-9]*),'` (multiline) to extract the 5 Phase 2 enum members, assert each appears as a `key:` in manifest.yaml. RED first because manifest.yaml is empty.
    Test 12: `test_count_breakdown` — `len(utterances) == 65`, `sum(1 for u in utterances if u['kind']=='letter_name') == 32`, `sum(...kind=='example_word') == 32`, `sum(...kind=='narration') == 1`. RED first.
    Test 13: `test_starts_with_consistency` — for every example_word, the `starts_with` field exactly matches the target letter the word begins with (in Icelandic terms — `þrír` starts with `þ`, not with `t`). Verifies STAFIR-10 invariant from Phase 4 in advance. RED first.
    Test 14: `test_assets_match_phase2_paths` — for each of the 5 Phase 2 stub keys, the `asset` value in manifest.yaml exactly matches the path Phase 2 already wrote into `lib/gen/audio_manifest.g.dart` (so the regenerated manifest in Plan 04 doesn't accidentally relocate the existing AAC files).
    Test 15: `test_cli_validates_repo_files` — invoking `python tools/tts/validate_manifest.py` (no args, run from repo root) exits 0 once all three YAML files are correct.
    Test 16: `test_cli_rejects_bad_fixture` — invoking `python tools/tts/validate_manifest.py tools/tts/tests/fixtures/manifest_duplicate_key.yaml` exits non-zero with the duplicate-key error message in stderr.
  </behavior>
  <action>
    **Step A — RED: write `test_validate_manifest.py`** covering Tests 10–16. Run pytest, confirm RED. Commit:
    `test(03-02): add failing repo-manifest contract tests`

    **Step B — GREEN: author the three YAML files + the CLI validator** (one commit):

    1. **`manifest.yaml`** — author 65 entries. Order them in the file as:
       (a) all 32 `letter_name` entries in MMS alphabetical order (matching `kIcelandicAlphabet`),
       (b) all 32 `example_word` entries in MMS alphabetical order keyed by their `starts_with` letter,
       (c) `narrationWelcome`.

       For letter_name entries, `text` is the spoken letter name in Icelandic (NOT the glyph alone — e.g. `"a"`, `"á"`, `"bé"`, `"dé"`, `"eð"`, `"e"`, `"é"`, `"eff"`, `"ge"`, `"há"`, `"i"`, `"í"`, `"joð"`, `"ká"`, `"ell"`, `"emm"`, `"enn"`, `"o"`, `"ó"`, `"pé"`, `"err"`, `"ess"`, `"té"`, `"u"`, `"ú"`, `"vaff"`, `"ex"`, `"y"`, `"ý"`, `"þorn"`, `"æ"`, `"ö"`). Some of these are debatable (e.g. is the spoken name "be" or "bé"? "ess" or "es"?) — when in doubt, use the conservative form most likely to render correctly via Tiro Diljá v2; the review pass in Plan 07 will catch and override mispronunciations.

       For example_word entries, pick concrete imageable nouns whose first letter (in IPA-equivalent terms — i.e. `þrír` for `þ`, NOT `trír`) matches `starts_with`. Use the picks below as the v1 list (Plan 07's review pass / a follow-up commit can swap any of these for better picks):

       | starts_with | text          | English | UtteranceKey  | asset                                        |
       |-------------|---------------|---------|---------------|----------------------------------------------|
       | a           | api           | ape/monkey | wordA       | assets/audio/letters/words/api.aac           |
       | á           | ár            | year    | wordAAcute    | assets/audio/letters/words/ar.aac            |
       | b           | bók           | book    | wordB         | assets/audio/letters/words/bok.aac           |
       | d           | dúkka         | doll    | wordD         | assets/audio/letters/words/dukka.aac         |
       | ð           | maður         | man     | wordEth       | assets/audio/letters/words/madur.aac (note: ð is word-medial; rare as initial — use one of {maður, koma frá veður}) |
       | e           | epli          | apple   | wordE         | assets/audio/letters/words/epli.aac          |
       | é           | él            | snow shower | wordEAcute| assets/audio/letters/words/el.aac            |
       | f           | fiskur        | fish    | wordF         | assets/audio/letters/words/fiskur.aac        |
       | g           | gata          | street  | wordG         | assets/audio/letters/words/gata.aac          |
       | h           | hundur        | dog     | wordH         | assets/audio/letters/words/hundur.aac        |
       | i           | ís            | ice/ice cream | wordI   | assets/audio/letters/words/is.aac            |
       | í           | ís            | duplicate of i? — use `íþrótt` instead | wordIAcute | assets/audio/letters/words/ithrott.aac |
       | j           | jól           | Christmas | wordJ       | assets/audio/letters/words/jol.aac           |
       | k           | kýr           | cow     | wordK         | assets/audio/letters/words/kyr.aac           |
       | l           | lampi         | lamp    | wordL         | assets/audio/letters/words/lampi.aac         |
       | m           | mús           | mouse   | wordM         | assets/audio/letters/words/mus.aac           |
       | n           | nef           | nose    | wordN         | assets/audio/letters/words/nef.aac           |
       | o           | ostur         | cheese  | wordO         | assets/audio/letters/words/ostur.aac         |
       | ó           | ólína         | (name) — use `ól` (strap) or `ólafur` instead | wordOAcute | assets/audio/letters/words/olafur.aac |
       | p           | pera          | pear    | wordP         | assets/audio/letters/words/pera.aac          |
       | r           | rós           | rose    | wordR         | assets/audio/letters/words/ros.aac           |
       | s           | sól           | sun     | wordS         | assets/audio/letters/words/sol.aac           |
       | t           | tönn          | tooth   | wordT         | assets/audio/letters/words/tonn.aac          |
       | u           | uggi          | fin     | wordU         | assets/audio/letters/words/uggi.aac          |
       | ú           | úr            | watch   | wordUAcute    | assets/audio/letters/words/ur.aac            |
       | v           | vatn          | water   | wordV         | assets/audio/letters/words/vatn.aac          |
       | x           | xýlófónn      | xylophone — rare in Icelandic; alternative is `xerox`. Mark `notes_for_reviewer: "x is rare word-initially in Icelandic; expect Diljá to mispronounce — likely needs override"` | wordX | assets/audio/letters/words/xylofonn.aac |
       | y           | ylur          | warmth  | wordY         | assets/audio/letters/words/ylur.aac          |
       | ý           | ýta           | to push | wordYAcute    | assets/audio/letters/words/yta.aac           |
       | þ           | þrír          | three   | wordThorn     | assets/audio/letters/words/thrir.aac         |
       | æ           | æða           | vein    | wordAe        | assets/audio/letters/words/aeda.aac          |
       | ö           | öxl           | shoulder | wordOumlaut  | assets/audio/letters/words/oxl.aac           |

       Notes:
       - `notes_for_reviewer` field is OPTIONAL; populate it for hot-spot pronunciations the review pass should pay attention to (especially `þ`, `ð` words; `x` and `c/q/w/z`-adjacent which Icelandic rarely uses; the child's name "Hugrún").
       - Final word picks are the user's call during review — Plan 07's review pass may change them. Plan 02 ships a v1 list that satisfies STAFIR-10 (every letter has an example word starting with it).

       The narration entry:
       ```yaml
       - key: narrationWelcome
         text: "Halló Hugrún. Veldu stafi eða tölur."  # "Hello Hugrún. Choose letters or numbers."
         asset: assets/audio/narration/welcome_hugrun.aac
         kind: narration
         notes_for_reviewer: "Hot spot — pronunciation of 'Hugrún'. Review carefully."
       ```

       Top of file:
       ```yaml
       # manifest.yaml — single source of truth for Phase 3 audio pipeline
       # See tools/tts/schema.py for validation; tools/tts/bake_audio.py (Plan 04) for the full pipeline.
       version: 1
       voice: dilja_v2  # default voice for all utterances; Tiro Diljá v2 (verified 2026-05-02 in tools/tts/README.md)
       language: is-IS
       utterances:
         # ... 65 entries ...
       ```

       Use the EXACT voice ID string captured by Plan 01 in the README (e.g. if Plan 01 verified `Diljá_v2`, write that here, not `dilja_v2`). The schema validator allows any non-empty string; the Tiro client in Plan 03 sends it verbatim.

    2. **`pronunciation_overrides.yaml`**:
       ```yaml
       # pronunciation_overrides.yaml — per-utterance SSML / text-substitution overrides.
       # Empty at Phase 3 plan 02; entries added during Plan 07's review pass.
       # See tools/tts/schema.py validate_overrides for schema.
       version: 1
       overrides: {}
       ```

    3. **`reviewed.yaml`**:
       ```yaml
       # reviewed.yaml — reviewer sign-off log.
       # Empty at Phase 3 plan 02; entries written by tools/tts/review_server.py (Plan 05) during Plan 07.
       # See tools/tts/schema.py validate_reviewed for schema.
       version: 1
       entries: {}
       ```

    4. **`tools/tts/validate_manifest.py`** — CLI entrypoint:
       ```python
       """python tools/tts/validate_manifest.py [path-to-manifest]

       With no args: validates manifest.yaml, pronunciation_overrides.yaml, and reviewed.yaml at the repo root.
       With one arg: validates that single file (auto-detects schema by filename).

       Exits 0 on success, 1 on any validation failure.
       """
       ```
       The CLI is small (≤80 lines) — most logic lives in schema.py. Print human-readable errors to stderr.

    5. **Run pytest** (`python -m pytest tools/tts/tests/test_validate_manifest.py -x`). All Task 2 tests pass — including Tests 10–16 (good repo manifest, stub keys preserved, count breakdown, starts_with consistency, asset-path consistency with Phase 2, CLI happy path, CLI bad-fixture rejection).

    6. **Run** `python tools/tts/validate_manifest.py` from repo root — exits 0.

    7. **Run** `bash tools/check-asset-paths.sh` — still passes (the validator is stricter than check-asset-paths but produces a strict superset of compliant paths, so nothing should regress).

    Commit:
    `feat(03-02): author manifest.yaml + pronunciation_overrides.yaml + reviewed.yaml + CLI validator`

    Atomic commit count for Task 2: 2 (RED + GREEN).

    Total Plan 02 atomic commits: 4 (2 in Task 1 + 2 in Task 2).
  </action>
  <verify>
    <automated>python3 tools/tts/validate_manifest.py && python3 -m pytest tools/tts/tests/ -x && bash tools/check-asset-paths.sh && grep -c "^  - key: " manifest.yaml | grep -v '^#' | grep -c .</automated>
  </verify>
  <done>
    `manifest.yaml` exists with exactly 65 utterances (verified by `grep -c '^  - key: ' manifest.yaml` returning 65 — the count comes out grep-friendly because every key line uses the same indent). `pronunciation_overrides.yaml` and `reviewed.yaml` exist with empty schemas. `python tools/tts/validate_manifest.py` exits 0. All Phase 2 stub keys (letterA, letterEth, letterThorn, wordHundur, narrationWelcome) are present in manifest.yaml. pytest passes ≥16 tests across schema + validate_manifest test files. `tools/check-asset-paths.sh` still passes.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| YAML files (manifest/overrides/reviewed) → Python pipeline | Untrusted-author input crosses here only in the sense that human typos can produce malformed YAML. No external author. |
| schema.py validators → downstream consumers (tiro_client, manifest_writer) | All later plans rely on the validator catching schema drift; if validate_manifest.py is bypassed, malformed YAML reaches Tiro client / manifest writer. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-02-01 | Tampering | manifest.yaml edited by hand without re-running validator | mitigate | Plan 06 ships `tools/check-manifest-sync.sh` which fails CI if manifest.yaml is invalid OR out-of-sync with audio_manifest.g.dart. Plan 02 only authors the validator; Plan 06 wires it into CI. |
| T-03-02-02 | Information disclosure | reviewer name + identity stored in `reviewed.yaml` committed to git | accept | Reviewer is the user (Jon) per D-30. Storing their name + ISO timestamp in a committed YAML is acceptable for a private solo project; if the repo is ever published, the reviewer line is the only PII and can be stripped. |
| T-03-02-03 | Denial of service | manifest.yaml entry with extreme values (e.g. 10MB text) blows up Tiro request | mitigate | schema.py constrains `text` to ≤500 chars (added as a max_len check in validate_manifest). Defensive bound, never expected to trip in practice — kids' app phrases are short. |
| T-03-02-04 | Repudiation | Manifest entry changed but reviewer sign-off `reviewed.yaml` retained for the OLD text | mitigate | reviewed.yaml schema (D-17) records `text_hash: sha256(text + voice + ssml)`. Plan 04's manifest writer (with Plan 06's CI guard) MUST re-verify the hash matches the current manifest entry before treating the review as valid. Plan 02 ensures the schema field exists. |
| T-03-02-05 | Spoofing | Bypassing validate_manifest.py and committing invalid YAML | mitigate | Plan 06 wires `python tools/tts/validate_manifest.py` into CI's `analyze-and-test` job; CI fails the build if manifest is invalid. Plan 02's contribution is the validator + tests; Plan 06 is the enforcement. |

</threat_model>

<verification>
- `python3 tools/tts/validate_manifest.py` returns exit 0
- `python3 -m pytest tools/tts/tests/ -x` passes (cumulative test count: ≥25 across Plans 01 + 02)
- `grep -c '^- key: \|^  - key: ' manifest.yaml` returns 65
- `python3 -c "import yaml; m=yaml.safe_load(open('manifest.yaml')); ks={u['key'] for u in m['utterances']}; assert {'letterA','letterEth','letterThorn','wordHundur','narrationWelcome'} <= ks"` exits 0 (D-22 invariant)
- `bash tools/check-asset-paths.sh` still passes (asset paths in manifest.yaml are not yet *files*; the existing 5 placeholder AAC files Phase 2 wrote are unchanged and continue to pass)
- `flutter test` and `flutter analyze` still pass (Plan 02 does not touch Dart)
</verification>

<success_criteria>
1. `manifest.yaml` at repo root, 65 entries, schema-valid, includes all Phase 2 stub keys (D-22).
2. `pronunciation_overrides.yaml` at repo root, empty + schema-valid (AUDIO-07).
3. `reviewed.yaml` at repo root, empty + schema-valid (D-17 schema).
4. `tools/tts/schema.py` exports `validate_manifest`, `validate_overrides`, `validate_reviewed` with pytest coverage exercising every error mode.
5. `tools/tts/validate_manifest.py` CLI runs end-to-end against the real repo files and exits 0.
6. AUDIO-01 (manifest exists with metadata + reviewer flag + override hooks) and AUDIO-07 (overrides file exists from day one) satisfied.
7. No Dart code touched; no asset binaries touched; no CI changes (Plan 06 owns CI wiring).
</success_criteria>

<output>
After completion, create `.planning/phases/03-tts-pipeline-audio-review-tooling/03-02-SUMMARY.md` covering:
- 4 atomic commits (2× RED, 2× GREEN)
- Final manifest.yaml count breakdown (32 + 32 + 1 = 65)
- Any deviations from the example-word picks list (e.g. if `xýlófónn` was changed to a different word; if a `ð`-medial word was substituted)
- Voice ID string used (verbatim from Plan 01 README) — flag for Plan 03
- Carry-over to Plan 03: schema.py is the consumer-facing import surface; tiro_client.py + normalize.py read manifest entries via this module
- Carry-over to Plan 07: example-word picks are TENTATIVE — review pass may swap any of them
</output>
