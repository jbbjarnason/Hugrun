#!/usr/bin/env bash
# tools/tts/setup_voice.sh — idempotently download the Piper Steinn voice model.
#
# Phase 3 (Piper migration, 2026-05-02): replaces the Tiro v1 plan after the Tiro
# service was found offline. Steinn is the male Icelandic voice from Grammatek
# Símarómur, packaged for Piper at huggingface.co/rhasspy/piper-voices.
#
# This script downloads ~76 MB of ONNX model weights + a small JSON config. The
# voice files are gitignored (see tools/tts/.gitignore) — every developer runs
# this once before invoking the TTS pipeline. Skips download if both files
# already exist with non-zero size.
#
# Usage:
#   bash tools/tts/setup_voice.sh
#
# Verifies via SHA-256 check is OPTIONAL — Hugging Face serves the file behind
# a CDN with content hash; we trust their CAS-bridge URLs.
set -euo pipefail

VOICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/voices"
VOICE_ONNX="${VOICE_DIR}/is_IS-steinn-medium.onnx"
VOICE_JSON="${VOICE_DIR}/is_IS-steinn-medium.onnx.json"
BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/is/is_IS/steinn/medium"

mkdir -p "${VOICE_DIR}"

# JSON config (~4 KB)
if [[ -s "${VOICE_JSON}" ]]; then
  echo "ok: ${VOICE_JSON} already present ($(wc -c <"${VOICE_JSON}") bytes)"
else
  echo "downloading ${VOICE_JSON} ..."
  curl -fL --progress-bar -o "${VOICE_JSON}" "${BASE_URL}/is_IS-steinn-medium.onnx.json"
  echo "ok: ${VOICE_JSON} ($(wc -c <"${VOICE_JSON}") bytes)"
fi

# ONNX model (~76 MB)
if [[ -s "${VOICE_ONNX}" ]] && [[ $(wc -c <"${VOICE_ONNX}") -gt 50000000 ]]; then
  echo "ok: ${VOICE_ONNX} already present ($(wc -c <"${VOICE_ONNX}") bytes)"
else
  echo "downloading ${VOICE_ONNX} (~76 MB; may take a minute) ..."
  curl -fL --progress-bar -o "${VOICE_ONNX}" "${BASE_URL}/is_IS-steinn-medium.onnx"
  echo "ok: ${VOICE_ONNX} ($(wc -c <"${VOICE_ONNX}") bytes)"
fi

echo "Steinn voice ready at ${VOICE_DIR}"
