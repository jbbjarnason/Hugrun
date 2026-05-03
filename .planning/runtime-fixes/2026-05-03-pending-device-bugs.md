# Pending Device-Test Bugs — handoff to next session

**Reported by Jon during real-device testing on 2026-05-03 (Huawei MediaPad CMR W09, Android 9).**

The app is functional on device after the Phase 22 (real-device fix) pass. These are quality / UX issues caught during play.

## Verbatim user comments from this session (chronological, for context)

These are Jon's exact words / concerns. Treat them as the source of truth for what to fix and how:

1. **"the app doesnt work"** — referring to first device-run attempt. Resolved by Phase 22 (5 critical bugs fixed: 29 letters silent, kLetterToWord empty, slug mismatch, AudioEngine warmup race, missing pubspec assets entry for `assets/audio/numbers/`).

2. **"when I click æ I get aeda, why the wrong spelling"** — example word for æ was "æða" (vein/artery). Heard as "aeda" by kid. Fixed: replaced with "ær" (ewe). New sheep image sourced.

3. **"v vatn is weirdly said"** — Piper Steinn's pronunciation of `vaff` (letter name) and `vatn` (water) is rough. Pending fix; Azure TTS migration would resolve.

4. **"the other letters also have misspellings like ö"** — confirms the Piper-quality issue is broad, not just 1-2 letters. Diacritics generally weak.

5. **"can we enhance what we have, it is 80% okay"** — initial preference: don't switch TTS, just improve. Then changed mind to Azure (see #11).

6. **"and below the picture of vatn you should have the word spelled"** — wants the example word as TEXT below the image. Literacy aid. Item 2 in the pending list.

7. **"and you can find many more pictures online like pera and api and all of the letters, just google those"** — wants every example word to have a real image. Some currently are placeholder text. Sourcing required for all 32 (and later all ~160 if 5-words-per-letter happens).

8. **"we can also go with azure neural tts, just let me know how to make credentials"** — strategic switch. Runbook at `.planning/deployment/azure-tts-setup.md`. Awaiting credentials.

9. **"and can you add a big back button"** — UX bug. Current back affordance is missing/tiny on activity screens. A 5-year-old can't navigate home. Item 3.

10. **"sometimes I click and I dont get sound, when I am quickly clicking"** — AudioEngine cancel-on-new-tap race. Item 5.

11. **"dúkka is a teddy bear not a dúkka, the picture"** — image-content mismatch. Item 1.

12. **"and g and j and y and ý and þ need to go a bit up, it is cutted"** — descender clipping in LetterTile. Item 4.

13. **"can you add more words, like for h, we can also have hákarl. like can we try to have at least 5 words for each letter"** — major scope expansion to 5 words/letter. Item 8.

14. **"p can you add pabbi"** — wants `pabbi` (daddy) for letter p. Currently only `pera` (pear). Should be in the 5-words-per-letter set.

15. **"and m for mamma"** — wants `mamma` (mommy) for letter m. Currently only `mús` (mouse). Should be in the 5-words-per-letter set.

**Pattern emerging:** Jon prioritizes WARM, FAMILIAR, KID-RELATIONAL words over abstract ones. mamma/pabbi >> mús; hákarl (shark — exciting) >> hundur alone. The 5-words-per-letter list (item 8 below) should bias toward words a 5yo encounters daily: family, food, animals seen at the zoo or in books, body parts, household objects. Less so: abstract concepts, verbs, places.

## Earlier session principles (persistent)

These were established earlier and should carry forward:

- **"remember TDD and use marionette for e2e tests"** — TDD red→green→refactor mandatory; Marionette is the E2E framework (saved to project memory at `~/.claude/projects/-Users-jonb-Projects-hugrun/memory/feedback_testing.md`).
- **"80% is OK"** — don't perfectionist. Ship working over perfect.
- **No text instructions visible to child** (PROJECT.md core constraint) — but example word LABELS below images are OK; that's content, not instruction. Top-level "Stafir" / "Tölur" / "Stillingar" AppBar titles were visible to child and are now hidden (Phase 12).
- **No fail states, no scores, no timers** (PROJECT.md core).
- **Native-speaker pronunciation review is non-negotiable** — neither Claude nor any spectral-analysis tool can certify Icelandic phonetic correctness. User (or another native speaker) must do this manually via `python3 tools/tts/review_server.py` after each bake.

