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

## Tiro TTS facts (verified 2026-05-02)

> **STATUS: BLOCKED.** The public Tiro TTS service at `tts.tiro.is` is no longer
> reachable. All documented endpoints return HTTP 404. The successor TTS API
> hosted by Grammatek requires paid client credentials. See "Tiro service
> outage" below for the full investigation and escalation options.

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
