# Requirements: Hugrún

**Defined:** 2026-05-02
**Core Value:** A five-year-old can pick up a tablet, tap, and learn — discoverable through visuals and audio alone, with no failure states, no scores, no instructions to read.

## v1 Requirements

Requirements for v1 release. The MVP cut is FOUND + AUDIO + STAFIR (full-alphabet tap-to-hear); subsequent v1 categories expand from there. Each requirement maps to one roadmap phase.

### Foundation

- [ ] **FOUND-01**: Flutter app runs on iOS and Android tablets from a single codebase, pinned to one Flutter SDK via `fvm`
- [ ] **FOUND-02**: Project uses Riverpod (codegen) for state, Drift (SQLite) for persistence, just_audio for playback — versions pinned to a consistent family
- [ ] **FOUND-03**: Drift schema is versioned from v1 with migration scaffolding in place; no destructive migrations are possible
- [ ] **FOUND-04**: Canonical 32-letter Icelandic alphabet constant (`kIcelandicAlphabet`) exists in code with a unit test asserting MMS school order (a á b d ð e é f g h i í j k l m n o ó p r s t u ú v x y ý þ æ ö); no C/Q/W/Z
- [ ] **FOUND-05**: Asset path conventions are lowercase, ASCII-safe (e.g. `eth.aac` for ð), and enforced by a generated asset manifest
- [ ] **FOUND-06**: TDD workflow established — every phase writes tests first; CI runs unit + widget tests on every commit
- [ ] **FOUND-07**: Marionette E2E test harness is installed, configured, and runs at least one smoke test against the app on both iOS and Android
- [ ] **FOUND-08**: App has two visible rooms (Stafir, Tölur) on a single home screen; only Stafir is functional through MVP, Tölur is a placeholder
- [ ] **FOUND-09**: Parent gate exists — a 3-second hold-to-open interaction with a visible ring-fill, gating any parent-only screens
- [ ] **FOUND-10**: No network calls are made during play — verified by an integration test that fails if any HTTP request occurs in a play session
- [ ] **FOUND-11**: No analytics, ads, or IAP SDKs are present in the dependency graph — verified by a CI check on `pubspec.lock`

### Audio Pipeline

- [ ] **AUDIO-01**: A YAML utterance manifest (`manifest.yaml`) describes every audio clip the app needs (letter names, example words, narrator phrases) with metadata including reviewer flag and pronunciation overrides
- [ ] **AUDIO-02**: A Python build pipeline (`tools/tts/`) reads the manifest, calls Tiro TTS (Diljá v2 voice) for each entry, and saves raw output
- [ ] **AUDIO-03**: All clips are loudness-normalized to -19 LUFS / -1 dBTP via `ffmpeg-normalize`; clips that deviate >±0.5 LU after normalization fail the pipeline
- [ ] **AUDIO-04**: All clips are encoded as AAC-LC mono 96 kbps 48 kHz in M4A container
- [ ] **AUDIO-05**: All clips are padded with 20–50 ms leading silence to mask encoder priming delay
- [ ] **AUDIO-06**: Pipeline emits a generated `lib/gen/audio_manifest.g.dart` file (committed to git) mapping typed `UtteranceKey`s to AAC asset paths — no runtime JSON parsing
- [ ] **AUDIO-07**: A `pronunciation_overrides.yaml` file exists from day one, allowing per-utterance SSML or phoneme substitutions
- [ ] **AUDIO-08**: Every clip is 100% reviewed by a native Icelandic speaker before bundling; pipeline rejects any asset bundle where any clip lacks a `reviewed: true` flag
- [ ] **AUDIO-09**: A review UI (HTML page or Flutter screen) plays each clip alongside its label so the reviewer can sign off entry-by-entry
- [ ] **AUDIO-10**: Tiro TTS auth, voice ID strings, and rate limits are verified via live curl call; results documented in `tools/tts/README.md`

### Stafir (MVP)

