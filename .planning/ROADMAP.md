# Roadmap: Hugrún

## Overview

Hugrún is built outward from a single high-quality loop: tap a letter, hear it, see and hear the example word. The roadmap front-loads the foundations that everything else inherits — Drift schema versioning, the canonical 32-letter Icelandic alphabet, asset path conventions, a hand-written audio manifest stub, the Python TTS pipeline with mandatory native-speaker review, and a warm-pool AudioEngine. By the end of Phase 3, Hugrún (the child) can pick up the tablet and tap any of the 32 letters to hear the letter name and example word at sub-50ms latency — that is the MVP cut and the moment the project is "playable." Phases 4–6 expand Stafir into matching, CVC blending, and tracing. Phases 7–8 build the Tölur (numbers) room with tap-to-hear, subitizing, one-to-one correspondence, and addition. Phase 9 lands the moat: parent-supplied photos tagged with Icelandic words that override stock imagery in matching and numeracy. Public release (REL-*) is deliberately deferred to v2.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Skeleton & Drift Schema** - Flutter project bootstrap, Riverpod root scope, Drift v1 schema with stepwise migrations, two-room home shell, Marionette E2E harness
- [ ] **Phase 2: Alphabet, Asset Conventions & Manifest Stub** - Canonical 32-letter Icelandic constant, lowercase ASCII asset paths, hand-written `audio_manifest.g.dart` with placeholder clips that unblocks AudioEngine work
- [ ] **Phase 3: TTS Pipeline & Audio Review Tooling** - Python pipeline (Tiro Diljá v2 → ffmpeg-normalize → AAC → generated Dart manifest) with `pronunciation_overrides.yaml`, review UI, and mandatory `reviewed: true` gate
- [ ] **Phase 4: Stafir Tap-to-Hear MVP** - Warm-pool AudioEngine, 32-letter grid with letter-name + example-word playback, parent gate, child name capture — the "playable" milestone
- [ ] **Phase 5: Letter-to-Word Matching** - Image-prompt with 4 letter options in Stafir, no-fail wrong taps, celebratory correct taps, hooks ready for Phase 9 photos
- [ ] **Phase 6: CVC Blending & Phoneme Audio Set** - Separate phoneme audio set for all 32 letters, 8+ starter words (kýr, sól, hús, rós, bók, mús, hár, gás), tap-to-blend mechanic
- [ ] **Phase 7: Letter Tracing (Ítalíuskrift)** - CustomPainter tracing surface, lowercase Ítalíuskrift letterforms for all 32 letters, calibrated tolerance, soft stroke-order, completion celebration with child name
- [ ] **Phase 8: Tölur Tap-to-Hear & Sequencing** - Numbers room with digits 1–10, gendered audio for 1–4, sequencing activity, school-convention masculine for abstract counting
- [ ] **Phase 9: Numeracy Activities (One-to-One, Subitizing, Addition)** - One-to-one correspondence, subitizing 1–5, addition with objects (no `+` symbol), all under no-fail rules
- [ ] **Phase 10: Personalization — Photo System** - Parent photo upload + Icelandic-word tagging, curated lexicon, photo overrides for matching and numeracy, Drift v1→v2 migration with `schemaAt(1)` round-trip test

## Phase Details

### Phase 1: Skeleton & Drift Schema
**Goal**: A runnable Flutter app on iOS and Android with the architectural foundations in place — Riverpod root scope, Drift v1 schema with migration scaffolding, two-room home shell, parent-gate primitive, and a green Marionette E2E smoke test — so every subsequent phase has somewhere to land.
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-06, FOUND-07, FOUND-08, FOUND-09, FOUND-10, FOUND-11
**Success Criteria** (what must be TRUE):
  1. `flutter run` launches the app on a connected iOS tablet and an Android tablet from the same codebase, with the Flutter SDK pinned via `fvm`
  2. The home screen shows two visible rooms (Stafir, Tölur); tapping Stafir opens a placeholder room and tapping Tölur opens a placeholder room
  3. The app has a 3-second hold-to-open parent gate primitive with a visible ring-fill that gates a stub parent settings screen
  4. A Marionette E2E smoke test runs in CI on both iOS and Android, opens the app, and asserts the home screen renders both rooms
  5. CI pipeline runs `flutter test` on every commit, and a CI check on `pubspec.lock` fails the build if any analytics, ads, or IAP SDK is added