## Current state of the world (2026-05-03 evening)

- All 14 numbered phases (1-13.1) shipped. Phase 14 (deploy CIs) + Phase 15 (verify green) shipped.
- 469 unit/widget tests passing.
- 5 CI workflows green on https://github.com/jbbjarnason/Hugrun
- App functional on Huawei MediaPad CMR W09, Android 9 (5 critical real-device bugs fixed).
- Real CC photos for 32 lexicon nouns (with 8 swapped to kid-friendly cartoon style in Phase 11.2).
- Audio: 118 clips baked via Piper Steinn voice, technical-pass approved, native-speaker review still pending.
- Web repo: https://github.com/jbbjarnason/Hugrun (main branch, all commits pushed).
- Build artifacts (APK + IPA unsigned) generated automatically by deploy-android + deploy-ios workflows on every push to main.
- Google Play setup runbook at `.planning/deployment/google-play-setup.md` (designed for browser-driving Claude).
- Azure TTS setup runbook at `.planning/deployment/azure-tts-setup.md` (designed for Jon to follow OR a browser-driving agent).

## Priority list

### 1. dúkka image is a teddy bear, not a doll (5 min)

`assets/images/letters/words/dukka.webp` currently shows a teddy bear from Phase 11.1's Wikipedia auto-pick. `dúkka` means "doll" in Icelandic. Needs swap.

**Fix:** Source CC-licensed doll image from Wikimedia Commons / Openclipart. Replace `dukka.webp`. Update CREDITS.md.

### 2. Show example word text below image (15 min)

When a letter is tapped, the kid sees the picture but not the spelled word. Adding the word text below the image is a literacy aid.

**Files to modify:**
- `lib/features/stafir/widgets/example_word_overlay.dart` — primary change site
- `lib/features/stafir/matching/matching_round_image.dart` — also show word
- `lib/features/stafir/cvc/cvc_activity.dart` — show CVC word
- `lib/features/tolur/correspondence/correspondence_activity.dart` — show noun
- `lib/features/tolur/addition/addition_activity.dart` — show noun

**Style:** lowercase, sans-serif rounded, 36-48pt, centered below image. Maybe wrapped in pastel-colored chip.

**Tests to update:** the corresponding `_test.dart` files for each widget — assert the word Text widget is present.

### 3. Big back button on kid surfaces (15 min)

Currently the back-affordance on activity screens is missing or tiny (after Phase 12 stripped the AppBar). A 5-year-old can't navigate home.

**Design:** ~80px circular tap target, top-left, pastel color, `Icons.home_filled` or a house glyph. On tap → `Navigator.popUntil((r) => r.isFirst)` to go all the way home.

**Surfaces needing the button:** StafirRoom, TolurRoom, MatchingActivity, CvcActivity, TracingActivity, SequencingActivity, CorrespondenceActivity, SubitizingActivity, AdditionActivity, ParentSettingsScreen, PhotoUploadScreen, LexiconPicker.

(Probably easier: one shared `BigBackButton` widget reused everywhere. Conditionally pop or popUntil based on stack depth.)

### 4. Descender letters clipped (10 min)

Letters with descenders are visually cut off at the bottom of their tiles: **g, j, y, ý, þ** (and possibly `p`, `q` if they existed).

**Fix:** In `lib/features/stafir/widgets/letter_tile.dart`, the Text widget for the letter glyph needs more vertical breathing room — likely a `padding: EdgeInsets.only(bottom: 16)` on the inner container or a baseline shift.

**Test:** Update widget tests with explicit golden / dimension assertions for these 5 letters.

### 5. Rapid-click audio drops (20 min — needs investigation)

User reports: rapid taps sometimes produce no sound. Symptom: silent fails, not crashes.

**Likely cause:** in `lib/core/audio/audio_engine.dart`, when `play(A)` is loading and `play(B)` cancels A, the cancellation throws "Loading interrupted" — but the throw might be propagating to play(B)'s own setup path, dropping it too.

**Diagnostic steps:**
1. Add detailed logging to `play()` method
2. Reproduce locally with rapid synthetic taps
3. Inspect logcat for the order of events
4. Likely fix: wrap each play() in its own try/catch so prior-load failures don't cascade

