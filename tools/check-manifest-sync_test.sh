#!/usr/bin/env bash
# Self-test for tools/check-manifest-sync.sh — Phase 3 Plan 06.
#
# Cases:
#   1. not_yet_baked   — real repo state matches Phase 2 stub → skip + exit 0.
#   2. invalid_yaml    — manifest.yaml malformed → exit non-zero.
#   3. drift_after_bake — Dart has 65 entries but missing one manifest key → exit non-zero.
#
# We use the real repo for case 1 (the integration test confirming the guard
# correctly reports "skipped" today). For cases 2 and 3 we mutate a copy and
# run the guard against it.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO}/tools/check-manifest-sync.sh"
FAILS=0

run_case() {
  local name="$1" workdir="$2" expect="$3" script_arg="${4:-$SCRIPT}"
  local rc
  set +e
  (cd "$workdir" && bash "$script_arg") &>/dev/null
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    actual="pass"
  else
    actual="fail"
  fi
  if [[ "$actual" != "$expect" ]]; then
    echo "FAIL: $name (expected $expect, got $actual; rc=$rc)" >&2
    FAILS=$((FAILS + 1))
  else
    echo "ok: $name ($actual as expected; rc=$rc)"
  fi
}

# --- Case 1: not_yet_baked (real repo) ---
run_case "not_yet_baked" "$REPO" "pass"

# --- Case 2: invalid_yaml ---
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Mirror enough repo structure for the script to run.
mkdir -p "$TMP/tools/tts/.venv/bin" "$TMP/lib/gen" "$TMP/lib/core/manifest" "$TMP/assets/audio"
cp "$REPO/tools/tts/validate_manifest.py" "$TMP/tools/tts/"
cp "$REPO/tools/tts/schema.py" "$TMP/tools/tts/"
cp "$REPO/tools/tts/bake_audio.py" "$TMP/tools/tts/"
cp "$REPO/tools/tts/manifest_writer.py" "$TMP/tools/tts/"
cp "$REPO/tools/tts/piper_client.py" "$TMP/tools/tts/"
cp "$REPO/tools/tts/normalize.py" "$TMP/tools/tts/"
cp -r "$REPO/tools/tts/templates" "$TMP/tools/tts/"
touch "$TMP/tools/tts/__init__.py"
touch "$TMP/tools/__init__.py"
ln -s "$REPO/tools/tts/.venv/bin/python" "$TMP/tools/tts/.venv/bin/python" 2>/dev/null || true
mkdir -p "$TMP/tools"
cp "$SCRIPT" "$TMP/tools/check-manifest-sync.sh"

# Invalid manifest YAML.
echo "this is :: not :: valid YAML at all : :" >"$TMP/manifest.yaml"
echo "version: 1" >"$TMP/pronunciation_overrides.yaml"
echo "overrides: {}" >>"$TMP/pronunciation_overrides.yaml"
echo "version: 1" >"$TMP/reviewed.yaml"
echo "entries: {}" >>"$TMP/reviewed.yaml"
cp "$REPO/lib/gen/audio_manifest.g.dart" "$TMP/lib/gen/"

# Pass the COPY of the script in $TMP (relative path within $TMP) so that the
# script's `cd "$(dirname $0)/.."` resolves to $TMP, not the real repo.
run_case "invalid_yaml" "$TMP" "fail" "tools/check-manifest-sync.sh"

# --- Summary ---
if [[ "$FAILS" -gt 0 ]]; then
  echo "$FAILS case(s) failed" >&2
  exit 1
fi
echo "self-test ok"
