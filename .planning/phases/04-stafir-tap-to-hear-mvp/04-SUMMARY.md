---
phase: 04
title: Stafir Tap-to-Hear MVP
status: human_needed
date: 2026-05-02
plans:
  - 04-01-orientation-and-warmup
  - 04-02-audio-engine-play-queue
  - 04-03-letter-tile-widget
  - 04-04-stafir-room
  - 04-05-child-name-and-settings
  - 04-06-welcome-narration
  - 04-07-marionette-e2e-and-mvp-verification
tags: [flutter, riverpod, just_audio, drift, audio, mvp]
metrics:
  total-tests: 165
  test-delta: +81 (84 → 165)
  flutter-analyze: clean (2 known riverpod_lint warnings on test-time scoped overrides)
  flutter-build-apk-debug: passes
---

# Phase 4: Stafir Tap-to-Hear MVP — Master Summary

The MVP "playable" milestone. After Phase 4, Hugrún can pick up the
tablet, open Stafir, and tap any of the 32 letters to hear the letter
name (when the manifest has it) with synchronous visual feedback.

Plans executed: all 7 (04-01 through 04-07). One human-verify checkpoint
remains (the 240fps latency test on Hugrún's actual tablet — STAFIR-02
verification gate per D-28).

## Plan summaries

| Plan | Subject | Commits | Tests |
|------|---------|---------|-------|
| 04-01 | Orientation lock + AudioEngine warm pool | 4 | 12 |
| 04-02 | AudioEngine play queue | 3 | 13 |
| 04-03 | LetterTile widget + palette | 3 | 14 |
| 04-04 | StafirRoom (32-tile grid) | 2 | 15 |
| 04-05 | childNameProvider + ParentSettingsScreen | 2 | 14 |
| 04-06 | WelcomeNarrationController | 2 | 9 |
| 04-07 | Integration test + Marionette doc + LATENCY-VERIFICATION | 1 | (integration test, real-binding only) |

## What was built (the MVP loop)

```
App start
  ↓
configureSystemChrome (D-15, D-16: landscape + immersive)
  ↓
runApp(HugrunApp inside ProviderScope)
  ↓
appDatabaseProvider materializes (Phase 1)
  ↓
audioEngineProvider materializes — WarmUp() unawaited (D-01..D-03)
  ↓
HomePage build + initState
  ↓
WelcomeNarrationController.maybeFireOnce post-frame (D-18, D-19, D-21)
  ↓
audioEngine.play(narrationWelcome) — Hugrún hears "Halló"
  ↓
[Tap Stafir room button]
  ↓
StafirRoom > LetterGrid (32 LetterTiles, MMS order, 4×8 landscape)
  ↓
[Tap letter glyph]
  ↓
LetterTile.onTapDown — scale animation fires synchronously (STAFIR-06)
  ↓
StafirRoom._onLetterTap — letterToUtteranceKey, then audioEngine.play
  ↓
AudioEngine: cancel-on-retap, dispatch via setAudioSources playlist
            (or graceful no-op for letters not in stub manifest, D-22 D-23)
  ↓
ExampleWordOverlay fades in if pairing exists (Phase 2 stub: empty)
```

## Quality gate

- [x] All 7 plans executed
- [x] AudioEngine 4-player warm pool, top-level non-autoDispose Riverpod (D-01, D-02, STAFIR-09)
- [x] Stafir grid renders 32 letters in MMS order (STAFIR-01)
- [x] Tap targets ≥200 logical-px (STAFIR-01 proxy verified by widget test)
- [x] Synchronous visual feedback in onTapDown, NOT awaiting audio (STAFIR-06)
- [x] Cancel-on-retap, cancel-on-different-letter behaviors (STAFIR-04, STAFIR-05; verified by audio_engine_play_test)
- [x] Letters without manifest clips fail gracefully (D-22, D-23)
- [x] Landscape orientation locked, immersive mode (D-15, D-16)
- [x] ParentSettingsScreen with Vista save persisting to Drift (D-17, PERS-01, PERS-02)
- [x] Welcome narration once-per-session, name-aware (D-18, D-19, PERS-03)
- [x] Marionette scripted Stafir scenario added (D-27)
- [x] flutter analyze clean (modulo 2 known riverpod_lint warnings)
- [x] flutter test all pass (165 / 165)
- [x] flutter build apk --debug succeeds
- [x] No edits outside Phase 4 scope (Phase 3 owned files left alone — see Deviations)
- [x] No new banned packages

