"""tools/tts/tiro_spike.py — one-shot Tiro TTS verification (Plan 01 Task 2, D-06).

Hits the live Tiro endpoint with a small phrase; writes the raw audio to
tools/tts/_raw/ for the human-verify checkpoint.

Usage:
  python tools/tts/tiro_spike.py
  python tools/tts/tiro_spike.py --list-voices
  python tools/tts/tiro_spike.py --text "<phrase>" --voice "<id>" --format pcm
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

import requests


BASE_URL = os.environ.get("TIRO_BASE_URL", "https://tts.tiro.is")
SYNTHESIZE_PATH = os.environ.get("TIRO_SYNTHESIZE_PATH", "/v0/speech/synthesize")
VOICES_PATH = os.environ.get("TIRO_VOICES_PATH", "/v0/voices")
RAW_DIR = Path(__file__).resolve().parent / "_raw"
DEFAULT_TEXT = "halló Hugrún"
DEFAULT_VOICE = "Diljá v2"
DEFAULT_FORMAT = "pcm"
DEFAULT_SAMPLE_RATE = 16000
DEFAULT_TIMEOUT = 30.0
MAX_RETRIES = 3
BACKOFF_BASE = 1.0


class UnsupportedTiroResponseError(Exception):
    """Raised when Tiro returns a content-type the spike doesn't recognize."""


class TiroSpikeError(Exception):
    """Generic Tiro spike error (auth, transport, etc.)."""


def build_request(
    text: str,
    voice_id: str,
    output_format: str,
    *,
    sample_rate: int = DEFAULT_SAMPLE_RATE,
    engine: str = "standard",
) -> dict:
    """Construct the Tiro synthesize request body.

    Tiro's documented field names (per research/STACK.md):
      - Text       : utterance string (raw or SSML)
      - VoiceId    : voice identifier (verbatim, including diacritics)
      - OutputFormat : pcm | wav | mp3 | ogg
      - SampleRate : optional, integer Hz
      - Engine     : optional, "standard" | "neural"
    """
    body: dict = {
        "Text": text,
        "VoiceId": voice_id,
        "OutputFormat": output_format,
        "SampleRate": sample_rate,
    }
    if engine:
        body["Engine"] = engine
    return body


def parse_response(content_type: str, body: bytes) -> tuple[str, bytes]:
    """Normalize a Tiro response to (format, audio_bytes).

    Recognized content-types:
      - audio/wav, audio/x-wav   → wav
      - audio/L16                → pcm (raw 16-bit LE samples)
      - application/octet-stream → pcm (assumed; verify against spike output)
      - audio/mpeg               → mp3
    Anything else raises UnsupportedTiroResponseError.
    """
    ct = (content_type or "").split(";")[0].strip().lower()
    if ct in {"audio/wav", "audio/x-wav"}:
        return ("wav", body)
    if ct in {"audio/l16", "audio/pcm"}:
        return ("pcm", body)
    if ct == "application/octet-stream":
        return ("pcm", body)
    if ct == "audio/mpeg":
        return ("mp3", body)
    raise UnsupportedTiroResponseError(
        f"Tiro returned unexpected content-type {content_type!r}; body[:80]={body[:80]!r}"
    )


def _post_with_retry(
    url: str,
    body: dict,
    *,
    headers: dict | None = None,
    timeout: float = DEFAULT_TIMEOUT,
    max_retries: int = MAX_RETRIES,
) -> requests.Response:
    """POST with exponential backoff on 429. Surfaces 401 immediately."""
    last_exc: Exception | None = None
    for attempt in range(max_retries + 1):
        try:
            response = requests.post(url, json=body, headers=headers or {}, timeout=timeout)
        except requests.RequestException as exc:
            last_exc = exc
            if attempt >= max_retries:
                raise TiroSpikeError(f"Network error after {attempt + 1} attempts: {exc}") from exc
            time.sleep(BACKOFF_BASE * (2 ** attempt))
            continue

        if response.status_code == 429 and attempt < max_retries:
            retry_after = response.headers.get("Retry-After")
            try:
                wait = float(retry_after) if retry_after else BACKOFF_BASE * (2 ** attempt)
            except (TypeError, ValueError):
                wait = BACKOFF_BASE * (2 ** attempt)
            time.sleep(wait)
            continue

        return response

    if last_exc is not None:
        raise TiroSpikeError(f"Exhausted retries: {last_exc}") from last_exc
    # Defensive: should not reach here.
    raise TiroSpikeError("Exhausted retries with no recorded error")


