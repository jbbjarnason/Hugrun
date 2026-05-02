# Project Research Summary

**Project:** Hugrún — Icelandic literacy + numeracy app for Hugrún (age 5)
**Domain:** Offline-first Flutter kids' educational app, single-device, no accounts
**Researched:** 2026-05-02
**Confidence:** HIGH on stack and architecture; HIGH on features and pitfalls for alphabet room; MEDIUM on Tiro TTS API specifics (auth/rate limits not fully verified)

---

## Executive Summary

Hugrún is an offline-first Flutter app for a 5-year-old Icelandic-speaking child, built around a single loop that research confirms is the right foundation: tap a letter, hear it, see an example word. The product is best understood as a personalized Icelandic equivalent of Endless Alphabet — same no-fail philosophy, same tap-to-hear feel, but built for a real child with her actual name, photos, and environment as content. No competitor in the Icelandic market combines the full 32-letter MMS-ordered alphabet, zero-gamification philosophy, co-play design, and child-specific personalization. That gap is the moat.

The recommended approach is build-first, not feature-first. The highest-leverage work is the audio pipeline and tap-to-hear mechanic, because every subsequent activity inherits the quality bar set there. The stack is Flutter 3.41 + Riverpod codegen + Drift + just_audio, all user-locked and well-suited to this app. The single most important pre-build decision is **do not use ElevenLabs**: their Prohibited Use Policy explicitly bans apps targeting children under 13. This is a terms of service violation regardless of plan tier, not a gray area. Tiro TTS (Icelandic government-funded, Apache 2.0, Diljá v2 voice) is the correct and only compliant choice.

The primary risks are not technical — they are content quality risks. A single mispronounced `ð` or `þ`, a wrong alphabet order, or audio clips that vary in loudness will undermine trust faster than any missing feature. The mitigation is mandatory 100% native-speaker review of every clip before bundling, a hardcoded loudness normalization pass (-19 LUFS / -1 dBTP for kids-on-tablets), and a `pronunciation_overrides.yaml` file established from day one. The roadmap must treat the TTS pipeline as infrastructure, not a deliverable — it must be complete and reviewed before the MVP ships.

---

## Key Findings

### Recommended Stack

Flutter 3.41.5 (pinned via `fvm`) with Riverpod 4.x code generation, Drift 2.32+, and just_audio 0.10.x is the complete, compatible, and sufficient stack. The codegen triad (riverpod_generator + drift_dev + freezed) all run through build_runner, making the marginal cost of each generator near zero. `flutter_gen_runner` is critical at 200-400 audio clip scale — string-based asset paths produce silent failures on specific letters that are nearly impossible to debug.

The audio pipeline runs entirely outside Flutter: Python script reads `manifest.yaml`, calls Tiro TTS for raw PCM, runs `ffmpeg-normalize` at -19 LUFS / -1 dBTP mono, encodes to AAC-LC 96 kbps 48 kHz M4A, and emits a generated Dart manifest. The generated `audio_manifest.g.dart` is committed to git so Flutter builds are reproducible without Python. This decoupling is architecturally significant — it allows audio work and Flutter work to proceed in parallel.

**Core technologies:**
- Flutter 3.41.5 + Dart 3.9 — app framework, iOS + Android; pin via fvm to prevent SDK churn
- Riverpod 4.x with codegen (`@riverpod` annotations) — eliminates boilerplate, automatic scoping, test-overridable
- Drift 2.32+ with drift_flutter — reactive streams pair naturally with Riverpod; explicit migrations protect Hugrún's data
- just_audio 0.10.x + audio_session 0.2.x — warm player pool achieves <50ms tap-to-audio; custom audio session config avoids iOS/Android edge cases
- freezed 3.x — immutable domain models and sealed state machines
- flutter_gen_runner 5.x — type-safe asset references; mandatory at 200+ audio clip count
- Tiro TTS (Diljá v2, Apache 2.0) — best-in-class Icelandic neural voice, free, government-funded, no under-13 restrictions
- ffmpeg-normalize — EBU R128 at -19 LUFS; mandatory pipeline step
- fvm — Flutter SDK version pinning; solo project insurance against SDK churn
- Marionette — E2E test framework (per project constraint)

**Do not use:**
- ElevenLabs — Prohibited Use Policy explicitly bans apps targeting children under 13; not a gray area
- just_audio_background — kids app needs no background audio; adds App Store review red flags
- go_router — two screens do not warrant a routing framework; Navigator 1.0 with MaterialPageRoute is correct
- Any analytics SDK — prohibited by Apple Kids Category guidelines and PROJECT.md constraint
- sqlite3_flutter_libs directly — drift_flutter handles this since Drift 2.32

### Expected Features

