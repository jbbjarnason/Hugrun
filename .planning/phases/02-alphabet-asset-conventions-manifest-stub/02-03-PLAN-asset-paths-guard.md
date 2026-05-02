---
phase: 02-alphabet-asset-conventions-manifest-stub
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - tools/check-asset-paths.sh
  - tools/check-asset-paths_test.sh
  - tools/test-fixtures/bad-asset-paths/Foo.aac
  - tools/test-fixtures/bad-asset-paths/þrír.aac
  - tools/test-fixtures/bad-asset-paths/with space.aac
  - tools/test-fixtures/bad-asset-paths/áli.aac
  - tools/test-fixtures/bad-asset-paths/UPPER/lower.aac
  - tools/test-fixtures/bad-asset-paths/.gitkeep
  - tools/test-fixtures/good-asset-paths/letters/names/eth.aac
  - tools/test-fixtures/good-asset-paths/letters/words/hundur.aac
  - tools/test-fixtures/good-asset-paths/.gitkeep
  - .github/workflows/ci.yml
autonomous: true
requirements:
  - FOUND-05
user_setup: []

must_haves:
  truths:
    - "tools/check-asset-paths.sh walks an asset root (default assets/) and exits non-zero if any filename or directory name violates D-06 (lowercase ASCII alphanumerics + underscore + hyphen + slash + dot only; no spaces; no diacritics; no uppercase)"
    - "tools/check-asset-paths_test.sh self-tests the script using bad fixtures (Foo.aac, þrír.aac, with space.aac, áli.aac, UPPER/lower.aac) — every fixture must trigger a failure"
    - "tools/check-asset-paths_test.sh self-tests the script using good fixtures (letters/names/eth.aac, letters/words/hundur.aac) — these must pass"
    - ".github/workflows/ci.yml analyze-and-test job runs both check-asset-paths.sh AND check-asset-paths_test.sh"
    - "Running check-asset-paths.sh on the actual assets/ directory (post-Plan-02-02) passes"
  artifacts:
    - path: "tools/check-asset-paths.sh"
      provides: "CI guard script that walks an asset root and rejects bad filenames/directories"
      min_lines: 30
    - path: "tools/check-asset-paths_test.sh"
      provides: "Self-test for check-asset-paths.sh with bad + good fixtures"
      min_lines: 30
    - path: "tools/test-fixtures/bad-asset-paths/"
      provides: "Intentionally bad asset path fixtures per D-07"
    - path: "tools/test-fixtures/good-asset-paths/"
      provides: "Known-good asset path fixtures matching D-06"
    - path: ".github/workflows/ci.yml"
      provides: "CI wiring for the new guard + self-test"
      contains: "check-asset-paths"
  key_links:
    - from: ".github/workflows/ci.yml"
      to: "tools/check-asset-paths.sh"
      via: "step in analyze-and-test job"
      pattern: "tools/check-asset-paths.sh"
    - from: ".github/workflows/ci.yml"
      to: "tools/check-asset-paths_test.sh"
      via: "step in analyze-and-test job (self-test)"
      pattern: "tools/check-asset-paths_test.sh"
    - from: "tools/check-asset-paths_test.sh"
      to: "tools/check-asset-paths.sh"
      via: "invokes script against bad+good fixtures"
      pattern: "check-asset-paths.sh"
---

<objective>
Land the CI guard that enforces D-06 asset path conventions on every commit.
The guard walks `assets/` and rejects any file or directory whose name uses
non-ASCII characters, uppercase letters, spaces, or other forbidden
characters. A self-test (modelled on Phase 1's
`tools/check-no-tracking_test.sh`) runs both bad and good fixtures through
the script to prove it catches violations and lets clean paths pass.

Purpose: PITFALL #20 (asset case-sensitivity differs iOS vs Android vs Linux
CI) is a known foot-gun. A `Hundur.aac` reference works on macOS Simulator
(case-insensitive APFS) and fails on Linux CI / Android (case-sensitive).
This guard turns that latent bug into a build-time failure and locks in the
D-06 conventions Phase 3 (Python pipeline), Phase 4 (Stafir images), Phase 6
(phonemes), and Phase 8/9 (numbers) all need to follow.

