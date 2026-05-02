---
phase: 3
title: TTS Pipeline & Audio Review Tooling
status: blocked
plans: 7
plans_complete: 0
plans_partial: 1   # 03-01 tooling shipped; spike returned escalation
plans_blocked: 6
date: 2026-05-02
duration: ~50 min (Plan 01 only)
requirements_satisfied: []
requirements_blocked:
  - AUDIO-01  # Plan 02 — manifest.yaml authoring
  - AUDIO-02  # Plan 03 — Tiro client
  - AUDIO-03  # Plan 03 — LUFS reject
  - AUDIO-04  # Plan 03 — AAC-LC mono codec
  - AUDIO-05  # Plan 03 — silence pad
  - AUDIO-06  # Plan 04 — committed Dart manifest
  - AUDIO-07  # Plan 02 — overrides file
  - AUDIO-08  # Plan 04/05 — review gate
  - AUDIO-09  # Plan 05 — review UI
  - AUDIO-10  # Plan 01 — Tiro auth/voice IDs (PARTIAL: investigated, not verified live; service is offline)
---

# Phase 3 Master Summary — BLOCKED

## Status

Phase 3 cannot ship in its planned form. The Tiro TTS service that the entire
phase was scoped around (per PROJECT.md, ROADMAP.md, Phase 3 context, and all
seven plans) is no longer reachable. Plan 01's verification spike — whose
explicit purpose was to catch exactly this kind of issue *before* any pipeline
code is written — succeeded in catching it.

## What was delivered

| Plan | Status | Outcome |
|---|---|---|
| 03-01 | tooling shipped, escalation surfaced | ffmpeg + ffmpeg-normalize installed, Python venv set up, `check_deps.py` + `tiro_spike.py` written and tested with mocks (21/21). Live spike returned HTTP 404 against every documented Tiro endpoint. Outage documented in `tools/tts/README.md` with four escalation paths. |
| 03-02..03-07 | not started | Each depends transitively on Plan 01's live spike. Without a working TTS provider, manifest.yaml schema work, Tiro client, normalize wrapper, manifest writer, review UI, CI sync guard, and end-to-end review pass all consume API specifics that don't exist. |

## Atomic commits

5 atomic commits in Plan 01 (RED + GREEN check_deps, RED + GREEN tiro_spike,
docs/findings) + 1 housekeeping doc commit capturing the 7 plans + Phase 4
context. Plans 02–07 contributed zero commits.

## What's blocked

Every requirement in the AUDIO-01..09 family. AUDIO-10 ("Tiro TTS auth, voice
ID strings, and rate limits are verified via live curl call") is partially
satisfied — the live curl call was made and *its result is documented* — but
the result was "service offline" not "service confirmed working".

## What needs to happen before Phase 3 can resume

The user (Jon) needs to choose one of the following and obtain
credentials / set up infrastructure as needed:

1. **api2.grammatek.com (paid commercial Grammatek TTS).** Same Icelandic
   neural voices (Diljá v2, Álfur v2) that the original v1 plan called for.
   Different API shape (token auth, `/tts/v1/speech` endpoint). Pricing
   unknown without contacting `info@grammatek.com`.
2. **Microsoft Azure Neural TTS.** PROJECT.md's documented fallback. Voices
   `is-IS-GudrunNeural` (female) and `is-IS-GunnarNeural` (male). Free tier
   typically 500K characters/month for Neural voices. Different voice talent
   than Tiro's Diljá v2 — review pass would compare against new reference
   audio.
3. **Amazon Polly.** Voices `Karl` (M) and `Dóra` (F) for Icelandic. Standard
   (non-neural) quality only — research STACK.md flags these as fallback-tier.
4. **Self-host upstream tiro-tts via Docker.** The `icelandic-lt/tiro-tts`
   code is Apache 2.0 and the published Diljá / Álfur model checkpoints are
   downloadable. Significant infrastructure work for a solo build.

Once a provider is chosen, the plan revision should be light:

- **Plan 01** stays as-is — tooling baseline + spike are reusable. Rewrite
  `tiro_spike.py` (or rename to `tts_spike.py`) for the chosen provider.
- **Plan 02** unchanged — manifest.yaml schema is provider-agnostic.
- **Plan 03 (tiro_client.py)** rewritten for the chosen provider. The
  override-priority and cache-fingerprint logic in the test harness is reusable
  verbatim; only the HTTP layer changes.
- **Plans 04–07** unchanged — they depend on the *interface* of TiroClient +
  Normalizer, not on the underlying provider.

## Self-Check: PASSED (for what was completed)

- 5 atomic commits in `git log`.
- All Plan 01 artifacts present on disk.
- `python3 tools/tts/check_deps.py` and `pytest tools/tts/tests/` (21/21) pass.
- `flutter test` (84/84), `flutter analyze`, `bash tools/check-asset-paths.sh`,
  `bash tools/check-no-tracking.sh` all pass — Plan 01 caused no regressions
  in Phase 1/2 invariants.

## Deferred items (carried forward)

| Item | Rationale | Status |
|---|---|---|
| Plans 02–07 implementation | Blocked on TTS provider selection | Carry to next session |
| Tiro voice ID `Diljá v2` confirmation | Cannot verify against offline service | Re-verify against chosen provider |
| SSML support verification | Cannot verify against offline service | Re-verify against chosen provider |
| Rate limit observation | Cannot verify against offline service | Re-verify against chosen provider |
| Phase 4 (Stafir MVP) | Depends on Phase 3 audio assets | Blocked on Phase 3 unblock |

## Recommendation

The cheapest unblock is **option 2 (Azure Neural TTS)** — has a generous free
tier, Icelandic voices, neural quality on par with Tiro Diljá v2, and standard
SDKs in every language. The provider switch is a one-Plan-03 rewrite once
credentials are in hand.
