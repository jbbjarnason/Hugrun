---
phase: 03-tts-pipeline-audio-review-tooling
plan: 06
type: execute
wave: 5
depends_on: ["03-04"]
files_modified:
  - tools/check-manifest-sync.sh
  - tools/check-manifest-sync_test.sh
  - tools/test-fixtures/manifest-sync/.gitkeep
  - tools/test-fixtures/manifest-sync/manifest_drift.yaml
  - tools/test-fixtures/manifest-sync/audio_manifest_old.g.dart
  - .github/workflows/ci.yml
autonomous: true
requirements:
  - AUDIO-01
  - AUDIO-06
  - AUDIO-08

must_haves:
  truths:
    - "tools/check-manifest-sync.sh validates manifest.yaml + pronunciation_overrides.yaml + reviewed.yaml schemas (D-23.1) and asserts that re-running manifest_writer produces output byte-identical to the committed lib/gen/audio_manifest.g.dart (D-23.3 / D-24)"
    - "tools/check-manifest-sync.sh fails CI with non-zero exit if any reviewed.yaml entry is missing for a manifest key (D-23.2)"
    - "tools/check-manifest-sync_test.sh self-test exists, exercises bad fixtures (drifted manifest + missing review + valid sync), and runs in CI"
    - "Both scripts are wired into .github/workflows/ci.yml's analyze-and-test job, following the Phase 2 pattern of additive checks (no new jobs)"
    - "The check is robust to a not-yet-baked state: if lib/gen/audio_manifest.g.dart matches the Phase 2 hand-written stub AND reviewed.yaml is empty, the check is SKIPPED with an informational message (Phase 3 has not yet run end-to-end)"
  artifacts:
    - path: tools/check-manifest-sync.sh
      provides: "CI guard: manifest.yaml + reviewed.yaml validated; lib/gen/audio_manifest.g.dart in sync (D-24)"
    - path: tools/check-manifest-sync_test.sh
      provides: "Self-test exercising drift, missing-review, valid-sync, and not-yet-baked branches"
    - path: tools/test-fixtures/manifest-sync/
      provides: "Fixtures used by the self-test (intentional drift between manifest and Dart)"
  key_links:
    - from: tools/check-manifest-sync.sh
      to: tools/tts/bake_audio.py
      via: "bash invokes `python tools/tts/bake_audio.py --skip-tiro --skip-review-gate --check-sync` to re-render the manifest writer output to a temp file, then diffs against lib/gen/audio_manifest.g.dart"
      pattern: "bake_audio\\.py.*--check-sync"
    - from: tools/check-manifest-sync.sh
      to: tools/tts/validate_manifest.py
      via: "bash invokes `python tools/tts/validate_manifest.py` first; if schemas fail, the rest is skipped"
      pattern: "validate_manifest\\.py"
    - from: .github/workflows/ci.yml (analyze-and-test job)
      to: tools/check-manifest-sync.sh
      via: "two new steps inserted alongside the existing check-asset-paths steps"
      pattern: "check-manifest-sync"
---

<objective>
Wire the manifest-sync invariant into CI per D-23 + D-24 + D-25 (deferral):

1. **`tools/check-manifest-sync.sh`** — bash script that runs in CI. Three checks:
   - **(a) YAML schemas valid** (D-23.1): runs `python tools/tts/validate_manifest.py`; fails on any schema violation.
   - **(b) reviewed.yaml exhaustive** (D-23.2): asserts every key in manifest.yaml has a corresponding `entries.{key}.reviewed: true` in reviewed.yaml. SKIPPED with a clear "phase-3-not-yet-baked" message when reviewed.yaml is empty AND lib/gen/audio_manifest.g.dart still matches the Phase 2 stub. Once the bake has happened (Plan 07), this check enforces the gate.
   - **(c) lib/gen/audio_manifest.g.dart in sync** (D-23.3 / D-24): runs `python tools/tts/bake_audio.py --check-sync` (a new lightweight mode that re-renders the manifest_writer output without doing Tiro/normalize work) and diffs against the committed file. Failure = "someone updated manifest.yaml without re-running the pipeline".