### 6. Pronunciation issues — DEFERRED IF AZURE TTS HAPPENS

User reports v / vatn / ö (and others) sound off. These are Piper Steinn quality limits.

**Strategic decision pending:** user said "we can also go with azure neural tts" — see `.planning/deployment/azure-tts-setup.md` for the credential setup runbook. Once `AZURE_TTS_KEY` + `AZURE_TTS_REGION` are added as GitHub secrets / env vars, dispatch an agent to:
1. Write `tools/tts/azure_client.py` (REST client for Azure TTS)
2. Re-bake all 118 clips with `is-IS-GudrunNeural` voice
3. Re-run spectral review
4. Regenerate `lib/gen/audio_manifest.g.dart`
5. Push

**If Azure NOT chosen:** add per-letter overrides in `pronunciation_overrides.yaml` for v, ö, and any other reported letters. Re-bake those specific clips. Iterate as user finds more.

### 7. Optional: Mouse photo unclear

`mus.webp` (mouse) — agent flagged it as small/unclear thumbnail; user hasn't reported but worth swapping during the next image pass.

### 8. Expand to 5 words per letter — MAJOR SCOPE (3-4 hours)

User asks: each letter should have at least 5 example words, not just 1. E.g. for `h`: hundur (dog), hákarl (shark), hús (house), hár (hair), hattur (hat), etc.

**Scope:**
- 32 letters × 5 words = ~160 example words (vs current 32)
- Each new word needs: manifest.yaml entry + audio clip + image + reviewed.yaml entry
- ~128 new audio clips to bake (~10 min Piper batch, or Azure if migrated)
- ~128 new CC-licensed images to source

**UI change required:**
- When kid taps letter, currently plays the SINGLE wordX clip
- New behavior: randomly pick one of 5 wordX_a, wordX_b, wordX_c, wordX_d, wordX_e on each tap (or rotate sequentially)
- Edit `lib/core/audio/utterance_resolver.dart` and/or `lib/features/stafir/example_word_resolver.dart`

**Suggested word lists (kid-friendly Icelandic, 5 per letter):**
```
a: api, álfur, amma, akur, ananas      (monkey, elf, grandma, field, pineapple)
á: ár, áll, ást, ávöxtur, álfur        (year, eel, love, fruit, elf)
b: bók, bíll, banani, brauð, bolti     (book, car, banana, bread, ball)
d: dúkka, drekka, dómur, dagur, dýr    (doll, drink, judgment, day, animal)
ð: maður, faðir, móðir, leður, vaða    (note: ð never word-initial; show words containing ð)
e: epli, eldur, egg, ein, ekkert       (apple, fire, egg, one-fem, nothing)
é: él, ég, éta, éla, éng                (snow shower, I, eat, ...)
f: fiskur, fugl, fótbolti, faðir, ferja (fish, bird, football, father, ferry)
g: gás, gata, gulur, glas, garður       (goose, street, yellow, glass, garden)
h: hundur, hákarl, hús, hár, hattur     (dog, shark, house, hair, hat)
i: ilmur, ís, ísbjörn, inni, eins        (scent, ice, polar bear, inside, similar)
í: íþrótt, íkorni, ís, íbúð, ísbjörn    (sport, squirrel, ice, apartment, polar bear)
j: jól, jakki, jökull, járn, járnbraut  (Christmas, jacket, glacier, iron, train)
k: kýr, köttur, kanína, kaka, kjúklingur (cow, cat, rabbit, cake, chicken)
l: lampi, ljón, laxa, lestur, leikur    (lamp, lion, salmon, reading, game)
m: mús, móðir, máni, matur, melóna      (mouse, mother, moon, food, melon)
n: nef, nóa, nálarsteinar, nótt, nikulás (nose, Noah, ..., night, Santa)
o: ostur, opna, ofn, olía, önd          (cheese, open, oven, oil, duck)
ó: ól, ósk, óperu, óvin, óhreinn         (belt, wish, opera, enemy, dirty)
p: pera, papa, peysu, pizza, páfagaukur (pear, daddy, sweater, pizza, parrot)
r: rós, rautt, rúta, rauf, rolla         (rose, red, bus, slot, sheep)
s: sól, snjór, smjör, sokkar, segull    (sun, snow, butter, socks, magnet)
t: tönn, tré, tölva, tunglið, teppi     (tooth, tree, computer, the moon, blanket)
u: ugla, undir, upp, út, urð            (owl, under, up, out, rocky terrain)
ú: úr, úlfur, úlpa, úti, út              (watch, wolf, anorak, outside, out)
v: vatn, vasi, vél, vagn, vík            (water, vase, machine, wagon, cove)
x: xýlófónn, ... (only ~3-5 Icelandic words start with x — may not reach 5)
y: ylur, yndi, yfir, ymja, ys            (warmth, joy, over, ..., bustle)
ý: ýta, ýtri, ýmist, ýll, ýll            (push, outer, sometimes, ...)
þ: þrír, þúsund, þytur, þríhjól, þrúga  (three, thousand, whoosh, tricycle, grape)
æ: ær, æða, æðislegt, æfing, ætla       (ewe, vein, awesome, practice, intend)
ö: öxl, önd, ör, öld, össa              (shoulder, duck, scar/arrow, century, ...)
```

