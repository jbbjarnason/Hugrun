#!/usr/bin/env bash
# CI guard: fails if any banned analytics/ads/IAP SDK appears in pubspec.lock.
# Source: CONTEXT D-20. Block-list, not allow-list.
# Maps to FOUND-11 ("no analytics/ads/IAP SDKs in dep graph").
set -euo pipefail

LOCK="${1:-pubspec.lock}"
if [[ ! -f "$LOCK" ]]; then
  echo "ERROR: $LOCK not found" >&2
  exit 2
fi

BANNED=(
  firebase_analytics
  firebase_crashlytics
  sentry_flutter
  mixpanel_flutter
  amplitude_flutter
  google_mobile_ads
  in_app_purchase
  app_tracking_transparency
  flutter_facebook_audience_network
)

FOUND_ANY=0
for pkg in "${BANNED[@]}"; do
  # Match `  pkg:` at start of an indented line (pubspec.lock entry header).
  # Skip comments (lines starting with #) so this script doesn't trigger on
  # its own comment listing the banned packages, or on any future header
  # prose mentioning a banned package.
  if grep -E "^[[:space:]]+${pkg}:" "$LOCK" | grep -v '^[[:space:]]*#' >/dev/null; then
    echo "FORBIDDEN PACKAGE FOUND: $pkg" >&2
    echo "  See PROJECT.md 'no analytics/ads/IAP' constraint and CONTEXT D-20." >&2
    FOUND_ANY=1
  fi
done

if [[ "$FOUND_ANY" -eq 1 ]]; then
  echo "" >&2
  echo "Build failed: $LOCK contains banned package(s) listed above." >&2
  echo "If you have a legitimate need to add one, escalate to /gsd-discuss-phase" >&2
  echo "and update CONTEXT D-20 — do not silently bypass this check." >&2
  exit 1
fi
echo "tools/check-no-tracking.sh: $LOCK passes (no banned packages)"
