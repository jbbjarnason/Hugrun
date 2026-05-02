"""Tests for tools/tts/piper_spike.py — Piper migration verification (D-06).

Tests are mocked so they do NOT require Piper to be installed or the Steinn
voice file present. Live verification happens by running
`python -m tools.tts.piper_spike --text 'halló'` outside pytest.
"""
from __future__ import annotations

import io
import subprocess
import sys
from pathlib import Path
from unittest import mock

import pytest


def test_module_imports():
    """Test 1: import succeeds."""
    from tools.tts.piper_spike import (  # noqa: F401
        synthesize,
        build_piper_argv,
        main,
        PiperSpikeError,
        VoiceModelMissingError,
    )


def test_build_piper_argv_default():
    """Test 2: build_piper_argv(model, output_file) → list with --model + --output_file."""
    from tools.tts.piper_spike import build_piper_argv

    argv = build_piper_argv(Path("voices/is_IS-steinn-medium.onnx"), Path("/tmp/out.wav"))

    assert argv[0] == "piper"
    assert "--model" in argv
    assert str(Path("voices/is_IS-steinn-medium.onnx")) in argv
    assert "--output_file" in argv or "--output-file" in argv
    assert str(Path("/tmp/out.wav")) in argv


def test_build_piper_argv_with_length_scale():
    """Test 3: optional length_scale + noise_scale are passed through (D-13/D-15)."""
    from tools.tts.piper_spike import build_piper_argv

    argv = build_piper_argv(
        Path("voices/m.onnx"),
        Path("/tmp/o.wav"),
        length_scale=1.1,
        noise_scale=0.667,
    )

    assert "--length-scale" in argv or "--length_scale" in argv
    assert "1.1" in argv
    assert "--noise-scale" in argv or "--noise_scale" in argv
    assert "0.667" in argv


def test_synthesize_invokes_piper_subprocess(tmp_path):
    """Test 4: synthesize() calls subprocess.run with piper argv and writes to output."""
    from tools.tts.piper_spike import synthesize

    out = tmp_path / "out.wav"
    voice = tmp_path / "voice.onnx"
    voice.write_bytes(b"fake-onnx" * 10)
    cfg = tmp_path / "voice.onnx.json"
    cfg.write_text("{}")

    fake_completed = mock.MagicMock(returncode=0, stdout=b"", stderr=b"")

    def fake_run(argv, **kwargs):
        # Simulate piper writing the WAV file.
        # Find --output_file or --output-file in argv and write a fake WAV header.
        out_path = None
        for i, a in enumerate(argv):
            if a in ("--output_file", "--output-file"):
                out_path = Path(argv[i + 1])
                break
        if out_path is not None:
            # 44-byte RIFF/WAVE header + minimal PCM body.
            out_path.write_bytes(b"RIFF" + (b"\x00" * 40) + b"data" + b"\x00\x00\x00\x00")
        return fake_completed

    with mock.patch("subprocess.run", side_effect=fake_run) as mocked:
        result = synthesize(
            text="halló",
            voice_model=voice,
            output_path=out,
        )

    assert mocked.called
    assert out.exists()
    assert out.stat().st_size > 0
    assert result.output_path == out
    assert result.text == "halló"


def test_synthesize_raises_on_missing_voice(tmp_path):
    """Test 5: synthesize() raises VoiceModelMissingError when voice ONNX is absent."""
    from tools.tts.piper_spike import synthesize, VoiceModelMissingError

    out = tmp_path / "out.wav"
    missing_voice = tmp_path / "does_not_exist.onnx"

    with pytest.raises(VoiceModelMissingError) as exc_info:
        synthesize(text="halló", voice_model=missing_voice, output_path=out)

    assert "setup_voice.sh" in str(exc_info.value).lower() or "missing" in str(exc_info.value).lower()


