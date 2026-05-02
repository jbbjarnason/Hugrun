---
phase: 1
plan: 04
subsystem: marionette-e2e
tags: [e2e, marionette, blocked, checkpoint]
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified: []
decisions: []
metrics:
  duration: 0
  tasks: 0 of 3 (CHECKPOINT BLOCKED at Task 1)
  tests: 0
  completed: 2026-05-02 (BLOCKED)
---

# Phase 1 Plan 04: Marionette E2E Summary

## Status: BLOCKED at Task 1 CHECKPOINT

Per Plan 04 Task 1, the executor must verify the Marionette package exists on pub.dev and matches an E2E test framework description before proceeding to Task 2 (installation + scaffolding).

## Findings (verification)
Searched pub.dev as of 2026-05-02 with the following results:

| Package | Status | Description |
|---|---|---|
| `marionette` | **does not exist** (pub.dev returns NoSuchKey / 404) | — |
| `marionette_flutter` v0.5.0 (Apr 2026, leancodepl) | exists, **wrong purpose** | "Flutter extensions for AI agent interaction via MCP — lets Claude, Copilot, and Cursor tap, scroll, type, and screenshot your app." This is an **MCP-based AI agent tool**, not a scripted E2E test framework. |
| `flutter_marionette` v0.2.0 (2019, abandoned) | exists, **incompatible** | Dart 2.x SDK constraint (`>=2.1.0 <3.0.0`); incompatible with Dart 3.10.7. Last published 2019. |
| `marionette_mcp`, `marionette_cli`, `marionette_logger`, `marionette_logging` | various | All part of the same `leancodepl/marionette_mcp` MCP-tooling family — none are E2E test frameworks. |

## Why this is escalated rather than auto-substituted
Per the orchestrator's `<critical_constraints>` (#2) for this Phase 1 execution:

> Plan 04 has a checkpoint — `marionette` package name on pub.dev must be verified before installation. If the package doesn't exist or doesn't match an E2E framework description, stop and report to the orchestrator. **Do NOT substitute** with a different E2E framework (e.g., patrol) — the user explicitly mandated Marionette.

`marionette_flutter` is an AI-agent automation harness rather than a scripted E2E framework. It's possible the user actually wants this — there is a real workflow where AI agents (Claude / Copilot) drive the app via MCP for end-to-end-like verification, including the [`marionette-verify` skill mentioned in PROJECT.md key decisions](../../PROJECT.md). The PROJECT.md note "Marionette for E2E tests... Flutter-native E2E framework, parallelizable via marionette-verify skill" — combined with the maintainer being `leancodepl/marionette_mcp` — strongly suggests this **is** the package the user means.

But CONTEXT D-09 explicitly anticipates this uncertainty:
> install Marionette as a dev_dependency (latest stable from pub.dev — verify name and version at install time; if naming differs from `marionette`, document in CONTEXT or escalate). Marionette is the user's mandated E2E framework.

**Decision required from user:** approve `marionette_flutter ^0.5.0` (the leancodepl MCP-based agent harness) as the Phase 1 Marionette implementation, OR escalate to `/gsd-discuss-phase` for a project-level review.

## What was NOT done in Plan 04
- No `marionette` / `marionette_flutter` package added to pubspec.yaml
- No `marionette/smoke.marionette.dart` created
- No `integration_test/marionette_smoke_test.dart` created
- No `test_driver/integration_driver.dart` created
- No `tools/run-marionette.sh` created
- `.github/workflows/ci.yml` `marionette-e2e` job is guarded with `if: false` (Plan 05 detail)

When this checkpoint is resolved, Plan 04 Task 2 + Task 3 can be executed straightforwardly: install the approved package, scaffold the smoke test using the provided plan, and run on iPad Air simulator + Pixel Tablet AVD.

## Commits
None. (No work performed past the blocking checkpoint.)

## Status
**BLOCKED.** All Plan 04 deliverables awaiting user decision on Marionette package identity.
