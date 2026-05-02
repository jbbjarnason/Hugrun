# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-02)

**Core value:** A five-year-old can pick up a tablet, tap, and learn — discoverable through visuals and audio alone, with no failure states, no scores, no instructions to read.
**Current focus:** Phase 1 — Skeleton & Drift Schema

## Current Position

Phase: 1 of 10 (Skeleton & Drift Schema)
Plan: — (not yet planned)
Status: Ready to plan
Last activity: 2026-05-02 — Roadmap created (10 phases, 61/61 v1 requirements mapped)

Progress: [░░░░░░░░░░] 0%

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

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 7 (Tracing) flagged for `/gsd-research-phase` before planning — Ítalíuskrift digitization has no published SVG path library; expect 1–2 days of design work
- Tiro TTS auth and rate limits documented at MEDIUM confidence — verify via curl in Phase 3 before pipeline build (per Phase 3 Success Criterion 4)
- Riverpod 3.x vs 4.x is mid-migration — pin a consistent family at Phase 1 `flutter create` time (`dart pub outdated`)

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Public Release | REL-01..REL-06 (privacy policy, Kids Category, TestFlight, multi-speaker QA, support) | Deferred to v2 | Init 2026-05-02 |
| Personalization v2 | PERS-V2-01 (free-text photo tagging), PERS-V2-02 (multi-child) | Deferred to v2 | Init 2026-05-02 |
| Activities v2 | TRACE-V2-01 (uppercase tracing), NUM-V2-01 (numbers >10), NUM-V2-02 (subtraction), PARENT-V2-01 (parent companion) | Deferred to v2 | Init 2026-05-02 |

## Session Continuity

Last session: 2026-05-02 — initialization
Stopped at: Roadmap created, all 61 v1 requirements mapped to 10 phases
Resume file: None