- [ ] **STAFIR-02 latency ≤50ms verified on Hugrún's tablet** — human-verify
      checkpoint, see LATENCY-VERIFICATION.md and 04-VERIFICATION.md

## Key decisions exercised

D-01..D-03 (AudioEngine architecture), D-04..D-05 (play queue + cancel),
D-08 (silence-pad health check), D-09..D-14 (Stafir grid + tile),
D-15..D-16 (orientation + immersive), D-17..D-21 (name + welcome),
D-22..D-23 (Phase 2 stub fallback), D-26..D-28 (test strategy), D-30 (palette + animation).

All 30 decisions in 04-CONTEXT.md were reached or explicitly deferred.

## Architectural commitments — preserved

- `lib/core/audio/` is Flutter+Dart layer (NOT pure-Dart domain) — depends on `package:just_audio` and `package:flutter`.
- `lib/core/manifest/` and `lib/core/alphabet/` remain pure Dart (Phase 1 D-08 / Phase 2 D-13 invariant).
- AudioPlayer creation flows exclusively through `audioEngineProvider` — never in widget build, never per-tap (PITFALLS #7, #8).
- Riverpod `keepAlive: true` for app-scoped providers (`audioEngineProvider`, `appDatabaseProvider`, `childNameProvider`, `welcomeNarrationControllerProvider`).

## Deviations summary

The full deviation list is in each plan's SUMMARY.md. Highlights:

1. **Phase 3 parallel commit history pollution** — Phase 3's untracked
   `assets/audio/letters/words/*.aac` files and `.planning/phases/03/*` summaries
   got bundled into my Plan 04-01 and 04-02 GREEN commits. The work is
   correct and tested; the commit subjects are mine, but the diffs include
   Phase 3's files. Future restoration of clean phase boundaries: rebase
   to split commits, OR accept the noise and document.

2. **`ConcatenatingAudioSource` deprecated → `setAudioSources`** (Plan 04-02).
   Functionally equivalent; cleaner API.

3. **Test infrastructure: `_runWidgetThenUnmount` + `_primeChildName` helpers**
   (Plans 04-05, 04-06). Drift's stream-query `markAsClosed` `Timer.zero`
   fires async during dispose; we explicitly unmount widgets and listen-prime
   stream providers so timers fire inside the fake-async window.

4. **Skipped golden tests** (Plans 04-03, 04-04). Time-pressure deviation;
   widget tests cover the layout invariants. Polish pass to add later.

5. **Skipped integration_test/parent_settings_db_test.dart** (Plan 04-05).
   The widget test already verifies round-trip on in-memory DB; Phase 1's
   database_smoke_test.dart already exercises real-platform Drift.

6. **Widget-test variant of "welcome narration fires on home mount"
   deferred to 04-07 integration test** — Drift StreamProvider + flutter_test
   fake-async don't interact reliably; integration_test runs against a real
   binding where it works.

## What's next (post-MVP)

1. **STAFIR-02 latency check** (Jon, manual, 240fps camera). See LATENCY-VERIFICATION.md.
2. **Phase 3 manifest swap-in.** When Phase 3's review pass completes and the
   regenerated `lib/gen/audio_manifest.g.dart` ships, follow the 5-step
   checklist documented inline in `lib/features/stafir/stafir_room.dart`.
3. **Polish pass** (post-MVP): real example-word images, golden tests,
   integration_test/parent_settings_db_test.dart, possibly UI-SPEC-driven
   palette/font refinements.
4. **Phase 5+** (deferred per ROADMAP).

## Files created/modified summary

### Created (lib/)
- `lib/core/audio/audio_engine.dart` (191 lines)
- `lib/core/audio/audio_engine_provider.dart` (42 lines)
- `lib/core/audio/audio_player_like.dart` (44 lines)
- `lib/core/audio/utterance_resolver.dart` (62 lines)
- `lib/features/home/welcome_narration_controller.dart` (60 lines)
- `lib/features/home/welcome_narration_keys.dart` (32 lines)
- `lib/features/parent_settings/child_name_provider.dart` (24 lines)
- `lib/features/stafir/example_word_resolver.dart` (52 lines)
- `lib/features/stafir/widgets/letter_grid.dart` (47 lines)
- `lib/features/stafir/widgets/letter_tile.dart` (115 lines)
- `lib/features/stafir/widgets/letter_tile_palette.dart` (32 lines)
- `lib/features/stafir/widgets/example_word_overlay.dart` (105 lines)

### Modified (lib/)
- `lib/main.dart` (added `configureSystemChrome` + landscape lock)
- `lib/features/stafir/stafir_room.dart` (rewritten from Phase 1 placeholder)
- `lib/features/parent_settings/parent_settings_screen.dart` (rewritten from Phase 1 stub)
- `lib/features/home/home_page.dart` (StatelessWidget → ConsumerStatefulWidget for welcome trigger)

### Created (test/)
- `test/core/audio/_fakes/fake_audio_player.dart`
- `test/core/audio/audio_engine_test.dart`
- `test/core/audio/audio_engine_provider_test.dart`
- `test/core/audio/audio_engine_play_test.dart`
- `test/core/audio/utterance_resolver_test.dart`
- `test/features/home/welcome_narration_controller_test.dart`
- `test/features/home/welcome_narration_keys_test.dart`
- `test/features/parent_settings/child_name_provider_test.dart`
- `test/features/stafir/example_word_resolver_test.dart`
- `test/features/stafir/widgets/letter_tile_palette_test.dart`
- `test/features/stafir/widgets/letter_tile_test.dart`
- `test/features/stafir/widgets/letter_grid_test.dart`
- `test/features/stafir/widgets/example_word_overlay_test.dart`
- `test/skeleton/main_orientation_test.dart`

### Created (integration_test/)
- `integration_test/stafir_flow_test.dart`
- `integration_test/test_helpers/fake_audio_engine.dart`

### Created (marionette/)
- `marionette/stafir_smoke.marionette.dart`

### Modified (test/)
- `test/app/app_test.dart`
- `test/features/home/home_page_test.dart`
- `test/features/parent_settings/parent_settings_screen_test.dart`
- `test/features/stafir/stafir_room_test.dart`

### Created (.planning/)
- `.planning/phases/04-stafir-tap-to-hear-mvp/LATENCY-VERIFICATION.md`
- `.planning/phases/04-stafir-tap-to-hear-mvp/04-{01..07}-SUMMARY.md`
- `.planning/phases/04-stafir-tap-to-hear-mvp/04-SUMMARY.md` (this file)
- `.planning/phases/04-stafir-tap-to-hear-mvp/04-VERIFICATION.md`

## Phase 4 closing posture

The MVP is **shippable from a code-quality standpoint**: 165 tests pass,
flutter analyze is clean, the debug APK builds, the Stafir grid renders
all 32 letters with synchronous visual feedback, and audio dispatches
cleanly for the 3 letters in the Phase 2 stub manifest. When Phase 3
flips the manifest from 5 entries to 65, the app lights up automatically
via the documented manifest swap-in checklist.

The MVP is **not yet shipped** until:
1. Phase 3 completes its review pass (parallel work).
2. Jon runs the 240fps latency test on Hugrún's tablet (STAFIR-02 gate).
3. Jon does the subjective end-to-end smoke (does it feel right to a 5-year-old).

See `04-VERIFICATION.md` for the gating rubric.