- [ ] **STAFIR-01**: Stafir room shows all 32 letters in MMS order on a single screen, sized so each tap target is ≥2 cm × 2 cm physical on Hugrún's tablet
- [ ] **STAFIR-02**: Tapping any letter plays the letter name (e.g. *"há"* for h) within ≤50 ms perceived latency, measured via 240 fps camera test on real hardware
- [ ] **STAFIR-03**: After the letter name finishes, the app plays an example word (e.g. *"hundur"*) and shows a corresponding image
- [ ] **STAFIR-04**: Re-tapping the same letter cancels the current clip and restarts from the letter name; no audio overlap
- [ ] **STAFIR-05**: Tapping a different letter mid-playback cancels the current clip and starts the new letter's playback
- [ ] **STAFIR-06**: Visual feedback (letter scale + color animation) fires synchronously with the tap gesture, independent of audio readiness
- [ ] **STAFIR-07**: There are no failure states — no "wrong" feedback, no scores, no timers, no progress indicators visible to the child
- [ ] **STAFIR-08**: There are zero text instructions visible to the child anywhere in Stafir
- [ ] **STAFIR-09**: AudioEngine warms a pool of ≥2 AudioPlayer instances at app start; no AudioPlayer is created per tap
- [ ] **STAFIR-10**: Each of the 32 letters has at least one example word audio clip and a matching image; the example word starts with the target letter (in IPA-equivalent terms; e.g. *þrír* for þ)

### Personalization

- [ ] **PERS-01**: Parent can enter the child's name in the parent settings screen; default is "Hugrún"
- [ ] **PERS-02**: The child's name is persisted in the Drift database and survives app restart
- [ ] **PERS-03**: The child's name is used in at least one voice-over (e.g. a greeting on app open) by selecting from a pre-baked clip set; if the name has no pre-baked clip, the greeting falls back to a name-less version

### Stafir — Activities

