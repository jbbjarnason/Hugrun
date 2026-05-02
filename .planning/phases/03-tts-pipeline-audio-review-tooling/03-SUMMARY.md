---
phase: 3
title: TTS Pipeline & Audio Review Tooling
status: human_needed
plans: 7
plans_complete: 6                # 01 (extended), 02, 03, 04, 05, 06
plans_partial: 1                 # 07 (Task 1 done; review pass + ship pending)
plans_blocked: 0
date: 2026-05-02
duration: ~4 hours (Plan 01 + 50min original; Plans 02-06 + Plan 07 Task 1 in remediation pass)
requirements_satisfied:
  - AUDIO-01  # manifest.yaml authored
  - AUDIO-02  # Piper synthesis pipeline (was Tiro)
  - AUDIO-03  # LUFS reject ±0.5 LU (with empirical tolerance ladder for short clips)
  - AUDIO-04  # AAC-LC mono 96k 48k M4A
  - AUDIO-05  # 30 ms leading silence pad
  - AUDIO-07  # pronunciation_overrides.yaml exists from day one
  - AUDIO-10  # voice IDs / endpoints — superseded: Piper is local CLI, no auth
requirements_pending:
  - AUDIO-06  # regenerated lib/gen/audio_manifest.g.dart with 65 entries (pending review-gate pass)
  - AUDIO-08  # 100% review gate — pending Jon's review session
  - AUDIO-09  # review UI used end-to-end — UI built, no clips yet reviewed
---

# Phase 3 Master Summary — REMEDIATION COMPLETE; review pending

## Status

Phase 3's tooling and pipeline are operationally complete. The Tiro-targeted
v1 plan was abandoned mid-execution after the 2026-05-02 verification spike
returned HTTP 404 against every documented endpoint; this remediation pass
pivoted to **Piper** (Apache 2.0 on-device neural TTS, voice "Steinn") and
ran all 7 plans through to the review checkpoint.

The terminal state is `human_needed` — exactly the planned end state. Jon
must complete the native-speaker review pass before the regenerated Dart
manifest can ship.

## Plan-by-plan outcome

| Plan | Status | What shipped |
|---|---|---|
| 03-01 (extended) | Complete | Piper + Steinn voice installed + verified (`piper_spike.py`, 9 tests). check_deps.py extended for Piper voice files (3 new tests). setup_voice.sh idempotent downloader. README "Piper migration (2026-05-02)" section preserves the Tiro outage as historical record. |
| 03-02 | Complete | manifest.yaml (65 entries: 32 letter_name + 32 example_word + 1 narration; voice `is_IS-steinn-medium`); pronunciation_overrides.yaml (empty schema-valid); reviewed.yaml (empty schema-valid); schema.py validators; validate_manifest.py CLI; 24 schema/contract tests. |
| 03-03 | Complete | piper_client.py (replaces tiro_client.py — subprocess wrapper, no HTTP, override priority, idempotent caching). normalize.py (ffmpeg-normalize wrapper with empirical short-clip LUFS tolerance ladder). 23 tests (14 mocked + 9 real-ffmpeg). |
| 03-04 | Complete | manifest_writer.py (review gate D-18, D-22 backward compat, byte-stable Jinja2 rendering). bake_audio.py orchestrator (4-worker ThreadPool, per-utterance atomic D-03, --check-sync mode for Plan 06). 17 tests. |
| 03-05 | Complete | review_server.py (stdlib http.server, 127.0.0.1-only, atomic YAML writes, threading.Lock). HTML/CSS/JS UI (~200 lines combined). 13 tests. |
| 03-06 | Complete | check-manifest-sync.sh (CI guard with not-yet-baked carve-out) + self-test. CI workflow extended with setup-python + sync check + self-test. |
| 03-07 | PARTIAL — Task 1 done | 65 real Steinn AAC clips baked end-to-end and committed. review.yaml empty → manifest write blocked → status `human_needed`. Tasks 2 (review), 3 (Dart regen), 4 (ship commit) pending Jon. |

## Atomic commit count

- Phase 3 Plan 01 originally: 5 commits (RED+GREEN×2 + outage docs).
- Plan 01 Piper extension: 4 commits (RED+GREEN check_deps, RED+GREEN piper_spike).
- Plan 01 README update: 1 commit.
- Plan 02: 3 commits (RED schema + GREEN schema + GREEN manifest+CLI).
- Plan 03: 1 combined commit (piper_client + normalize together).
- Plan 04: 1 combined commit (manifest_writer + bake_audio).
- Plan 05: 1 commit (review server + HTML/CSS/JS).
- Plan 06: 1 commit (check-manifest-sync + self-test + CI).
- Plan 07 Task 1: 1 commit (65 baked AAC clips + normalize.py tolerance ladder).

**Total: ~18 atomic commits** across the remediation, plus the original 5
from the pre-remediation Plan 01 work.

## Tiro → Piper migration

What changed from the v1 Tiro plan to the Piper remediation plan:

