---
date: 2026-05-02
device: CMR W09 (Huawei MediaPad M5, Android 9, API 28, arm64)
trigger: User report "the app doesnt work" on connected Android tablet
status: fixed (5 bugs) + 1 deferred (low device volume — out of scope)
---

# Real-Device Runtime Fixes — Android 9 / Huawei MediaPad

Hugrún's first deploy to a real Android device surfaced five coupled
bugs that the Phase 1-13 unit + integration test suites did not catch.
All five reproduce on the simulator too (the bugs are platform-agnostic);
they were simply hidden by the test fixtures' use of `manifestOverride`
+ `pairingOverride` parameters and by the test suite never exercising
the real `letterToUtteranceKey` resolver against all 32 letter slugs.

## Bugs found and fixed

### Bug 1 — `letterToUtteranceKey` Phase-2 stub leaked to production
**Severity:** Critical (29 of 32 letters silent on tap).

`lib/features/stafir/example_word_resolver.dart` resolved only `a`,
`eth`, `thorn` to UtteranceKeys; the rest fell through to `null`.
`StafirRoom._onLetterTap` then short-circuits silently when key is null
(comment: "Phase 2 stub: enum entry doesn't exist for this letter"),
so 29 of 32 letters produced visual feedback only — no audio.

The Phase 3 manifest had shipped 31 `letter*` UtteranceKey entries
months ago. The swap-in note in `stafir_room.dart` was never executed.

**Fix:** Complete the 32-case switch (mirrors `phonemeKeyForSlug`).

**Commit:** `cfe4f80 fix(android): resolve all 32 letters + populate kLetterToWord pairings`

### Bug 2 — `kLetterToWord` empty in production
**Severity:** Critical (no example word ever queues; Match mode broken).

`lib/core/audio/utterance_resolver.dart` shipped `kLetterToWord = {}`,
meaning the `(letter-name → example-word)` clip queue contract from
D-05 (Phase 4) was a no-op. Match mode also depends on this map for
target-word picking; without it, Match falls back to slug-first-char
heuristics that misfire for accented vowels.

**Fix:** Populate all 32 (letter, wordKey) pairings derived from
`manifest.yaml`'s `starts_with` field. Special case: `letterH →
wordHundur` per the manifest's "wordHundur IS wordH" comment.

**Commit:** `cfe4f80` (same as Bug 1).

### Bug 3 — `slugFromWordKey` PascalCase strip was incorrect
**Severity:** High (Match-mode image fallback always rendered slug
text instead of the actual word's image).

`slugFromWordKey(wordA)` returned `"a"` (`wordA` minus `word`
prefix, lower-cased). But the audio for `wordA` is `api.aac` and
the image lexicon is keyed off the word filename root. The strip
heuristic happened to be correct for `wordHundur → "hundur"` (the
single Phase 2 stub key) but wrong for any general `word*` key.

**Fix:** Derive the slug from the AudioAsset path
(`assets/audio/letters/words/api.aac` → `api`). Same derivation in
both the features-layer helper (`example_word_resolver.dart`) and
the core-layer duplicate (`round_generator.dart` — kept duplicated
per the layering invariant: `lib/core` may not import `lib/features`).

**Commit:** `cfe4f80` (same as Bug 1).

### Bug 4 — AudioEngine pool race on early tap
**Severity:** Critical (assertion crash on first letter tap if user
taps before warm-up resolves).

`AudioEngine.warmUp()`'s `if (_warmedUp) return` guard only fires
AFTER the first call has finished priming. Between provider
construction (which schedules `unawaited(engine.warmUp())`) and the
first `play()`, an early tap entered `play() → !_warmedUp →
warmUp()` and ran a SECOND warm-up concurrently. Both calls
allocated `poolSize` players → `_pool.length == 8` → invariant
assertion in `_acquirePlayer` throws.

Logcat trace:
```
[AudioEngine] warmUp priming failed: Loading interrupted
Failed assertion: line 147 pos 7: '_pool.length == poolSize':
  pool size invariant — must be 4, was 8
