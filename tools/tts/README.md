# Hugrún TTS Pipeline

Local-only Python pipeline that turns `manifest.yaml` into reviewed,
loudness-normalized AAC clips and regenerates `lib/gen/audio_manifest.g.dart`.

## Status

Phase 3 — Piper migration in progress (2026-05-02). Build-time on-device neural
TTS via the open-source `piper-tts` CLI, Icelandic voice "Steinn" from
Grammatek Símarómur. Replaces the v1 plan that targeted Tiro after the Tiro
service was found offline (see "Tiro service outage" section below — historical
record).

## Setup

```bash
# 1. Install ffmpeg
brew install ffmpeg

# 2. Install ffmpeg-normalize (isolated via pipx)
brew install pipx && pipx ensurepath
pipx install ffmpeg-normalize
# After ensurepath, restart your shell or `export PATH="$HOME/.local/bin:$PATH"`

# 3. Install Piper (local on-device neural TTS)
pipx install piper-tts
# (brew install piper-tts is NOT available on Homebrew as of 2026-05-02 —
# pipx is the preferred install method on macOS.)

# 4. Download the Steinn voice model (~76 MB ONNX + 4 KB JSON config; gitignored)
bash tools/tts/setup_voice.sh

# 5. Create venv + install Python deps
python3 -m venv tools/tts/.venv
source tools/tts/.venv/bin/activate
pip install -r tools/tts/requirements.txt

# 6. Verify everything
python tools/tts/check_deps.py    # all green (ffmpeg, piper, voice files, modules)

# 7. Verify Piper synthesis with a one-shot spike
python tools/tts/piper_spike.py --text "halló Hugrún"
# → writes a WAV under tools/tts/_raw/; play it back to confirm Steinn quality.
```

## Verified versions (2026-05-02)

- ffmpeg: 8.1 (Homebrew, arm64 sequoia bottle)
- ffmpeg-normalize: 1.37.6 (pipx-managed)
- python3: 3.14.3 (Homebrew)
- piper-tts: 1.4.2 (pipx-managed; binary at `~/.local/bin/piper`)
- voice: `is_IS-steinn-medium.onnx` (76,495,465 bytes; SHA from Hugging Face
  CAS-bridge; commit `7a6c333ec560f0e688371adc2fbb7bbe105028c6` of
  rhasspy/piper-voices)

## Piper migration (2026-05-02)

After the Tiro spike returned HTTP 404 for every documented endpoint (see
historical record below), Phase 3 pivots to **Piper** — Apache 2.0 on-device
neural TTS that runs entirely offline and generates audio at build time.

### Why Piper

- **Apache 2.0** — same license slot Tiro held; no new licensing risk for a
  kids' app (research Finding 1).
- **Offline** — no API keys, no rate limits, no service-availability concerns.
  The pipeline runs from `make` / a local script and produces deterministic
  output given the same `(text, voice, length-scale)` triple.
- **Same architectural slot** — build-time generator → AAC clips ship as
  static assets. ffmpeg-normalize, manifest_writer, review UI, reviewed.yaml
  gate are all reused unchanged.
- **Parallelizable** — the pipeline can synthesize multiple clips concurrently
  (no rate limit, just CPU cores).

### Voice: Steinn (male, Icelandic)

`is_IS-steinn-medium` from `huggingface.co/rhasspy/piper-voices` —
upstream-trained on Grammatek Símarómur data. PROJECT.md's v1 narrator was
"Diljá v2" (female); the Piper voices repo currently ships only the male
Steinn voice for `is_IS`. Final voice quality is Jon's call during the Plan 07
review pass; if Steinn is unsatisfactory the fallback is Microsoft Azure
Neural TTS (`is-IS-GudrunNeural` female / `is-IS-GunnarNeural` male) per the
PROJECT.md fallback chain.

### Piper invocation

```bash
echo "halló Hugrún" | piper \
  --model tools/tts/voices/is_IS-steinn-medium.onnx \
  --output_file out.wav
```

Output: 16-bit signed PCM WAV, mono, 22,050 Hz. The pipeline downstream
re-samples to 48 kHz and re-encodes as AAC-LC mono 96 kbps M4A via
`ffmpeg-normalize` + a final `ffmpeg` pass for the silence pad (D-09 / D-10 /
D-12).

### Prosody control (D-13, D-15)