Output: Two shell scripts (`tools/check-asset-paths.sh` + its self-test),
fixture trees under `tools/test-fixtures/{bad,good}-asset-paths/`, and a CI
workflow update wiring both into the `analyze-and-test` job (per D-14, D-15:
no new jobs, purely additive within existing jobs).
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
@tools/check-no-tracking.sh
@tools/check-no-tracking_test.sh
@.github/workflows/ci.yml

<interfaces>
D-06 path naming rules (the spec the script enforces):
  - Lowercase only (no uppercase letters anywhere in path components)
  - ASCII letters [a-z], digits [0-9], underscore `_`, hyphen `-`, slash `/`
    (path separator), dot `.` (extension separator) — nothing else
  - No diacritics or non-ASCII characters
  - No spaces in filenames or directory names
  - Allowed extensions: .aac (audio), .webp / .png (images), .svg (vector)

Self-test bad fixtures (D-07; these MUST trigger a failure):
  - Foo.aac                 (uppercase letter `F`)
  - þrír.aac                (non-ASCII characters `þ`, `í`)
  - with space.aac          (literal space)
  - áli.aac                 (non-ASCII `á`)
  - UPPER/lower.aac         (uppercase directory name)

Self-test good fixtures (these MUST pass):
  - letters/names/eth.aac
  - letters/words/hundur.aac

The script signature mirrors check-no-tracking.sh:
  bash tools/check-asset-paths.sh [assets-root]
where the default root is `assets/` and the optional first arg lets the
self-test point at fixture directories.

Pattern from Phase 1 (tools/check-no-tracking_test.sh) — `run_case` helper:
  - sets up a tmpdir
  - runs the script against fixtures
  - asserts pass/fail
  - tracks FAILS counter; exits non-zero if any case failed

CI integration (D-14, D-15) — additive within the existing `analyze-and-test`
job, NOT a new job. Two new steps next to the existing
`tools/check-no-tracking.sh` and `tools/check-no-tracking_test.sh` steps.

Phase 1 ci.yml step pattern (existing):
  - name: tools/check-no-tracking.sh
    run: bash tools/check-no-tracking.sh
  - name: tools/check-no-tracking_test.sh (self-test)
    run: bash tools/check-no-tracking_test.sh

