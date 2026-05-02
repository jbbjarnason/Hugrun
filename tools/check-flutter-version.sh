#!/usr/bin/env bash
# Soft check: warn (do not fail) when local Flutter doesn't match .fvmrc.
# Per CONTEXT D-15 — guides user toward installing fvm without blocking work.
set -uo pipefail  # NOT -e: we want to keep going on flutter --version failures

if [[ ! -f .fvmrc ]]; then
  echo "WARN: .fvmrc not found; skipping Flutter version check" >&2
  exit 0
fi

PINNED="$(grep -oE '"flutter":\s*"[^"]+"' .fvmrc | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [[ -z "$PINNED" ]]; then
  echo "WARN: .fvmrc has no parseable Flutter version" >&2
  exit 0
fi

LOCAL="$(flutter --version 2>/dev/null | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | head -n1 | awk '{print $2}')"
if [[ -z "$LOCAL" ]]; then
  echo "WARN: cannot detect local Flutter version (is fvm/flutter on PATH?)" >&2
  exit 0
fi

if [[ "$LOCAL" != "$PINNED" ]]; then
  echo "WARN: Flutter version drift — .fvmrc pins $PINNED, local is $LOCAL" >&2
  echo "      Install fvm and run 'fvm use $PINNED' to align." >&2
else
  echo "tools/check-flutter-version.sh: Flutter $LOCAL matches .fvmrc"
fi
exit 0  # never fail