Piper supports `--length-scale` (1.0 = normal; >1 slower; <1 faster) and
`--noise-scale` (generator noise; default tuned per voice). Phoneme-level
overrides are NOT directly supported by the Piper CLI; for fine pronunciation
fixes we use **text substitution** (e.g. write `"hund-ur"` instead of
`"hundur"`) or **eSpeak-style phoneme spelling** in the input text. The
review UI's "Re-record needed" button is the trigger; Jon hand-edits
`pronunciation_overrides.yaml` between bake runs.

### Voice file location and gitignore

`tools/tts/voices/is_IS-steinn-medium.onnx` (~76 MB) and
`tools/tts/voices/is_IS-steinn-medium.onnx.json` (~4 KB) are downloaded by
`bash tools/tts/setup_voice.sh` on first run. Both files are listed in
`tools/tts/.gitignore` and never committed (don't bloat the repo).
`setup_voice.sh` is idempotent — re-running it skips the download if both
files are already present with non-zero size.

### Removing the Tiro plumbing

`tools/tts/tiro_spike.py` is preserved as a historical record of the
verification spike that uncovered the outage. It is not invoked by any
later phase; new pipeline work targets `piper_spike.py` and (in Plan 03)
`piper_client.py` instead.



## HTTP client choice

`requests` (not `httpx`) — synchronous-only is fine for the pipeline (rate-limit at
1 req/sec dominates anyway). `requests-mock` is the test-time mock library.

## Tiro TTS facts (verified 2026-05-02 — HISTORICAL RECORD)

> **STATUS: SUPERSEDED by the Piper migration above.** The public Tiro TTS
> service at `tts.tiro.is` is offline; the section below documents the
> verification spike that uncovered the outage. Kept for historical record /
> future reference if Tiro ever returns.

- **Base URL**: `https://tts.tiro.is` (DNS still resolves; CNAME → talgreinir.is → 35.190.211.139; HTTP server reachable but returns 404 for every documented path)
- **Synthesize endpoint** (per upstream `icelandic-lt/tiro-tts` source `src/app.py`): `/v0/speech` (POST). **Returns 404.**
- **List-voices endpoint** (per upstream): `/v0/voices` (GET). **Returns 404.**
- **Auth**: unverifiable — service is offline. Public API was unauthenticated when last reachable.
- **Voice ID for narrator (Diljá v2)**: per upstream `src/schemas.py`, the `VoiceId` field is a free-form string, example value `Alfur`. The Diljá v2 voice was historically `Diljá v2` (literal, with diacritic + space + lowercase v + 2). **Could not be verified live.**
- **Output formats supported** (per upstream schemas.py): `pcm`, `mp3`, `ogg_vorbis`, `json` (speech marks). **Could not be verified live.**
- **SSML support** (per upstream schemas.py): YES — `TextType=ssml`, supported tags: `<speak>`, `<phoneme alphabet="x-sampa">`, `<prosody rate volume>`, `<sub>`. **Could not be verified live.**
- **Sample rates** (per upstream schemas.py): `8000`, `16000`, `22050` Hz.
- **Rate limit observed**: n/a — service offline.

### Tiro service outage (2026-05-02 investigation)

`tts.tiro.is` resolves but the upstream Tiro TTS service has been deprecated.
Probed all documented and inferred endpoints; every one returns HTTP 404:

| Probe                                         | Status |
|-----------------------------------------------|--------|
| `GET https://tts.tiro.is/`                    | 404    |
| `GET https://tts.tiro.is/v0/voices`           | 404    |
| `POST https://tts.tiro.is/v0/speech`          | 404    |
| `POST https://tts.tiro.is/v0/speech/synthesize` | 404  |
| `GET https://tts.tiro.is/openapi.json`        | 404    |
| `GET https://tts.tiro.is/v0/openapi.json`     | 404    |
| `GET https://tts.tiro.is/swagger`             | 404    |

The `tts.tiro.is` host returns Go-style `404 page not found` plain text
(`x-content-type-options: nosniff`), which strongly suggests the upstream
`tiro-tts` app is no longer deployed at that address. The DNS CNAME points to
`talgreinir.is` (Tiro's STT React app, last commit 2022-09 in
`icelandic-lt/tiro-tts`).

The successor TTS API maintained by Grammatek (current owners of the original
Tiro work) is at `api2.grammatek.com`:

```bash
$ curl https://api2.grammatek.com/tts/v1/voices
{"error":"Invalid access token provided"}      # HTTP 401
```

Per Grammatek's public Ruby gem (`grammatek/tts-ruby-gem`):

> Please contact Grammatek via info@grammatek.com to receive your individual
> client credentials.

This is a **paid commercial API**, not a free / public service. Authentication
flow: `POST /auth/v1` with client credentials → temporary access token →
`POST /tts/v1/speech` for synthesis.

### Escalation options (project-level decision required — Plan 01 cannot proceed)

The audio pipeline is the entire point of Phase 3; we cannot continue without a
working TTS service. The choices are:

1. **Pivot to api2.grammatek.com (Grammatek TTS).** Same Icelandic voices
   (Diljá v2, Álfur v2, etc. — same models, same Reykjavík University
   provenance). Different API shape (`/tts/v1/speech` instead of `/v0/speech`,
   token auth instead of unauthenticated). User must contact `info@grammatek.com`
   for client credentials. Pricing model unknown without contact.
2. **Pivot to Microsoft Azure Neural TTS.** Per PROJECT.md — Azure has
   `is-IS-GudrunNeural` and `is-IS-GunnarNeural` voices. Commercial API with a
   monthly free tier (typically 500K characters/month for Neural voices).
   Different voices than Tiro Diljá v2 — review pass would compare against
   different reference audio than the v1 plan envisioned.
3. **Pivot to Amazon Polly.** Has `Karl` (Icelandic male) and `Dóra` (Icelandic
   female) voices. Lower-quality than the neural Tiro/Azure voices per research
   STACK.md. Free tier ~5M chars/month for 12 months.
4. **Self-host the upstream tiro-tts.** The `icelandic-lt/tiro-tts` repo
   (Apache 2.0) plus the published Diljá / Álfur model checkpoints can be run
   locally via Docker, in theory. Significant infrastructure work; not viable
   for a solo build with ASAP-playable goals.

**Until the user (Jon) selects one of these options and supplies credentials
(or sets up self-hosting), Phase 3 Plans 02–07 are blocked.** Plan 01's tooling
baseline (ffmpeg, ffmpeg-normalize, Python deps, check_deps.py, tiro_spike.py
with mocked tests) is complete and can be reused with a different TTS backend
once a path forward is chosen.

**Sources:**
- live curl probes 2026-05-02 (all 404)
- `icelandic-lt/tiro-tts` source `src/app.py` (route definitions: `/v0/speech` POST, `/v0/voices` GET)
- `icelandic-lt/tiro-tts` source `src/schemas.py` (request body fields: Engine, OutputFormat, SampleRate, Text, VoiceId, TextType + SSML grammar)
- `grammatek/tts-ruby-gem` README + `lib/grammatek-tts/configuration.rb` (`@host = 'api2.grammatek.com'`, paid commercial API, OAuth-style auth)
- DNS: `tts.tiro.is` CNAME → `talgreinir.is` → `35.190.211.139`

## Troubleshooting

- "ffmpeg: command not found" → `brew install ffmpeg`
- "ffmpeg-normalize: command not found" → `pipx install ffmpeg-normalize` and ensure `~/.local/bin` is on PATH
- "piper: command not found" → `pipx install piper-tts` and ensure `~/.local/bin` is on PATH
- "Piper voice model missing" → `bash tools/tts/setup_voice.sh` (downloads ~76 MB ONNX from Hugging Face)
- "ModuleNotFoundError: No module named 'requests'" → `pip install -r tools/tts/requirements.txt`

## Layout (D-01, post-Piper-migration)

```
tools/tts/
  README.md                # this file
  requirements.txt         # pinned Python deps
  check_deps.py            # --check-deps entrypoint (D-29)
  setup_voice.sh           # idempotent Steinn voice downloader (D-05)
  piper_spike.py           # one-shot Piper verification (D-06)
  piper_client.py          # subprocess wrapper (Plan 03)
  tiro_spike.py            # HISTORICAL: original Tiro verification (kept for record)
  normalize.py             # ffmpeg-normalize wrapper (Plan 03)
  bake_audio.py            # main pipeline orchestrator (Plan 04)
  manifest_writer.py       # Dart codegen (Plan 04)
  review_server.py         # local review UI (Plan 05)
  schema.py                # YAML validators (Plan 02)
  validate_manifest.py     # CLI validator (Plan 02)
  templates/               # Jinja2 templates for codegen + review HTML
  static/                  # CSS + JS for review UI
  tests/                   # pytest test suite
  voices/                  # Steinn ONNX + JSON config (gitignored, downloaded by setup_voice.sh)
  _raw/                    # local cache of raw Piper output (gitignored)
```