**Plans**: 5 plans
- [ ] 01-01-PLAN-bootstrap.md — Flutter create + pubspec pinning + Icelandic locale + ProviderScope + D-07 directory skeleton + first widget test (TDD RED→GREEN)
- [ ] 01-02-PLAN-database.md — Drift v1 child_profiles table + DAO + bootstrap (default 'Hugrún') + schemaAt(1) snapshot + Riverpod provider
- [ ] 01-03-PLAN-rooms-and-gate.md — Two-room home shell + StafirRoom/TolurRoom/ParentSettingsScreen placeholders + ParentGate widget primitive (3s hold + ring fill, no haptics)
- [ ] 01-04-PLAN-marionette-e2e.md — Marionette package install (verify name on pub.dev) + smoke test green on iPad Air simulator + Pixel Tablet AVD
- [ ] 01-05-PLAN-ci-and-guards.md — GitHub Actions 3-job CI + check-no-tracking.sh (block 9 banned SDKs) + NoNetworkHttpOverrides integration test + check-flutter-version.sh + check-domain-purity.sh
**UI hint**: yes

### Phase 2: Alphabet, Asset Conventions & Manifest Stub
**Goal**: Lock the three decisions every later phase depends on — the canonical 32-letter Icelandic alphabet, lowercase ASCII-safe asset path conventions, and a hand-written audio manifest stub with 2–3 placeholder AAC clips — so AudioEngine and Stafir UI work can proceed in parallel with Phase 3's Python pipeline.
**Depends on**: Phase 1
**Requirements**: FOUND-04, FOUND-05
**Success Criteria** (what must be TRUE):
  1. A `kIcelandicAlphabet` constant exists with all 32 letters in MMS school order (a á b d ð e é f g h i í j k l m n o ó p r s t u ú v x y ý þ æ ö); a unit test asserts the exact order and the absence of C/Q/W/Z
  2. A generated asset manifest enforces lowercase ASCII-safe paths (e.g. `eth.aac` for ð, `ae.aac` for æ); a CI check fails the build on any non-ASCII or uppercase asset filename
  3. `lib/gen/audio_manifest.g.dart` is committed to git with at least 3 placeholder entries (e.g. `letterA`, `letterH`, `wordHundur`) and matching placeholder AAC files in `assets/audio/`, so Flutter widget code can compile and reference real `UtteranceKey`s before the Python pipeline exists
**Plans**: 3 plans
- [ ] 02-01-PLAN-alphabet.md — IcelandicLetter freezed model + kIcelandicAlphabet (32 letters MMS order) + D-04 exhaustive tests + lib/core/alphabet domain-purity wiring (TDD RED→GREEN→REFACTOR)
- [ ] 02-02-PLAN-manifest-stub.md — assets/ folder skeleton (D-05) + 5 placeholder AAC clips + UtteranceKey enum + AudioAsset + hand-written lib/gen/audio_manifest.g.dart + D-11 tests
- [ ] 02-03-PLAN-asset-paths-guard.md — tools/check-asset-paths.sh (D-06) + self-test with bad/good fixtures (D-07) + CI wiring into analyze-and-test (D-14, D-15)

### Phase 3: TTS Pipeline & Audio Review Tooling
**Goal**: A reproducible Python pipeline that turns `manifest.yaml` into 100% native-speaker-reviewed, loudness-normalized AAC clips and a regenerated `audio_manifest.g.dart`, with `pronunciation_overrides.yaml` available from day one and a review UI that gates final asset bundling on entry-by-entry reviewer sign-off.
**Depends on**: Phase 2
**Requirements**: AUDIO-01, AUDIO-02, AUDIO-03, AUDIO-04, AUDIO-05, AUDIO-06, AUDIO-07, AUDIO-08, AUDIO-09, AUDIO-10
**Success Criteria** (what must be TRUE):
  1. Running `make audio` reads `tools/tts_pipeline/manifest.yaml`, calls Tiro TTS with the Diljá v2 voice for each entry, applies any `pronunciation_overrides.yaml` SSML/phoneme substitutions, runs `ffmpeg-normalize` to -19 LUFS / -1 dBTP, encodes AAC-LC mono 96 kbps 48 kHz M4A with 20–50 ms leading silence padding, and emits an updated `lib/gen/audio_manifest.g.dart`
  2. The pipeline rejects the asset bundle (non-zero exit) if any clip lacks a `reviewed: true` flag or if any clip deviates more than ±0.5 LU from the -19 LUFS target after normalization
  3. A review UI (HTML page or Flutter screen) plays each clip alongside its label and lets a native-speaker reviewer mark each entry reviewed; reviewer sign-off persists into the manifest
  4. Tiro TTS auth, voice ID strings (Diljá v2), and rate limits are verified via live curl call and documented in `tools/tts/README.md`