**Must have — MVP table stakes:**
- All 32 Icelandic letters in MMS order (a á b d ð e é f g h i í j k l m n o ó p r s t u ú v x y ý þ æ ö) — no C Q W Z
- Tap-to-hear: letter name + example word, ≤50ms perceived latency, re-tap cancels and restarts current clip
- Pre-baked AAC audio, 100% native-speaker reviewed, loudness-normalized at -19 LUFS
- Zero-fail interaction — wrong tap is no-op; no negative feedback of any kind
- No text instructions anywhere — 5-year-olds cannot read UI copy
- Tap targets ≥ 2cm × 2cm physical (validate on actual tablet)
- Parent gate: 3-second hold with visual ring fill
- Child name capture for personalized voice-overs
- Offline, no ads, no IAP, no analytics, no network during play

**Should have — v1 scope post-MVP:**
- Letter-to-word matching activity (3 candidate images, personalized photo hook ~40% frequency)
- Letter tracing (Ítalíuskrift lowercase, generous 25-35px tolerance, soft stroke-order, no fail state)
- CVC blending (kýr/sól/hús/rós + bók/mús/hár/gás — letter taps play phonemes, narrator blends)
- Numbers room: tap-to-hear numerals → sequencing 1-5 → one-to-one correspondence → subitizing 1-5 → addition sums-to-5
- Photo-tagged personalization: curated ~200-noun Icelandic lexicon
- Phoneme audio set (separate from letter-name set — required for CVC blending)
- Gendered number audio: 5 numerals × 3 genders for 1-4 (5+ does not decline)

**Differentiators (competitive moat):**
- Personalization with parent-supplied photos — no Icelandic-market competitor does this
- Child name in voice-overs — makes the app feel built for her, because it was
- Co-play design — every Icelandic competitor assumes solo use
- Full 32 letters including ð, þ, æ, ö at equal audio quality
- Single narrator voice (Diljá v2) across the whole app — sonic identity

**Hard anti-features:**
- Stars, scores, streaks, points, levels, unlock mechanics
- Timers on child responses
- Voice recognition / microphone input
- Multiple narrator voices, character avatars, story mode
- Parent dashboard or progress reports
- Adaptive difficulty algorithms

**Defer to v2+:**
- Free-text photo tagging (parent types Icelandic word + runtime TTS)
- Uppercase letterforms in tracing
- Numbers beyond 10
- Public release infrastructure (privacy policy, Kids Category, TestFlight, support email)

### Architecture Approach

Feature-first with a shared `mechanics/` layer. Four mechanic primitives (TapToHear, Tracing, Matching, Sequencing) are top-level peers of `features/`, not nested inside any room. Domain layer is pure Dart with no Flutter imports. AudioEngine is a singleton warm-pool service initialized at app start, never lives in a widget build method, never auto-disposes, always available via root-scoped Riverpod provider.

**Major components:**
1. `AudioEngine` (core/audio) — warm AudioPlayer pool (4 players); `play(key)` fires in <30ms; `warmCache(keys)` pre-loads room assets
2. `AudioManifest` (core/manifest + gen/) — generated `const Map<UtteranceKey, AudioAsset>`; zero runtime parse cost; committed to git
3. `AppDatabase` (core/db) — Drift singleton with stepwise migrations from v1; child_profile only in MVP; photo_tags + activity_log added in v2
4. Riverpod hierarchy — three concentric scopes: app-scoped, room-scoped (auto-dispose), activity-scoped
5. Mechanic widgets (mechanics/) — generic, room-agnostic; never import from features/
6. Feature rooms (features/) — compose mechanics + room-specific layout
7. Python TTS pipeline (tools/) — runs outside Flutter; emits audio_manifest.g.dart and AAC files

**Critical architectural insight:** The hand-written 2-3 clip audio manifest stub (with placeholder AAC files) is the single highest-leverage unblock. It decouples Flutter development from the Python pipeline.

**Key patterns:**
- Generated compile-time audio manifest over runtime JSON parse
- Warm player pool over per-tap AudioPlayer creation — mandatory for <50ms tap-to-audio
- Riverpod scoped overrides — room entry triggers warmCache; room exit auto-disposes room state
- Drift stepwise migrations from day one
- TDD throughout: unit/widget tests precede implementation; Marionette for E2E

### 11 Critical Findings

**Finding 1: ElevenLabs is off the table.**
Their Prohibited Use Policy: "Users are prohibited from...using the Services to make available bundled solutions that target anyone under the age of 13." Hugrún is 5. ToS violation regardless of plan tier. Tiro TTS (Diljá v2) is the correct and only compliant choice. Microsoft Azure Neural TTS (Gudrun/Gunnar) is a fallback if Tiro quality is ever insufficient.

