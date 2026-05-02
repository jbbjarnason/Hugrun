---
phase: 02-alphabet-asset-conventions-manifest-stub
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/core/alphabet/icelandic_letter.dart
  - lib/core/alphabet/icelandic_letter.freezed.dart
  - lib/core/alphabet/alphabet.dart
  - test/core/alphabet/alphabet_test.dart
  - test/core/alphabet/icelandic_letter_test.dart
  - tools/check-domain-purity.sh
autonomous: true
requirements:
  - FOUND-04
user_setup: []

must_haves:
  truths:
    - "kIcelandicAlphabet exposes exactly 32 IcelandicLetter entries in MMS school order (a á b d ð e é f g h i í j k l m n o ó p r s t u ú v x y ý þ æ ö)"
    - "No C, Q, W, or Z appears in kIcelandicAlphabet"
    - "Each letter exposes glyph, name, and assetSlug fields, with assetSlug matching the D-03 mapping table exactly"
    - "All 32 assetSlug values are unique and match ^[a-z][a-z0-9_]*$"
    - "lib/core/alphabet/ contains only pure Dart (no package:flutter imports), enforced by tools/check-domain-purity.sh"
  artifacts:
    - path: "lib/core/alphabet/icelandic_letter.dart"
      provides: "IcelandicLetter freezed model (glyph, name, assetSlug)"
      contains: "@freezed"
    - path: "lib/core/alphabet/alphabet.dart"
      provides: "kIcelandicAlphabet const list of 32 IcelandicLetter entries"
      contains: "const List<IcelandicLetter> kIcelandicAlphabet"
    - path: "test/core/alphabet/alphabet_test.dart"
      provides: "Exhaustive D-04 unit tests (length, order, no-CQWZ, slug map, slug regex, slug uniqueness)"
    - path: "test/core/alphabet/icelandic_letter_test.dart"
      provides: "Equality / copyWith tests for the freezed IcelandicLetter model"
  key_links:
    - from: "lib/core/alphabet/alphabet.dart"
      to: "lib/core/alphabet/icelandic_letter.dart"
      via: "import (no package:flutter)"
      pattern: "import 'icelandic_letter.dart'"
    - from: "tools/check-domain-purity.sh"
      to: "lib/core/alphabet/"
      via: "DOMAIN_PATHS array"
      pattern: "lib/core/alphabet"
---

<objective>
Land the canonical 32-letter Icelandic alphabet primitive that every later phase
(Stafir grid, audio manifest, CVC blending, tracing) depends on. Define the
`IcelandicLetter` freezed model, the `kIcelandicAlphabet` constant in MMS school
order, and a slug map covering ASCII-safe filenames for diacritic letters
(`eth`, `thorn`, `ae`, `o_umlaut`, etc.). All in pure Dart, no Flutter imports —
extend `tools/check-domain-purity.sh` to keep it that way.