**Plans**: 7 plans
- [ ] 03-01-PLAN-tooling-and-tiro-spike.md — ffmpeg + ffmpeg-normalize install, Python deps, Tiro TTS verification spike (D-06, D-28, D-29) with human-verify checkpoint on Tiro reachability + Diljá v2 sanity check
- [ ] 03-02-PLAN-manifest-yaml-and-overrides.md — manifest.yaml (65 entries: 32 letter_name + 32 example_word + welcome) + pronunciation_overrides.yaml (empty) + reviewed.yaml (empty) + tools/tts/schema.py validators (D-04, D-13, D-17, D-22)
- [ ] 03-03-PLAN-tiro-client-and-normalize.md — TDD: tools/tts/tiro_client.py (rate limit, retry, override priority, caching) + tools/tts/normalize.py (ffmpeg-normalize wrapper, ±0.5 LU reject, silence pad, AAC-LC mono 96k 48k)
- [ ] 03-04-PLAN-bake-and-manifest-writer.md — tools/tts/bake_audio.py orchestrator (plan/generate/normalize/review-gate/manifest stages, per-utterance atomic) + tools/tts/manifest_writer.py (Jinja2 → audio_manifest.g.dart + utterance_key.dart, D-22 backward compat)
- [ ] 03-05-PLAN-review-ui.md — tools/tts/review_server.py (stdlib http.server, 127.0.0.1:8765, Approve / Re-record / Bulk-approve, atomic YAML writes) + HTML/CSS/JS templates
- [ ] 03-06-PLAN-ci-manifest-sync-guard.md — tools/check-manifest-sync.sh + self-test wired into analyze-and-test job (D-23, D-24); has Phase-3-not-yet-baked carve-out
- [ ] 03-07-PLAN-bake-and-review-pass.md — Run pipeline end-to-end against live Tiro → 65 AAC clips → review pass (HUMAN-VERIFY checkpoint) → regenerate audio_manifest.g.dart + utterance_key.dart with all 65 entries → atomic ship commit

### Phase 4: Stafir Tap-to-Hear MVP
**Goal**: Hugrún can pick up the tablet, open Stafir, and tap any of the 32 letters to hear the letter name followed by an example word and see the matching image — at sub-50ms perceived latency, with no fail states, no scores, no text, and no audio overlap. Parent can enter Hugrún's name in settings and the app uses it in at least one voice-over. **This is the MVP "playable" milestone.**
**Depends on**: Phase 3
**Requirements**: STAFIR-01, STAFIR-02, STAFIR-03, STAFIR-04, STAFIR-05, STAFIR-06, STAFIR-07, STAFIR-08, STAFIR-09, STAFIR-10, PERS-01, PERS-02, PERS-03
**Success Criteria** (what must be TRUE):
  1. The Stafir room shows all 32 letters in MMS order on a single screen with each tap target ≥2 cm × 2 cm physical on Hugrún's tablet; visual feedback (scale + color) fires synchronously with the tap independent of audio readiness
  2. Tapping any letter plays the letter name within ≤50 ms perceived latency (verified by 240 fps camera test on real hardware) followed by an example word with a matching image; re-tapping the same letter cancels and restarts from the letter name; tapping a different letter cancels the current clip and starts the new one — no audio overlap ever
  3. Each of the 32 letters has at least one example-word audio clip and matching image where the example word starts with the target letter (in IPA-equivalent terms, e.g. *þrír* for þ); the AudioEngine warms a pool of ≥2 AudioPlayer instances at app start and never creates one per tap
  4. There are zero text instructions visible to the child anywhere in Stafir, no failure states, no scores, no timers, and no progress indicators visible to the child
  5. Parent can enter the child's name in the parent settings screen (default "Hugrún"); the name persists across app restart in Drift, and is used in at least one voice-over (e.g. an open-app greeting) by selecting from a pre-baked clip set, with a name-less fallback when no pre-baked clip exists
**UI hint**: yes

