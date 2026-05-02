#!/usr/bin/env bash
# tools/check-manifest-sync.sh — Phase 3 CI guard (D-23, D-24).
#
# Three checks:
#   (a) YAML schemas valid (D-23.1) — invokes tools/tts/validate_manifest.py.
#   (b) Phase-3-not-yet-baked carve-out — if reviewed.yaml is empty AND
#       lib/gen/audio_manifest.g.dart still matches the Phase 2 5-key stub,
#       skip with an informational message.
#   (c) lib/gen/audio_manifest.g.dart in sync (D-23.3 / D-24) — re-renders
#       the manifest_writer output via `bake_audio.py --check-sync` and
#       diffs against the committed file.
#   (d) reviewed.yaml exhaustive (D-23.2) — every manifest key has reviewed:true.
#
# Run from repo root.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."  # repo root

if [[ ! -f manifest.yaml ]]; then
  echo "skip(03-06): manifest.yaml not present"
  exit 0
fi

PYTHON="${PYTHON:-python3}"
if [[ -x tools/tts/.venv/bin/python ]]; then
  PYTHON="tools/tts/.venv/bin/python"
fi

echo "=== validate manifest/overrides/reviewed schemas ==="
"$PYTHON" tools/tts/validate_manifest.py

echo "=== check audio_manifest.g.dart in sync with manifest.yaml ==="
EXPECTED="$("$PYTHON" tools/tts/bake_audio.py --check-sync --allow-stub-baseline)"

# If --check-sync emitted a `skip(...)` line, surface it and stop.
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
"$PYTHON" - <<'PY'
import sys
import yaml

m = yaml.safe_load(open("manifest.yaml"))
r = yaml.safe_load(open("reviewed.yaml")) or {"entries": {}}
keys = {u["key"] for u in m["utterances"]}
reviewed_ok = {k for k, v in (r.get("entries") or {}).items() if v.get("reviewed") is True}
missing = sorted(keys - reviewed_ok)
if r.get("entries"):
    if missing:
        msg = f"FAIL: {len(missing)} unreviewed manifest entries: {missing[:5]}"
        if len(missing) > 5:
            msg += f"... (+{len(missing) - 5} more)"
        print(msg, file=sys.stderr)
        sys.exit(1)
PY

echo "ok: manifest sync"
