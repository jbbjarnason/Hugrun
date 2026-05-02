---
phase: 3
plan: 01
plan-name: tooling-and-tiro-spike
status: blocked
date: 2026-05-02
duration: ~50 min
requirements_satisfied:
  - AUDIO-10  # partial — Tiro auth/voice IDs/rate limits documented as "service offline" rather than verified live
key-files:
  created:
    - tools/tts/check_deps.py
    - tools/tts/tiro_spike.py
    - tools/tts/requirements.txt
    - tools/tts/README.md
    - tools/tts/.gitignore
    - tools/tts/__init__.py
    - tools/tts/tests/__init__.py
    - tools/tts/tests/conftest.py
    - tools/tts/tests/test_check_deps.py
    - tools/tts/tests/test_tiro_spike.py
    - tools/tts/_raw/.gitkeep
  modified: []
decisions:
  - "ffmpeg installed via Homebrew (8.1); ffmpeg-normalize via pipx (1.37.6); Python deps via local venv (Python 3.14.3 on macOS Sequoia)."
  - "HTTP client: `requests` (synchronous-only is fine; rate limit at 1 req/sec dominates)."
  - "Tiro endpoint paths verified from upstream source (icelandic-lt/tiro-tts src/app.py): POST /v0/speech, GET /v0/voices."
  - "Tiro VoiceId examples confirmed from upstream src/schemas.py: free-form string, example 'Alfur'; Diljá v2 historical convention 'Diljá v2'."
  - "Live Tiro endpoint at tts.tiro.is is OFFLINE — every probed path returns HTTP 404. DNS CNAME → talgreinir.is (Tiro's STT React app)."
  - "Successor service api2.grammatek.com requires paid commercial credentials. PHASE 3 BLOCKED pending user choice of TTS provider."
---

# Plan 03-01 Summary — Tooling Baseline + Tiro Verification Spike

## Status

**BLOCKED.** Tooling baseline shipped successfully. The Tiro TTS service that
Phase 3 was designed around is offline; the live verification spike returned
HTTP 404 for every documented and inferred endpoint. Plans 02–07 cannot start
until the user (Jon) chooses an alternative TTS provider.

## What was built (works end-to-end)

| Artifact | Purpose |
|---|---|
| `tools/tts/check_deps.py` (D-29) | --check-deps + --json modes; 10/10 pytest cases mocked. Confirms ffmpeg / ffmpeg-normalize / python3 / pyyaml / jinja2 / requests / pytest are all available locally. |
| `tools/tts/tiro_spike.py` (D-06) | build_request, parse_response (WAV / PCM / MP3 / octet-stream / unknown→raise), exponential backoff on 429, explicit 401 surfacing. 11/11 pytest cases mocked. CLI: `--text`, `--voice`, `--format`, `--list-voices`. |
| `tools/tts/requirements.txt` | requests==2.32.4, pyyaml==6.0.2, jinja2==3.1.4, pytest==8.3.3, requests-mock==1.12.1 |
| `tools/tts/README.md` | Setup instructions, verified versions (ffmpeg 8.1 / ffmpeg-normalize 1.37.6 / python 3.14.3), full Tiro outage investigation + 4 escalation options. |
| `tools/tts/.gitignore` | `_raw/*`, `.venv/`, `.pytest_cache/`, `last-run.json`. `_raw/.gitkeep` retained. |
| Local installs | ffmpeg 8.1 (Homebrew), ffmpeg-normalize 1.37.6 (pipx, isolated), Python venv at `tools/tts/.venv` |

`python3 tools/tts/check_deps.py` exits 0 with all green.
`python3 -m pytest tools/tts/tests/` passes 21/21.

## What was attempted but failed (this is the blocker)

Live curl probes against `https://tts.tiro.is` on 2026-05-02:

| Probe | Result |
|---|---|
| `GET /` | 404 |
| `GET /v0/voices` | 404 |
| `POST /v0/speech` | 404 |
| `POST /v0/speech/synthesize` | 404 |
| `GET /openapi.json` / `/v0/openapi.json` | 404 |
| `GET /swagger` | 404 |