This plan adds:
  - name: tools/check-asset-paths.sh
    run: bash tools/check-asset-paths.sh
  - name: tools/check-asset-paths_test.sh (self-test)
    run: bash tools/check-asset-paths_test.sh
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED -- failing self-test against a non-existent script + fixture trees</name>
  <files>tools/check-asset-paths_test.sh, tools/test-fixtures/bad-asset-paths/Foo.aac, tools/test-fixtures/bad-asset-paths/þrír.aac, tools/test-fixtures/bad-asset-paths/with space.aac, tools/test-fixtures/bad-asset-paths/áli.aac, tools/test-fixtures/bad-asset-paths/UPPER/lower.aac, tools/test-fixtures/bad-asset-paths/.gitkeep, tools/test-fixtures/good-asset-paths/letters/names/eth.aac, tools/test-fixtures/good-asset-paths/letters/words/hundur.aac, tools/test-fixtures/good-asset-paths/.gitkeep</files>
  <behavior>
    Build the failure scaffold first:

    (a) Create the bad-fixture tree under `tools/test-fixtures/bad-asset-paths/`:
      - Foo.aac (empty file)
      - þrír.aac (empty file — Unicode `þ` and `í`)
      - "with space.aac" (empty file, literal space in name)
      - áli.aac (empty file — Unicode `á`)
      - UPPER/lower.aac (uppercase directory)
      - .gitkeep (so the dir survives even if all bad files are removed)

    (b) Create the good-fixture tree under `tools/test-fixtures/good-asset-paths/`:
      - letters/names/eth.aac (empty file)
      - letters/words/hundur.aac (empty file)
      - .gitkeep

    (c) Create `tools/check-asset-paths_test.sh` modelled on
    `tools/check-no-tracking_test.sh`. The self-test:
      - Locates the script via `SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-asset-paths.sh"`
      - Defines a `run_case "name" "fixture-dir" "expect"` helper (`expect` =
        `pass` or `fail`)
      - Runs ONE case per bad fixture file (Foo.aac, þrír.aac, with space.aac,
        áli.aac, UPPER/lower.aac) — each in its own tmpdir copy of the
        bad-asset-paths fixture, expect `fail`. Alternative: run the whole
        bad-fixture dir once, expect `fail` (simpler; sufficient for D-07).
        Either is acceptable; pick the per-case approach for clearer error
        attribution.
      - Runs ONE case against the good-asset-paths fixture, expect `pass`.
      - Runs ONE case against an empty tmpdir (no files), expect `pass`
        (empty asset tree is valid).
      - Tracks FAILS; exits non-zero if any case failed.

    (d) Make the test script executable (`chmod +x`).

    Run `bash tools/check-asset-paths_test.sh`. It MUST fail because
    `tools/check-asset-paths.sh` does not exist yet (`SCRIPT` resolves to a
    non-existent path; bash cannot invoke it).

    NOTE on creating fixtures: filenames containing `þrír.aac`, `áli.aac`, and
    `with space.aac` need to be created carefully. Use `touch` with quoted
    UTF-8 names directly:
      touch "tools/test-fixtures/bad-asset-paths/þrír.aac"
      touch "tools/test-fixtures/bad-asset-paths/áli.aac"
      touch "tools/test-fixtures/bad-asset-paths/with space.aac"
    Confirm git tracks the UTF-8 byte sequences (`git config core.quotepath
    false` if necessary; the project's .gitconfig should already handle
    Unicode names — Phase 1 doesn't touch this).
  </behavior>
  <action>
    Create the fixture trees and the self-test script. Do NOT create
    `tools/check-asset-paths.sh` itself — that's Task 2.

    Commit message: `test(02-03): scaffold check-asset-paths fixtures + self-test (RED)`
  </action>
  <verify>
    <automated>chmod +x tools/check-asset-paths_test.sh &amp;&amp; (! bash tools/check-asset-paths_test.sh 2>&amp;1 | tee /tmp/asset-paths-red.log) &amp;&amp; (grep -E "No such file|not found|cannot" /tmp/asset-paths-red.log || (echo "RED OK -- script missing as expected"; true))</automated>
  </verify>
  <done>Bad-fixture tree (5 violation files) + good-fixture tree (2 clean files) + self-test script exist; running the self-test fails because the under-test script doesn't exist; commit landed with `test(02-03):` prefix.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN -- check-asset-paths.sh that catches every D-06 violation</name>
  <files>tools/check-asset-paths.sh</files>
  <behavior>
    Implement `tools/check-asset-paths.sh` to make the Task 1 self-test pass.

    Required behavior:
      - Accept optional first arg as asset root (default `assets/`).
      - Walk every file and directory under the root using `find`.
      - For each path component (each filename + each directory name along
        the way), apply D-06 checks:
          1. No uppercase letters anywhere in the component (`[A-Z]`).
          2. ASCII-only (regex against the ALLOWED set, NOT a "no non-ASCII"
             check, which is harder to write portably). Allowed character
             class for a single component: `^[a-z0-9._-]+$`.
          3. No spaces.
          4. Implicitly: no `..`, no leading `.` weirdness beyond the dotfile
             allowlist (`.gitkeep` is the one allowed dotfile; the script can
             skip `.gitkeep` explicitly).
      - Allowed extensions: only enforce on FILES (not directories). Allowed
        extensions: `.aac`, `.webp`, `.png`, `.svg`. Files with other
        extensions are flagged. Files matching `.gitkeep` are skipped.
      - Empty/non-existent root: pass with a friendly message.
      - On any violation: print a clear error message indicating the
        offending path and which rule it violated, set FAIL=1, continue
        scanning to surface ALL violations in a single run (don't bail on
        first hit).
      - Exit 0 on clean tree, 1 on any violation.

    Implementation pattern (mirrors check-no-tracking.sh):
      ```bash
      #!/usr/bin/env bash
      # CI guard: enforces D-06 asset path conventions.
      # See .planning/phases/02-alphabet-asset-conventions-manifest-stub/02-CONTEXT.md
      # Maps to FOUND-05 ("asset path conventions enforced by a generated
      # asset manifest" -- this script is the enforcement half).
      set -euo pipefail

      ROOT="${1:-assets/}"
      if [[ ! -d "$ROOT" ]]; then
        echo "tools/check-asset-paths.sh: $ROOT does not exist (skipping)"
        exit 0
      fi

      ALLOWED_COMPONENT='^[a-z0-9._-]+$'
      ALLOWED_EXTS=('aac' 'webp' 'png' 'svg')
      FAIL=0

      while IFS= read -r -d '' entry; do
        rel="${entry#$ROOT}"
        rel="${rel#/}"
        # Split into components and validate each.
        IFS='/' read -ra parts <<< "$rel"
        for c in "${parts[@]}"; do
          # Allow .gitkeep explicitly.
          if [[ "$c" == ".gitkeep" ]]; then continue; fi
          if [[ "$c" =~ [A-Z] ]]; then
            echo "ASSET PATH VIOLATION (uppercase): $entry" >&2
            FAIL=1
            continue
          fi
          if [[ "$c" =~ \  ]]; then
            echo "ASSET PATH VIOLATION (space): $entry" >&2
            FAIL=1
            continue
          fi
          if ! [[ "$c" =~ $ALLOWED_COMPONENT ]]; then
            echo "ASSET PATH VIOLATION (non-ASCII or forbidden char): $entry" >&2
            FAIL=1
            continue
          fi
        done

        # Extension check on files only.
        if [[ -f "$entry" ]] && [[ "$(basename "$entry")" != ".gitkeep" ]]; then
          ext="${entry##*.}"
          ok=0
          for a in "${ALLOWED_EXTS[@]}"; do
            [[ "$ext" == "$a" ]] && ok=1 && break
          done
          if [[ "$ok" -eq 0 ]]; then
            echo "ASSET PATH VIOLATION (extension '$ext'): $entry" >&2
            FAIL=1
          fi
        fi
      done < <(find "$ROOT" \( -type f -o -type d \) ! -name '.git' -print0)

      if [[ "$FAIL" -eq 1 ]]; then
        echo "" >&2
        echo "Build failed: $ROOT contains asset paths that violate D-06." >&2
        echo "  Convention: lowercase ASCII alphanumerics + . _ - / only." >&2
        echo "  No spaces. No diacritics. No uppercase. No non-.aac/.webp/.png/.svg files." >&2
        exit 1
      fi
      echo "tools/check-asset-paths.sh: $ROOT passes (asset paths conform to D-06)"
      ```

    The regex `^[a-z0-9._-]+$` rejects `Foo` (uppercase F), `þrír` (non-ASCII
    bytes), `áli` (non-ASCII bytes), `with space` (the embedded space), and
    `UPPER` (uppercase). It accepts `eth.aac`, `hundur.aac`, `letters`,
    `names`, `words`, `welcome_hugrun.aac`, etc.

    Bash regex word: bash matches against bytes, not Unicode codepoints.
    Non-ASCII characters appear as multi-byte sequences that don't match the
    `[a-z0-9._-]` class. This is correct (and intentional — the goal is to
    reject non-ASCII).

    Make the script executable (`chmod +x`).

    Run `bash tools/check-asset-paths_test.sh` -> pass.
    Run `bash tools/check-asset-paths.sh assets/` -> pass (assumes plan 02-02
    has landed; if 02-02 hasn't landed yet, the script still passes against
    an empty `assets/` tree because `assets/.gitkeep` is the lone file and
    is allowlisted).
  </behavior>
  <action>
    Write the script per the implementation above. Run the self-test plus
    the script against the actual `assets/` directory.

    Note: this plan's wave is 2 alongside Plan 02-02; both can develop in
    parallel because they touch disjoint files. However the script's
    "passes against actual assets/" verification might depend on Plan 02-02
    having landed (so `assets/audio/letters/names/eth.aac` etc. exist).
    That's fine — the script passes regardless of whether the assets exist
    yet (D-06 only restricts path conventions, not which files must be
    present). The verification step below uses `assets/` if present and
    otherwise the good-fixtures dir.

    Commit message: `feat(02-03): add tools/check-asset-paths.sh enforcing D-06 conventions (GREEN)`
  </action>
  <verify>
    <automated>chmod +x tools/check-asset-paths.sh &amp;&amp; bash tools/check-asset-paths_test.sh &amp;&amp; bash tools/check-asset-paths.sh tools/test-fixtures/good-asset-paths/ &amp;&amp; (! bash tools/check-asset-paths.sh tools/test-fixtures/bad-asset-paths/) &amp;&amp; bash tools/check-asset-paths.sh assets/</automated>
  </verify>
  <done>`tools/check-asset-paths.sh` exists, is executable, and exits 0 on the actual `assets/` tree + good fixtures, and exits 1 on every bad fixture; the self-test passes; commit landed with `feat(02-03):` prefix.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: GREEN -- wire check-asset-paths.sh + self-test into CI analyze-and-test job</name>
  <files>.github/workflows/ci.yml</files>
  <behavior>
    Add two new steps to `.github/workflows/ci.yml`'s `analyze-and-test` job,
    immediately after the two existing `check-no-tracking` steps and before
    `check-domain-purity.sh` (or in any consistent ordering — the order
    doesn't affect outcome but clustering by purpose helps readability):

    ```yaml
          - name: tools/check-asset-paths.sh
            run: bash tools/check-asset-paths.sh

          - name: tools/check-asset-paths_test.sh (self-test)
            run: bash tools/check-asset-paths_test.sh
    ```

    Per D-14: only the `analyze-and-test` job is touched. Per D-15: NO new
    job is added. The other two CI jobs (`integration-no-network`,
    `marionette-e2e`) are untouched.

    Validate the workflow YAML still parses (use `yamllint` if installed; if
    not, a `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"`
    sanity check is sufficient — Python ships on macOS by default).

    No GitHub-side push is required for this verify (the user has not yet
    pushed CI per Phase 1 outstanding-work item 6); local YAML syntax check
    is the gate.
  </behavior>
  <action>
    Edit ci.yml inserting the two new steps. Verify the workflow file
    parses as valid YAML.

    Commit message: `ci(02-03): wire check-asset-paths + self-test into analyze-and-test job (D-14, D-15)`
  </action>
  <verify>
    <automated>python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" &amp;&amp; grep -E "check-asset-paths\.sh" .github/workflows/ci.yml | grep -v '^#' | wc -l | grep -E "^[[:space:]]*2$"</automated>
  </verify>
  <done>`.github/workflows/ci.yml` parses as valid YAML; both `check-asset-paths.sh` and `check-asset-paths_test.sh` appear as named steps inside `analyze-and-test`; no new top-level jobs added (still 3 jobs total); commit landed with `ci(02-03):` prefix.</done>
</task>

</tasks>

<verification>
After all 3 tasks complete:

```bash
# Self-test against the script
bash tools/check-asset-paths_test.sh                       # exits 0

# Script against actual assets (post 02-02 -- if 02-02 landed first)
bash tools/check-asset-paths.sh assets/                    # exits 0

# Script against good fixtures
bash tools/check-asset-paths.sh tools/test-fixtures/good-asset-paths/    # exits 0

# Script against bad fixtures (expect failure)
! bash tools/check-asset-paths.sh tools/test-fixtures/bad-asset-paths/  # script exits non-zero

# CI YAML parses
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"

# CI YAML wired correctly: 2 references to check-asset-paths (one for the
# script step, one for the self-test step), excluding the file path itself
# in workflow comments
grep -c "check-asset-paths" .github/workflows/ci.yml       # >= 2 (uncommented)

# Atomic commits this plan
git log --oneline -- tools/check-asset-paths.sh tools/check-asset-paths_test.sh tools/test-fixtures/ .github/workflows/ci.yml \
  | wc -l                                                  # expect 3
```
</verification>

<success_criteria>
- `tools/check-asset-paths.sh` walks an asset root and rejects any path that
  contains uppercase letters, non-ASCII characters, spaces, or disallowed
  extensions; exits 0 on clean trees; exits 1 on any violation.
- `tools/check-asset-paths_test.sh` exercises the script with intentional bad
  fixtures (Foo.aac, þrír.aac, with space.aac, áli.aac, UPPER/lower.aac) and
  good fixtures (letters/names/eth.aac, letters/words/hundur.aac); fails if
  the script fails to catch any bad fixture or rejects any good fixture.
- Both scripts are executable (chmod +x) and follow Phase 1's
  check-no-tracking.sh / check-no-tracking_test.sh structure.
- `.github/workflows/ci.yml` adds two new steps to the existing
  `analyze-and-test` job; no new jobs are introduced (D-14, D-15).
- Phase 2 success criterion 2 (FOUND-05 generated asset manifest enforces
  lowercase ASCII-safe paths; CI fails on any non-ASCII or uppercase asset
  filename) is met.
- 3 atomic commits land: RED (fixtures + self-test) -> GREEN (script) ->
  GREEN (CI wiring).
</success_criteria>

<output>
After completion, create
`.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-03-SUMMARY.md`
covering: commits landed, self-test cases (count + outcomes), CI YAML diff
summary, any deviations from D-06 / D-07 / D-14 / D-15, and explicit
confirmation that the script exits non-zero against EACH of the 5 D-07 bad
fixtures.
</output>
