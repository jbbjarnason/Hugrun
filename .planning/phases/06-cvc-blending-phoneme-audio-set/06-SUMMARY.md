---
phase: 06
title: CVC Blending & Phoneme Audio Set
status: human_needed
plans:
  - 06-01-phoneme-manifest-extension
  - 06-02-cvc-core-and-activity
  - 06-03-mode-toggle-and-integration
date: 2026-05-02
tags: [phase-6, cvc, phonemes, flutter, riverpod, post-mvp, review-pending]
requirements_satisfied:
  - CVC-01  # ≥8 starter words: kýr, sól, hús, rós, bók, mús, hár, gás
  - CVC-03  # tap each letter, hear phoneme, hear blend
requirements_pending:
  - CVC-02  # phoneme audio set exists for all 32 letters — clips baked,
            #   awaiting native-speaker review (same gate as Phase 3 D-18)
metrics:
  total-tests: 263
  test-delta: +39 (224 → 263)
  flutter-analyze: 7 warnings (all riverpod_lint scoped-providers in test
    files, same family Phase 5 documented)
  flutter-build-apk-debug: passes
  domain-purity: passes
  asset-paths: passes
  no-tracking: passes
  manifest-sync: passes (correctly skips with stub-baseline carve-out)
  manifest-utterances: 65 → 100 (+35: 32 phoneme + 3 new CVC)
  baked-aac-clips: 35 new + 65 backfilled (Phase 3 carryover)
  enum-utterancekey-entries: 5 → 45 (+40: 32 phoneme + 5 reused word + 3 new word)
---

# Phase 6: CVC Blending & Phoneme Audio Set — Master Summary

A post-MVP activity that teaches phoneme blending. Phase 6 adds:

- **A separate phoneme audio set** for all 32 Icelandic letters
  (CVC-02; clips baked, **awaiting reviewer pass**).
- **A CVC blending activity** in the Stafir room — image of a 3-letter
  word + 3 LetterTiles. Tap each letter, hear its phoneme; tap all 3
  in any order, hear the full word blend (CVC-01, CVC-03).
- **A 3-mode Stafir toggle** (Letters / Match / **CVC**). 3-second hold
  cycles through the modes — kid-mode-safe.

Plans executed: all 3 (06-01 through 06-03).

## Plan summaries

| Plan | Subject | Commits | Tests | Status |
|------|---------|---------|-------|--------|
| 06-01 | Phoneme manifest extension + bake | 2 (+ 1 fix(03)) | 0 (pipeline-side) | human_needed |
| 06-02 | CVC core data model + activity widget | 4 | +34 (22 unit + 12 widget) | complete |
| 06-03 | 3-mode toggle + integration test | 3 | +5 unit + 1 integration | complete |

## What was built (the CVC loop)

```
StafirRoom (in cvc mode after the toggle cycles)
  ↓
[Adult holds top-right toggle for 3 seconds — twice from default]
  ↓
StafirModeToggle.onToggle fires twice (letters→match, match→cvc)
  ↓
StafirRoom._mode swaps to StafirMode.cvc
  ↓
CvcActivity mounts → watches cvcCurrentWordProvider
  ↓
cvcCurrentWordProvider picks 1 of 8 from kCvcWords
  ↓
Render: _CvcRoundImage (top 55%) + 3 LetterTile widgets (row below)
  ↓
[Child taps tile in any order — D-11 soft]
  ↓
phonemeKeyForSlug(letter.assetSlug) → UtteranceKey.phoneme<X>
  ↓
audioEngine.play(phonemeKey) — silent fallback if clip unreviewed (D-21)
  ↓
Tile fades to opacity 0.55 (D-12 — visual cue)
  ↓
[After all 3 positions tapped]
  ↓
audioEngine.play(word.wordClip) — full blend audio
  ↓
Auto-advance Timer (2s) → ref.invalidate(cvcCurrentWordProvider)
  ↓
Round resets, new word picked, child restarts
  ↓
[Loop continues — infinite rounds, no counter, no score]
```

## Quality gate

