"""tools/tts/validate_manifest.py — Plan 02 CLI validator.

Usage:
  python tools/tts/validate_manifest.py
    Validates manifest.yaml + pronunciation_overrides.yaml + reviewed.yaml
    at the repo root. Exits 0 on success, 1 on any validation failure.

  python tools/tts/validate_manifest.py path/to/file.yaml
    Validates one file (auto-detected by filename).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# When invoked as `python tools/tts/validate_manifest.py`, the repo root needs
# to be on sys.path so `tools.tts.schema` resolves.
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

import yaml  # noqa: E402

from tools.tts.schema import (  # noqa: E402
    validate_manifest,
    validate_overrides,
    validate_reviewed,
)

REPO_ROOT_FILES = (
    ("manifest.yaml", validate_manifest),
    ("pronunciation_overrides.yaml", validate_overrides),
    ("reviewed.yaml", validate_reviewed),
)


def _detect_validator(filename: str):
    name = Path(filename).name
    if "manifest" in name and "audio" not in name and "validate" not in name:
        return validate_manifest
    if "override" in name:
        return validate_overrides
    if "review" in name:
        return validate_reviewed
    return None


def _validate_one(path: Path, validator) -> bool:
    try:
        data = yaml.safe_load(path.read_text())
    except Exception as exc:
        print(f"FAIL {path}: invalid YAML — {exc}", file=sys.stderr)
        return False

    result = validator(data)
    if result.ok:
        print(f"ok {path}")
        return True
    print(f"FAIL {path}:", file=sys.stderr)
    for err in result.errors:
        print(f"  - {err}", file=sys.stderr)
    return False


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate Phase 3 YAML files against tools/tts/schema.py."
    )
    parser.add_argument(
        "path",
        nargs="?",
        default=None,
        help="path to one YAML file (default: validate manifest+overrides+reviewed at repo root)",
    )
    args = parser.parse_args(argv)

    if args.path:
        path = Path(args.path)
        validator = _detect_validator(args.path)
        if validator is None:
            print(
                f"FAIL {path}: cannot determine validator from filename "
                f"(expected 'manifest', 'override', or 'review')",
                file=sys.stderr,
            )
            return 1
        return 0 if _validate_one(path, validator) else 1

    # Default: validate the three repo-root files.
    repo_root = Path.cwd()
    all_ok = True
    for filename, validator in REPO_ROOT_FILES:
        full = repo_root / filename
        if not full.is_file():
            print(f"FAIL {filename}: file not found at {full}", file=sys.stderr)
            all_ok = False
            continue
        if not _validate_one(full, validator):
            all_ok = False

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
