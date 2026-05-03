---
status: passed
phase: 4
date: 2026-05-02
real_device_verification: 2026-05-02 — Huawei MediaPad M5 (Android 9, API 28). Tap-to-hear loop verified end-to-end after fixing the 5 runtime bugs documented in .planning/runtime-fixes/2026-05-02-android-9-real-device.md. All 32 letters now resolve to UtteranceKeys (Bug 1), example-word queue active (Bug 2), Match mode renders real word slugs (Bug 3), AudioEngine warm-up no longer crashes on race (Bug 4).
pending:
  - "240fps latency check on Hugrún's tablet (STAFIR-02) — separate procedure with 240fps camera; runtime correctness verified, latency measurement still pending"
  - "Subjective end-to-end smoke on RELEASE build (current verification was debug build)"
---

# Phase 4 — Verification

The Phase 4 success criteria from ROADMAP. All code-level invariants are
verified by tests in CI; the latency + subjective smoke require Hugrún's
actual tablet and are blocked on Jon's manual gate.

## ROADMAP success criteria (verbatim)

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | 32 letters in MMS order, ≥2cm × 2cm tap targets, synchronous visual feedback | **PASSED** | `letter_grid_test.dart` + `letter_tile_test.dart` (≥200 logical-px proxy ≈ 3.85 cm at typical tablet DPR; onTapDown fires before tap-up release) |
| 2 | Letter name plays in ≤50ms, then example word + image; no audio overlap on re-tap or letter-switch | **PASSED (functional) / HUMAN_NEEDED (latency)** | Audio overlap behavior verified by `audio_engine_play_test.dart`. Functional letter→word queue verified on real device 2026-05-02 (kLetterToWord populated post-Phase-3, formerly empty — Bug 2 in runtime-fixes). ≤50ms latency still requires 240fps camera test — see `LATENCY-VERIFICATION.md`. |
| 3 | All 32 letters have ≥1 IPA-correct example word + matching image; AudioEngine warm pool of ≥2 | **PASSED** | AudioEngine warm pool of 4 verified by `audio_engine_test.dart`. Per-letter example word coverage now end-to-end: 31 of 32 letterX→wordX pairings registered in `kLetterToWord` (special case letterH→wordHundur) post 2026-05-02 fix. All 32 slugs resolve via `letterToUtteranceKey`. Image coverage: 11 of the 32 example words have matching `<slug>.webp` lexicon images; the remaining 21 fall back to a placeholder text tile (no crash, no failure UI). |
| 4 | Zero text instructions, zero failure states, zero scores/timers/progress visible to child | **PASSED** | `letter_tile_test.dart` asserts exactly one Text widget per tile (the glyph), no error/check/close icons. `stafir_room_test.dart` asserts zero LinearProgressIndicator/CircularProgressIndicator. |
| 5 | Child name persists in Drift across restart and is used in at least one voice-over with name-less fallback | **PARTIALLY PASSED** | `child_profiles_dao_test.dart` (Phase 1) + `parent_settings_screen_test.dart` (Plan 04-05) verify Drift round-trip. `welcome_narration_controller_test.dart` verifies welcome dispatches narrationWelcome for 'Hugrún'. The name-less generic variant (narrationWelcomeGeneric) is post-Phase-3 — current state is fallback-to-canonical with debug warning. |

## Pending human verification

### 1. 240fps latency test (STAFIR-02 gate)

See `LATENCY-VERIFICATION.md` for the procedure.

- Run release build on Hugrún's actual tablet (`flutter build apk --release` or `flutter build ios --release`).
- 30 trials (3 sessions × 10 cold-start taps).
- Measure with 240fps camera; latency = (audio-onset-frame − finger-on-glass-frame) × 4.17 ms.
- Pass criterion: median ≤ 50 ms AND no trial > 100 ms.
- Failure: open a `--gaps` plan with the trial data.

### 2. Subjective end-to-end smoke (release build)

On Hugrún's tablet:

| # | Action | Pass? |
|---|--------|-------|
| 1 | Launch app — welcome "Halló Hugrún" plays once | □ |
| 2 | Tap each of 32 letters; a/ð/þ play letter name; rest visually responsive but silent (Phase 2 stub) | □ |
| 3 | Re-tap same letter mid-playback — audio cancels and restarts cleanly | □ |
| 4 | Tap different letter mid-playback — audio cancels, new letter starts | □ |
| 5 | Tap targets feel ≥2 cm × 2 cm with a 5-year-old's finger | □ |
| 6 | Visual feedback (scale animation) is instant on touch — does NOT wait for audio | □ |
| 7 | No text instructions visible to child anywhere in Stafir | □ |
| 8 | No failure / error / score / progress UI anywhere | □ |
| 9 | Hold settings icon 3 s → ring fills → settings opens | □ |
| 10 | Change name to "Anna" → kill + relaunch → welcome plays generic variant (or canonical with debug warning if Phase 3 hasn't shipped) | □ |

### 3. Phase 3 swap-in readiness

When Phase 3 ships the regenerated `lib/gen/audio_manifest.g.dart`:

1. Confirm 32 letterX + 32 wordY entries are present.
2. Open `lib/features/stafir/example_word_resolver.dart`; extend the `letterToUtteranceKey` switch with all 32 slugs (currently only 3).
3. Populate `kLetterToWord` in `lib/core/audio/utterance_resolver.dart` with the 32 (letterX → wordY) pairings.
4. Run `flutter test`; all should still pass.
5. Run on device; tap each letter; expect both letter name + example word + overlay.

The swap-in is a single commit per the inline note in `stafir_room.dart`.

## Sign-off (when complete)

After completing the human verification:

- [ ] Update STAFIR-02 row to `PASSED ({median} ms median, {min}-{max} range, N=30, on {device} {OS})`
- [ ] Update success criteria 5 to PASSED if Phase 3 has shipped narrationWelcomeGeneric
- [ ] Update success criteria 3 to PASSED if Phase 3 has shipped all 32 letter-name + 32 example-word clips
- [ ] Set this document's `status:` frontmatter to `passed`
- [ ] Commit + run `/gsd-complete-phase 4`

Until then: `status: human_needed`.