**Finding 2: Mandatory 100% native-speaker review of every audio clip.**
Not spot-checks. Every clip, with headphones, in a quiet room, by a native Icelandic speaker. Pipeline must require a `reviewed: true` flag before emitting final asset bundle. A single botched `ð` or `þ` destroys trust immediately.

**Finding 3: Icelandic alphabet is 32 letters in a specific order.**
Modern school convention: a á b d ð e é f g h i í j k l m n o ó p r s t u ú v x y ý þ æ ö. No C, Q, W, Z. Store as `kIcelandicAlphabet` constant with unit test asserting 32 letters in correct order. Source from current MMS textbook, not Wikipedia.

**Finding 4: Tap latency <50ms requires AudioPlayer pre-warming.**
Creating an AudioPlayer per tap costs 100-300ms on Android. Pre-warm: allocate 2-4 players at app start, play silent clip on first player to activate iOS AVAudioSession, pad clips with 20-50ms leading silence. Visual feedback fires synchronously with gesture, independent of audio.

**Finding 5: Audio normalization at -19 LUFS / -1 dBTP mono.**
Not -16 LUFS (streaming) — children + tablets at 100% volume produce 90+ dB SPL near face. Mono because single narrator. Apply after silence padding. Reject clips deviating >±0.5 LU.

**Finding 6: Riverpod 3.x vs 4.x is mid-migration.**
flutter_riverpod 3.3.1 stable, but riverpod_generator 4.0.3 requires riverpod 4.x. Run `dart pub outdated` at creation, pin consistent family. Do not mix riverpod_annotation 4.x with flutter_riverpod 3.x.

**Finding 7: drift_flutter 0.3.0 replaces sqlite3_flutter_libs.**
Use only `drift_flutter: ^0.3.0`. Adding `sqlite3_flutter_libs` directly causes version conflicts with sqlite3 4.x.

**Finding 8: AudioPlayer must never live in widget build, autoDispose, or per-tap scope.**
Top-level non-autoDispose Provider in main(). Use `ref.watch(provider.select(...))` for granular subscriptions. Pin Riverpod to known-good version.

**Finding 9: Drift schema migrations from Phase 0.**
`drift_dev schema dump` after v1 release; commit snapshots; bump schemaVersion for any change; write tests using `schemaAt(N)`. No cloud backup by design — migration failure loses Hugrún's personalization permanently.

**Finding 10: Tracing tolerance must be calibrated on Hugrún.**
5yo motor research: tolerance band ~50-60% of stroke width on each side; soft stroke-order (visual hint, never hard rejection); generous endpoint snap (~30% of stroke length). CustomPainter requires RepaintBoundary isolation and shouldRepaint=false unless stroke buffer changed.

**Finding 11: App Store Kids Category compliance requires explicit planning.**
Photo upload triggers Apple Guideline 5.1.4(b) — parental consent beyond 3-second gate required for collecting photos from minors. Crash reporting SDKs (Sentry, Firebase Crashlytics) restricted in Kids Category. Use iOS MetricKit / Android Play Console crash reports. Privacy policy required before submission.

---

## Implications for Roadmap

### Suggested Phase Structure

**Phase 0: Foundation**
Rationale: Three decisions must be locked before any content or code can be built correctly — alphabet canonical order, asset path conventions, Drift schema versioning policy.
Delivers: Project skeleton, `kIcelandicAlphabet` constant + unit test, asset naming conventions (lowercase, ASCII-safe, e.g. `eth.aac`), Drift schema v1 with migration scaffolding, ProviderScope + MaterialApp, two empty room pages, fvm pin, build.yaml codegen config, Marionette E2E harness.
Avoids: Pitfalls 2 (alphabet order), 8 (Drift migrations), 12 (parameterization), 20 (asset case-sensitivity).
Research flag: Standard patterns — skip phase research.

**Phase 1: TTS Pipeline + Tap-to-Hear MVP**
Rationale: This is the entire product bet. The tap-to-hear loop quality bar is inherited by every subsequent activity.
Delivers: Python TTS pipeline (manifest.yaml → Tiro Diljá v2 → ffmpeg-normalize → AAC → audio_manifest.g.dart), 100% native-speaker reviewed audio for all 32 letters + 32 example words, AudioEngine warm pool, TapToHearTile mechanic, Stafir room full 32-letter grid, parent gate, child name capture.
Avoids: Pitfalls 1 (mispronunciation), Finding 1 (ElevenLabs), 4 (latency), 5 (loudness), 6 (failure feedback), 7 (Riverpod/audio lifecycle), 13 (bundle), 15 (pacing).
Research flag: Verify Tiro TTS auth and voice ID strings via curl before pipeline build.

