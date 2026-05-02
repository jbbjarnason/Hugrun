# Hugrún TTS Pipeline

Local-only Python pipeline that turns `manifest.yaml` into reviewed,
loudness-normalized AAC clips and regenerates `lib/gen/audio_manifest.g.dart`.

## Status

Phase 3 plan 01 — tooling baseline complete; Tiro spike pending Task 2.

## Setup

```bash
# 1. Install ffmpeg
brew install ffmpeg

# 2. Install ffmpeg-normalize (isolated via pipx)
brew install pipx && pipx ensurepath
pipx install ffmpeg-normalize
# After ensurepath, restart your shell or `export PATH="$HOME/.local/bin:$PATH"`

# 3. Create venv + install Python deps
python3 -m venv tools/tts/.venv
source tools/tts/.venv/bin/activate
pip install -r tools/tts/requirements.txt

# 4. Verify everything
python tools/tts/check_deps.py    # all green
```

## Verified versions (2026-05-02)

- ffmpeg: 8.1 (Homebrew, arm64 sequoia bottle)
- ffmpeg-normalize: 1.37.6 (pipx-managed)
- python3: 3.14.3 (Homebrew)

## HTTP client choice

`requests` (not `httpx`) — synchronous-only is fine for the pipeline (rate-limit at
1 req/sec dominates anyway). `requests-mock` is the test-time mock library.

## Tiro TTS facts

(filled in by tools/tts/tiro_spike.py — see Task 2 of Plan 01)

## Troubleshooting

- "ffmpeg: command not found" → `brew install ffmpeg`
- "ffmpeg-normalize: command not found" → `pipx install ffmpeg-normalize` and ensure `~/.local/bin` is on PATH
- "ModuleNotFoundError: No module named 'requests'" → `pip install -r tools/tts/requirements.txt`
- "TIRO_API_KEY not set" → optional unless the spike (Plan 01 Task 2) proves Tiro requires auth (research suggests it does NOT, MEDIUM confidence)

## Layout (D-01)

```
tools/tts/
  README.md                # this file
  requirements.txt         # pinned Python deps
  check_deps.py            # --check-deps entrypoint (D-29)
  tiro_spike.py            # one-shot Tiro verification (D-06; Plan 01 Task 2)
  tiro_client.py           # HTTP wrapper (Plan 03)
  normalize.py             # ffmpeg-normalize wrapper (Plan 03)
  bake_audio.py            # main pipeline orchestrator (Plan 04)
  manifest_writer.py       # Dart codegen (Plan 04)
  review_server.py         # local review UI (Plan 05)
  schema.py                # YAML validators (Plan 02)
  validate_manifest.py     # CLI validator (Plan 02)
  templates/               # Jinja2 templates for codegen + review HTML
  static/                  # CSS + JS for review UI
  tests/                   # pytest test suite
  _raw/                    # local cache of raw Tiro output (gitignored)
```
