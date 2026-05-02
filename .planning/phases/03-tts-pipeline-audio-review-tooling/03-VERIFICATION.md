---
status: human_needed
phase: 3
date: 2026-05-02
pending:
  - "User decision: choose TTS provider (api2.grammatek.com paid / Azure Neural / AWS Polly / self-hosted tiro-tts)"
  - "Once chosen + credentials obtained: rewrite tools/tts/tiro_spike.py and tools/tts/tiro_client.py (Plan 03 future work) for the chosen provider"
  - "Native-speaker review of N clips — N=0 today; the 65 v1 clips will exist only after Plans 02–07 ship against the new provider"
---

# Phase 3 Verification — human_needed

## Why human_needed

The live Tiro TTS service at `tts.tiro.is` is offline (HTTP 404 on every
documented endpoint, verified 2026-05-02). The successor commercial API at
`api2.grammatek.com` requires paid client credentials.

Phase 3's tooling baseline shipped successfully (Plan 01: ffmpeg / ffmpeg-normalize
installed, `check_deps.py` and `tiro_spike.py` written + tested with mocks).
Plans 02–07 cannot start without a working TTS provider — they consume the
exact endpoint, voice ID, output format, and SSML facts that Plan 01 was
supposed to verify.

## Pending items

### 1. TTS provider decision (project-level)

The user must choose one of:

| Option | Pros | Cons | Cost |
|---|---|---|---|
| Grammatek `api2.grammatek.com` | Same neural voices as Tiro Diljá v2 | New API shape; commercial credentials | Pricing unknown — email info@grammatek.com |
| Microsoft Azure Neural TTS | PROJECT.md fallback; mature SDK; Icelandic neural voices `GudrunNeural` / `GunnarNeural` | Different voice talent than Diljá v2 | Free tier ~500K chars/month |
| Amazon Polly | Free tier 5M chars/12mo | Non-neural voices `Karl` / `Dóra` — research STACK.md flags lower naturalness | Free for first year |
| Self-hosted `icelandic-lt/tiro-tts` | Same Diljá v2 voice; Apache 2.0; no per-call cost | Significant infrastructure work | Hardware/electricity only |

### 2. Re-verify provider facts via spike

Once a provider is chosen, run the equivalent of Plan 01 Task 2 against it:

- Endpoint URL + path
- Auth model (token / API key / none)
- Voice ID for the narrator (Diljá v2 equivalent or replacement)
- Output formats (PCM / WAV / MP3 / Ogg)
- SSML support (yes / no / partial; document supported tags)
- Observed rate limit + the conservative pipeline default

### 3. Native-speaker review

Once Plans 02–07 ship and the bake pipeline runs against the chosen provider,
~65 v1 clips will need to be reviewed (32 letter names + 32 example words +
welcome narration). The review UI infrastructure (Plan 05) is part of the
blocked work — review cannot start until the audio exists.

## What is currently passing

`flutter test` (84 tests), `flutter analyze`, `bash tools/check-asset-paths.sh`,
`bash tools/check-no-tracking.sh`, `python3 -m pytest tools/tts/tests/` (21
mocked tests). No regressions from Plan 01.

## What is currently failing

Live Tiro endpoint reachability — single root cause for the entire Phase 3
blockage.