Every endpoint the upstream `icelandic-lt/tiro-tts` source defines (verified
against `src/app.py` and `src/schemas.py`) is unreachable. The host returns
Go-style `404 page not found` plain text — strongly indicating the upstream
service is no longer deployed at that hostname.

DNS evidence:
- `tts.tiro.is` → CNAME `talgreinir.is` → `35.190.211.139`
- `talgreinir.is` is Tiro's *speech-recognition* (STT) React app, not the TTS service.
- `icelandic-lt/tiro-tts` repo last commit is 2022-09-26 ("Remove use of Sequitur G2P").

Successor: `api2.grammatek.com` (Grammatek's commercial TTS API). Returns
401 `{"error":"Invalid access token provided"}` — paid credentials required.

## Atomic commits made (chronological)

| Hash | Type | Message (truncated) |
|---|---|---|
| `cef3f93` | RED   | test(03-01): add failing pytest harness for tools/tts/check_deps |
| `d0b3669` | GREEN | feat(03-01): add tools/tts/check_deps.py + Python requirements pin |
| `7242e29` | RED   | test(03-01): add failing pytest harness for tools/tts/tiro_spike |
| `07abf7a` | GREEN | feat(03-01): add tools/tts/tiro_spike.py with build_request + retry/backoff |
| `f7b63fd` | docs  | docs(03-01): document Tiro TTS service outage from live verification spike (D-06, D-15) |

(Plus `ee46554` `docs(03)` capturing the 7 phase plans + Phase 4 context that
were uncommitted from the planning step.)

**Total: 5 atomic Plan-01 commits + 1 housekeeping doc commit.**

## Deviations from plan

- **[Rule 4 — Architectural escalation] Tiro TTS service is offline.** Plan 01
  Task 2 STOP CONDITION (a) was triggered by the live curl call. The plan's
  README template was authored assuming a working endpoint; it was rewritten
  to document the outage + escalation paths as the *actual* verification
  finding.
- **[Rule 1 — Bug fix] `_safe_version()` ffmpeg edge case.** ffmpeg accepts
  `-version` (single dash) and writes to stderr; `--version` returns exit 8.
  Probe both forms; concatenate stdout+stderr. Caught by running check_deps.py
  live before the GREEN commit; tests already exercise mocked subprocess so
  they didn't surface this.

## Carry-overs

- **For Plans 02–07:** BLOCKED until TTS provider chosen.
- **For when work resumes:** `tools/tts/tiro_spike.py` is salvageable as a
  generic TTS smoke-test (rename + re-target). The Tiro request shape (`Text`,
  `VoiceId`, `OutputFormat`, optional `SampleRate` + `Engine` + `TextType` for
  SSML) matches both the upstream Tiro and the Grammatek successor API
  closely enough that `build_request` is reusable; only the URL + auth would
  change.
- **For Plan 03 (tiro_client.py):** the test fixtures already encode the
  override-priority logic (override.ssml > override.text > entry.text), the
  voice-priority logic (entry.voice > manifest.voice), and the cache
  fingerprint scheme. None of those depend on the live API; they will port to
  whatever provider Phase 3 ends up using.
- **Threat T-03-01-05** (TIRO_API_KEY leak) becomes more prominent if the user
  pivots to Grammatek — a real client_id+client_secret pair. check_deps.py's
  `check_env_vars` already redacts values; tiro_client.py (Plan 03, when it
  ships) must inherit that discipline.

## Self-Check: PASSED

- All five atomic commits exist in git log (verified).
- `tools/tts/check_deps.py`, `tools/tts/tiro_spike.py`, `tools/tts/README.md`,
  `tools/tts/requirements.txt`, `tools/tts/.gitignore` exist on disk.
- `python3 tools/tts/check_deps.py` exits 0 with all green.
- `python3 -m pytest tools/tts/tests/` passes 21/21.
- `flutter analyze`, `flutter test` (84 tests), `bash tools/check-asset-paths.sh`,
  `bash tools/check-no-tracking.sh` all pass — no regressions from Plan 01.

The only outstanding item is the live Tiro call success criterion, which is
blocked on infrastructure outside this repo.
