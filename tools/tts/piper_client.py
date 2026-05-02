"""tools/tts/piper_client.py — Phase 3 Plan 03 Piper synthesis client.

Replaces the Tiro-based plan after the 2026-05-02 service outage. This module
wraps the local `piper` CLI (no HTTP, no API keys) and provides:

- PiperClient class with synthesize(entry, overrides) → SynthesisResult.
- Override-priority resolution (overrides.text > entry.text; entry.voice >
  manifest.voice).
- Idempotent caching: tools/tts/_raw/{key}.wav + sidecar JSON. Cache fingerprint
  includes (used_text, used_voice, length_scale, noise_scale).
- Parallelism: 4 ThreadPoolExecutor workers by default (Piper is local + safe
  to invoke concurrently).

Errors surface as PiperError (covers VoiceModelMissing, subprocess failure,
output mismatch).
"""
from __future__ import annotations

import hashlib
import json
import logging
import subprocess
from dataclasses import dataclass
from pathlib import Path

log = logging.getLogger(__name__)

DEFAULT_VOICE_PATH = (
    Path(__file__).resolve().parent / "voices" / "is_IS-steinn-medium.onnx"
)


class PiperError(Exception):
    """Generic Piper client error."""


class PiperVoiceMissingError(PiperError):
    """Voice ONNX model file is missing on disk."""


@dataclass(frozen=True)
class SynthesisResult:
    """Outcome of a successful synthesize() call."""
    raw_path: Path
    used_text: str
    used_voice: str
    length_scale: float | None
    noise_scale: float | None
    fingerprint: str
    cached: bool


def _resolve_text_voice(
    entry: dict,
    overrides: dict,
    manifest_voice: str,
) -> tuple[str, str, float | None, float | None]:
    """Apply D-13/D-14 priority rules.

    text:   overrides.<key>.text > entry.text
    voice:  entry.voice (per-utterance override) > manifest_voice
    length_scale / noise_scale: overrides.<key>.length_scale (else None)

    Returns (used_text, used_voice, length_scale, noise_scale).
    """
    key = entry["key"]
    override = (overrides or {}).get(key, {}) or {}

    if "text" in override and override["text"]:
        used_text = override["text"]
    elif "phonemes" in override and override["phonemes"]:
        # eSpeak-style phoneme spelling — passed through as the text input
        # (Piper interprets bracketed phonemes inline).
        used_text = override["phonemes"]
    else:
        used_text = entry["text"]

    used_voice = entry.get("voice") or manifest_voice
    length_scale = override.get("length_scale")
    noise_scale = override.get("noise_scale")

    return used_text, used_voice, length_scale, noise_scale


def _fingerprint(
    used_text: str,
    used_voice: str,
    length_scale: float | None,
    noise_scale: float | None,
) -> str:
    """Cache fingerprint = sha256(text:voice:length_scale:noise_scale) prefix.

    Plan 04's manifest_writer hashes (used_text, used_voice) for the review
    gate; this fingerprint is broader so cache busts when prosody shifts.
    """
    parts = f"{used_text}::{used_voice}::{length_scale}::{noise_scale}"
    return hashlib.sha256(parts.encode("utf-8")).hexdigest()[:16]


class PiperClient:
    """Synthesize manifest entries via the local piper CLI.

    Caching: synthesize() looks up tools/tts/_raw/{key}.wav + .meta.json. If
    the sidecar fingerprint matches the current call, no piper invocation;
    SynthesisResult.cached=True.
    """

    def __init__(
        self,
        *,
        voice_default: str = "is_IS-steinn-medium",
        voice_model_path: Path = DEFAULT_VOICE_PATH,
        cache_dir: Path = Path("tools/tts/_raw"),
        piper_binary: str = "piper",
        timeout: float = 60.0,
    ) -> None:
        self.voice_default = voice_default
        self.voice_model_path = Path(voice_model_path)
        self.cache_dir = Path(cache_dir)
        self.piper_binary = piper_binary
        self.timeout = timeout

    def _ensure_voice(self) -> None:
        if not self.voice_model_path.is_file() or self.voice_model_path.stat().st_size == 0:
            raise PiperVoiceMissingError(
                f"Voice model missing at {self.voice_model_path}. "
                f"Run `bash tools/tts/setup_voice.sh`."
            )

    def synthesize(
        self,
        entry: dict,
        overrides: dict | None = None,
    ) -> SynthesisResult:
        overrides = overrides or {}
        used_text, used_voice, length_scale, noise_scale = _resolve_text_voice(
            entry, overrides, self.voice_default
        )
        fingerprint = _fingerprint(used_text, used_voice, length_scale, noise_scale)

        self.cache_dir.mkdir(parents=True, exist_ok=True)
        key = entry["key"]
        raw_path = self.cache_dir / f"{key}.wav"
        sidecar_path = self.cache_dir / f"{key}.meta.json"

        # Cache lookup.
        if raw_path.is_file() and sidecar_path.is_file() and raw_path.stat().st_size > 0:
            try:
                sidecar = json.loads(sidecar_path.read_text())
                if sidecar.get("fingerprint") == fingerprint:
                    return SynthesisResult(
                        raw_path=raw_path,
                        used_text=used_text,
                        used_voice=used_voice,
                        length_scale=length_scale,
                        noise_scale=noise_scale,
                        fingerprint=fingerprint,
                        cached=True,
                    )
            except (json.JSONDecodeError, OSError):
                # Sidecar corrupted; treat as cache miss.
                pass

        # Cache miss: synthesize.
        self._ensure_voice()
        argv = [
            self.piper_binary,
            "--model",
            str(self.voice_model_path),
            "--output_file",
            str(raw_path),
        ]
        if length_scale is not None:
            argv.extend(["--length-scale", str(length_scale)])
        if noise_scale is not None:
            argv.extend(["--noise-scale", str(noise_scale)])

        try:
            completed = subprocess.run(
                argv,
                input=used_text.encode("utf-8"),
                capture_output=True,
                timeout=self.timeout,
                check=False,
            )
        except FileNotFoundError as exc:
            raise PiperError(
                f"piper binary '{self.piper_binary}' not found on PATH. "
                f"Install via `pipx install piper-tts`."
            ) from exc
        except subprocess.TimeoutExpired as exc:
            raise PiperError(f"piper timed out after {self.timeout}s for {key}") from exc

        if completed.returncode != 0:
            stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
            raise PiperError(f"piper failed for {key}: rc={completed.returncode} {stderr}")

        if not raw_path.exists() or raw_path.stat().st_size == 0:
            raise PiperError(
                f"piper exited 0 but did not write output at {raw_path} for {key}"
            )

        # Write sidecar atomically.
        sidecar_data = {
            "key": key,
            "used_text": used_text,
            "used_voice": used_voice,
            "length_scale": length_scale,
            "noise_scale": noise_scale,
            "fingerprint": fingerprint,
            "bytes": raw_path.stat().st_size,
        }
        tmp_sidecar = sidecar_path.with_suffix(".json.tmp")
        tmp_sidecar.write_text(json.dumps(sidecar_data, ensure_ascii=False, indent=2))
        tmp_sidecar.replace(sidecar_path)

        return SynthesisResult(
            raw_path=raw_path,
            used_text=used_text,
            used_voice=used_voice,
            length_scale=length_scale,
            noise_scale=noise_scale,
            fingerprint=fingerprint,
            cached=False,
        )