- [ ] **MATCH-01**: Letter-to-word matching activity in Stafir room — image of an object appears, child taps the correct starting letter from 4 options
- [ ] **MATCH-02**: Wrong taps in matching are no-ops with no negative feedback (no shake, no red, no sound)
- [ ] **MATCH-03**: Correct taps in matching trigger an animation and audio cue; no points or stars
- [ ] **MATCH-04**: Matching activity supports personalized photos (Phase 5 feature) at ~40% frequency once photos exist
- [ ] **TRACE-01**: Letter tracing activity in Stafir room uses the Ítalíuskrift lowercase letterforms for all 32 letters
- [ ] **TRACE-02**: Tracing tolerance is ~50–60% of stroke width on each side (calibrated on Hugrún's tablet)
- [ ] **TRACE-03**: Stroke order is enforced softly — wrong-stroke starts produce a visual hint (faded ghost), never a hard rejection
- [ ] **TRACE-04**: Letter tracing has no failure state, no timer; child can stop and resume freely
- [ ] **TRACE-05**: On completion, tracing plays a celebration animation including the child's name in the voice-over
- [ ] **CVC-01**: CVC blending activity covers ≥8 starter words: kýr, sól, hús, rós, bók, mús, hár, gás
- [ ] **CVC-02**: A separate phoneme audio set exists for all 32 letters (distinct from the letter-name set used in tap-to-hear)
- [ ] **CVC-03**: In CVC blending, the child taps each letter in order; each tap plays the letter's phoneme, then the narrator blends the full word

### Tölur (Numbers Room)

- [ ] **NUM-01**: Tölur room displays digits 1–10 with tap-to-hear behavior matching Stafir's tap mechanic
- [ ] **NUM-02**: Numbers 1–4 have gendered audio variants (masculine, feminine, neuter); 5–10 have a single form per the Icelandic grammar rule that 5+ does not decline
- [ ] **NUM-03**: Abstract counting (no pictured object) uses the masculine form (school convention); pictured-object counting uses the gender of the depicted noun
- [ ] **NUM-04**: One-to-one correspondence activity — child taps each of N pictured objects in sequence as the voice counts; the last number narrated equals the count
- [ ] **NUM-05**: Subitizing activity — 1–5 dots flash for 1–3 seconds in varied arrangements (dice, line, random, finger-pattern); child taps the matching numeral
- [ ] **NUM-06**: Sequencing activity — drag numerals into order; find the missing number in a sequence
- [ ] **NUM-07**: Addition with objects — objects appear, more objects join (with narration *"Tveir hundar koma. Einn hundur kemur til viðbótar."*); child counts the total. No `+` symbol.
- [ ] **NUM-08**: All number activities follow the same no-fail / no-score / no-timer rules as Stafir

### Personalization — Photos

- [ ] **PHOTO-01**: Parent can upload photos via the parent settings screen (camera or photo library)
- [ ] **PHOTO-02**: Each photo can be tagged with one Icelandic word from a curated lexicon of ~200 nouns
- [ ] **PHOTO-03**: Tagged photos are stored locally in the Drift database; no cloud upload, no sync
- [ ] **PHOTO-04**: Tagged photos override default stock images for the matching activity for that tag (e.g. parent's dog photo replaces the default *hundur* image)
- [ ] **PHOTO-05**: Tagged photos appear in numeracy activities (e.g. *"Þrír boltar"* uses the parent's photo of three actual balls)
- [ ] **PHOTO-06**: Photo storage is bounded — pipeline limits image dimensions (e.g. 1024 px max edge) and JPEG quality to keep DB size predictable
- [ ] **PHOTO-07**: Drift schema migration from v1 (single `child_profile` table) to v2 (adds `photo_tags`) is tested using `schemaAt(1)` and round-trips data correctly

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Public Release

- **REL-01**: Privacy policy is published and linked from the app
- **REL-02**: Apple Kids Category compliance audit passes (Guideline 5.1.4(b) parental consent for photo collection)
- **REL-03**: Crash reporting uses iOS MetricKit / Android Play Console (no Sentry/Firebase Crashlytics — restricted in Kids Category)
- **REL-04**: TestFlight beta with trusted Icelandic-parent testers
- **REL-05**: Multi-native-speaker QA pass on all audio
- **REL-06**: Support email and basic landing page

### Personalization v2

- **PERS-V2-01**: Free-text photo tagging — parent types arbitrary Icelandic word, runtime TTS (or pre-baked common-word fallback) provides audio
- **PERS-V2-02**: Multi-child support (separate profiles)

### Activities v2

- **TRACE-V2-01**: Uppercase Icelandic letterforms in tracing
- **NUM-V2-01**: Numbers beyond 10 (11–20, then 100s)
- **NUM-V2-02**: Subtraction activity matching addition's no-symbol approach
- **PARENT-V2-01**: Parent companion review screen showing what the child has been tapping

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Live runtime TTS | Latency, quality variance, network dependency; all audio is pre-baked |
| ElevenLabs TTS | Prohibited Use Policy bans bundled solutions targeting under-13s |
| Stars, scores, points, levels, streaks | Violates Core Value (no fail/score states); creates extrinsic-reward dependence |
| Timers on child responses | Same as above; pressure conflicts with the no-fail philosophy |
| Voice recognition / microphone input | Out of scope for tap-based UX; privacy concerns for kids' apps |
| Multiple narrator voices, character avatars | Sonic identity is one warm voice; consistency > variety at age 5 |
| Parent dashboard / progress reports (v1) | Co-play assumed; data-rich progress tracking not the value model |
| Adaptive difficulty algorithms | Hand-curated content; algorithmic adaptation adds complexity without clear win for one child |
| Rhyming games | Icelandic inflectional endings make this harder than English; not where the leverage is at age 5 |
| Sentence-level reading | Out of scope for this age and milestone |
| Multiplayer / social features | Single-device, single-child app |
| Rewards systems, stickers, collectibles | Same as scoring — extrinsic rewards |
| "Curriculum" framing or grade-level claims | Not a curriculum app; not what this is |
| Localization beyond Icelandic | Icelandic-first is the entire point |
| Cloud, sync, accounts, server | Fully local by design |
| go_router | Two-room app; Navigator 1.0 + MaterialPageRoute is sufficient |
| just_audio_background | No background audio needed; adds App Store review red flags |
| Sentry / Firebase Crashlytics | Restricted in Apple Kids Category; use platform-native crash reporting |
| Hive / Isar | User-locked Drift; revisited and rejected |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Pending |
| FOUND-02 | Phase 1 | Pending |
| FOUND-03 | Phase 1 | Pending |
| FOUND-04 | Phase 2 | Pending |
| FOUND-05 | Phase 2 | Pending |
| FOUND-06 | Phase 1 | Pending |
| FOUND-07 | Phase 1 | Pending |
| FOUND-08 | Phase 1 | Pending |
| FOUND-09 | Phase 1 | Pending |
| FOUND-10 | Phase 1 | Pending |
| FOUND-11 | Phase 1 | Pending |
| AUDIO-01 | Phase 3 | Pending |
| AUDIO-02 | Phase 3 | Pending |
| AUDIO-03 | Phase 3 | Pending |
| AUDIO-04 | Phase 3 | Pending |
| AUDIO-05 | Phase 3 | Pending |
| AUDIO-06 | Phase 3 | Pending |
| AUDIO-07 | Phase 3 | Pending |
| AUDIO-08 | Phase 3 | Pending |
| AUDIO-09 | Phase 3 | Pending |
| AUDIO-10 | Phase 3 | Pending |
| STAFIR-01 | Phase 4 | Pending |
| STAFIR-02 | Phase 4 | Pending |
| STAFIR-03 | Phase 4 | Pending |
| STAFIR-04 | Phase 4 | Pending |
| STAFIR-05 | Phase 4 | Pending |
| STAFIR-06 | Phase 4 | Pending |
| STAFIR-07 | Phase 4 | Pending |
| STAFIR-08 | Phase 4 | Pending |
| STAFIR-09 | Phase 4 | Pending |
| STAFIR-10 | Phase 4 | Pending |
| PERS-01 | Phase 4 | Pending |
| PERS-02 | Phase 4 | Pending |
| PERS-03 | Phase 4 | Pending |
| MATCH-01 | Phase 5 | Pending |
| MATCH-02 | Phase 5 | Pending |
| MATCH-03 | Phase 5 | Pending |
| MATCH-04 | Phase 5 | Pending |
| CVC-01 | Phase 6 | Pending |
| CVC-02 | Phase 6 | Pending |
| CVC-03 | Phase 6 | Pending |
| TRACE-01 | Phase 7 | Pending |
| TRACE-02 | Phase 7 | Pending |
| TRACE-03 | Phase 7 | Pending |
| TRACE-04 | Phase 7 | Pending |
| TRACE-05 | Phase 7 | Pending |
| NUM-01 | Phase 8 | Pending |
| NUM-02 | Phase 8 | Pending |
| NUM-03 | Phase 8 | Pending |
| NUM-06 | Phase 8 | Pending |
| NUM-08 | Phase 8 | Pending |
| NUM-04 | Phase 9 | Pending |
| NUM-05 | Phase 9 | Pending |
| NUM-07 | Phase 9 | Pending |
| PHOTO-01 | Phase 10 | Pending |
| PHOTO-02 | Phase 10 | Pending |
| PHOTO-03 | Phase 10 | Pending |
| PHOTO-04 | Phase 10 | Pending |
| PHOTO-05 | Phase 10 | Pending |
| PHOTO-06 | Phase 10 | Pending |
| PHOTO-07 | Phase 10 | Pending |

**Coverage:**
- v1 requirements: 61 total (counts: FOUND 11, AUDIO 10, STAFIR 10, PERS 3, MATCH 4, TRACE 5, CVC 3, NUM 8, PHOTO 7)
- Mapped to phases: 61
- Unmapped: 0
- Status: 100% coverage ✓

**Phase distribution:**
- Phase 1 (Skeleton & Drift Schema): 9 requirements (FOUND-01, 02, 03, 06, 07, 08, 09, 10, 11)
- Phase 2 (Alphabet & Asset Conventions): 2 requirements (FOUND-04, 05)
- Phase 3 (TTS Pipeline): 10 requirements (AUDIO-01..10)
- Phase 4 (Stafir Tap-to-Hear MVP): 13 requirements (STAFIR-01..10, PERS-01..03)
- Phase 5 (Letter-to-Word Matching): 4 requirements (MATCH-01..04)
- Phase 6 (CVC Blending): 3 requirements (CVC-01..03)
- Phase 7 (Letter Tracing): 5 requirements (TRACE-01..05)
- Phase 8 (Tölur Tap-to-Hear & Sequencing): 5 requirements (NUM-01, 02, 03, 06, 08)
- Phase 9 (Numeracy Activities): 3 requirements (NUM-04, 05, 07)
- Phase 10 (Personalization Photos): 7 requirements (PHOTO-01..07)

---
*Requirements defined: 2026-05-02*
*Last updated: 2026-05-02 after roadmap creation (10 phases, 61/61 v1 requirements mapped)*
