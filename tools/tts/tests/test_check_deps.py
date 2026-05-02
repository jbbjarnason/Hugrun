"""Tests for tools/tts/check_deps.py — Phase 3 Plan 01 dependency verifier (D-29).

Tests use mocking so they do NOT require ffmpeg / ffmpeg-normalize / Tiro to be installed.
The live machine verification is done by running `python tools/tts/check_deps.py` outside pytest.
"""
from __future__ import annotations

import json
import sys
from io import StringIO
from unittest import mock


def test_module_imports():
    """Test 1: import succeeds."""
    from tools.tts.check_deps import (  # noqa: F401
        check_binaries,
        check_python_modules,
        check_env_vars,
        main,
    )


def test_check_binaries_returns_results_per_binary():
    """Test 2: check_binaries returns one CheckResult per binary with the documented fields."""
    from tools.tts.check_deps import check_binaries

    fake_completed = mock.MagicMock(returncode=0, stdout="ffmpeg version 8.1\n", stderr="")

    def which_side(name):
        return f"/opt/homebrew/bin/{name}" if name in {"ffmpeg", "ffmpeg-normalize", "python3"} else None

    with mock.patch("shutil.which", side_effect=which_side), \
         mock.patch("subprocess.run", return_value=fake_completed):
        results = check_binaries(["ffmpeg", "ffmpeg-normalize", "python3"])

    assert len(results) == 3
    for r in results:
        assert hasattr(r, "ok")
        assert hasattr(r, "found_path")
        assert hasattr(r, "version")
        assert hasattr(r, "message")
        assert r.ok is True
        assert r.found_path is not None
        assert r.version is not None


def test_check_binaries_missing_binary_reports_not_ok():
    """Test 2b: a missing binary surfaces ok=False with a hint message."""
    from tools.tts.check_deps import check_binaries

    with mock.patch("shutil.which", return_value=None):
        results = check_binaries(["definitely-not-a-real-binary-xyz"])

    assert len(results) == 1
    r = results[0]
    assert r.ok is False
    assert r.found_path is None
    assert "not found" in r.message.lower() or "missing" in r.message.lower()


def test_check_python_modules_present():
    """Test 3a: present modules report ok=True."""
    from tools.tts.check_deps import check_python_modules

    # `sys` is in the stdlib — always present.
    results = check_python_modules(["sys"])
    assert len(results) == 1
    assert results[0].ok is True


def test_check_python_modules_missing_emits_pip_hint():
    """Test 3b: missing modules surface a pip install hint."""
    from tools.tts.check_deps import check_python_modules

    results = check_python_modules(["definitely_not_a_real_module_xyz_99"])
    assert len(results) == 1
    r = results[0]
    assert r.ok is False
    assert "pip install" in r.message.lower()


def test_check_env_vars_optional_missing_does_not_fail():
    """Test 4: optional env var absence does not fail the run; presence is reported."""
    from tools.tts.check_deps import check_env_vars

    # remove the env var if it exists for this test
    with mock.patch.dict("os.environ", {}, clear=False):
        # explicitly unset
        import os
        os.environ.pop("DEFINITELY_NOT_SET_VAR_XYZ", None)
        results = check_env_vars(["DEFINITELY_NOT_SET_VAR_XYZ"], required=False)

    assert len(results) == 1
    r = results[0]
    # not required + not set → ok=True (reports presence/absence informationally).
    assert r.ok is True
    assert "not set" in r.message.lower() or "absent" in r.message.lower()


def test_check_env_vars_required_missing_fails():
    """Test 4b: a required env var that is missing surfaces ok=False."""
    from tools.tts.check_deps import check_env_vars
    import os

    with mock.patch.dict("os.environ", {}, clear=False):
        os.environ.pop("REQUIRED_VAR_XYZ", None)
        results = check_env_vars(["REQUIRED_VAR_XYZ"], required=True)

    assert results[0].ok is False


def test_main_check_deps_exits_zero_when_all_green():
    """Test 5: main(--check-deps) exits 0 only when every check passes."""
    from tools.tts.check_deps import main

    fake_completed = mock.MagicMock(returncode=0, stdout="ffmpeg version 8.1\n", stderr="")

    def which_side(name):
        return f"/opt/homebrew/bin/{name}"

    with mock.patch("shutil.which", side_effect=which_side), \
         mock.patch("subprocess.run", return_value=fake_completed), \
         mock.patch.object(sys, "stdout", new_callable=StringIO):
        rc = main(argv=["--check-deps"])
    assert rc == 0


def test_main_check_deps_nonzero_on_missing_binary():
    """Test 5b: main exits non-zero when a required binary is missing."""
    from tools.tts.check_deps import main

    with mock.patch("shutil.which", return_value=None), \
         mock.patch.object(sys, "stdout", new_callable=StringIO), \
         mock.patch.object(sys, "stderr", new_callable=StringIO):
        rc = main(argv=["--check-deps"])
    assert rc != 0


def test_check_piper_voice_present():
    """Test 7 (Piper migration 2026-05-02): check_piper_voice reports ok when both
    .onnx and .onnx.json exist with non-zero size."""
    from tools.tts.check_deps import check_piper_voice
    from pathlib import Path
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        d = Path(tmp)
        onnx = d / "is_IS-steinn-medium.onnx"
        cfg = d / "is_IS-steinn-medium.onnx.json"
        # Write fake but non-empty content (50 MB threshold from setup_voice.sh
        # is what *download* uses; check_piper_voice uses presence + non-empty).
        onnx.write_bytes(b"x" * 1024)
        cfg.write_text("{}")
        results = check_piper_voice(d)

    assert len(results) >= 1
    assert all(r.ok for r in results)


def test_check_piper_voice_missing_files():
    """Test 7b: check_piper_voice surfaces ok=False with an actionable hint when
    voice files are missing (suggests `bash tools/tts/setup_voice.sh`)."""
    from tools.tts.check_deps import check_piper_voice
    from pathlib import Path
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        d = Path(tmp)
        # Empty directory — both files absent.
        results = check_piper_voice(d)

    assert any(not r.ok for r in results)
    msgs = " ".join(r.message for r in results).lower()
    assert "setup_voice.sh" in msgs or "is_is-steinn-medium" in msgs


def test_main_includes_piper_in_required_binaries():
    """Test 7c: main() now checks `piper` as one of REQUIRED_BINARIES."""
    from tools.tts import check_deps

    assert "piper" in check_deps.REQUIRED_BINARIES


def test_main_json_emits_single_line_json():
    """Test 6: main(--json) emits a single-line JSON document with all CheckResults."""
    from tools.tts.check_deps import main

    fake_completed = mock.MagicMock(returncode=0, stdout="ffmpeg version 8.1\n", stderr="")

    def which_side(name):
        return f"/opt/homebrew/bin/{name}"

    captured = StringIO()
    with mock.patch("shutil.which", side_effect=which_side), \
         mock.patch("subprocess.run", return_value=fake_completed), \
         mock.patch.object(sys, "stdout", captured):
        rc = main(argv=["--json"])

    assert rc == 0
    out = captured.getvalue().strip()
    # Single-line JSON.
    assert "\n" not in out.rstrip("\n")
    parsed = json.loads(out)
    # Some structure — must include keys for binaries / modules / env_vars.
    assert isinstance(parsed, dict)
    assert "binaries" in parsed
    assert "python_modules" in parsed
    assert "env_vars" in parsed
