---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: blocked
stopped_at: Phase 3 Plan 01 complete; Plans 02-07 BLOCKED on TTS provider outage (tts.tiro.is offline)
last_updated: "2026-05-02T13:30:00.000Z"
last_activity: 2026-05-02 — Phase 3 Plan 01 tooling shipped (5 commits); live Tiro spike returned HTTP 404 across all endpoints; Phase 3 Plans 02-07 blocked pending TTS provider decision (Azure Neural / Grammatek / Polly / self-hosted)
progress:
  total_phases: 10
  completed_phases: 0
  total_plans: 1
  completed_plans: 0
  partial_plans: 1
  percent: 1
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-02)

**Core value:** A five-year-old can pick up a tablet, tap, and learn — discoverable through visuals and audio alone, with no failure states, no scores, no instructions to read.
**Current focus:** Phase 3 — TTS Pipeline & Audio Review Tooling (BLOCKED on provider outage)

## Current Position

Phase: 3 of 10 (TTS Pipeline & Audio Review Tooling)
Plan: 03-01 done (tooling baseline + spike); 03-02..03-07 BLOCKED
Status: BLOCKED — pending user decision on TTS provider (see .planning/phases/03-tts-pipeline-audio-review-tooling/03-VERIFICATION.md)
Last activity: 2026-05-02 — Plan 01 tooling shipped (5 commits); live Tiro spike returned HTTP 404; outage + 4 escalation paths documented in tools/tts/README.md

Progress: [█░░░░░░░░░] 5%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| — | — | — | — |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Init: Flutter + Riverpod + Drift + just_audio user-locked stack
- Init: Tiro TTS (Diljá v2) sole v1 provider; ElevenLabs explicitly excluded (Prohibited Use Policy)
- Init: MVP cut = end of Phase 4 (Stafir tap-to-hear); ASAP playable
- Init: Public release (REL-*) deferred to v2
- Init: TDD with Marionette E2E as project-level constraint
- 2026-05-02 (Plan 03-01): ffmpeg via Homebrew (8.1), ffmpeg-normalize via pipx (1.37.6), HTTP client = `requests` (synchronous-only sufficient given 1 req/sec rate limit)
- 2026-05-02 (Plan 03-01): Tiro TTS endpoint paths confirmed from upstream `icelandic-lt/tiro-tts` source — POST /v0/speech, GET /v0/voices (not the /v0/speech/synthesize speculated in research/STACK.md)
- 2026-05-02 (Plan 03-01): Tiro service at `tts.tiro.is` is offline (404 on every endpoint). User decision required: pivot to api2.grammatek.com (paid), Azure Neural TTS (free tier), AWS Polly (free tier), or self-hosted tiro-tts via Docker.

### Pending Todos

None yet.

### Blockers/Concerns

- **CRITICAL (2026-05-02):** Phase 3 Plans 02-07 blocked — `tts.tiro.is` returns HTTP 404 on every documented endpoint. Phase 4 (Stafir MVP) transitively blocked. See `.planning/phases/03-tts-pipeline-audio-review-tooling/03-VERIFICATION.md` for the four escalation paths. **User decision required.**
- Phase 7 (Tracing) flagged for `/gsd-research-phase` before planning — Ítalíuskrift digitization has no published SVG path library; expect 1–2 days of design work
- Riverpod 3.x vs 4.x is mid-migration — pin a consistent family at Phase 1 `flutter create` time (`dart pub outdated`)

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Public Release | REL-01..REL-06 (privacy policy, Kids Category, TestFlight, multi-speaker QA, support) | Deferred to v2 | Init 2026-05-02 |
| Personalization v2 | PERS-V2-01 (free-text photo tagging), PERS-V2-02 (multi-child) | Deferred to v2 | Init 2026-05-02 |
| Activities v2 | TRACE-V2-01 (uppercase tracing), NUM-V2-01 (numbers >10), NUM-V2-02 (subtraction), PARENT-V2-01 (parent companion) | Deferred to v2 | Init 2026-05-02 |

## Session Continuity

Last session: 2026-05-02T13:30:00.000Z
Stopped at: Phase 3 Plan 01 complete; Plans 02-07 BLOCKED on TTS provider outage
Resume file: .planning/phases/03-tts-pipeline-audio-review-tooling/03-VERIFICATION.md
