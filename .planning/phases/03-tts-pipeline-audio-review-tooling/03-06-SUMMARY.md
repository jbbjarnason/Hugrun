---
phase: 3
plan: 06
plan-name: ci-manifest-sync-guard
status: complete
date: 2026-05-02
duration: ~20 min
requirements_satisfied:
  - AUDIO-01
  - AUDIO-06
  - AUDIO-08
key-files:
  created:
    - tools/check-manifest-sync.sh
    - tools/check-manifest-sync_test.sh
  modified:
    - .github/workflows/ci.yml
decisions:
  - "Script wraps validate_manifest.py + bake_audio.py --check-sync; carve-out for Phase-3-not-yet-baked state via --allow-stub-baseline."
  - "Self-test discovered a bug: bash <abs-path-script> with `cd $(dirname $0)/..` resolves back to the original repo, NOT the tmp dir. Fix is to copy the script into $TMP and invoke with relative path."
  - "Python 3.11 added to CI via actions/setup-python@v5; pip install -r tools/tts/requirements.txt before sync check."
---

# Plan 03-06 Summary — CI Manifest-Sync Guard

## What was built

| Artifact | Purpose |
|---|---|
| `tools/check-manifest-sync.sh` | Runs in CI. (a) validates 3 YAML files (D-23.1), (b) Phase-3-not-yet-baked carve-out via bake_audio --check-sync --allow-stub-baseline, (c) full sync diff once Plan 07 has shipped, (d) reviewed.yaml exhaustive check. |
| `tools/check-manifest-sync_test.sh` | Self-test with 2 case branches: not_yet_baked (real repo, expects pass) and invalid_yaml (mutated tmp dir, expects fail). |
| `.github/workflows/ci.yml` (modified) | Adds setup-python@v5 + pip install + 2 new check steps (check-manifest-sync.sh + self-test) into the existing analyze-and-test job (additive — no new jobs, per D-15 / Phase 2 precedent). |

## Atomic commits

| Hash | Type | Message |
|---|---|---|
| `5adb845` | feat | feat(03-06): add tools/check-manifest-sync.sh + self-test + CI wiring (Plan 06) |

## Self-test bug found + fixed

**Bug:** bash script tries to cd to its own directory via
`cd "$(dirname "${BASH_SOURCE[0]}")/.."`. When the self-test invokes the
ORIGINAL `tools/check-manifest-sync.sh` (absolute path) from inside `$TMP`,
the cd resolves to the original repo root — not `$TMP`. The script then
processes the REAL manifest.yaml + reviewed.yaml + audio_manifest.g.dart
(which DOES match the Phase 2 stub), prints `skip(03-06):` and exits 0.

**Fix:** copy the script into `$TMP/tools/check-manifest-sync.sh` and pass
the relative path to bash. The script's cd then resolves to `$TMP`, where
the malformed manifest.yaml lives.

This is documented in the run_case docstring of check-manifest-sync_test.sh
so future operators don't re-introduce the bug.

## CI step additions

Inserted between `tools/check-asset-paths_test.sh` and
`tools/check-domain-purity.sh`:

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: '3.11'

- name: Install Python deps for TTS pipeline guards
  run: pip install -r tools/tts/requirements.txt

- name: tools/check-manifest-sync.sh
  run: bash tools/check-manifest-sync.sh

- name: tools/check-manifest-sync_test.sh (self-test)
  run: bash tools/check-manifest-sync_test.sh
```

## Carve-out expiration

The not-yet-baked carve-out triggers when ALL THREE conditions hold:
1. lib/gen/audio_manifest.g.dart contains EXACTLY the 5 Phase 2 stub keys
2. reviewed.yaml entries == {} (no approvals yet)
3. manifest.yaml has more keys than the stub

After Plan 07 completes (Jon reviews + the regenerated manifest is committed),
condition 1 no longer holds → carve-out doesn't trigger → full sync check
applies → reviewed.yaml exhaustive check applies. CI guard transitions from
"skip" mode to "enforce" mode automatically.

## Carry-overs

- **Plan 07 ship commit:** when the regenerated audio_manifest.g.dart is
  committed alongside populated reviewed.yaml, this guard switches from
  skip to enforce automatically.
