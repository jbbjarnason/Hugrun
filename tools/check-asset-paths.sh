#!/usr/bin/env bash
# CI guard: enforces D-06 asset path conventions.
# See .planning/phases/02-alphabet-asset-conventions-manifest-stub/02-CONTEXT.md
# Maps to FOUND-05 ("asset path conventions enforced by a generated asset
# manifest" — this script is the enforcement half).
#
# Rules (D-06):
#   - Lowercase only (no uppercase letters anywhere in any path component).
#   - ASCII letters [a-z], digits [0-9], underscore `_`, hyphen `-`,
#     dot `.` (extension separator) only — no diacritics, no non-ASCII bytes.
#   - No spaces in filenames or directory names.
#   - Allowed file extensions: .aac (audio), .webp / .png (raster image),
#     .svg (vector), .json (Phase 7 D-02 — MMAH-format glyph data under
#     assets/tracing/). `.gitkeep` is allowlisted. `CREDITS.md` is
#     allowlisted (Phase 11 — image provenance documentation; not a
#     runtime asset, not bundled by Flutter).
#
# PITFALL #20 motivation: macOS Simulator (case-insensitive APFS) silently
# accepts `Hundur.aac` references that fail on Linux CI / Android (case-
# sensitive). This guard turns that latent bug into a build-time failure.
set -euo pipefail

ROOT="${1:-assets/}"
if [[ ! -d "$ROOT" ]]; then
  echo "tools/check-asset-paths.sh: $ROOT does not exist (skipping)"
  exit 0
fi

ALLOWED_COMPONENT='^[a-z0-9._-]+$'
ALLOWED_EXTS=('aac' 'webp' 'png' 'svg' 'json')
FAIL=0

# Strip trailing slash from ROOT for clean relative-path math.
ROOT="${ROOT%/}"

while IFS= read -r -d '' entry; do
  # Skip the root itself.
  [[ "$entry" == "$ROOT" ]] && continue

  # Compute relative path (strip the root + leading slash).
  rel="${entry#$ROOT}"
  rel="${rel#/}"

  # Validate each path component.
  IFS='/' read -ra parts <<< "$rel"
  for c in "${parts[@]}"; do
    [[ -z "$c" ]] && continue
    # Allow .gitkeep explicitly (the only permitted dotfile).
    [[ "$c" == ".gitkeep" ]] && continue
    # Allow CREDITS.md explicitly (Phase 11 image provenance docs;
    # not a runtime asset — Flutter does not bundle .md files).
    [[ "$c" == "CREDITS.md" ]] && continue

    if [[ "$c" =~ [A-Z] ]]; then
      echo "ASSET PATH VIOLATION (uppercase): $entry" >&2
      FAIL=1
      continue
    fi
    if [[ "$c" == *' '* ]]; then
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

  # Extension check on regular files only (skip dirs and .gitkeep).
  if [[ -f "$entry" ]]; then
    base="$(basename "$entry")"
    [[ "$base" == ".gitkeep" ]] && continue
    [[ "$base" == "CREDITS.md" ]] && continue
    # Files without an extension are flagged.
    if [[ "$base" != *.* ]]; then
      echo "ASSET PATH VIOLATION (no extension): $entry" >&2
      FAIL=1
      continue
    fi
    ext="${base##*.}"
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
  echo "  No spaces. No diacritics. No uppercase. Allowed extensions: .aac, .webp, .png, .svg, .json." >&2
  exit 1
fi
echo "tools/check-asset-paths.sh: $ROOT passes (asset paths conform to D-06)"