- [x] manifest.yaml extended with 32 phoneme + 3 new CVC entries (100 total)
- [x] `bake_audio.py` ran end-to-end; review gate appropriately blocking
- [x] CvcWord + kCvcWords + phonemeKeyForSlug pure Dart, tested
- [x] CvcActivity widget renders correctly + tap-order tolerant + blend
      plays after 3 taps in any order
- [x] StafirMode enum extended with cvc; 3-mode cycle works
- [x] Integration test compiles clean (`flutter analyze`: 0 issues on the file)
- [x] `flutter analyze` clean modulo 7 documented riverpod_lint warnings
- [x] `flutter test` 263 / 263 pass
- [x] `flutter build apk --debug` succeeds
- [x] `tools/check-domain-purity.sh` updated with `lib/core/cvc` and passes
- [x] Atomic commits (10 task commits across 3 plans)
- [x] Summaries written

## Architectural commitments — preserved

- **Pure-Dart `lib/core/cvc/`**: enforced via CI script. No Flutter imports
  under that subtree.
- **Reuse-not-duplicate**: LetterTile, AudioEngine, ParentGateController
  (via toggle), StafirModeToggle, kIcelandicAlphabet — all imported and
  used directly, no fork-and-modify.
- **No fail-state UI**: 0 stars, 0 trophies, 0 score numbers, 0 "wrong"
  text. Tests C10/C11 assert.
- **Soft order (D-11)**: tap-order tolerance verified via test C5 (c2-first
  accepted) and the integration test (c2, c1, v out-of-order).
- **D-21 silent fallback**: phoneme keys exist in the enum but are absent
  from `kAudioManifest`. Activity is structurally functional but silent
  for unreviewed clips — exactly the documented contract.

## Key decisions exercised

D-01..D-04 (manifest extension), D-05..D-07 (CVC core data model), D-08
(parallel layout), D-09..D-14 (activity widget — round, taps, soft order,
visual cue, auto-advance, replay), D-15..D-16 (toggle cycle + 3-second
hold), D-17..D-19 (test strategy), D-20..D-21 (manifest extension protocol
+ silent fallback).

All 21 decisions in 06-CONTEXT.md were reached.

## Deviations summary

The full deviation list lives in each plan SUMMARY. Highlights:

1. **Phase 3 backfill** (Plan 06-01). Discovered during Workstream A: the
   65 Phase 3 AAC clips on disk were 4-byte stubs from Phase 2; Phase 3
   baked but never staged the real Steinn output. Auto-fix per Rule 1;
   committed as a separate `fix(03):` before the Phase 6 manifest commit.

2. **CvcWord is hand-written, not Freezed** (Plan 06-02). 5-field value
   class — Freezed adds 100+ generated lines for ~10 lines of payload.
   Same pattern as Phase 2's `AudioAsset`.

3. **Image area is inline `_CvcRoundImage`** (Plan 06-02). Phase 5's
   `MatchingRoundImage` is a public widget because tests find it by
   Type. CVC tests don't need that, so keeping the image inline reduces
   file count.

4. **`audio_manifest_test.dart` restructured** (Plan 06-02). Original had
   `expect(UtteranceKey.values.length, 5)` and an exhaustive switch —
   both incompatible with the 5→45 enum extension. New posture: per-group
   invariants (Phase 2 stub vs. Phase 6 extension). The D-21 silent
   fallback contract gets its own dedicated test.

5. **eSpeak phoneme markup deferred to review pass** (Plan 06-01). The
   plan said to "use what produces best Steinn output". Steinn's
   built-in eSpeak frontend treats raw single letters as the LETTER NAME
   for consonants (e.g. `t` → "té"). The pragmatic decision was to bake
   raw glyphs first and let the reviewer add eSpeak markup overrides
   (`[[t]]`) on a per-key basis as the listening session reveals which
   ones need it. Reduces churn during the bake; documented in each
   `notes_for_reviewer:` field.

6. **Phase 7 + Phase 8 untracked planning artifacts** observed during
   Phase 6 execution (`.planning/phases/07-letter-tracing-italiuskrift/`,
   `.planning/phases/08-tolur-tap-to-hear-sequencing/`). Out of Phase 6
   scope — left untouched.

## Files created/modified summary

