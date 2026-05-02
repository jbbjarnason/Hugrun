#!/usr/bin/env bash
# Self-test for tools/check-no-tracking.sh.
# Runs in CI as part of the analyze-and-test job.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-no-tracking.sh"
FAILS=0

run_case() {
  local name="$1"
  local fixture="$2"
  local expect="$3"  # 'pass' or 'fail'
  local tmp; tmp="$(mktemp -d)"
  printf '%b' "$fixture" > "$tmp/pubspec.lock"
  if (cd "$tmp" && bash "$SCRIPT") &>/dev/null; then
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

run_case "clean lock passes" \
  'packages:\n  flutter:\n    dependency: "direct main"\n    version: "0.0.0"\n' "pass"

for pkg in firebase_analytics firebase_crashlytics sentry_flutter \
           mixpanel_flutter amplitude_flutter google_mobile_ads \
           in_app_purchase app_tracking_transparency \
           flutter_facebook_audience_network; do
  run_case "detects $pkg" \
    "packages:\n  ${pkg}:\n    version: \"1.0.0\"\n" "fail"
done

if [[ "$FAILS" -gt 0 ]]; then
  echo "SELF-TEST FAILED: $FAILS case(s) failed" >&2
  exit 1
fi
echo "self-test ok"