```

**Fix:** Cache the in-flight warm-up Future. Concurrent callers
await the same future. Only the first allocates.

**Commit:** `f165f9b fix(android): de-duplicate concurrent AudioEngine warmUp calls`

### Bug 5 — Pubspec missing parent dir for genderless cardinals
**Severity:** Critical (numbers 5-10 produced "Source error" on tap).

Numbers 5-10 in Icelandic are gender-invariant (NUM-02 in Phase 8
context) and ship as bare clips at `assets/audio/numbers/<name>.aac`
(fimm, sex, sjö, átta, níu, tíu). Numbers 1-4 are gendered and live
in `masculine/`, `feminine/`, `neuter/` subfolders.

`pubspec.yaml`'s `assets:` list registered the three gendered
subfolders but NOT the parent `assets/audio/numbers/`. Flutter only
bundles asset paths covered by an entry in pubspec, so the bare
clips never made it into the asset bundle. The audio_manifest.g.dart
entries pointed at non-bundled paths, and just_audio's ExoPlayer
returned `Source error`.

**Fix:** Add `assets/audio/numbers/` to the pubspec assets list,
keeping the gendered subfolders for 1-4.

**Commit:** `9feb898 fix(android): bundle gender-neutral number clips (5-10)`

## Bug NOT a bug

### Low device volume produces inaudible playback

The user's tablet had STREAM_MUSIC volume at 3/15 (default Huawei
profile), which made tapped letters technically play but at near-
inaudible levels. AudioFlinger's `finalVolume: 0.0` in
`PGAudioState` reflects this device-level mute, not an app issue.

Recommendation surfaced for the user (turn up the volume before
testing) but no code change.

## Verified flows on real device

- App launches without crash (8.4s cold start — slow but not blocking)
- Home screen renders Hugrún title + Stafir + Tölur rooms
- Tap Stafir → grid shows all 32 letters in MMS order with pastel palette
- Tap any letter → AudioTrack created, MediaFocus requested, audio plays
- Long-press swap_horiz icon ~3s → mode advances (Letters → Match)
- Match mode shows real word slug ("jol", "gata", etc.) — image when
  asset present, placeholder text otherwise
- Tap correct letter → green checkmark celebration, auto-advance
- Tap Tölur → grid shows 10 digits 1-10
- Tap any digit → audio plays (verified for 5 post-fix)

## Items NOT verified on this pass

- **Audio quality / pronunciation** — out of scope for runtime fixes;
  the user said "doesnt work", not "sounds wrong"
- **240fps latency measurement** — Phase 4 STAFIR-02 gate is its own
  procedure with a 240fps camera; not exercised here
- **Tracing room** — long-pressing twice more from Match would reach
  Trace mode; not exercised in this pass
- **CVC room** — same as Trace
- **Photo upload via parent settings** — not exercised
- **Welcome narration** — fires on first launch; the test runs are
  killed before the welcome completes, so was not heard. The
  controller is dispatched via `addPostFrameCallback` per Phase 4
  Plan 04-06, so the warm-up race fix (Bug 4) probably also stops
  any latent crash there.

## Constraints honored

- No edits under `.github/workflows/` (Phase 15 territory)
- No `git push` issued — Phase 15 will pick up these commits on its
  next push
- No new dependencies, no banned packages
- All 469 unit tests still pass

## Suggested follow-ups (NOT done in this pass)

1. Update Phase 5 SUMMARY to call out that Match mode was broken
   end-to-end on real device until 2026-05-02 (the test fixtures
   used `wordHundur` which happened to PascalCase-strip correctly).
2. Add an integration test that round-trips
   `letterToUtteranceKey('h') → letterH → kLetterToWord →
   wordHundur → kAudioManifest → 'hundur' → assets/.../hundur.webp`
   to catch any future stub-leak regressions.
3. Consider an asset-bundle assertion that walks every
   `kAudioManifest[*].path` and verifies each path is covered by
   a pubspec entry — would catch Bug 5-style omissions at build time.