Purpose: Phase 4 cannot render the 32-letter grid, Phase 3 cannot key the
generated audio manifest, and Phase 6 cannot key the phoneme set without this
constant. Locking it now (with exhaustive D-04 tests) prevents the
"alphabet drift" pitfall (PITFALLS #2) — a known critical foot-gun where the
shipped app teaches a different alphabet than Hugrún sees in school.

Output: A pure-Dart `lib/core/alphabet/` package + matching test directory +
one-line edit to `tools/check-domain-purity.sh` to keep the new domain folder
Flutter-free.
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

<interfaces>
<!-- The IcelandicLetter contract this plan introduces. Downstream plans
     (02-02 manifest stub, Phase 3 pipeline, Phase 4 Stafir grid) consume it. -->

From lib/core/alphabet/icelandic_letter.dart (this plan creates):
```dart
@freezed
class IcelandicLetter with _$IcelandicLetter {
  const factory IcelandicLetter({
    required String glyph,     // Unicode glyph: 'a', 'á', 'ð', 'þ', 'æ', 'ö', etc.
    required String name,      // Icelandic letter name spoken aloud: 'a', 'á', 'eð', 'þoddn', 'e'
    required String assetSlug, // ASCII-safe filename slug per D-03: 'a', 'a_acute', 'eth', 'thorn', 'ae', 'o_umlaut'
  }) = _IcelandicLetter;
}
```

From lib/core/alphabet/alphabet.dart (this plan creates):
```dart
const List<IcelandicLetter> kIcelandicAlphabet = <IcelandicLetter>[
  IcelandicLetter(glyph: 'a',  name: 'a',     assetSlug: 'a'),
  IcelandicLetter(glyph: 'á',  name: 'á',     assetSlug: 'a_acute'),
  // ... 30 more entries in MMS order ...
];
```

From .planning/phases/02-alphabet-asset-conventions-manifest-stub/02-CONTEXT.md D-03:
```
glyph -> assetSlug mapping (authoritative; tests assert this exact table):
  a -> a              á -> a_acute
  b -> b              d -> d
  ð -> eth            e -> e
  é -> e_acute        f -> f
  g -> g              h -> h
  i -> i              í -> i_acute
  j -> j              k -> k
  l -> l              m -> m
  n -> n              o -> o
  ó -> o_acute        p -> p
  r -> r              s -> s
  t -> t              u -> u
  ú -> u_acute        v -> v
  x -> x              y -> y
  ý -> y_acute        þ -> thorn
  æ -> ae             ö -> o_umlaut
```

From freezed 3.2.5 + freezed_annotation 3.1.0 (already in pubspec from Phase 1
remediation commit dc507e8): standard `@freezed`/`@Freezed()` annotation,
`with _$ClassName`, `_$ClassName` private constructor, generated
`_ClassName` impl class. Run `dart run build_runner build` to materialise
`icelandic_letter.freezed.dart`.

From tools/check-domain-purity.sh (Phase 1; modify):
```bash
DOMAIN_PATHS=(
  "lib/core/db/tables"
  "lib/core/parent_gate"
  # When Phase 2 adds lib/core/manifest/types/, append it here.   <-- existing TODO
  # When Phase 4 adds lib/domain/, append it here.
)
```
This plan adds `"lib/core/alphabet"` to that array.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — failing alphabet + IcelandicLetter tests</name>
  <files>test/core/alphabet/alphabet_test.dart, test/core/alphabet/icelandic_letter_test.dart</files>
  <behavior>
    Write the full D-04 test battery against types that don't exist yet.

    `test/core/alphabet/alphabet_test.dart` (per D-04):
    - `kIcelandicAlphabet.length == 32`
    - The exact glyph order matches the MMS list (literal list comparison):
      `['a','á','b','d','ð','e','é','f','g','h','i','í','j','k','l','m','n','o','ó','p','r','s','t','u','ú','v','x','y','ý','þ','æ','ö']`
    - `kIcelandicAlphabet.every((l) => !{'c','q','w','z'}.contains(l.glyph))`
    - Data-driven: each letter's `assetSlug` matches the D-03 fixture map (use a `const Map<String,String> kExpectedSlugs = {...}` literal in the test file mirroring D-03 verbatim; iterate `for (final letter in kIcelandicAlphabet) expect(letter.assetSlug, kExpectedSlugs[letter.glyph])`).
    - `Set.from(kIcelandicAlphabet.map((l) => l.assetSlug)).length == 32` (uniqueness)
    - `RegExp(r'^[a-z][a-z0-9_]*$')` matches every `assetSlug`
    - Each letter's `name` is non-empty (smoke check; precise name pronunciation comes from Phase 3 audio review)

    `test/core/alphabet/icelandic_letter_test.dart` (smoke for the freezed model — keeps the model wired through codegen):
    - Two equal `IcelandicLetter` instances with the same fields are `==` and have equal `hashCode` (proves `@freezed` is generating `==`/`hashCode`)
    - `copyWith(assetSlug: 'x_test')` returns a new instance with the new slug and unchanged glyph/name (proves `copyWith` generation)

    Run `flutter test test/core/alphabet/`. The test file imports
    `package:hugrun/core/alphabet/icelandic_letter.dart` and
    `package:hugrun/core/alphabet/alphabet.dart`; both files do not exist yet,
    so the run MUST fail at the import / `Undefined name` step.
  </behavior>
  <action>
    Create both test files with the assertions above.

    Per D-04 + the global TDD constraint (PROJECT.md "Testing — TDD with
    Marionette for E2E"), this is the RED commit — tests reference symbols that
    don't exist yet. Use `flutter_test`'s `test`/`expect` (no `widgetTest`
    needed; both files are pure-Dart unit tests).

    Do NOT create `lib/core/alphabet/icelandic_letter.dart` or
    `lib/core/alphabet/alphabet.dart` in this task — that's Task 2.

    Commit message: `test(02-01): add failing alphabet + IcelandicLetter tests (RED)`
  </action>
  <verify>
    <automated>flutter test test/core/alphabet/ 2>&1 | grep -E "Could not find|Undefined name|compilation failed|Some tests failed" &amp;&amp; echo "RED OK"</automated>
  </verify>
  <done>Both test files exist; `flutter test test/core/alphabet/` fails with import / undefined-name errors; commit landed with `test(02-01):` prefix.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — IcelandicLetter freezed model + kIcelandicAlphabet constant + domain-purity wiring</name>
  <files>lib/core/alphabet/icelandic_letter.dart, lib/core/alphabet/alphabet.dart, lib/core/alphabet/icelandic_letter.freezed.dart, tools/check-domain-purity.sh</files>
  <behavior>
    Make the Task 1 tests pass with minimal code:

    `lib/core/alphabet/icelandic_letter.dart` per D-12 / D-13:
    - `import 'package:freezed_annotation/freezed_annotation.dart';`
    - `part 'icelandic_letter.freezed.dart';`
    - `@freezed` class `IcelandicLetter` with `String glyph`, `String name`, `String assetSlug` factory parameters.
    - NO `import 'package:flutter/...';` anywhere — this is domain code (Phase 1 D-08 + this phase D-13).

    `lib/core/alphabet/alphabet.dart` per D-01 (path + const-list shape):
    - `import 'icelandic_letter.dart';`
    - `const List<IcelandicLetter> kIcelandicAlphabet = <IcelandicLetter>[ ... ];` — exactly 32 entries in the D-02 / Finding-3 MMS order.
    - For each letter, `assetSlug` matches D-03 verbatim. The `name` field is the spoken Icelandic letter name (use the D-CONTEXT examples and the natural Icelandic letter names; e.g. `'eð'` for ð, `'þorn'` for þ, `'ess'` for s, `'há'` for h, etc.). `name` doesn't need to be perfect Icelandic prosody — Phase 3 owns audio review — but it must be non-empty and reasonable so `kIcelandicAlphabet` reads naturally.
    - NO `import 'package:flutter/...';`.

    `tools/check-domain-purity.sh`:
    - Append `"lib/core/alphabet"` to the `DOMAIN_PATHS` array (one-line edit; the existing inline TODO comment about `lib/core/manifest/types/` stays — that gets handled in plan 02-02).

    Run `dart run build_runner build --delete-conflicting-outputs` to generate
    `lib/core/alphabet/icelandic_letter.freezed.dart`. Commit the generated
    file (project policy: generated files in `lib/gen/` and Phase 1's
    `lib/core/db/database.g.dart` / `database_provider.g.dart` are committed —
    follow the same convention for `*.freezed.dart`).

    All Task 1 tests pass. `flutter analyze` is clean. `dart format
    --set-exit-if-changed .` is clean. `tools/check-domain-purity.sh` exits 0.
  </behavior>
  <action>
    Create the two `lib/core/alphabet/*.dart` source files; run `build_runner`
    to materialize the freezed part file; commit all three. Append the
    `lib/core/alphabet` line to `tools/check-domain-purity.sh`.

    Watch out for: PITFALL #2 — copy the MMS order character-by-character from
    D-02 (`a á b d ð e é f g h i í j k l m n o ó p r s t u ú v x y ý þ æ ö`).
    Do NOT trust autocomplete; do NOT include c/q/w/z; do NOT swap þ/æ/ö
    (historical pre-1980 order placed those at the end). Test 1 will catch
    drift but spend the 30 seconds to type carefully.

    PITFALL #20 (asset case-sensitivity): every `assetSlug` is lowercase ASCII.
    The D-04 regex test enforces this; the underscore separator (`a_acute`,
    `o_umlaut`) follows D-03's "use underscore" convention.

    Commit message: `feat(02-01): add IcelandicLetter freezed model + kIcelandicAlphabet (32 letters, MMS order) (GREEN)`
  </action>
  <verify>
    <automated>flutter test test/core/alphabet/ &amp;&amp; flutter analyze lib/core/alphabet/ &amp;&amp; bash tools/check-domain-purity.sh &amp;&amp; dart format --set-exit-if-changed lib/core/alphabet/ test/core/alphabet/</automated>
  </verify>
  <done>All D-04 assertions pass; freezed model has equality + copyWith; domain-purity check confirms `lib/core/alphabet/` has zero `package:flutter/` imports; commit landed with `feat(02-01):` prefix.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: REFACTOR — cleanup, docs, format</name>
  <files>lib/core/alphabet/icelandic_letter.dart, lib/core/alphabet/alphabet.dart, test/core/alphabet/alphabet_test.dart, test/core/alphabet/icelandic_letter_test.dart</files>
  <behavior>
    Tighten the implementation without changing behavior:

    - Add a doc comment to `kIcelandicAlphabet` citing the source: "Canonical 32-letter Icelandic alphabet in MMS (Menntamálastofnun) school order. Source: PITFALLS #2, RESEARCH SUMMARY Finding 3, CONTEXT D-02. No C/Q/W/Z."
    - Add a doc comment to `IcelandicLetter` describing each field's role (glyph = Unicode display, name = spoken letter name for audio key lookup, assetSlug = ASCII-safe filename slug per CONTEXT D-03).
    - Group the 32 const entries with a one-line comment per row of 8 letters for diff legibility, OR leave one-per-line if line count is already low — either is fine, pick whichever reads cleaner.
    - In `test/core/alphabet/alphabet_test.dart`, factor the D-03 expected-slug map into a top-level `const Map<String,String> kExpectedSlugs` if not already.

    All tests still pass. `flutter analyze` clean. `dart format --set-exit-if-changed .` clean.

    If after Task 2 the code is already clean and well-doc'd, this task can
    be a no-op refactor — commit a chore/docs touch with that note. Don't
    invent work.
  </behavior>
  <action>
    Read the Task 2 output, add docstrings + minor formatting tweaks, run
    tests + analyze + format. If nothing meaningful to refactor, commit a
    docs-only touch noting "REFACTOR: no behavior changes; alphabet const
    already minimal."

    Commit message: `refactor(02-01): document alphabet primitives + group letter rows for readability`
    (or `chore(02-01): no-op REFACTOR pass — alphabet primitives already minimal` if literally nothing to change)
  </action>
  <verify>
    <automated>flutter test test/core/alphabet/ &amp;&amp; flutter analyze &amp;&amp; dart format --set-exit-if-changed .</automated>
  </verify>
  <done>3 atomic commits exist (RED → GREEN → REFACTOR) on the current branch covering plan 02-01; all alphabet tests still green; `flutter analyze` clean repo-wide.</done>
</task>

</tasks>

<verification>
After all 3 tasks complete:

```bash
# Full test pass
flutter test                      # All Phase 1 (66) + Phase 2 alphabet tests green

# Static checks
flutter analyze                   # 0 issues
dart format --set-exit-if-changed .

# Domain purity
bash tools/check-domain-purity.sh # passes; lib/core/alphabet now in DOMAIN_PATHS

# Manual sanity (one-shot)
dart -e 'import "package:hugrun/core/alphabet/alphabet.dart"; void main() { print(kIcelandicAlphabet.length); print(kIcelandicAlphabet.map((l) => l.glyph).join(" ")); }' \
  | grep -E "^32$"

# Atomic commit count
git log --oneline -- lib/core/alphabet/ test/core/alphabet/ tools/check-domain-purity.sh \
  | wc -l   # expect 3 (RED, GREEN, REFACTOR)
```
</verification>

<success_criteria>
- `kIcelandicAlphabet` constant exists with all 32 letters in MMS school order
  (a á b d ð e é f g h i í j k l m n o ó p r s t u ú v x y ý þ æ ö).
- Unit tests assert (a) length 32, (b) exact order, (c) no C/Q/W/Z, (d) every
  letter's `assetSlug` matches the D-03 mapping, (e) all slugs unique, (f) all
  slugs match `^[a-z][a-z0-9_]*$`.
- `IcelandicLetter` is a `@freezed` model with `glyph`, `name`, `assetSlug`
  fields; equality and `copyWith` work.
- `lib/core/alphabet/` is pure Dart (no `package:flutter/` imports), enforced
  by an updated `tools/check-domain-purity.sh`.
- 3 atomic commits land: RED (failing tests) → GREEN (impl) → REFACTOR
  (docs/format).
- Phase 1 success criteria 1 (FOUND-04) is materially met: the canonical
  alphabet exists in code with the asserted properties.
</success_criteria>

<output>
After completion, create
`.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-01-SUMMARY.md`
covering: commits landed, test count delta, any deviations from D-02 / D-03 /
D-04 / D-12 / D-13, and an explicit confirmation that `lib/core/alphabet/` is
listed in `tools/check-domain-purity.sh`'s `DOMAIN_PATHS` array.
</output>