### Phase 5: Letter-to-Word Matching
**Goal**: A letter-to-word matching activity in the Stafir room where an image of an object appears and the child taps the correct starting letter from 4 options — wrong taps are silent no-ops, correct taps celebrate with animation and audio, and the activity is wired to consume personalized photos at ~40% frequency once Phase 10 lands.
**Depends on**: Phase 4
**Requirements**: MATCH-01, MATCH-02, MATCH-03, MATCH-04
**Success Criteria** (what must be TRUE):
  1. The matching activity displays an image of an object plus 4 letter options; the child can tap any option and the activity progresses to a new prompt
  2. Wrong taps produce no negative feedback whatsoever — no shake, no red, no buzz, no sound — and the child can keep tapping until they hit the right letter
  3. Correct taps trigger a celebratory animation and audio cue with no points, stars, or score visible
  4. The matching activity has an image-source abstraction that returns either a stock image or a personalized photo for a given tag; in v1 it returns stock images, but a unit test confirms the abstraction will route ~40% of prompts to personalized photos when photos exist
**UI hint**: yes

### Phase 6: CVC Blending & Phoneme Audio Set
**Goal**: A CVC (consonant-vowel-consonant) blending activity covering at least 8 starter words (kýr, sól, hús, rós, bók, mús, hár, gás) with a separate phoneme audio set for all 32 letters distinct from the letter-name set used in tap-to-hear, where the child taps each letter in order, hears its phoneme, and the narrator blends the full word.
**Depends on**: Phase 5
**Requirements**: CVC-01, CVC-02, CVC-03
**Success Criteria** (what must be TRUE):
  1. A separate phoneme audio set exists for all 32 letters, generated through the same Phase 3 pipeline (loudness-normalized, native-speaker-reviewed) and addressable via distinct `UtteranceKey`s from the letter-name set
  2. The CVC blending activity covers at least 8 words: kýr, sól, hús, rós, bók, mús, hár, gás; each word has letter cards laid out in order
  3. Tapping each letter card in order plays that letter's phoneme; once all letters in the word have been tapped, the narrator plays the full word as a blend
**UI hint**: yes

### Phase 7: Letter Tracing (Ítalíuskrift)
**Goal**: A letter tracing activity in the Stafir room using the Menntamálastofnun Ítalíuskrift lowercase letterforms for all 32 letters, with tracing tolerance calibrated on Hugrún's tablet (~50–60% of stroke width on each side), soft stroke-order enforcement (visual hint, never hard rejection), no failure state, no timer, and a completion celebration that includes the child's name in the voice-over.
**Depends on**: Phase 6
**Requirements**: TRACE-01, TRACE-02, TRACE-03, TRACE-04, TRACE-05
**Success Criteria** (what must be TRUE):
  1. All 32 lowercase Ítalíuskrift letterforms are digitized and rendered via CustomPainter in the tracing surface; a Marionette E2E test confirms each letter loads and is traceable
  2. Tracing tolerance is ~50–60% of stroke width on each side and is calibrated against measurements taken on Hugrún's actual tablet; tracing-tolerance unit tests pin the calibrated values
  3. Wrong-stroke starts produce a faded ghost visual hint but never a hard rejection or failure; the child can stop and resume any trace freely with no timer pressure
  4. Completing a trace plays a celebration animation with a voice-over that includes the child's name (using the Phase 4 name selection mechanism, falling back to a name-less version if no pre-baked clip exists)
**UI hint**: yes