2. **`tools/check-manifest-sync_test.sh`** — self-test, following the Phase 2 pattern (`tools/check-asset-paths_test.sh` and `tools/check-no-tracking_test.sh`). Test cases:
   - GOOD: stable manifest + matching Dart → exit 0.
   - DRIFTED: manifest has a new entry; Dart doesn't → exit non-zero.
   - MISSING REVIEW: reviewed.yaml missing an entry for a manifest key → exit non-zero.
   - PHASE-3-NOT-YET-BAKED: matches the Phase 2 stub state → exit 0 with informational message (skipped).
   - INVALID YAML: manifest.yaml is malformed → exit non-zero.

3. **`.github/workflows/ci.yml`** — add two new steps to the existing `analyze-and-test` job (do NOT create a new job; per D-15 / Phase 2 precedent: additive within existing jobs). Steps run AFTER the Phase 2 asset-path checks:
   - Install Python deps (already cached if subosito's flutter-action set up Python; otherwise `pip install -r tools/tts/requirements.txt`).
   - `bash tools/check-manifest-sync.sh`
   - `bash tools/check-manifest-sync_test.sh`

4. **A new `--check-sync` flag in `tools/tts/bake_audio.py`** (a small Plan 04 addendum): renders the manifest_writer output to a tmp file with `skip_review_gate=True` (because CI doesn't have reviewed clips yet — that's Plan 07's job) AND `skip_tiro=True` (no Tiro keys in CI), reads existing AAC durations from disk if available else from a stub-duration ffprobe call, and prints the rendered Dart to stdout. The bash guard captures stdout and `diff`s it against the committed file. If durations are unmeasurable in CI (no AAC files), bake_audio uses the durations recorded in `lib/gen/audio_manifest.g.dart` itself — that is, the check is "would the writer produce the same Dart given the same inputs?" — a pure-text consistency check that does NOT require AAC files in CI. Add this flag to bake_audio.py in this plan (small enough delta to belong here, not Plan 04).

Output:
- 2 bash scripts (~80 lines each).
- 1 fixture directory with intentional bad/good states.
- 1 CI workflow extension (2 new steps).
- 1 small bake_audio.py extension (~30 lines added).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-CONTEXT.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-04-SUMMARY.md
@tools/check-asset-paths.sh
@tools/check-asset-paths_test.sh
@tools/check-no-tracking_test.sh
@.github/workflows/ci.yml
@manifest.yaml
@reviewed.yaml
@lib/gen/audio_manifest.g.dart

<interfaces>
<!-- Phase 2's existing self-test pattern. Embedded so Plan 06 follows the same shape. -->

Pattern from `tools/check-no-tracking_test.sh`:
- `set -euo pipefail`
- `SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-no-tracking.sh"`
- `run_case "name" "fixture_content" "pass|fail"` helper that creates a tmpdir, writes a fixture, runs the script in that tmpdir, asserts expected exit.
- `FAILS=0`; increment on mismatch; final `[[ "$FAILS" -gt 0 ]] && exit 1`.

Phase 1's CI guard pattern: each guard is a bash script that prints a clear "ok" / "fail" message and exits cleanly. CI step name maps 1:1 to script name.

bake_audio.py `--check-sync` flag (added in this plan):
```python
parser.add_argument("--check-sync", action="store_true",
    help="Render lib/gen/audio_manifest.g.dart to stdout (using existing durations) without running Tiro or normalize; intended for CI consistency check.")
```

When set:
- Skip plan/generate/normalize stages entirely.
- Read existing `lib/gen/audio_manifest.g.dart` to extract current durations (regex: `UtteranceKey.(\w+):.*Duration\(milliseconds: (\d+)\)`).
- Build `durations_ms` dict from those.
- For keys in manifest.yaml that don't yet appear in audio_manifest.g.dart (Phase 3 first run, or new keys added in Phase 6/8), use a placeholder duration of 0 — but ONLY if `skip_review_gate=True` (which is implied by `--check-sync`). Print a warning to stderr.
- Render the Dart output via `manifest_writer.write_audio_manifest(..., out_manifest_path=Path('/dev/stdout'))` — but Jinja2 doesn't directly write to /dev/stdout, so capture as string and print.

The CI guard then:
```bash
ACTUAL="$(cat lib/gen/audio_manifest.g.dart)"
EXPECTED="$(python tools/tts/bake_audio.py --check-sync)"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  diff <(echo "$ACTUAL") <(echo "$EXPECTED") || true
  echo "FAIL: manifest.yaml and lib/gen/audio_manifest.g.dart out of sync"
  exit 1
fi
```

Phase 2-baseline behavior — the not-yet-baked state:
- `manifest.yaml` has 65 entries (Plan 02).
- `reviewed.yaml` is empty (Plan 02; Plan 07 populates it).
- `lib/gen/audio_manifest.g.dart` has only 5 entries from Phase 2's hand-written stub.
- A naive `--check-sync` here would FAIL because manifest.yaml has 60 more keys than the Dart file.

The guard handles this with an explicit "not-yet-baked" detection:
```bash
if [[ $(grep -c '^  - key: ' manifest.yaml) -gt 5 ]] && \
   [[ $(grep -c '^  UtteranceKey\.' lib/gen/audio_manifest.g.dart) -eq 5 ]] && \
   [[ "$(yaml_get reviewed.yaml entries)" == "{}" ]]; then
  echo "skip(03-06): Phase 3 pipeline has not yet been run end-to-end (Plan 07). Manifest sync check skipped."
  echo "  manifest.yaml has $(grep -c '^  - key: ' manifest.yaml) entries"
  echo "  lib/gen/audio_manifest.g.dart still matches Phase 2 stub (5 entries)"
  echo "  reviewed.yaml is empty"
  exit 0
fi
```
After Plan 07 ships ~65 reviewed clips, this branch no longer triggers; the full check applies.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add --check-sync flag to bake_audio.py + check-manifest-sync.sh + self-test (TDD)</name>
  <files>
    tools/tts/bake_audio.py
    tools/tts/tests/test_bake_audio.py
    tools/check-manifest-sync.sh
    tools/check-manifest-sync_test.sh
    tools/test-fixtures/manifest-sync/.gitkeep
    tools/test-fixtures/manifest-sync/manifest_drift.yaml
    tools/test-fixtures/manifest-sync/audio_manifest_old.g.dart
  </files>
  <behavior>
    Test 21 (RED, in test_bake_audio.py): `python tools/tts/bake_audio.py --check-sync` exits 0 against the current state (Phase 2 stub) when run with `--allow-stub-baseline` flag (the not-yet-baked carve-out). Without the flag, exits non-zero because manifest.yaml has 65 keys but the Dart only has 5.
    Test 22: `python tools/tts/bake_audio.py --check-sync` against a synthetic "post-Plan-07" state (Dart has 65 entries matching manifest, reviewed.yaml fully populated) exits 0 without `--allow-stub-baseline`.
    Test 23: `python tools/tts/bake_audio.py --check-sync` after introducing a fake new key into manifest.yaml that's NOT in the Dart → exits non-zero.

    For the bash self-test (`tools/check-manifest-sync_test.sh`):
    Case 1 — `not_yet_baked`: matches Phase 2 stub state, expects exit 0 with a `skip(03-06):` informational line.
    Case 2 — `valid_sync`: synthetic full-pipeline-complete state, expects exit 0.
    Case 3 — `manifest_drift`: manifest.yaml has a key the Dart lacks, expects non-zero.
    Case 4 — `missing_review`: reviewed.yaml missing an entry for a manifest key (post-bake state), expects non-zero.
    Case 5 — `invalid_manifest_yaml`: manifest.yaml has invalid YAML, expects non-zero.

    For the live invocation (after this plan ships), `bash tools/check-manifest-sync.sh` against the actual repo state should print `skip(03-06): Phase 3 pipeline has not yet been run end-to-end` and exit 0 — because Plan 07 hasn't run yet.
  </behavior>
  <action>
    **Step A — RED (bake_audio --check-sync)**: extend `test_bake_audio.py` with Tests 21, 22, 23. Run pytest, confirm RED. Commit:
    `test(03-06): add failing --check-sync flag tests for bake_audio.py`

    **Step B — GREEN (bake_audio --check-sync)**: extend `tools/tts/bake_audio.py`:

    1. Add `--check-sync` and `--allow-stub-baseline` flags to argparse.
    2. New code path:
       ```python
       def run_check_sync(*, allow_stub_baseline: bool, ...) -> int:
           manifest = read_yaml(manifest_path)
           validate_manifest(manifest)  # bail early if invalid
           dart_existing = Path("lib/gen/audio_manifest.g.dart").read_text()

           # Detect not-yet-baked state.
           manifest_keys = {u["key"] for u in manifest["utterances"]}
           dart_keys = set(re.findall(r"UtteranceKey\.(\w+):", dart_existing))
           if allow_stub_baseline:
               if dart_keys == {"letterA", "letterEth", "letterThorn", "wordHundur", "narrationWelcome"} \
                  and manifest_keys >= dart_keys \
                  and read_yaml(reviewed_path).get("entries", {}) == {}:
                   print("skip(03-06): Phase 3 pipeline has not yet been run end-to-end (Plan 07).")
                   return 0

           # Extract durations from existing Dart for keys present there.
           durations = dict(re.findall(r"UtteranceKey\.(\w+):.*?milliseconds: (\d+)", dart_existing, re.DOTALL))
           durations = {k: int(v) for k, v in durations.items()}
           # For keys not yet in Dart, use 0 (will produce drift error if real run hasn't happened).
           for k in manifest_keys - dart_keys:
               durations[k] = 0

           used_texts = {u["key"]: resolve_used_text_voice(u, manifest, overrides) for u in manifest["utterances"]}

           rendered = render_to_string(manifest, used_texts, durations)
           sys.stdout.write(rendered)
           return 0
       ```

       The `--check-sync` exit code is always 0 if rendering succeeds — the bash guard does the diff + comparison.

    Run pytest, confirm GREEN. Commit:
    `feat(03-06): add --check-sync and --allow-stub-baseline flags to bake_audio.py`

    **Step C — Author check-manifest-sync.sh**:
    ```bash
    #!/usr/bin/env bash
    # CI guard: enforces manifest.yaml ↔ lib/gen/audio_manifest.g.dart consistency.
    # See .planning/phases/03-tts-pipeline-audio-review-tooling/03-CONTEXT.md D-23, D-24.
    # Maps to AUDIO-01 (manifest exists), AUDIO-06 (committed Dart in sync), AUDIO-08 (review gate enforced).
    #
    # Behavior:
    # 1. Validates the three YAML files via tools/tts/validate_manifest.py.
    # 2. If reviewed.yaml is empty AND lib/gen/audio_manifest.g.dart matches Phase 2 stub
    #    AND manifest.yaml has more keys than the stub → SKIP with informational message
    #    (Phase 3's full pipeline run / Plan 07 hasn't shipped yet).
    # 3. Otherwise: assert every manifest key has reviewed: true; assert
    #    `bake_audio.py --check-sync` output equals committed audio_manifest.g.dart.
    set -euo pipefail

    cd "$(dirname "${BASH_SOURCE[0]}")/.."  # repo root

    if [[ ! -f manifest.yaml ]]; then
      echo "skip(03-06): manifest.yaml not present"
      exit 0
    fi

    echo "=== validate manifest/overrides/reviewed schemas ==="
    python3 tools/tts/validate_manifest.py

    echo "=== check audio_manifest.g.dart in sync with manifest.yaml ==="
    EXPECTED="$(python3 tools/tts/bake_audio.py --check-sync --allow-stub-baseline)"

    # If --check-sync emitted a `skip(...)` line and exited 0, surface it and stop.
    if [[ "$EXPECTED" == skip\(03-06\):* ]]; then
      echo "$EXPECTED"
      exit 0
    fi

    ACTUAL="$(cat lib/gen/audio_manifest.g.dart)"
    if [[ "$ACTUAL" != "$EXPECTED" ]]; then
      echo "FAIL: lib/gen/audio_manifest.g.dart out of sync with manifest.yaml" >&2
      diff <(echo "$ACTUAL") <(echo "$EXPECTED") || true
      echo "Re-run: python3 tools/tts/bake_audio.py" >&2
      exit 1
    fi

    echo "=== check reviewed.yaml exhaustive ==="
    python3 - <<'PY'
    import sys, yaml
    m = yaml.safe_load(open("manifest.yaml"))
    r = yaml.safe_load(open("reviewed.yaml")) or {"entries": {}}
    keys = {u["key"] for u in m["utterances"]}
    reviewed_ok = {k for k, v in (r.get("entries") or {}).items() if v.get("reviewed") is True}
    missing = sorted(keys - reviewed_ok)
    # If reviewed.yaml is empty, this is the not-yet-baked state — skipped above. If we got here,
    # we expect reviewed.yaml to be exhaustive.
    if r.get("entries"):
        if missing:
            print(f"FAIL: {len(missing)} unreviewed manifest entries: {missing[:5]}{'...' if len(missing)>5 else ''}", file=sys.stderr)
            sys.exit(1)
    PY

    echo "ok: manifest sync"
    ```

    Make executable: `chmod +x tools/check-manifest-sync.sh`.

    **Step D — Author check-manifest-sync_test.sh** following the Phase 2 self-test pattern:
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-manifest-sync.sh"
    REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    FAILS=0

    run_case() {
      local name="$1" workdir="$2" expect="$3"
      if (cd "$workdir" && bash "$SCRIPT") &>/dev/null; then
        actual="pass"
      else
        actual="fail"
      fi
      if [[ "$actual" != "$expect" ]]; then
        echo "FAIL: $name (expected $expect, got $actual)" >&2
        FAILS=$((FAILS+1))
      fi
    }

    # Case 1: not-yet-baked state (real repo state; Plan 07 hasn't run)
    run_case "not_yet_baked" "$REPO" "pass"

    # Case 2: drifted manifest (synthetic — fixture has 6 entries, Dart has 5)
    TMP="$(mktemp -d)"
    cp "$REPO/tools/test-fixtures/manifest-sync/manifest_drift.yaml" "$TMP/manifest.yaml"
    cp "$REPO/tools/test-fixtures/manifest-sync/audio_manifest_old.g.dart" "$TMP/lib/gen/audio_manifest.g.dart"
    # ... copy other necessary files (overrides.yaml, reviewed.yaml, tools/tts/, etc.)
    run_case "manifest_drift" "$TMP" "fail"
    rm -rf "$TMP"

    # ... (cases 3, 4, 5 follow the same pattern; in practice some cases require enough
    # repo scaffolding that copying ALL relevant files is impractical — the simpler approach
    # is to mutate the real repo's manifest.yaml in a stash/restore loop. That's risky in CI;
    # safer to construct minimal "fake repo" tmpdirs that contain only the files the script
    # actually reads. See implementation notes below.)

    if [[ "$FAILS" -gt 0 ]]; then exit 1; fi
    echo "self-test ok"
    ```

    Implementation note for self-test: the script depends on `manifest.yaml`, `pronunciation_overrides.yaml`, `reviewed.yaml`, `lib/gen/audio_manifest.g.dart`, AND the `tools/tts/` Python modules. The simplest robust approach is:
    - For Case 1 (not_yet_baked), run against the real repo (no temp dir) — this is the integration test that the GUARD is correctly reporting "skipped" today.
    - For Cases 2–5, build minimal fixture repos under `$TMP` that include symlinks to `$REPO/tools/tts/` (so Python imports work) plus fixture YAML/Dart files for the inputs being mutated.

    Make executable: `chmod +x tools/check-manifest-sync_test.sh`.

    **Step E — fixtures**:
    - `tools/test-fixtures/manifest-sync/manifest_drift.yaml`: copy of manifest.yaml with one extra utterance NOT in `audio_manifest_old.g.dart`.
    - `tools/test-fixtures/manifest-sync/audio_manifest_old.g.dart`: matches Phase 2's 5-entry stub structure but with a stale key.
    - `.gitkeep` to ensure the directory exists.

    **Run** `bash tools/check-manifest-sync.sh` against the real repo — should print `skip(03-06):` and exit 0.
    **Run** `bash tools/check-manifest-sync_test.sh` — should print `self-test ok` and exit 0.

    Commit:
    `feat(03-06): add tools/check-manifest-sync.sh + self-test (D-23/D-24)`

    Atomic commit count for Task 1: 3 (RED bake_audio + GREEN bake_audio + bash scripts).
  </action>
  <verify>
    <automated>bash tools/check-manifest-sync.sh && bash tools/check-manifest-sync_test.sh && python3 -m pytest tools/tts/tests/test_bake_audio.py -x</automated>
  </verify>
  <done>
    `bash tools/check-manifest-sync.sh` exits 0 with `skip(03-06):` line (current real state). `bash tools/check-manifest-sync_test.sh` exits 0 with `self-test ok`. `pytest tools/tts/tests/test_bake_audio.py` includes ≥3 new tests for `--check-sync`. The fixtures directory has the bad/good fixture files committed.
  </done>
</task>

<task type="auto">
  <name>Task 2: Wire check-manifest-sync.sh + self-test into .github/workflows/ci.yml (analyze-and-test job)</name>
  <files>
    .github/workflows/ci.yml
  </files>
  <behavior>
    The analyze-and-test job in the existing `.github/workflows/ci.yml` gains two new steps, sequenced AFTER the existing `tools/check-asset-paths_test.sh` step and BEFORE `tools/check-domain-purity.sh` (alphabetic ordering of guard names is OK; what matters is the step appears in the same job, not as a new job — D-15 / Phase 2 precedent).

    The job must have Python 3.11+ available so the bash script can call `python3 tools/tts/validate_manifest.py` and `python3 tools/tts/bake_audio.py --check-sync`. GitHub Actions ubuntu-latest runners ship Python 3 by default; verify pip install runs (or accept the system Python). Add a `Set up Python` step earlier in the job if needed.
  </behavior>
  <action>
    1. Read existing `.github/workflows/ci.yml`.
    2. Find the `analyze-and-test` job's steps list.
    3. After `Set up Python` (add it if not already present, before `flutter pub get`):
       ```yaml
       - uses: actions/setup-python@v5
         with:
           python-version: '3.11'

       - name: Install Python deps for TTS pipeline guards
         run: |
           pip install -r tools/tts/requirements.txt
       ```
    4. After the `tools/check-asset-paths_test.sh` step, insert:
       ```yaml
       - name: tools/check-manifest-sync.sh
         run: bash tools/check-manifest-sync.sh

       - name: tools/check-manifest-sync_test.sh (self-test)
         run: bash tools/check-manifest-sync_test.sh
       ```
    5. **No new jobs** (D-15 / Phase 2 precedent). All additions stay inside `analyze-and-test`.
    6. Validate the YAML parses: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"`.
    7. Locally run the inserted steps in sequence to verify they pass.

    Commit:
    `ci(03-06): wire check-manifest-sync.sh + self-test into analyze-and-test job`

    Atomic commit count for Task 2: 1.

    Total Plan 06 atomic commits: 4 (1 RED, 2 GREEN, 1 CI).
  </action>
  <verify>
    <automated>python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && bash tools/check-manifest-sync.sh && bash tools/check-manifest-sync_test.sh</automated>
  </verify>
  <done>
    `.github/workflows/ci.yml` parses as valid YAML. The `analyze-and-test` job has 2 new steps + 2 Python-setup steps. Locally invoking the same commands succeeds. No new CI jobs were created.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| GitHub Actions runner → tools/check-manifest-sync.sh | CI runner trusts the bash script + the Python tooling. No external inputs beyond the repo contents. |
| bash script → Python pipeline | bash invokes `python3 tools/tts/validate_manifest.py` and `python3 tools/tts/bake_audio.py --check-sync`. Python output is treated as text for diff. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-06-01 | Tampering | Someone updates manifest.yaml without re-running the pipeline + commits | mitigate | The whole point of this plan. CI fails the build with a clear "re-run python tools/tts/bake_audio.py" message. |
| T-03-06-02 | Tampering | Someone hand-edits lib/gen/audio_manifest.g.dart | mitigate | Same check — the diff against `--check-sync` output catches it. |
| T-03-06-03 | Spoofing | Someone toggles `reviewed: true` for an unreviewed clip without text_hash | mitigate | This isn't directly Plan 06's job — it's caught by Plan 04's manifest_writer. But the YAML-schema validate step rejects malformed reviewed.yaml entries (missing fields). |
| T-03-06-04 | Denial of service | The not-yet-baked carve-out lets a partially-completed pipeline ship | accept | Phase 3 explicitly ships in two waves: tooling (Plans 01–06) + pipeline run (Plan 07). The carve-out is a deliberate, time-bounded acceptable state. After Plan 07, the carve-out condition is no longer satisfied; the full check applies. |
| T-03-06-05 | Information disclosure | TIRO_API_KEY leaks via CI logs | accept | CI does NOT need the Tiro key (`--check-sync` skips Tiro). The variable is not set in CI. |
| T-03-06-06 | Tampering | A pre-merge patch removes `--allow-stub-baseline` and silently ships unbaked audio | mitigate | The flag is benign; it ONLY relaxes the check during the not-yet-baked state. After Plan 07 runs, `lib/gen/audio_manifest.g.dart` no longer matches the stub, so `--allow-stub-baseline` has no effect. |

</threat_model>

<verification>
- `bash tools/check-manifest-sync.sh` returns exit 0 with the `skip(03-06):` line (real state)
- `bash tools/check-manifest-sync_test.sh` returns exit 0 with `self-test ok`
- `python3 -m pytest tools/tts/tests/ -x` still passes (cumulative)
- `.github/workflows/ci.yml` parses as valid YAML
- All Phase 1 + 2 CI guards still pass (`tools/check-no-tracking.sh`, `tools/check-no-tracking_test.sh`, `tools/check-asset-paths.sh`, `tools/check-asset-paths_test.sh`, `tools/check-domain-purity.sh`, `tools/check-flutter-version.sh`)
- `flutter test`, `flutter analyze` still pass
</verification>

<success_criteria>
1. `tools/check-manifest-sync.sh` exists, validates schemas, asserts manifest ↔ Dart sync, asserts reviewed.yaml exhaustiveness, with a documented "not-yet-baked" carve-out.
2. `tools/check-manifest-sync_test.sh` exists with ≥4 self-test cases (good, drift, missing-review, invalid YAML).
3. CI workflow extended with 2 new steps + Python setup; no new jobs.
4. `bake_audio.py` has `--check-sync` and `--allow-stub-baseline` flags with pytest coverage.
5. AUDIO-01 (manifest exists), AUDIO-06 (Dart in sync, no runtime parse), AUDIO-08 (review gate) are enforced via CI from this plan onward.
</success_criteria>

<output>
After completion, create `.planning/phases/03-tts-pipeline-audio-review-tooling/03-06-SUMMARY.md` covering:
- 4 atomic commits
- The exact CI step names added (so a future operator can find them)
- The not-yet-baked carve-out's expiration condition (post-Plan-07: stub baseline no longer matches)
- Carry-over to Plan 07: after the bake + review pass, this guard switches from "skip" to "enforce" automatically
</output>
