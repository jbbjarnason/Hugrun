"""tools/tts/check_deps.py — Phase 3 dependency verifier (D-29).

Verifies that:
  - ffmpeg, ffmpeg-normalize, python3 are on PATH
  - Required Python modules are importable (pyyaml, jinja2, requests, pytest)
  - TIRO_API_KEY env var is set when required (Plan 01 verifies whether this is
    actually needed via the live spike).

Usage:
  python tools/tts/check_deps.py                # human-readable; exit 0 on full pass
  python tools/tts/check_deps.py --check-deps   # alias of default
  python tools/tts/check_deps.py --json         # single-line JSON document
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass, asdict
from typing import Iterable


REQUIRED_BINARIES = ("ffmpeg", "ffmpeg-normalize", "python3", "piper")
REQUIRED_MODULES = ("yaml", "jinja2", "requests", "pytest")
# 2026-05-02 Piper migration: TIRO_API_KEY no longer required (Piper is local CLI,
# no auth, no API keys). Kept in OPTIONAL_ENV_VARS only as a soft historical hint;
# the audit-quiet behavior is unchanged.
OPTIONAL_ENV_VARS: tuple[str, ...] = ()

# Default voice directory (D-05). Override by passing a path explicitly.
DEFAULT_VOICE_DIR = "tools/tts/voices"
PIPER_VOICE_ONNX = "is_IS-steinn-medium.onnx"
PIPER_VOICE_JSON = "is_IS-steinn-medium.onnx.json"


@dataclass
class CheckResult:
    name: str
    ok: bool
    found_path: str | None = None
    version: str | None = None
    message: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


def _safe_version(binary: str, path: str) -> str | None:
    """Best-effort version capture; returns None on failure (does NOT raise).

    Tries `--version` first (the GNU convention used by python3, ffmpeg-normalize),
    then falls back to `-version` (ffmpeg's native single-dash flag).
    """
    for flag in ("--version", "-version"):
        try:
            completed = subprocess.run(
                [path, flag],
                capture_output=True,
                text=True,
                timeout=5,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            return None
        # Some tools (ffmpeg) emit on stderr; some on stdout. Either is fine.
        text = (completed.stdout or "") + (completed.stderr or "")
        first_line = text.splitlines()
        if first_line and first_line[0].strip():
            return first_line[0].strip()
        # else: try the next flag form
    return None


def check_binaries(binaries: Iterable[str]) -> list[CheckResult]:
    """Locate each binary and capture its version. Missing → ok=False with hint."""
    results: list[CheckResult] = []
    for b in binaries:
        path = shutil.which(b)
        if path is None:
            results.append(
                CheckResult(
                    name=b,
                    ok=False,
                    found_path=None,
                    version=None,
                    message=(
                        f"{b}: not found on PATH. Install via brew: `brew install {b}` "
                        f"(or `pipx install {b}` for ffmpeg-normalize)."
                    ),
                )
            )
            continue
        version = _safe_version(b, path)
        results.append(
            CheckResult(
                name=b,
                ok=True,
                found_path=path,
                version=version,
                message=f"{b}: {version or '(version unavailable)'} at {path}",
            )
        )
    return results


def check_python_modules(modules: Iterable[str]) -> list[CheckResult]:
    """Probe each Python module via importlib.util.find_spec."""
    results: list[CheckResult] = []
    for m in modules:
        spec = importlib.util.find_spec(m)
        if spec is None:
            results.append(
                CheckResult(
                    name=m,
                    ok=False,
                    message=(
                        f"{m}: missing — pip install -r tools/tts/requirements.txt"
                    ),
                )
            )
        else:
            results.append(
                CheckResult(
                    name=m,
                    ok=True,
                    found_path=getattr(spec, "origin", None),
                    message=f"{m}: importable",
                )
            )
    return results


def check_env_vars(vars_: Iterable[str], *, required: bool = False) -> list[CheckResult]:
    """Report presence/absence of env vars.

    If required=False, an absent var still reports ok=True (informational).
    If required=True, absence is a hard failure.
    """
    results: list[CheckResult] = []
    for v in vars_:
        present = v in os.environ and bool(os.environ[v])
        if present:
            results.append(
                CheckResult(
                    name=v,
                    ok=True,
                    message=f"{v}: set (value redacted)",
                )
            )
        else:
            results.append(
                CheckResult(
                    name=v,
                    ok=not required,
                    message=(
                        f"{v}: not set"
                        + (
                            " (required — see tools/tts/README.md)"
                            if required
                            else " (optional — only required if Plan 01 spike proved Tiro auth)"
                        )
                    ),
                )
            )
    return results


def check_piper_voice(voice_dir) -> list[CheckResult]:
    """Verify the Steinn voice ONNX + JSON config files are present (D-05).

    Voice files are gitignored (~76 MB ONNX); they are downloaded by
    `bash tools/tts/setup_voice.sh` on first run. This check surfaces an
    actionable error if the user skipped setup.
    """
    from pathlib import Path
    voice_dir = Path(voice_dir)
    onnx = voice_dir / PIPER_VOICE_ONNX
    cfg = voice_dir / PIPER_VOICE_JSON
    results: list[CheckResult] = []

    for label, path in (("piper-voice-onnx", onnx), ("piper-voice-config", cfg)):
        if path.is_file() and path.stat().st_size > 0:
            results.append(
                CheckResult(
                    name=label,
                    ok=True,
                    found_path=str(path),
                    version=f"{path.stat().st_size} bytes",
                    message=f"{label}: {path} ({path.stat().st_size} bytes)",
                )
            )
        else:
            results.append(
                CheckResult(
                    name=label,
                    ok=False,
                    found_path=None,
                    message=(
                        f"{label}: missing at {path}. "
                        f"Run `bash tools/tts/setup_voice.sh` to download "
                        f"{PIPER_VOICE_ONNX} from huggingface.co/rhasspy/piper-voices."
                    ),
                )
            )
    return results


def _all_ok(results: list[CheckResult]) -> bool:
    return all(r.ok for r in results)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify Phase 3 TTS pipeline dependencies (D-29)."
    )
    parser.add_argument("--check-deps", action="store_true", help="(default) verify deps")
    parser.add_argument("--json", action="store_true", help="emit single-line JSON")
    args = parser.parse_args(argv)

    binaries = check_binaries(REQUIRED_BINARIES)
    modules = check_python_modules(REQUIRED_MODULES)
    env_vars = check_env_vars(OPTIONAL_ENV_VARS, required=False)
    voice = check_piper_voice(DEFAULT_VOICE_DIR)

    payload = {
        "binaries": [r.to_dict() for r in binaries],
        "python_modules": [r.to_dict() for r in modules],
        "env_vars": [r.to_dict() for r in env_vars],
        "piper_voice": [r.to_dict() for r in voice],
    }

    if args.json:
        sys.stdout.write(json.dumps(payload, separators=(",", ":")))
        sys.stdout.write("\n")
    else:
        print("=== Phase 3 dependency check ===")
        print()
        print("Binaries:")
        for r in binaries:
            mark = "ok" if r.ok else "FAIL"
            print(f"  [{mark}] {r.message}")
        print()
        print("Python modules:")
        for r in modules:
            mark = "ok" if r.ok else "FAIL"
            print(f"  [{mark}] {r.message}")
        print()
        print("Environment:")
        for r in env_vars:
            mark = "ok" if r.ok else "FAIL"
            print(f"  [{mark}] {r.message}")
        print()
        print("Piper voice files:")
        for r in voice:
            mark = "ok" if r.ok else "FAIL"
            print(f"  [{mark}] {r.message}")
        print()
        if _all_ok(binaries) and _all_ok(modules) and _all_ok(env_vars) and _all_ok(voice):
            print("All checks passed.")
        else:
            print("One or more checks failed; see messages above.", file=sys.stderr)

    if _all_ok(binaries) and _all_ok(modules) and _all_ok(env_vars) and _all_ok(voice):
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