def test_synthesize_raises_on_piper_nonzero_exit(tmp_path):
    """Test 6: piper exits non-zero → PiperSpikeError surfaced with stderr context."""
    from tools.tts.piper_spike import synthesize, PiperSpikeError

    voice = tmp_path / "voice.onnx"
    voice.write_bytes(b"fake")
    cfg = tmp_path / "voice.onnx.json"
    cfg.write_text("{}")
    out = tmp_path / "out.wav"

    def fake_run(*args, **kwargs):
        raise subprocess.CalledProcessError(
            returncode=1,
            cmd=args[0] if args else [],
            stderr=b"piper: model not loaded",
        )

    with mock.patch("subprocess.run", side_effect=fake_run):
        with pytest.raises(PiperSpikeError) as exc_info:
            synthesize(text="halló", voice_model=voice, output_path=out)

    assert "model not loaded" in str(exc_info.value).lower() or "exited" in str(exc_info.value).lower()


def test_synthesize_writes_text_via_stdin(tmp_path):
    """Test 7: piper receives the synthesis text via stdin (not as an argv flag),
    and the text is encoded as UTF-8 (Icelandic diacritics preserved)."""
    from tools.tts.piper_spike import synthesize

    voice = tmp_path / "voice.onnx"
    voice.write_bytes(b"fake")
    cfg = tmp_path / "voice.onnx.json"
    cfg.write_text("{}")
    out = tmp_path / "out.wav"

    captured_input: dict = {}

    def fake_run(argv, **kwargs):
        captured_input["input"] = kwargs.get("input")
        captured_input["argv"] = argv
        # Simulate write.
        out_path = None
        for i, a in enumerate(argv):
            if a in ("--output_file", "--output-file"):
                out_path = Path(argv[i + 1])
                break
        if out_path is not None:
            out_path.write_bytes(b"RIFF\x00\x00\x00\x00WAVE")
        return mock.MagicMock(returncode=0, stdout=b"", stderr=b"")

    with mock.patch("subprocess.run", side_effect=fake_run):
        synthesize(text="eð, þorn, æ, ö", voice_model=voice, output_path=out)

    raw = captured_input["input"]
    assert raw is not None
    if isinstance(raw, bytes):
        assert "eð".encode("utf-8") in raw
        assert "þorn".encode("utf-8") in raw
    else:
        assert "eð" in raw
        assert "þorn" in raw


def test_main_dry_run_lists_missing_voice(tmp_path):
    """Test 8: main() with explicit --voice path that does not exist surfaces a
    helpful pointer to setup_voice.sh and exits non-zero."""
    from tools.tts.piper_spike import main

    missing = tmp_path / "missing.onnx"
    out = tmp_path / "out.wav"
    captured = io.StringIO()

    with mock.patch.object(sys, "stderr", captured):
        rc = main(
            argv=[
                "--text",
                "halló",
                "--voice",
                str(missing),
                "--output",
                str(out),
            ]
        )

    assert rc != 0
    msg = captured.getvalue().lower()
    assert "missing" in msg or "setup_voice.sh" in msg


def test_main_happy_path(tmp_path):
    """Test 9: main() invokes synthesize() and exits 0 on success."""
    from tools.tts.piper_spike import main

    voice = tmp_path / "voice.onnx"
    voice.write_bytes(b"fake")
    out = tmp_path / "out.wav"

    def fake_run(argv, **kwargs):
        out_p = None
        for i, a in enumerate(argv):
            if a in ("--output_file", "--output-file"):
                out_p = Path(argv[i + 1])
                break
        if out_p is not None:
            out_p.write_bytes(b"RIFF\x00\x00\x00\x00WAVE")
        return mock.MagicMock(returncode=0, stdout=b"", stderr=b"")

    with mock.patch("subprocess.run", side_effect=fake_run), \
         mock.patch.object(sys, "stdout", io.StringIO()):
        rc = main(
            argv=[
                "--text",
                "halló Hugrún",
                "--voice",
                str(voice),
                "--output",
                str(out),
            ]
        )

    assert rc == 0
    assert out.exists()
    assert out.stat().st_size > 0
