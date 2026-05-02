"""Tests for tools/tts/piper_client.py — Plan 03 Piper synthesis client.

All tests mock subprocess.run so they don't require Piper or the voice model.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from unittest import mock

import pytest


def _voice_path(tmp_path: Path) -> Path:
    p = tmp_path / "voices" / "is_IS-steinn-medium.onnx"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(b"fake-onnx" * 100)
    return p


def _entry(**kwargs):
    base = {
        "key": "letterA",
        "text": "a",
        "asset": "assets/audio/letters/names/a.aac",
        "kind": "letter_name",
    }
    base.update(kwargs)
    return base


def _fake_run_writes_wav(argv, **kwargs):
    out_path = None
    for i, a in enumerate(argv):
        if a in ("--output_file", "--output-file"):
            out_path = Path(argv[i + 1])
            break
    if out_path is not None:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_bytes(b"RIFF" + (b"\x00" * 40) + b"WAVE" + b"data" + b"\x00\x00\x00\x00")
    return mock.MagicMock(returncode=0, stdout=b"", stderr=b"")


def test_module_imports():
    from tools.tts.piper_client import (  # noqa: F401
        PiperClient,
        SynthesisResult,
        PiperError,
        PiperVoiceMissingError,
        _resolve_text_voice,
        _fingerprint,
    )


def test_resolve_text_priority_override_text(tmp_path):
    from tools.tts.piper_client import _resolve_text_voice

    entry = _entry()
    overrides = {"letterA": {"text": "ah-ah"}}
    used_text, used_voice, ls, ns = _resolve_text_voice(entry, overrides, "is_IS-steinn-medium")
    assert used_text == "ah-ah"
    assert used_voice == "is_IS-steinn-medium"


def test_resolve_text_priority_phonemes(tmp_path):
    from tools.tts.piper_client import _resolve_text_voice

    entry = _entry()
    overrides = {"letterA": {"phonemes": "[[ a ]]"}}
    used_text, *_ = _resolve_text_voice(entry, overrides, "is_IS-steinn-medium")
    assert used_text == "[[ a ]]"


def test_resolve_text_priority_default(tmp_path):
    from tools.tts.piper_client import _resolve_text_voice

    entry = _entry()
    used_text, used_voice, ls, ns = _resolve_text_voice(entry, {}, "is_IS-steinn-medium")
    assert used_text == "a"
    assert used_voice == "is_IS-steinn-medium"
    assert ls is None
    assert ns is None


def test_resolve_voice_priority_per_utterance(tmp_path):
    from tools.tts.piper_client import _resolve_text_voice

    entry = _entry(voice="is_IS-steinn-low")
    used_text, used_voice, *_ = _resolve_text_voice(entry, {}, "is_IS-steinn-medium")
    assert used_voice == "is_IS-steinn-low"


def test_resolve_length_and_noise_scale(tmp_path):
    from tools.tts.piper_client import _resolve_text_voice

    entry = _entry()
    overrides = {"letterA": {"length_scale": 1.1, "noise_scale": 0.5}}
    _, _, ls, ns = _resolve_text_voice(entry, overrides, "is_IS-steinn-medium")
    assert ls == 1.1
    assert ns == 0.5


def test_synthesize_invokes_piper_and_writes_sidecar(tmp_path):
    from tools.tts.piper_client import PiperClient

    voice = _voice_path(tmp_path)
    cache_dir = tmp_path / "_raw"
    client = PiperClient(voice_model_path=voice, cache_dir=cache_dir)

    with mock.patch("subprocess.run", side_effect=_fake_run_writes_wav) as m:
        result = client.synthesize(_entry())

    assert m.called
    assert result.cached is False
    assert result.raw_path.exists()
    sidecar = json.loads((cache_dir / "letterA.meta.json").read_text())
    assert sidecar["used_text"] == "a"
    assert sidecar["used_voice"] == "is_IS-steinn-medium"
    assert sidecar["fingerprint"] == result.fingerprint


def test_synthesize_cache_hit_skips_piper(tmp_path):
    from tools.tts.piper_client import PiperClient

    voice = _voice_path(tmp_path)
    cache_dir = tmp_path / "_raw"
    client = PiperClient(voice_model_path=voice, cache_dir=cache_dir)

    # Prime cache with first call.
    with mock.patch("subprocess.run", side_effect=_fake_run_writes_wav):
        client.synthesize(_entry())

    # Second call: subprocess.run should NOT be invoked.
    with mock.patch("subprocess.run") as m:
        result = client.synthesize(_entry())
        assert not m.called
    assert result.cached is True


def test_synthesize_cache_invalidation_on_text_change(tmp_path):
    from tools.tts.piper_client import PiperClient

    voice = _voice_path(tmp_path)
    cache_dir = tmp_path / "_raw"
    client = PiperClient(voice_model_path=voice, cache_dir=cache_dir)

    with mock.patch("subprocess.run", side_effect=_fake_run_writes_wav):
        client.synthesize(_entry())

    # Override text → fingerprint mismatch → new piper call.
    overrides = {"letterA": {"text": "ah-ah"}}
    with mock.patch("subprocess.run", side_effect=_fake_run_writes_wav) as m:
        result = client.synthesize(_entry(), overrides)
        assert m.called
    assert result.cached is False
    assert result.used_text == "ah-ah"


def test_synthesize_voice_missing_raises(tmp_path):
    from tools.tts.piper_client import PiperClient, PiperVoiceMissingError

    missing_voice = tmp_path / "no.onnx"
    cache_dir = tmp_path / "_raw"
    client = PiperClient(voice_model_path=missing_voice, cache_dir=cache_dir)

    with pytest.raises(PiperVoiceMissingError) as exc_info:
        client.synthesize(_entry())
    assert "setup_voice.sh" in str(exc_info.value).lower() or "missing" in str(exc_info.value).lower()


def test_synthesize_subprocess_failure_raises_piper_error(tmp_path):
    from tools.tts.piper_client import PiperClient, PiperError

    voice = _voice_path(tmp_path)
    cache_dir = tmp_path / "_raw"
    client = PiperClient(voice_model_path=voice, cache_dir=cache_dir)

    failing = mock.MagicMock(returncode=1, stdout=b"", stderr=b"piper: model load failed")

    with mock.patch("subprocess.run", return_value=failing):
        with pytest.raises(PiperError) as exc_info:
            client.synthesize(_entry())
    assert "model load failed" in str(exc_info.value).lower() or "rc=1" in str(exc_info.value)


def test_synthesize_no_output_raises(tmp_path):
    from tools.tts.piper_client import PiperClient, PiperError

    voice = _voice_path(tmp_path)
    cache_dir = tmp_path / "_raw"
    client = PiperClient(voice_model_path=voice, cache_dir=cache_dir)

    # Subprocess succeeds but does NOT write the WAV.
    with mock.patch("subprocess.run", return_value=mock.MagicMock(returncode=0, stdout=b"", stderr=b"")):
        with pytest.raises(PiperError) as exc_info:
            client.synthesize(_entry())
    assert "did not" in str(exc_info.value).lower() or "no output" in str(exc_info.value).lower()


def test_synthesize_argv_includes_length_scale(tmp_path):
    from tools.tts.piper_client import PiperClient

    voice = _voice_path(tmp_path)
    cache_dir = tmp_path / "_raw"
    client = PiperClient(voice_model_path=voice, cache_dir=cache_dir)

    captured: dict = {}

    def capture_run(argv, **kwargs):
        captured["argv"] = argv
        captured["input"] = kwargs.get("input")
        return _fake_run_writes_wav(argv, **kwargs)

    with mock.patch("subprocess.run", side_effect=capture_run):
        client.synthesize(_entry(), {"letterA": {"length_scale": 1.2}})

    assert "--length-scale" in captured["argv"]
    assert "1.2" in captured["argv"]


def test_synthesize_text_passed_via_stdin_utf8(tmp_path):
    from tools.tts.piper_client import PiperClient

    voice = _voice_path(tmp_path)
    cache_dir = tmp_path / "_raw"
    client = PiperClient(voice_model_path=voice, cache_dir=cache_dir)

    captured: dict = {}

    def capture_run(argv, **kwargs):
        captured["input"] = kwargs.get("input")
        return _fake_run_writes_wav(argv, **kwargs)

    entry = _entry(key="letterEth", text="eð")
    with mock.patch("subprocess.run", side_effect=capture_run):
        client.synthesize(entry)

    assert captured["input"] == "eð".encode("utf-8")