### Created (lib/)
- `lib/core/cvc/cvc_word.dart` (78 lines)
- `lib/core/cvc/cvc_words.dart` (89 lines)
- `lib/core/cvc/phoneme_resolver.dart` (105 lines)
- `lib/features/stafir/cvc/cvc_activity.dart` (172 lines)
- `lib/features/stafir/cvc/cvc_providers.dart` (39 lines)
- `lib/features/stafir/cvc/cvc_providers.g.dart` (gitignored — generated)

### Modified (lib/)
- `lib/core/manifest/utterance_key.dart` — 5 → 45 enum entries
- `lib/features/stafir/stafir_mode.dart` — 2 → 3 mode values
- `lib/features/stafir/stafir_room.dart` — body switch arm for cvc
- `lib/features/stafir/widgets/stafir_mode_toggle.dart` — 3-arm icon switch

### Modified (top-level config)
- `manifest.yaml` — 65 → 100 utterances
- `pubspec.yaml` — assets list extended with `assets/audio/cvc/`
- `tools/check-domain-purity.sh` — added `lib/core/cvc`

### Created (assets/)
- `assets/audio/letters/phonemes/*.aac` (32 clips — awaiting review)
- `assets/audio/cvc/*.aac` (3 clips: hus, har, gas — awaiting review)
- `assets/audio/cvc/.gitkeep`

### Backfilled (assets/, fix(03))
- `assets/audio/letters/names/*.aac` (32 — Phase 3 real output)
- `assets/audio/letters/words/*.aac` (32 — Phase 3 real output)
- `assets/audio/narration/welcome_hugrun.aac` (1 — Phase 3 real output)

### Created (test/)
- `test/core/cvc/cvc_word_test.dart` (87 lines, 5 tests)
- `test/core/cvc/cvc_words_test.dart` (62 lines, 7 tests)
- `test/core/cvc/phoneme_resolver_test.dart` (66 lines, 10 tests)
- `test/features/stafir/cvc/cvc_activity_test.dart` (220 lines, 12 tests)

### Modified (test/)
- `test/core/manifest/audio_manifest_test.dart` — restructured for new posture
- `test/features/stafir/widgets/stafir_mode_toggle_test.dart` — M1/M3 + new M1b
- `test/features/stafir/stafir_room_test.dart` — added S4b, S4c

### Created (integration_test/)
- `integration_test/stafir_cvc_flow_test.dart` (153 lines, 1 device-only test)

### Created (.planning/)
- `.planning/phases/06-cvc-blending-phoneme-audio-set/06-{01..03}-SUMMARY.md`
- `.planning/phases/06-cvc-blending-phoneme-audio-set/06-SUMMARY.md` (this file)
- `.planning/phases/06-cvc-blending-phoneme-audio-set/06-VERIFICATION.md`

## Phase 6 closing posture

The CVC blending activity is **structurally complete**: 263 tests pass,
flutter analyze is clean (modulo 7 documented warnings), the debug APK
builds, the activity correctly renders 3 LetterTiles + an image,
responds to taps in any order, fires phonemes per tap and a blend after
3 taps, auto-advances after 2 seconds, never shows a fail/error/score/
timer indicator.

Two threads remain open:

1. **Phoneme + new CVC clip review pass** (CVC-02 still pending). The 32
   phoneme + 3 new CVC AAC clips are baked, normalized, and committed,
   but `reviewed.yaml` is empty for them. Until Jon runs
   `python3 tools/tts/review_server.py`, listens to each clip, and
   approves them, `lib/gen/audio_manifest.g.dart` won't regenerate and
   the keys remain absent from `kAudioManifest`. The activity is
   silently functional in the meantime (D-21).

2. **Phase 3 review pass** (still pending from before Phase 6). The 65
   re-baked Phase 3 letter-name and example-word clips also need approval
   — same review server, same workflow, same gate. Phase 3 already
   shipped its `human_needed` SUMMARY.

When Jon completes both review passes (likely as one session), the
manifest writer regenerates `lib/gen/audio_manifest.g.dart` with all
100 entries, the activity becomes audibly functional, and **CVC-02 +
the dependent runtime audio for Phase 4/5 ship**.

The Phase 6 scope is closed from a code-quality standpoint. Phase 7
(Letter Tracing) can begin in parallel with the audio review pass.