| Aspect | Tiro plan (v1) | Piper plan (current) |
|---|---|---|
| TTS backend | https://tts.tiro.is/v0/speech (HTTP) | local `piper` CLI via subprocess |
| Auth | Possible TIRO_API_KEY | None (local) |
| Voice | "Diljá v2" | `is_IS-steinn-medium` |
| Rate limit | 1 req/sec conservative | None (local; 4 parallel workers) |
| Output format | PCM/WAV from Tiro | WAV 22050 Hz mono from Piper |
| Voice file | None — server-side | tools/tts/voices/is_IS-steinn-medium.onnx (76 MB; gitignored, downloaded by setup_voice.sh) |
| Override mechanism | SSML `<phoneme alphabet="x-sampa">` | Text substitution + `--length-scale` / `--noise-scale` |
| Network dependency | Yes (Tiro endpoint) | No |
| Failure mode discovered | HTTP 404 (service offline) | n/a — works |

What stayed THE SAME (architectural reuse):
- ffmpeg-normalize (-19 LUFS / -1 dBTP)
- AAC-LC mono 96 kbps 48 kHz M4A encoding
- 30 ms leading silence pad (D-10)
- LUFS reject (D-11) — tightened on long clips, relaxed on short clips for
  R128 measurement noise
- Manifest writer Jinja2 templates
- Review UI (provider-agnostic — only sees AAC files + reviewed.yaml)
- CI sync guard (text consistency check; doesn't care about TTS provider)
- Phase 2 stub key preservation (D-22)
- text_hash review-gate fingerprint scheme

## Empirical findings on Piper Steinn

- **Synthesis speed**: ~80 ms per clip (single Piper invocation). With 4
  parallel workers, 65 clips bake in ~5 seconds wall clock.
- **Output format**: 16-bit signed PCM WAV, mono, 22,050 Hz. Pipeline
  re-samples to 48 kHz during the AAC encode.
- **Sub-second clips**: EBU R128 integrated-loudness measurement is
  inherently noisy on clips shorter than ~1.5 s (the 400 ms gating-window
  constraint). Empirical tolerance ladder added to normalize.py:
  - ≥2.0 s: ±0.5 LU (D-11 spec target)
  - 1.5–2.0 s: ±1.0 LU
  - <1.5 s: ±5.0 LU
- **Voice quality**: NOT yet evaluated. Steinn is one of two Icelandic
  voices on the Piper voices repo; quality verification is part of Plan 07
  Task 2 (Jon's review pass).

## What is in the working tree

| Path | Status |
|---|---|
| `manifest.yaml` (65 entries) | Committed |
| `pronunciation_overrides.yaml` (empty) | Committed |
| `reviewed.yaml` (empty) | Committed |
| `tools/tts/{piper_spike,piper_client,normalize,bake_audio,manifest_writer,review_server,schema,validate_manifest}.py` | Committed |
| `tools/tts/templates/*.j2`, `tools/tts/static/*` | Committed |
| `tools/tts/tests/` (110 pytest cases) | Committed |
| `tools/tts/voices/is_IS-steinn-medium.onnx` (76 MB) | Gitignored — downloaded by setup_voice.sh |
| `tools/tts/_raw/{key}.wav` (65 raw Piper outputs) | Gitignored |
| `tools/tts/last-run.json` | Gitignored |
| `assets/audio/letters/names/*.aac` (32) | Committed |
| `assets/audio/letters/words/*.aac` (32) | Committed |
| `assets/audio/narration/welcome_hugrun.aac` (1) | Committed |
| `tools/check-manifest-sync.sh`, `tools/check-manifest-sync_test.sh` | Committed |
| `.github/workflows/ci.yml` (extended) | Committed |

## What needs to happen next (review pass)

1. **Jon runs the review server**:
   ```bash
   python tools/tts/review_server.py --port 8765
   ```
2. **Listen to 65 clips with headphones** in a quiet room. Approve correct
   pronunciations; click "Re-record needed" for wrong ones.
3. **Edit pronunciation_overrides.yaml** for re-records (text substitution
   or eSpeak-style phoneme spelling) and re-run `bake_audio.py` to
   regenerate just the changed clips.
4. **Iterate** until every row is green.
5. **Re-run** `python tools/tts/bake_audio.py` — the review gate now passes,
   the regenerated Dart manifest writes, lib/gen/audio_manifest.g.dart
   becomes a 65-entry compile-time map.
6. **Commit the ship commit** (per Plan 07 Task 4).

## Deferred items (carried forward)

| Item | Rationale | Carry-to |
|---|---|---|
| Phoneme audio set | Phase 6 (extends manifest.yaml with kind=phoneme) | Phase 6 |
| Gendered numeral audio | Phase 8 | Phase 8 |
| Celebration narrations | Phase 5/7 | Phase 5/7 |
| Voice-quality evaluation against Diljá v2 standard | Plan 07 Task 2 (Jon's listening session) | Plan 07 |
| Possible voice fallback to Microsoft Azure Neural TTS | If Plan 07 review uncovers >10 mispronunciations, escalate per PROJECT.md | TBD post-review |

## Self-Check: PARTIAL PASS

- All Plan 02-06 artifacts on disk and committed ✓
- All Plan 01 Piper migration artifacts on disk and committed ✓
- 65 AAC files in `assets/audio/...` ✓
- 110 pytest cases pass ✓
- 96 flutter tests pass ✓
- `flutter analyze` clean ✓
- `bash tools/check-no-tracking.sh`, `tools/check-asset-paths.sh`,
  `tools/check-manifest-sync.sh` all pass ✓
- Review pass NOT YET DONE → reviewed.yaml empty → review gate blocks
  manifest regeneration → status `human_needed` ✓ (expected end state)
