"""Tests for tools/tts/tiro_spike.py — Plan 01 Task 2.

Live Tiro call is performed manually outside pytest. These tests use mocks to
verify the script's logic (build_request, parse_response, retry/backoff, error
surfacing).
"""
from __future__ import annotations

import io
import sys
from unittest import mock

import pytest


def test_module_imports():
    """Test 1: import succeeds; build_request exists."""
    from tools.tts.tiro_spike import build_request  # noqa: F401


def test_build_request_minimal():
    """Test 2: build_request returns a JSON-serializable dict with the documented Tiro fields."""
    from tools.tts.tiro_spike import build_request

    body = build_request("halló", "Diljá v2", "pcm")
    assert isinstance(body, dict)
    assert body.get("Text") == "halló"
    assert body.get("VoiceId") == "Diljá v2"
    assert body.get("OutputFormat") == "pcm"


def test_build_request_with_sample_rate():
    """Test 2b: SampleRate may be supplied."""
    from tools.tts.tiro_spike import build_request

    body = build_request("halló", "Diljá v2", "pcm", sample_rate=22050)
    assert body.get("SampleRate") in (22050, "22050")


def test_parse_response_wav():
    """Test 3a: WAV content-type returns ('wav', body)."""
    from tools.tts.tiro_spike import parse_response

    fmt, audio = parse_response("audio/wav", b"RIFF1234WAVE...")
    assert fmt == "wav"
    assert audio == b"RIFF1234WAVE..."


def test_parse_response_xwav():
    """Test 3b: audio/x-wav also returns 'wav'."""
    from tools.tts.tiro_spike import parse_response

    fmt, _ = parse_response("audio/x-wav", b"RIFF...")
    assert fmt == "wav"


def test_parse_response_pcm():
    """Test 3c: raw PCM (audio/L16 or octet-stream) returns 'pcm'."""
    from tools.tts.tiro_spike import parse_response

    fmt, _ = parse_response("audio/L16", b"\x00\x00\x01\x00")
    assert fmt == "pcm"
    fmt, _ = parse_response("application/octet-stream", b"\x00\x00\x01\x00")
    assert fmt == "pcm"


def test_parse_response_mp3():
    """Test 3d: MP3 content-type returns 'mp3'."""
    from tools.tts.tiro_spike import parse_response

    fmt, _ = parse_response("audio/mpeg", b"ID3...")
    assert fmt == "mp3"


def test_parse_response_unknown_raises():
    """Test 3e: unknown content-type raises UnsupportedTiroResponseError."""
    from tools.tts.tiro_spike import parse_response, UnsupportedTiroResponseError

    with pytest.raises(UnsupportedTiroResponseError):
        parse_response("application/json", b'{"error": "..."}')


def test_main_mocked_200(tmp_path, monkeypatch):
    """Test 4: a mocked 200 response writes the audio bytes to _raw/."""
    from tools.tts import tiro_spike

    fake_response = mock.MagicMock()
    fake_response.status_code = 200
    fake_response.headers = {"content-type": "audio/wav"}
    fake_response.content = b"RIFF" + b"\x00" * 100  # fake WAV

    with mock.patch("tools.tts.tiro_spike.requests.post", return_value=fake_response), \
         mock.patch.object(tiro_spike, "RAW_DIR", tmp_path):
        rc = tiro_spike.main(argv=["--text", "halló", "--voice", "Diljá v2", "--format", "wav"])

    assert rc == 0
    files = list(tmp_path.glob("spike-*.wav"))
    assert len(files) == 1
    assert files[0].read_bytes().startswith(b"RIFF")


def test_main_mocked_401_exits_nonzero(tmp_path, monkeypatch):
    """Test 5: a 401 response surfaces the auth error and exits non-zero."""
    from tools.tts import tiro_spike

    fake_response = mock.MagicMock()
    fake_response.status_code = 401
    fake_response.headers = {}
    fake_response.text = "Unauthorized"
    fake_response.content = b"Unauthorized"

    captured_err = io.StringIO()
    with mock.patch("tools.tts.tiro_spike.requests.post", return_value=fake_response), \
         mock.patch.object(tiro_spike, "RAW_DIR", tmp_path), \
         mock.patch.object(sys, "stderr", captured_err):
        rc = tiro_spike.main(argv=["--text", "halló", "--voice", "Diljá v2", "--format", "wav"])

    assert rc != 0
    err = captured_err.getvalue()
    assert "TIRO_API_KEY" in err or "401" in err


def test_main_mocked_429_retries_with_backoff(tmp_path, monkeypatch):
    """Test 6: 429 triggers retries with exponential backoff."""
    from tools.tts import tiro_spike

    # First two responses 429; third 200.
    r429 = mock.MagicMock(status_code=429, headers={"Retry-After": "1"}, content=b"")
    r200 = mock.MagicMock(status_code=200, headers={"content-type": "audio/wav"}, content=b"RIFF" + b"\x00" * 100)
    seq = [r429, r429, r200]

    sleep_calls: list[float] = []

    def fake_sleep(s):
        sleep_calls.append(s)

    def fake_post(*args, **kwargs):
        return seq.pop(0)

    with mock.patch("tools.tts.tiro_spike.requests.post", side_effect=fake_post), \
         mock.patch("tools.tts.tiro_spike.time.sleep", side_effect=fake_sleep), \
         mock.patch.object(tiro_spike, "RAW_DIR", tmp_path):
        rc = tiro_spike.main(argv=["--text", "halló", "--voice", "Diljá v2", "--format", "wav"])

    assert rc == 0
    # at least 2 sleep calls (one per 429), with monotonically non-decreasing values.
    assert len(sleep_calls) >= 2
    assert sleep_calls[1] >= sleep_calls[0]
