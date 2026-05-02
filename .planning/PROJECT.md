# Hugrún

## What This Is

A focused Flutter app for Hugrún (age 5) that teaches Icelandic letters/reading and early numeracy. Two rooms — *Stafir* (letters) and *Tölur* (numbers) — built around four shared mechanics: tap-to-hear, tracing, matching, sequencing. Built for one child first, with the option to release publicly later.

## Core Value

A five-year-old can pick up a tablet, tap, and learn — discoverable through visuals and audio alone, with no failure states, no scores, no instructions to read.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- Current scope. Building toward these. v1 = MVP cut, full alphabet tap-to-hear. -->

**MVP (v1):**

- [ ] Single home screen with two rooms (*Stafir*, *Tölur*) — only *Stafir* active in v1
- [ ] Letter recognition: tap any of the 32 Icelandic letters, hear the letter name + an example word
- [ ] Pre-generated, baked-in Icelandic audio for all letters and example words (no runtime TTS, no network)
- [ ] Responsive tap feel: audio + visual reaction within ~50ms, no perceptible latency
- [ ] Built and runs on both iOS and Android tablets (Hugrún's tablet is the test device)
- [ ] Parent settings gate (hold-3-seconds) — present even if minimal in v1
- [ ] Personalization: parent can enter the child's name (used in voice-overs)
- [ ] No ads, no IAP, no analytics SDKs, no network calls during play

**Beyond MVP (still v1 scope, deferred to later phases):**

- [ ] Letter-to-word matching activity
- [ ] Letter tracing (CustomPainter, sampled at 60Hz, generous tolerance, soft stroke-order enforcement, Menntamálastofnun handwriting model)
- [ ] CVC word blending (*kýr, sól, hús, rós* — tap each letter, hear sound, hear blend)
- [ ] Numbers room: one-to-one correspondence, number recognition, subitizing 1–5, addition with objects, sequencing
- [ ] Personalization: parent uploads photos and tags them with Icelandic words
- [ ] Personalization: child's name appears in tracing exercises and voice-overs

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- **Live/runtime TTS** — quality variance and latency unacceptable; all audio baked at build time and shipped as static AAC assets.
- **Failure states, timers, scores, stars, points** — replaced with intrinsic feedback (animation, sound, completion). "Wrong" becomes "try again" with no penalty.
- **Text instructions anywhere** — five-year-olds can't read instructions. Everything discoverable via visuals/audio.
- **Ads / IAP / analytics SDKs** — parents will notice if it ever ships, and it will matter.
- **Rhyming games** — Icelandic inflectional endings make this harder than English; not where the leverage is at age 5.
- **Sentence-level reading** — out of scope for this age and milestone.
- **Anything graded or scored** — see Core Value.
- **Multiplayer / social features.**
- **Rewards systems, stickers, collectible mechanics.**
- **"Curriculum" framing or grade-level claims** — not what this app is.
- **Localization beyond Icelandic** — Icelandic-first is the entire point.
- **Multi-child support** — keep simple; one child, one device.
- **Cloud, sync, accounts, server** — fully local, no network during play.
- **Parent-companion review app** — possible future, not now.
- **Rive animation** — deferred until tracing/matching activities are in scope (out of MVP).

## Context

**Builder:** A parent building for their own child. Solo build. Co-play assumed — the app is most valuable when an adult is occasionally engaged; design for that, not against it.

**Audience:** Hugrún, age 5, Icelandic-speaking. The app is named after her.

**Why Icelandic-specific:** All 32 Icelandic letters in standard order, including *á, ð, é, í, ó, ú, ý, þ, æ, ö*. Order matches what schools teach. Number grammar is gendered and declines (*einn hundur* vs *eitt hús*) — at age 5, use masculine for abstract counting (matching school convention); use the correct gendered form when counting specific pictured objects. Don't try to teach the grammar — just be consistent.

**Personalization is the moat.** Big apps can't put your dog and your child's name into the content. This app can. Generic content gets the app to "fine"; personalization gets it to "sticky."

**The build-first principle:** A single screen — tap one letter (*h*), hear it, see *hundur*, hear the word — with responsiveness, audio timing, and visual feedback dialed in is ~80% of what makes a kids' app feel good vs. cheap. If Hugrún plays with that one screen for ten minutes, there's something here. If she taps once and walks away, the rest of the app won't save it.

**Audio strategy (TTS):** All ~200–400 short clips pre-generated at build time, manually reviewed for pronunciation, bundled as compressed AAC. Generation pipeline: YAML utterance manifest → TTS API → AAC files → loudness normalization (`ffmpeg-normalize`) → Flutter asset map. Mispronunciations get manual overrides via SSML or `ice-g2p` phoneme spelling.

**TTS providers (v1 evaluates two):** Tiro TTS (`tts.tiro.is`) — Icelandic government-funded, neural, free, voices Diljá v2 / Álfur v2 / Bjartur / Rósa, default starting point. ElevenLabs — commercial multilingual, evaluated in parallel for v1; commercial/kids-app licensing must be checked before relying on it. One primary "narrator" voice for the whole app.

**Imagery:** Created or sourced by the assistant during build (illustrate or download licensed/free images). Parent-supplied photos override per-tag once personalization ships.

## Constraints

- **Tech stack — Flutter**: Cross-platform from day one (iOS + Android). Hugrún's tablet is the test device.
- **State management — Riverpod**: User-specified. Replaces any other state library mentioned in earlier notes.
- **Persistence — Drift (SQLite)**: User-specified. Replaces the Hive/Isar mention from the original plan.
- **Audio runtime — `just_audio` + `Ticker`**: For sync between audio and animation. Pre-loaded into memory, no disk read latency mid-tap, no network calls during play. Ever.
- **Animation — Rive (deferred), CustomPainter for tracing (deferred to post-MVP)**: Tracing requires full control; Rive for character animation when activities expand.
- **Testing — TDD with Marionette for E2E**: Test-driven development is the default workflow. Write unit/widget tests before implementation (red → green → refactor). Use Marionette as the end-to-end test framework for Flutter UI verification. Every phase plan should sequence test tasks before implementation tasks.
- **Privacy / safety**: No ads, no IAP, no analytics SDKs, no network calls during play, no accounts, no cloud, no sync.
- **Timeline**: ASAP playable for Hugrún. MVP cut is steps 1–2 of the build order (tap-to-hear prototype + full alphabet coverage). Other activities follow only after the loop is dialed in.
- **Audio quality**: Every clip loudness-normalized so no clip is louder than another. Manual pronunciation review pass required for every utterance. Mispronunciations get an entry in `pronunciation_overrides.yaml`.
- **Child UX bars**: Tap response < ~50ms perceived. No fail states. No timers. No scores. No text instructions. Forgiveness > correctness.

## Key Decisions

<!-- Decisions that constrain future work. Add throughout project lifecycle. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter for cross-platform | iOS + Android from day one; one codebase | — Pending |
| Riverpod for state | User specified | — Pending |
| Drift (SQLite) for persistence | User specified, overrides original Hive/Isar plan | — Pending |
| Pre-baked TTS audio (no runtime calls) | Avoids network, latency, quality variance; manual review pass possible | — Pending |
| Tiro + ElevenLabs evaluated in parallel for v1 | Best-of-both decision deferred until clips can be A/B'd | — Pending |
| MVP = build steps 1–2 only (tap-to-hear, full alphabet) | "ASAP playable" — ship the loop first, expand only if it lands | — Pending |
| App named "Hugrún" (= the child's name) | The app is for one child first; name reinforces personalization-as-moat | — Pending |
| Both iOS + Android from day one | Future-proof; child's tablet may change; testing on both validates platform abstractions early | — Pending |
| Personalization as the differentiating moat | Generic content = "fine"; child's dog, toys, name = "sticky" | — Pending |
| Skip Rive in MVP | Tap-to-hear MVP doesn't need character animation; defer until activities expand | — Pending |
| TDD as default workflow | User-specified; tests precede implementation in every phase plan | — Pending |
| Marionette for E2E tests | User-specified; Flutter-native E2E framework, parallelizable via marionette-verify skill | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-02 after initialization*
