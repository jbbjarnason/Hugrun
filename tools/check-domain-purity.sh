#!/usr/bin/env bash
# CI guard: domain-layer purity. No file under listed domain paths may import
# package:flutter — domain is pure Dart per CONTEXT D-08.
# Block-list of paths declared here; future paths added as the domain grows.
set -euo pipefail

DOMAIN_PATHS=(
  "lib/core/db/tables"      # Drift table definitions are pure-Dart
  "lib/core/parent_gate"    # ParentGateController must stay pure-Dart;
                            # parent_gate.dart is a widget — see EXCEPTIONS below
  "lib/core/alphabet"       # Phase 2 Plan 01: IcelandicLetter + kIcelandicAlphabet
  "lib/core/manifest"       # Phase 2 Plan 02: UtteranceKey + AudioAsset (audio manifest contract types)
  "lib/core/matching"       # Phase 5 Plan 01: MatchingRound + RoundGenerator (pure-Dart round logic, D-05)
  "lib/core/cvc"            # Phase 6 Plan 02: CvcWord + kCvcWords + phoneme_resolver (pure-Dart CVC domain, D-06)
  "lib/core/numbers"        # Phase 8 Plan 01: IcelandicNumber + kIcelandicNumbers + number_audio_resolver (pure-Dart number domain, D-04)
  # When Phase 4 adds lib/domain/, append it here.
)

# Files within DOMAIN_PATHS that are widgets (allowed to import package:flutter).
# Add to this list when introducing widgets inside domain folders.
EXCEPTIONS=(
  "lib/core/parent_gate/parent_gate.dart"
)

is_exception() {
  local f="$1"
  for ex in "${EXCEPTIONS[@]}"; do
    [[ "$f" == "$ex" ]] && return 0
  done
  return 1
}

FAIL=0
for dir in "${DOMAIN_PATHS[@]}"; do
  if [[ ! -d "$dir" ]]; then continue; fi
  while IFS= read -r -d '' f; do
    # Skip generated files.
    if [[ "$f" == *.g.dart ]] || [[ "$f" == *.freezed.dart ]] || [[ "$f" == *.steps.dart ]]; then
      continue
    fi
    if is_exception "$f"; then continue; fi
    if grep -E "^[[:space:]]*import[[:space:]]+'package:flutter/" "$f" >/dev/null 2>&1; then
      echo "DOMAIN PURITY VIOLATION: $f imports package:flutter" >&2
      echo "  Per CONTEXT D-08, domain layer files must be pure Dart." >&2
      FAIL=1
    fi
  done < <(find "$dir" -name '*.dart' -print0)
done

if [[ "$FAIL" -eq 1 ]]; then
  echo "" >&2
  echo "Build failed: domain-layer files import Flutter (D-08)." >&2
  exit 1
fi
echo "tools/check-domain-purity.sh: domain layer is Flutter-free"