**Phase 2: Activities — Letter Matching + CVC Blending**
Rationale: Shares Phase 1 quality bar. CVC blending requires phoneme audio set distinct from letter-name clips. Matching is the natural first home for personalized photos.
Delivers: Letter-to-word matching mechanic, CVC blending for 8 starter words, phoneme audio set for all 32 letters.
Research flag: Standard patterns.

**Phase 3: Letter Tracing**
Rationale: Requires Ítalíuskrift letterform SVG paths and real-hardware tolerance testing on Hugrún.
Delivers: Full letter tracing with CustomPainter, Ítalíuskrift lowercase, generous tolerance, soft stroke-order, completion celebration with child name.
Research flag: Needs `/gsd-research-phase` — Ítalíuskrift digitization approach, Impeller behavior with complex Path operations on iOS.

**Phase 4: Numbers Room**
Rationale: Reuses TapToHearTile from Stafir. Gender grammar data model must be designed before any number content is recorded.
Delivers: Tölur room with tap-to-hear numerals, sequencing 1-5, one-to-one correspondence, subitizing 1-5, addition sums-to-5; gendered number audio clips.
Avoids: Pitfall 10 (number grammar gender).
Research flag: Standard patterns.

**Phase 5: Personalization — Photo System**
Rationale: Photo picker + tag UI; delivers the moat feature.
Delivers: Parent photo upload + Icelandic-word tagging UI, curated ~200-noun lexicon, photo-enhanced matching and numeracy, Drift v2 migration (photo_tags + activity_log).
Research flag: Standard patterns. App Store compliance review if public release planned.

**Phase 6: Public Release (conditional)**
Rationale: Not required for Hugrún. Deliberate decision with compliance and support obligations.
Delivers: Privacy policy, Kids Category decision, TestFlight beta, native-speaker QA pass.
Research flag: Needs `/gsd-research-phase` — Apple's 2025 Kids Category guideline changes.

### Phase Ordering Rationale

- Phase 0 must precede everything: alphabet constant + asset conventions are wiring every phase depends on
- Phase 1 is the product bet: quality bar inherited by all activities
- Phases 2 and 3 independent; recommended 2 then 3 (matching < tracing complexity)
- Phase 4 after Phase 3 matches PROJECT.md deferred scope; Tölur reuses Phase 1 mechanics
- Phase 5 can overlap Phase 4 on parent-UI side
- Phase 6 is a deliberate decision point

### Research Flags

Needs `/gsd-research-phase` before planning:
- **Phase 3 (Tracing):** Ítalíuskrift digitization; Impeller behavior with complex Path operations
- **Phase 6 (Public Release):** Apple's 2025 Kids Category updates; parental consent UI for photo collection

Standard patterns: Phase 0, 1, 2, 4, 5

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against pub.dev; Riverpod 3.x vs 4.x — verify at pub get time |
| Features | HIGH | Global app patterns documented; Icelandic market sufficient for differentiation |
| Architecture | HIGH | Verified via Context7 and official docs |
| Pitfalls | HIGH | Tech and UX well-sourced; Tiro auth/rate limits MEDIUM |

**Overall confidence:** HIGH

### Gaps to Address

- **Tiro TTS auth and rate limits:** Verify via curl before Phase 1 pipeline build
- **Riverpod 3.x vs 4.x:** Run `dart pub outdated` at project creation; pin consistent family
- **Ítalíuskrift letterform assets:** No published SVG path library; plan 1-2 days design work before Phase 3
- **LUFS target calibration:** -19 LUFS is reasoned starting point; tune via listening test on Hugrún's tablet
- **ElevenLabs decision closure:** Log as Key Decision in PROJECT.md before Phase 1 to prevent re-entry of parallel-evaluation plan

---

## Sources

### Primary (HIGH confidence)
- pub.dev packages — version verification
- docs.flutter.dev/release/release-notes — Flutter 3.41.5 stable
- github.com/icelandic-lt/tiro-tts — voices, formats, SSML, Apache 2.0
- elevenlabs.io/use-policy — Prohibited Use Policy
- github.com/slhck/ffmpeg-normalize — EBU R128
- drift.simonbinder.eu/migrations — stepByStep strategy
- Apple App Review Guidelines 1.3, 5.1.4
- Frontiers in Psychology 2018 "Child-Centered Design"
- Nielsen Norman Group child UX research

### Secondary (MEDIUM confidence)
- repository.clarin.is — Tiro TTS archive
- github.com/ryanheise/just_audio issues — preload, latency
- graphogame.com/blog — Iceland impact
- primarium.info — Ítalíuskrift model
- codewithandrea.com — Flutter project structure

### Tertiary (LOW confidence / requires live verification)
- Tiro TTS auth and rate limits — requires live curl verification
- Riverpod 4.x stable status — mid-migration

---

*Research completed: 2026-05-02*
*Ready for roadmap: yes*
