# Phase 4: Stafir Tap-to-Hear MVP - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto`

<domain>
## Phase Boundary

**This is the MVP "playable" milestone.** Hugrún can pick up the tablet, open Stafir, and tap any of the 32 letters to hear the letter name followed by an example word and see the matching image — at sub-50ms perceived latency, with no fail states, no scores, no text, no audio overlap. Parent can enter Hugrún's name in settings and the app uses it in at least one voice-over.

**Requirements covered (13):** STAFIR-01..10 + PERS-01..03

</domain>

<decisions>
## Implementation Decisions

### AudioEngine (the heart of MVP)

- **D-01:** `AudioEngine` lives at `lib/core/audio/audio_engine.dart`, owned by a top-level non-autoDispose Riverpod provider in `lib/core/audio/audio_engine_provider.dart` with `@Riverpod(keepAlive: true)`. **Never** lives in a widget build, never autoDispose, never per-tap. (PITFALLS #8.)
- **D-02:** Warm pool of **4 `AudioPlayer` instances** allocated at app start (research Finding 4). Pool managed by AudioEngine internally — callers see only `play(UtteranceKey)` and `stop()`.
- **D-03:** App-start warm-up:
  1. Allocate 4 AudioPlayers
  2. Activate iOS `AVAudioSession` by playing a silent clip on player 0
  3. Pre-load the next-likely clips (Phase 4 = first 8 letters' name clips)
  Total warm-up budget: <500ms after `runApp`. Done in a Riverpod async-init provider so the home screen doesn't wait.
- **D-04:** `play(UtteranceKey key)`: idempotent + cancellable. If a different key is requested while one is playing, current player stops; next player from pool starts the new clip. If same key re-tapped, current player stops and replays from beginning (per STAFIR-04).
- **D-05:** Clip queue per tap: letter name → example word. Queued sequentially on the same player, no gap between. `play(letterKey)` enqueues both audio files (letter name from `letters/names/`, example word from `letters/words/`) and plays back-to-back via just_audio's `ConcatenatingAudioSource`.
- **D-06:** Visual feedback fires synchronously with the gesture (NOT after audio is ready) — letter scale + color animation start in the `onTapDown` handler. Audio is fire-and-forget. (Research Finding 4.)
- **D-07:** Latency budget: tap-to-audio-start <50ms perceived. Measured via logging in development; verified on hardware with a 240fps camera before MVP signoff. The warm pool + visual feedback synchronicity guarantee this without measurement; measurement is QA, not a coding task.
- **D-08:** Cold-start head-clipping fix (PITFALLS — Android first-play): clips are pre-padded with 20–50ms silence by Phase 3 pipeline; AudioEngine doesn't need its own padding. If Phase 3's silence pad is somehow absent, AudioEngine logs a warning but still plays.

### Stafir Room (the 32-letter grid)

- **D-09:** `StafirRoom` at `lib/features/stafir/stafir_room.dart`. Replaces Phase 1's placeholder. Layout: a single grid showing all 32 letters, MMS order, sized so each tap target is ≥2cm × 2cm physical on Hugrún's tablet. Use `MediaQuery.devicePixelRatio` + `MediaQueryData.size` to compute physical size and choose grid columns (likely 4 columns on a 10" iPad in portrait, 8 in landscape; lock orientation? — see D-15).
- **D-10:** Letter grid item widget: `LetterTile` at `lib/features/stafir/widgets/letter_tile.dart`. Displays the letter glyph (large, sans-serif, kid-friendly font), background color (low-saturation pastel; rotates by index for visual variety; locked palette). Tap handler: AudioEngine `play(UtteranceKey.letter${letter.assetSlug.camelCase})` + scale animation on `onTapDown`.
- **D-11:** Background image / mascot: TBD — defer to UI-SPEC. Phase 4 ships clean white background if no UI-SPEC is generated. (Recommend `/gsd-ui-phase 4` before starting; orchestrator should run it.)
- **D-12:** Example word image: when a letter is tapped, after the letter-name clip finishes, an example-word image fades in centered on the screen for ~3 seconds, then fades out, while the example-word audio plays. The image is loaded from `assets/images/letters/words/{slug}.webp` (or `.png` fallback). Phase 4 ships placeholder images for letters that don't have real ones yet (a simple text-on-color tile saying e.g. "hundur"). Real images come in a later polish pass.
- **D-13:** No "selected" state on the letter tile after tap — playback completes, animation returns to neutral, grid is the same. (Anti-feature: progress tracking, "stars on letters seen", anything that looks like score.)
- **D-14:** Empty state on first launch: nothing special. Grid shows. Child taps. Done.

### Orientation, Display

- **D-15:** Lock to landscape. Tablets in landscape give better grid layout for 32 letters and more comfortable tap zones. Implemented via `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])` in `main.dart` (post-WidgetsFlutterBinding.ensureInitialized).
- **D-16:** Status bar hidden, navigation bar hidden (`SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive)`). Kid-mode chrome.

### PERS-01..03: Child Name Capture

- **D-17:** `ParentSettingsScreen` (Phase 1 stub) is filled out:
  - One field: child's name. Default value from Drift `child_profiles` table, default "Hugrún".
  - "Save" button writes back to Drift via the `child_profiles_dao`.
  - Screen is parent-facing (text labels in Icelandic — `Stillingar`, `Nafn barns`, `Vista`).
- **D-18:** Welcome narration uses child's name. Implementation:
  - Manifest contains pre-baked "Halló Hugrún" (`narrationWelcome` from Phase 2/3).
  - If child name = "Hugrún": play `narrationWelcome`.
  - If child name ≠ "Hugrún": play a name-less variant `narrationWelcomeGeneric` (e.g. "Halló") — also pre-baked.
  - **Future v2:** dynamic name TTS. Out of scope for v1. (Per PROJECT.md.)
- **D-19:** Welcome plays once per app session, on home screen mount (not on every navigation back to home).

### Personalization data flow

- **D-20:** Riverpod provider `childNameProvider` (auto-init from Drift `child_profiles`). Watched by:
  - ParentSettingsScreen (current value)
  - Welcome narration logic in HomeScreen
- **D-21:** Updating name via settings invalidates `childNameProvider`; if the name changes between two known states, the next welcome plays the matching variant. No mid-session re-narration.

### MVP success criteria (verbatim from ROADMAP)

(Reproduced for plan-checker reference — verbatim from ROADMAP § Phase 4.)
1. 32 letters in MMS order, ≥2cm × 2cm tap targets, synchronous visual feedback
2. Letter name plays in ≤50ms (240fps verified), then example word + image; no audio overlap on re-tap or letter-switch
3. All 32 letters have at least one IPA-correct example word + matching image; AudioEngine warms ≥2 players at startup
4. Zero text instructions, zero failure states, zero scores/timers/progress visible to child
5. Child's name persists in Drift across restart and is used in at least one voice-over with name-less fallback

### Audio Asset Dependencies (BLOCKING)

- **D-22:** Phase 4 depends on Phase 3 having delivered:
  - All 32 letter-name clips (`letters/names/{slug}.aac`)
  - All 32 example-word clips (`letters/words/{word}.aac`)
  - `narrationWelcome` and `narrationWelcomeGeneric` clips
  - Regenerated `lib/gen/audio_manifest.g.dart` with all the new `UtteranceKey` entries
- **D-23:** **If Phase 3's review pass is not yet complete when Phase 4 plans execute**, two paths:
  1. (Preferred) Build Phase 4 against the Phase 2 stub manifest first (5 placeholder clips). Stafir grid renders all 32 letters but only `letterA, letterEth, letterThorn` actually play; rest fail gracefully (silent + visual feedback only). This unblocks Phase 4 development immediately, lets Jon review Phase 3 clips async, and the real clips drop in once review completes (manifest swap = single commit).
  2. (Fallback) Block Phase 4 until Phase 3 review completes. Slower but cleaner.
  Plan 4 should default to (1) and document the swap-in step.

### Test Strategy

- **D-24:** Unit tests: AudioEngine warm-up, play queue, cancel-on-new-tap, name provider.
- **D-25:** Widget tests: StafirRoom renders 32 LetterTiles, tap target sizes, ParentSettingsScreen save button writes to Drift.
- **D-26:** Integration test: full Stafir flow — open app, tap 5 different letters, verify audio fires, no exceptions, no audio overlap. Uses fake AudioPlayer that records play calls.
- **D-27:** Marionette E2E test: scripted variant exercises the home → Stafir → tap letter → return to home flow on iOS Sim + Android Emulator. MCP variant available for Jon to drive interactively.
- **D-28:** No latency-measurement test in CI — that's a 240fps camera test on Hugrún's tablet, done manually before MVP signoff. Document as a checkpoint in Plan 4 verification.

### UI-SPEC

- **D-29:** Phase 4 should generate a UI-SPEC.md before planning starts (orchestrator runs `/gsd-ui-phase 4`). The UI-SPEC locks: color palette, letter font, tile dimensions, animation curves, parent settings layout, welcome narration trigger UX.
- **D-30:** If UI-SPEC isn't generated (orchestrator skips), Plan 4 ships sensible defaults documented inline: SF Pro / Roboto rounded for letter glyph, 6-color pastel rotation, 200ms ease-out scale animation on tap, white background.

### Claude's Discretion

- Exact pastel palette + font selection (UI-SPEC territory; defaults documented in plan if UI-SPEC absent)
- Image sourcing for the 32 example words — Plan 4 ships placeholder text-on-color tiles; real images can come in a polish pass or via Phase 10 personalization
- Welcome narration audio clip source (one of Phase 3's narrations; specific selection at execution time)
- Whether to add a subtle background animation / mascot — defer to UI-SPEC

### Folded Todos

(None.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these.**

### Project context
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md` STAFIR-01..10, PERS-01..03
- `.planning/ROADMAP.md` § Phase 4
- All prior phase summaries: `01-SUMMARY.md`, `02-SUMMARY.md`, `03-SUMMARY.md`
- All prior phase contexts: `01-CONTEXT.md` (D-07 layout), `02-CONTEXT.md` (UtteranceKey shape), `03-CONTEXT.md` (audio specs, manifest format)

### Research
- `.planning/research/SUMMARY.md` Findings 4 (warm pool latency), 5 (LUFS — relevant for verifying AudioEngine doesn't add gain), 8 (Riverpod scope rules), 10 (tracing irrelevant for Phase 4)
- `.planning/research/ARCHITECTURE.md` AudioEngine + warm pool + Riverpod scope tree
- `.planning/research/PITFALLS.md` #4 (latency), #6 (failure feedback grammar — applies to no-failure-state requirement), #7 (Riverpod scope), #8 (no AudioPlayer in widget build)
- `.planning/research/FEATURES.md` tap-to-hear interaction patterns

### External docs
- https://pub.dev/packages/just_audio — ConcatenatingAudioSource, gapless playback
- https://pub.dev/packages/audio_session — iOS AVAudioSession config

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 1-3)
- ParentGate primitive (Phase 1) — already gates ParentSettingsScreen; Phase 4 just fills the screen
- ParentSettingsScreen placeholder (Phase 1) — Phase 4 replaces "Stillingar" stub with name field
- HomeScreen with two rooms (Phase 1) — Phase 4 replaces StafirRoom placeholder with real grid
- `kIcelandicAlphabet` constant (Phase 2) — Phase 4 iterates this to render the grid
- `lib/gen/audio_manifest.g.dart` (Phase 2 stub or Phase 3 generated) — Phase 4's AudioEngine reads from `kAudioManifest`
- Drift `child_profiles` table + DAO (Phase 1) — Phase 4 wires the name field to the settings UI
- `appDatabaseProvider` (Phase 1) — Phase 4 builds `childNameProvider` on top
- Marionette harness (Phase 1) — Phase 4 adds new smoke scenarios

### Established Patterns
- TDD red→green→refactor
- Riverpod codegen for non-trivial providers (`@Riverpod(keepAlive: true)` for AudioEngine)
- Atomic commits per cycle
- Domain layer pure Dart
- No new banned packages

### Integration Points
- `lib/core/audio/` — new AudioEngine + provider lives here
- `lib/features/stafir/stafir_room.dart` — replaces Phase 1 placeholder
- `lib/features/stafir/widgets/letter_tile.dart` — new
- `lib/features/parent_settings/parent_settings_screen.dart` — fills Phase 1 stub
- `lib/main.dart` — adds orientation lock + immersive mode
- `lib/app/app.dart` — wires welcome narration trigger
- `pubspec.yaml` — confirm just_audio + audio_session resolve at runtime
- `marionette/smoke.marionette.dart` + `integration_test/marionette_smoke_test.dart` — extend with Stafir flow

</code_context>

<specifics>
## Specific Ideas

- "Halló Hugrún" as the welcome narration — locked.
- Welcome plays once per session, on home mount.
- Landscape only — kid-friendly tablet usage assumes landscape grip.
- Immersive mode (no status bar) — locks the kid in the app, parent gate is the only exit.
- Pastel color rotation for letter tiles — soft, not harsh.

</specifics>

<deferred>
## Deferred Ideas

- Real example-word images (custom illustrated or licensed stock) — Phase 4 ships placeholder text tiles; polish pass or Phase 10 personalization replaces them
- Background mascot animation — UI-SPEC may add; otherwise white background
- Per-child profile (multi-child) — out of scope per PROJECT.md
- "Recently seen letters" tracking — anti-feature per Core Value (no progress UI for child)
- Voice-over selection (Diljá vs Álfur A/B test) — Phase 3 ships Diljá; future v2 might A/B
- Free-text photo tagging — Phase 10 v2

### Reviewed Todos (not folded)

None.

</deferred>

---

*Phase: 4 — Stafir Tap-to-Hear MVP*
*Context gathered: 2026-05-02*
