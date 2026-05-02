"""tools/tts/piper_spike.py — Piper TTS verification spike (D-06, Piper migration 2026-05-02).

Replaces the conceptual role of `tools/tts/tiro_spike.py` after the Tiro service
was found offline. Piper is Apache 2.0 on-device neural TTS; voice "Steinn" is
the male Icelandic voice from Grammatek Símarómur, packaged at
huggingface.co/rhasspy/piper-voices.

This module:
- Builds the piper CLI argv (model, output, optional length-scale / noise-scale).
- Pipes the synthesis text via stdin (UTF-8, preserves Icelandic diacritics).
- Surfaces VoiceModelMissingError if the ONNX voice file is absent (with a
  pointer to `bash tools/tts/setup_voice.sh`).
- Surfaces PiperSpikeError with stderr context on subprocess failure.

Live invocation:
  python -m tools.tts.piper_spike --text "halló Hugrún"

Or via this module's CLI directly:
  python tools/tts/piper_spike.py --text "halló" --output /tmp/out.wav
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

# Default voice file resolves under tools/tts/voices/ (gitignored; downloaded
# by setup_voice.sh on first run). D-05.
DEFAULT_VOICE = Path(__file__).resolve().parent / "voices" / "is_IS-steinn-medium.onnx"
DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "_raw"
DEFAULT_TEXT = "halló Hugrún"


class PiperSpikeError(Exception):
    """Raised when piper exits non-zero or fails to produce output."""


class VoiceModelMissingError(PiperSpikeError):
    """Raised when the voice ONNX model file is missing on disk."""


@dataclass(frozen=True)
class SpikeResult:
    """Outcome of a successful synthesize() call."""
    output_path: Path
    text: str
    voice_model: Path
    bytes_written: int


def build_piper_argv(
    voice_model: Path,
    output_path: Path,
    *,
    length_scale: float | None = None,
    noise_scale: float | None = None,
    piper_binary: str = "piper",
) -> list[str]:
    """Build the piper CLI argv.

    Piper accepts `--model`, `--output_file` (or `--output-file`), and optional
    `--length-scale` / `--noise-scale` for prosody control (D-13).
    """
    argv: list[str] = [
        piper_binary,
        "--model",
        str(voice_model),
        "--output_file",
        str(output_path),
    ]
    if length_scale is not None:
        argv.extend(["--length-scale", str(length_scale)])
    if noise_scale is not None:
        argv.extend(["--noise-scale", str(noise_scale)])
    return argv


def synthesize(
    text: str,
    *,
    voice_model: Path = DEFAULT_VOICE,
    output_path: Path,
    length_scale: float | None = None,
    noise_scale: float | None = None,
    piper_binary: str = "piper",
    timeout: float = 60.0,
) -> SpikeResult:
    """Synthesize `text` to `output_path` using Piper + Steinn voice.

    Raises:
        VoiceModelMissingError: voice ONNX file is missing on disk.
        PiperSpikeError: piper subprocess exited non-zero or failed to write output.
    """
    voice_model = Path(voice_model)
    output_path = Path(output_path)

    if not voice_model.is_file() or voice_model.stat().st_size == 0:
        raise VoiceModelMissingError(
            f"Piper voice model missing at {voice_model}. "
            f"Run `bash tools/tts/setup_voice.sh` to download "
            f"is_IS-steinn-medium.onnx from huggingface.co/rhasspy/piper-voices."
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)

    argv = build_piper_argv(
        voice_model,
        output_path,
        length_scale=length_scale,
        noise_scale=noise_scale,
        piper_binary=piper_binary,
    )

    try:
        completed = subprocess.run(
            argv,
            input=text.encode("utf-8"),
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or b"").decode("utf-8", errors="replace")
        raise PiperSpikeError(
            f"piper exited {exc.returncode}: {stderr or 'no stderr'}"
        ) from exc
    except FileNotFoundError as exc:
        raise PiperSpikeError(
            f"piper binary '{piper_binary}' not found on PATH. Install via `pipx install piper-tts`."
        ) from exc
    except subprocess.TimeoutExpired as exc:
        raise PiperSpikeError(f"piper timed out after {timeout}s") from exc

    if completed.returncode != 0:
        stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
        raise PiperSpikeError(
            f"piper exited {completed.returncode}: {stderr or 'no stderr'}"
        )

    if not output_path.exists() or output_path.stat().st_size == 0:
        stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
        raise PiperSpikeError(
            f"piper exited 0 but did not produce output at {output_path}: {stderr or 'no stderr'}"
        )

    return SpikeResult(
        output_path=output_path,
        text=text,
        voice_model=voice_model,
        bytes_written=output_path.stat().st_size,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Piper TTS verification spike (D-06, 2026-05-02 Piper migration)."
    )
    parser.add_argument("--text", default=DEFAULT_TEXT, help="phrase to synthesize")
    parser.add_argument(
        "--voice",
        default=str(DEFAULT_VOICE),
        help="path to voice ONNX model (default: tools/tts/voices/is_IS-steinn-medium.onnx)",
    )
    parser.add_argument(
        "--output",
        "--out",
        default=None,
        help="output WAV path (default: tools/tts/_raw/spike-<slug>.wav)",
    )
    parser.add_argument(
        "--length-scale",
        type=float,
        default=None,
        help="phoneme length multiplier (1.0 = normal; >1 slower)",
    )
    parser.add_argument(
        "--noise-scale",
        type=float,
        default=None,
        help="generator noise (default: model's preferred value)",
    )
    args = parser.parse_args(argv)

    voice_path = Path(args.voice)
    if args.output:
        output_path = Path(args.output)
    else:
        slug = "".join(c if c.isalnum() else "_" for c in args.text[:40]).strip("_") or "spike"
        DEFAULT_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        output_path = DEFAULT_OUTPUT_DIR / f"spike-{slug}.wav"

    try:
        result = synthesize(
            text=args.text,
            voice_model=voice_path,
            output_path=output_path,
            length_scale=args.length_scale,
            noise_scale=args.noise_scale,
        )
    except VoiceModelMissingError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    except PiperSpikeError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    print(
        f"ok: wrote {result.bytes_written} bytes to {result.output_path} "
        f"(text={result.text!r}, voice={result.voice_model.name})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