**Honest note:** some letters are hard to find 5 kid-friendly words for (x, ý, é). User should review the proposed list and prune/swap.

**Recommendation:** ship 3 words per letter first as a beta (~96 clips), iterate to 5 if quality holds.

This is best dispatched as a dedicated multi-hour agent run, with Azure TTS already in place so audio quality is high.

## Things to NOT lose in the noise

- **Repo is public at https://github.com/jbbjarnason/Hugrun** — Jon authorized push. CI pipelines live there.
- **Hugrún (the child) is 5 years old** — design must work for a non-reader.
- **Marionette is `marionette_flutter ^0.5.0`** (leancodepl) — MCP-based, not a scripted assertion framework. The integration tests provide the gating, not Marionette.
- **Audio review pending:** `reviewed.yaml` has `technically_reviewed: true` for all 118 clips but `reviewed: true` (= native-speaker approved) is FALSE. The manifest_writer has a soft-gate that emits the manifest with PRONUNCIATION REVIEW PENDING comments per entry. Production-quality release requires the native-speaker review pass. Ergonomics: `python3 tools/tts/review_server.py` opens a localhost UI for tap-through approval.
- **Phase 7 tracing is simplified placeholders** (Bezier curves, not authentic Briem). Designer pass deferred to v1.1+. Not blocking play.
- **The orchestrator (Claude) cannot listen to audio directly** but CAN render spectrograms and visually inspect via the Read tool. Spectral analysis caught the leading-silence bug (1180ms → 70ms) in Phase 13.1.
- **Test suite blind spots:** the 5 device bugs from Phase 22 all passed CI tests because the tests stubbed the hot paths. Tests need to be honest mocks of real behavior, not just "stub returns the 3 working cases."
- **License hygiene matters** — every image must be CC0/CC-BY/Pixabay/Pexels. Documented in `assets/images/CREDITS.md`. ElevenLabs TTS is BANNED for under-13 apps (their ToS); Piper (Apache 2.0) and Azure (commercial-friendly) are clean.
- **Budget warning:** Jon hit a usage limit during this session (resets 10am Atlantic/Reykjavik). Background-agent dispatches eat budget faster than direct work.

## Suggested agent dispatch order for next session

A fresh `/clear`'d session with full context budget could batch these as:

**Agent 1: UI fixes (1-4 above)** — 45 min
- Tasks 1, 2, 3, 4 in one agent run
- All are widget-layer / asset-swap; clean scope
- Push, user tests, iterate

**Agent 2: Audio race fix (5)** — 30 min
- Audio engine investigation
- Could also include pronunciation overrides if Azure not happening yet

**Agent 3: Azure TTS migration (6)** — 60 min, blocked on user adding Azure creds
- Full re-bake with Azure
- Spectral review confirms quality lift

## Other context

- Repo: https://github.com/jbbjarnason/Hugrun
- Branch: main, all commits pushed up to `e8eb498` (æ→ær fix)
- 469 tests passing, 5 CI workflows green on remote
- App functional on device with documented quality bugs above
- Build artifacts available in deploy-android / deploy-ios artifacts on every push

---

*Authored: 2026-05-03 during context-tight session — handoff for fresh session*