### Phase 8: Tölur Tap-to-Hear & Sequencing
**Goal**: The Tölur (numbers) room becomes functional with digits 1–10 in tap-to-hear matching the Stafir mechanic, gendered audio variants for 1–4 (masculine, feminine, neuter) with a single form for 5–10, abstract counting using masculine (school convention), and a sequencing activity (drag numerals into order, find missing number).
**Depends on**: Phase 7
**Requirements**: NUM-01, NUM-02, NUM-03, NUM-06, NUM-08
**Success Criteria** (what must be TRUE):
  1. The Tölur room displays digits 1–10 with tap-to-hear behavior reusing the Phase 4 TapToHearTile mechanic; latency, no-overlap, and visual-feedback rules are inherited unchanged
  2. Numbers 1–4 have masculine, feminine, and neuter audio variants; 5–10 have a single form; abstract counting (no pictured object) plays the masculine form
  3. The sequencing activity lets the child drag numerals into order and find a missing number in a sequence, with no fail state, no score, and no timer (matching Stafir's no-fail rules)
**UI hint**: yes

### Phase 9: Numeracy Activities (One-to-One, Subitizing, Addition)
**Goal**: Three numeracy activities — one-to-one correspondence (tap each pictured object as the voice counts), subitizing 1–5 (recognize quantities flashed in dice/line/random/finger arrangements), and addition with objects with narration like *"Tveir hundar koma. Einn hundur kemur til viðbótar."* (no `+` symbol) — all under the same no-fail / no-score / no-timer rules as Stafir, and using gender-correct audio for pictured objects.
**Depends on**: Phase 8
**Requirements**: NUM-04, NUM-05, NUM-07
**Success Criteria** (what must be TRUE):
  1. The one-to-one correspondence activity shows N pictured objects (N varies); as the child taps each in sequence, the voice counts and the last number narrated equals the count, using the gender of the depicted noun
  2. The subitizing activity flashes 1–5 dots for 1–3 seconds in varied arrangements (dice, line, random, finger-pattern); the child taps the matching numeral with no time pressure on the response
  3. The addition activity shows objects, then more objects join with narration counting the new total; no `+` symbol appears anywhere; the child counts the total
  4. All three activities are no-fail / no-score / no-timer; wrong taps are no-ops with no negative feedback
**UI hint**: yes

### Phase 10: Personalization — Photo System
**Goal**: The moat feature — parent can upload photos via the parent settings screen, tag each photo with one Icelandic word from a curated lexicon of ~200 nouns, and have those photos override default stock images in the matching activity and appear in numeracy activities. All storage is local (Drift), no cloud, no sync. Drift schema migrates from v1 to v2 (adds `photo_tags`) with a `schemaAt(1)` round-trip test.
**Depends on**: Phase 9
**Requirements**: PHOTO-01, PHOTO-02, PHOTO-03, PHOTO-04, PHOTO-05, PHOTO-06, PHOTO-07
**Success Criteria** (what must be TRUE):
  1. Parent can upload photos via the parent settings screen (camera or photo library) and tag each photo with one Icelandic word from a curated ~200-noun lexicon; photos persist locally and survive app restart
  2. Tagged photos override default stock images in the Phase 5 matching activity for that tag (e.g. parent's dog photo replaces the default *hundur* image) and appear in Phase 9 numeracy activities (e.g. *"Þrír boltar"* uses three actual ball photos)
  3. Photo storage is bounded — the upload pipeline limits image dimensions to 1024 px max edge and JPEG quality is capped, keeping DB size predictable; no cloud upload occurs (verified by the Phase 1 no-network integration test still passing)
  4. The Drift schema migration from v1 (single `child_profile` table) to v2 (adds `photo_tags`) is tested using `schemaAt(1)` and round-trips existing child-profile data without loss
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 (MVP) → 5 → 6 → 7 → 8 → 9 → 10

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Skeleton & Drift Schema | 0/5 | Planned | - |
| 2. Alphabet, Asset Conventions & Manifest Stub | 0/3 | Planned | - |
| 3. TTS Pipeline & Audio Review Tooling | 0/7 | Planned | - |
| 4. Stafir Tap-to-Hear MVP | 0/TBD | Not started | - |
| 5. Letter-to-Word Matching | 0/TBD | Not started | - |
| 6. CVC Blending & Phoneme Audio Set | 0/TBD | Not started | - |
| 7. Letter Tracing (Ítalíuskrift) | 0/TBD | Not started | - |
| 8. Tölur Tap-to-Hear & Sequencing | 0/TBD | Not started | - |
| 9. Numeracy Activities (One-to-One, Subitizing, Addition) | 0/TBD | Not started | - |
| 10. Personalization — Photo System | 0/TBD | Not started | - |

## Research Flags

Phases that need `/gsd-research-phase` before planning:

- **Phase 7 (Letter Tracing):** Ítalíuskrift digitization approach (no published SVG path library exists for Menntamálastofnun lowercase letterforms — plan 1–2 days design work); Impeller behavior with complex `Path` operations on iOS.

Phases with research flag *deferred to v2*:

- **Public Release (REL-* requirements):** Apple's 2026 Kids Category guideline updates, parental consent UI for photo collection (Guideline 5.1.4(b)), Privacy policy, TestFlight beta. Out of scope for v1; tracked in REQUIREMENTS.md v2.

Standard patterns (skip per-phase research): Phases 1, 2, 3, 4, 5, 6, 8, 9, 10.

## MVP Cut

The "ASAP playable" milestone is **the end of Phase 4**. At that point Hugrún can:
- Open the app on her tablet
- Tap any of the 32 letters
- Hear the letter name + example word at sub-50ms perceived latency
- See the matching image
- Have her name spoken in the open-app greeting

Phases 5–10 expand from there, but the build-first principle holds: if Phase 4 lands well, the rest builds on a proven loop. If Phase 4 doesn't land, no later phase can save it.