def _filename_slug(text: str) -> str:
    """Conservative slug for filename (ASCII, no punctuation)."""
    keep = []
    for ch in text:
        if ch.isalnum() and ord(ch) < 128:
            keep.append(ch)
        elif ch.isspace():
            keep.append("_")
    return "".join(keep) or "spike"


def synthesize(
    text: str,
    voice_id: str,
    output_format: str,
    *,
    base_url: str = BASE_URL,
    synthesize_path: str = SYNTHESIZE_PATH,
    api_key: str | None = None,
    timeout: float = DEFAULT_TIMEOUT,
) -> tuple[str, bytes]:
    """Issue a synthesize request; return (format, audio_bytes)."""
    body = build_request(text, voice_id, output_format)
    url = f"{base_url.rstrip('/')}{synthesize_path}"
    headers = {"content-type": "application/json"}
    if api_key:
        headers["authorization"] = f"Bearer {api_key}"

    response = _post_with_retry(url, body, headers=headers, timeout=timeout)

    if response.status_code == 401 or response.status_code == 403:
        raise TiroSpikeError(
            f"Tiro returned {response.status_code}: TIRO_API_KEY missing or rejected — "
            f"see tools/tts/README.md"
        )
    if response.status_code != 200:
        snippet = (response.text or "")[:200]
        raise TiroSpikeError(
            f"Tiro returned HTTP {response.status_code}: {snippet}"
        )

    return parse_response(response.headers.get("content-type", ""), response.content)


def list_voices(*, base_url: str = BASE_URL, voices_path: str = VOICES_PATH, timeout: float = 10.0) -> list[dict]:
    """GET the voices endpoint; return the parsed JSON list."""
    url = f"{base_url.rstrip('/')}{voices_path}"
    response = requests.get(url, timeout=timeout)
    if response.status_code != 200:
        raise TiroSpikeError(f"Tiro /voices returned HTTP {response.status_code}: {response.text[:200]}")
    return response.json()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Tiro TTS verification spike (Plan 01 Task 2, D-06).")
    parser.add_argument("--text", default=DEFAULT_TEXT, help="phrase to synthesize")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help="voice id (verbatim)")
    parser.add_argument(
        "--format",
        default=DEFAULT_FORMAT,
        choices=["pcm", "wav", "mp3", "ogg"],
        help="requested output format",
    )
    parser.add_argument("--list-voices", action="store_true", help="GET /v0/voices and print")
    parser.add_argument("--base-url", default=BASE_URL)
    parser.add_argument("--synthesize-path", default=SYNTHESIZE_PATH)
    parser.add_argument("--voices-path", default=VOICES_PATH)
    args = parser.parse_args(argv)

    api_key = os.environ.get("TIRO_API_KEY")
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    if args.list_voices:
        try:
            voices = list_voices(base_url=args.base_url, voices_path=args.voices_path)
        except TiroSpikeError as exc:
            print(f"FAIL: {exc}", file=sys.stderr)
            return 1
        print(json.dumps(voices, indent=2, ensure_ascii=False))
        return 0

    try:
        fmt, audio = synthesize(
            args.text,
            args.voice,
            args.format,
            base_url=args.base_url,
            synthesize_path=args.synthesize_path,
            api_key=api_key,
        )
    except TiroSpikeError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    except UnsupportedTiroResponseError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    slug = _filename_slug(args.text)
    out_path = RAW_DIR / f"spike-{slug}.{fmt}"
    out_path.write_bytes(audio)
    print(f"ok: wrote {len(audio)} bytes to {out_path} (format={fmt})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
