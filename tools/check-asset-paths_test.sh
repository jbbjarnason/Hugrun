#!/usr/bin/env bash
# Self-test for tools/check-asset-paths.sh.
# Runs in CI as part of the analyze-and-test job.
#
# Exercises the script against bad fixtures (each one of the 5 D-07
# violations: uppercase letter, non-ASCII bytes, space, non-ASCII bytes,
# uppercase directory name) and good fixtures (lowercase ASCII paths).
#
# Source of truth: 02-CONTEXT.md D-06 (path naming rules) and D-07 (self-test
# fixtures + CI wiring).
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-asset-paths.sh"
FIXTURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-fixtures"
BAD_DIR="$FIXTURES_DIR/bad-asset-paths"
GOOD_DIR="$FIXTURES_DIR/good-asset-paths"

FAILS=0

# run_case <name> <fixture-dir> <expect: pass|fail>
# Copies the fixture-dir into a tmpdir, runs the script against it, asserts
# pass/fail. Tmpdir-copy isolates each case so errors in one don't pollute
# another (and matches the check-no-tracking_test.sh pattern).
run_case() {
  local name="$1"
  local fixture="$2"
  local expect="$3"

  local tmp
  tmp="$(mktemp -d)"

  if [[ -d "$fixture" ]]; then
    # Copy fixture contents (including hidden files like .gitkeep) into tmpdir.
    cp -R "$fixture/." "$tmp/"
  fi

  if (bash "$SCRIPT" "$tmp") &>/dev/null; then
    if [[ "$expect" != "pass" ]]; then
      echo "FAIL: $name (expected fail, got pass)" >&2
      FAILS=$((FAILS + 1))
    fi
  else
    if [[ "$expect" != "fail" ]]; then
      echo "FAIL: $name (expected pass, got fail)" >&2
      FAILS=$((FAILS + 1))
    fi
  fi
  rm -rf "$tmp"
}

# run_single_bad_case <name> <bad-filename>
# Copies a SINGLE bad fixture file into an empty tmpdir so we attribute
# failures per-fixture. The fixture filename comes from BAD_DIR.
run_single_bad_case() {
  local name="$1"
  local relpath="$2"

  local tmp
  tmp="$(mktemp -d)"

  # Reproduce the path component (preserving subdirs like UPPER/).
  local dir_part
  dir_part="$(dirname "$relpath")"
  if [[ "$dir_part" != "." ]]; then
    mkdir -p "$tmp/$dir_part"
  fi
  cp "$BAD_DIR/$relpath" "$tmp/$relpath"

  if (bash "$SCRIPT" "$tmp") &>/dev/null; then
    echo "FAIL: $name (bad fixture '$relpath' should have failed but passed)" >&2
    FAILS=$((FAILS + 1))
  fi
  rm -rf "$tmp"
}

# 1. Each of the 5 D-07 bad fixtures, isolated, must trigger failure.
run_single_bad_case "uppercase-letter (Foo.aac)"        "Foo.aac"
run_single_bad_case "non-ASCII (þrír.aac)"              "þrír.aac"
run_single_bad_case "space (with space.aac)"            "with space.aac"
run_single_bad_case "non-ASCII (áli.aac)"               "áli.aac"
run_single_bad_case "uppercase-directory (UPPER/lower.aac)" "UPPER/lower.aac"

# 2. The whole bad-fixture directory must also fail (sanity).
run_case "all bad fixtures together" "$BAD_DIR" "fail"

# 3. The good-fixture directory must pass.
run_case "good fixtures (lowercase ASCII paths)" "$GOOD_DIR" "pass"

# 4. An empty asset directory must pass.
EMPTY_TMP="$(mktemp -d)"
run_case "empty asset directory" "$EMPTY_TMP" "pass"
rm -rf "$EMPTY_TMP"

if [[ "$FAILS" -gt 0 ]]; then
  echo "SELF-TEST FAILED: $FAILS case(s) failed" >&2
  exit 1
fi
echo "self-test ok"
