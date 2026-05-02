# Feature Research

**Domain:** Icelandic kids' literacy + numeracy app, ages 4–6, single-child / co-play
**Researched:** 2026-05-02
**Confidence:** MEDIUM-HIGH (HIGH on global app patterns and pedagogy; MEDIUM on Icelandic-specific implementations because store listings and curriculum docs are sparse)

---

## Icelandic Market Scan

The user's "Active scope" is already locked, so this section is descriptive (what's out there, what's missing) rather than recommendation-shaping. It does, however, sharpen the differentiator picture.

| App | Audience | What it does well | Gaps relevant to Hugrún |
|---|---|---|---|
| **GraphoGame lestrarleikur** (Grapho Group, Univ. Jyväskylä) | 4–9, full Icelandic | Adaptive phonics: graphemes → phonemes → blends → words. 20%+ of Iceland's population has downloaded it. 88% reading-skill improvement after 6 months. No ads, offline, free. | Game-loop heavy: avatar customization, "earn rewards", adventure map. Depends on rewards-as-motivation — exactly what the project rejects. Built for school deployment, not personalized to one child. Recommended dose 15 min/day. |
| **Lesa.app** (lesa.app, fall 2026 launch) | Grades 1–4 (ages ~6–10) | Reading adventure with levels, characters, post-reading "playground" reward. Targets joy of reading, national overview. | Older than Hugrún. Gamification-heavy. Not pre-reader friendly. |
| **Læsir** (Skólalausnir ehf, App Store) | "Learn to read in Icelandic" | Specific Icelandic phonics focus. | Very thin public info; appears school-deployment focused. |
| **Orðalykill / Mussila WordPlay** (Mussila) | Children & immigrants learning Icelandic | 22 vocab themes (school, kitchen, camping). Vocabulary, listening, spelling. Free. | Vocabulary builder, not a phonics-first app. Not for absolute pre-readers. |
| **Orðagull** (Rósa Mosi) | Speech / language pathology | Auditory understanding, repeating instructions, yes/no, vocabulary, speech production. | Therapy tool, not a play app. Reads instructions aloud — assumes child follows verbal instructions. |
| **Moka Mera Lingua** (Moka Mera AB) | 3–8, multilingual incl. Icelandic | No ads, no IAP, no data collection, offline. Two characters speak different languages. Award-winning for kid-safety design. | Not Iceland-built; Icelandic is a localization layer over Swedish-origin content. Generic, not personalizable. |
| **Vala Leikskóli** (Advania / InfoMentor) | Parents | Daycare communication: attendance, schedules, photos, messaging. | Not an educational app — included only because it's the most-installed leikskóli-branded app and worth knowing it isn't a competitor. |
| **123skoli.is** "Stafainnlögn" | Teachers | Print/digital materials for letter introduction in early grades. | Not an app; teacher resource. Useful as a curriculum reference. |
| **"Stafaland"** (named in milestone context) | — | Could not confirm an app by this exact name in current Apple/Google stores. Likely refers to a generic "letter land" preschool resource or a small/legacy product. | Treat as reference rather than competitor. |
| **Krakkalandi** (named in milestone context) | — | Could not confirm in app stores. Possibly a legacy app, web resource, or content brand. | Treat as reference rather than competitor. |
| **"Lærum að lesa"** (named in milestone context) | — | The literal phrase = "Let's learn to read". No specific app dominates that name; nearest matches are Lesa.app and Læsir above. | Treat as a category description, not a specific competitor. |

**Global reference apps** the user's PROJECT.md / context implicitly competes with even on an Icelandic device:
- **Khan Academy Kids** (2–8, free, no ads). Five animal characters; 1000+ activities across literacy, language, math, SEL. Adaptive-but-gentle — no fail states. Personalized in difficulty but not in content.
- **Endless Alphabet / Endless Numbers** (Originator). The single best reference for tap-to-feedback feel. Letters animate and vocalize the *phoneme* (not name) on touch; complete a word and a definition-acting animation plays. No scores, no timers, no fail.
- **Lingokids** (Monkimun, kidSAFE, ad-free, paid). 4000+ activities across 173 preschool lessons. Often cited as content-rich but navigation-overwhelming.
- **Writing Wizard** (L'Escapadou). The reference for letter tracing — 16 fonts, custom tolerance, animated stroke-order guides, sticker rewards, customizable letter size and difficulty.

### What's missing in the Icelandic market (the moat)
1. **No leading Icelandic app personalizes to *the specific child*.** GraphoGame adapts difficulty, but the dog in the example word is still a stock dog. Hugrún can ship "your dog *Snati* with the letter S" — no competitor can do this without a per-user content pipeline they aren't building.
2. **Nothing combines tap-to-hear simplicity with the full 32-letter set in Menntamálastofnun order plus zero-fail philosophy.** GraphoGame is closest but uses gamification as the engagement engine.
3. **Numbers + letters in one Icelandic app.** Most Icelandic apps are literacy-only. Mussila has separate music/language apps; numeracy in Icelandic for 4–6 is genuinely under-served.
4. **Co-play design.** Every Icelandic-market app assumes solo child use; none design explicitly for "parent on the couch joining in occasionally." That's a niche the app can own without effort.

---

## Feature Landscape

### Table Stakes (Users Expect These)

These are the floor. Missing one = the app feels broken or amateur to a parent.

| Feature | Why Expected | Complexity | Notes |
|---|---|---|---|
| All 32 Icelandic letters in MMS order | Anything less is "not a real Icelandic alphabet app" | LOW | a, á, b, d, ð, e, é, f, g, h, i, í, j, k, l, m, n, o, ó, p, r, s, t, u, ú, v, x, y, ý, þ, æ, ö. Skip c, q, w, z (school convention since ~1980). |
| Tap-to-hear letter name + example word | Established by Endless Alphabet / GraphoGame; users will tap and expect a sound | LOW | Already in MVP. Two-stage: letter sound first (~250 ms gap), then example word. Don't say the *letter name* and the *phoneme* both — pick one model and stick with it. School convention is letter name (e.g. "ess" for s) when introducing the alphabet. |
| Pre-baked, normalized, native-quality Icelandic audio | Bad TTS pronunciation = parent uninstalls. Especially for ð, þ, æ, ý | LOW–MED | Already locked. ffmpeg-normalize pass non-negotiable. Manual review pass per clip. Tiro's Diljá v2 + ElevenLabs evaluated as the milestone says. |
| Zero-fail interaction | Users expect this from Khan Academy Kids, Endless apps, Moka Mera | LOW | Wrong tap = nothing penalising happens; correct tap = celebration. Re-try is free and silent. |
| No text instructions; visuals + audio only | Pre-readers can't read instructions | LOW | Iconography + audio prompts. The whole UI must be navigable by a non-reader. |
| Tap target ≥ 2 cm × 2 cm physical | Established UX research: 5-year-olds have 57% accuracy on intended-target taps; large gross-motor targets compensate | LOW | ~75–90 px @ standard density on a tablet, but always validate by physical mm not px. Iconography on home screen and within rooms must hit this. |
| Tap-to-hear latency ≤ ~50 ms perceived | Already locked in PROJECT.md. Endless Alphabet feels instant; anything >100 ms feels "broken" to a 5-year-old | MED | Pre-load audio in memory via just_audio, no disk I/O on tap, no async work between tap and play. |
| Parent gate (multi-second hold or simple math) | App Store/Play Store reviewers and parents both expect a gate before settings | LOW | Already locked. Hold-3s. The math version (Apple's older guideline) is overkill here. |
| Offline operation | Tablet on a plane / in a car / parent doesn't want a network app for a 5-year-old | LOW | Already locked. No network calls during play. |
| No ads, no IAP, no analytics SDKs | Parent expectation that has hardened post-2020. Moka Mera and Khan Academy Kids both lead with "no ads". | LOW | Already locked. |
| Volume / mute respects system | Tablet in shared spaces. Parent will rage-uninstall if app overrides system volume | LOW | Standard just_audio behavior; verify on iOS silent switch. |
| Pause / leave activity = no penalty | Co-play means interruptions are constant. Re-entering must not punish | LOW | No "you have to start over" — state is per-letter, not per-session. |

### Differentiators (Where Hugrún Actually Wins)

| Feature | Value Proposition | Complexity | Notes |
|---|---|---|---|
| **Personalization with parent-supplied photos** | The single biggest moat. "S — Snati" with a photo of the child's actual dog is unmatched by any major app. | HIGH | Requires: photo picker, on-device tagging UI for parents (not child), tag → Icelandic word mapping, audio generation pipeline that lets parents tag a photo and produce/select audio for it. The audio side is the hard part — either ship a pre-recorded library of common pet/toy/family words and let parents pick the matching tag, or extend the build-time TTS pipeline with a "parent-add" run. |
| **Child's name in voice-overs and tracing** | "Hugrún, finnur þú H?" makes the app feel like it was built for *her*, because it was | LOW–MED | Name is text input; voice clip can be either pre-generated for top 200 Icelandic given names, or generated on-device once via Tiro. Plain inserted-name approach (e.g. "<chime> Hugrún <chime> finnur þú stafinn H?") sidesteps grammatical declension issues at age 5. |
| **Co-play design (parent occasionally engaged)** | No major app designs for this; every app assumes solo child or pure parent-led | LOW | UI affordances: pauseable audio, "tap to repeat" on every clip, bigger-than-needed targets so a parent's finger is fine too, no time-locked sequences a parent's chat would interrupt. Mostly an absence-of-anti-features. |
| **All 32 letters present in MVP, not staged** | Icelandic-specific letters (ð, þ, æ, ö, accented vowels) are exactly what differentiates from "global app with Icelandic localization" — under-investing here is fatal | LOW | Already locked. But ensure phoneme audio quality is *equal* across the diacritic-heavy letters; these are the ones cheap apps bungle. |
| **Photo-tagged personalization for numeracy too** | Counting "your three trucks" beats counting generic apples | MED | Reuse the same photo + tag system for numbers room. "Telja: 1, 2, 3 trukkar" with photos of the child's trucks. |
| **Single narrator voice across the whole app** | Sonic identity. Endless and Khan Kids both do this — feels like a character "lives" in the app. Most Icelandic apps mix voices. | LOW | Already implied by PROJECT.md's "one primary narrator voice". Worth flagging as a feature, not just a TTS detail. |
| **No gamification at all** | Anti-feature for the market, differentiator for the parent. "I want my kid to learn, not collect badges" is a real market segment | LOW | Already locked in PROJECT.md. Worth marketing as a feature if the app ever goes public. |
| **Subitizing as a first-class numeracy activity** | Genuinely under-built in apps targeting this age. Endless Numbers does eye-counting but not flash-and-recognize subitizing. Research links subitizing to later arithmetic ability. | MED | Flash 1–5 dots in standard arrangements (dice patterns + line + random), 1–3 second exposure. See activity spec below. |
| **One-to-one correspondence as explicit activity** | "Last number said = the count" is the conceptual jump most apps skip. Multi-touch makes this *more* natural than physical counters because each tap is registered. | MED | See activity spec below. |
| **MMS-aligned letter handwriting in tracing** | Parents will recognize and trust school-aligned letterforms; many global apps use generic / Anglo letterforms that look "off" for Icelandic | MED | Use *Ítalíuskrift* (the more modern, simpler model) as primary. Fallback: *Skrift 1–7* style. Letters are slightly slanted, simplified, unconnected, with exit strokes. Briem's letterforms cover all 32 — but the *Primarium* listing notes there is no *single* standardized model in Iceland; teacher choice is allowed. Designing to Ítalíuskrift is defensible and modern. |

### Per-Activity Specifications

#### 1. Tap-to-hear (MVP, locked)

**Layout.** 32-letter grid. Two reasonable layouts:
- (a) 4 cols × 8 rows portrait — works on a 10" tablet, each cell ≥ 2 cm.
- (b) 8 cols × 4 rows landscape — same constraint.

Pick one orientation; lock it (don't rotate — disorienting).

**Tap behavior.** Tap letter → ≤50 ms haptic + visual reaction (scale up 1.05x, 80 ms ease-out). Audio: letter name immediately. ~300 ms gap. Example word ("H — hundur"). Total clip ~1.2–1.6 s.

**Re-tap during playback.** Cancel current clip, restart. Don't queue. (Endless Alphabet does this; it's what makes the app feel responsive.)

**Idle state.** After ~20 s of no taps, very subtle shimmer on a random letter to invite re-engagement. No audio prompts (avoids being annoying during co-play conversation).

**Visited-state subtle indicator.** Slight color/border softening on letters already tapped this session. Resets on app restart. *Not* a progress score — purely an exploration aid so the child can see what's left to try. Optional; can defer.

**Accessibility.** Each letter is its own accessible widget with a semantic label (the letter + word).

#### 2. Letter-to-word matching (post-MVP, in v1 scope)

**Mechanic.** Show one letter prominently. Show 3 candidate pictures. Child taps the one that starts with that letter. Wrong tap: gentle bounce-back, no negative sound. Correct tap: image scales up, audio "H – hundur!", confetti or simple animation.

**Distractor design.** Distractors should *not* sound like the target letter (avoids the *bjarn* / *björn* / *brauð* confusion at age 5). Pull from a curated word→image mapping with phonetic distance.

**Personalization hook.** When a personalized photo exists for the target letter (e.g. parent's dog = "Snati" tagged for S), use that as the *correct* image roughly 40% of the time — frequent enough to feel personal, not so frequent it's the only image they ever see for that letter.

**Round structure.** 5–8 rounds, then a "well done" character animation, then exit to grid. No score shown.

#### 3. Letter tracing (post-MVP, in v1 scope)

**Letterform.** Ítalíuskrift lowercase as primary (slightly slanted, simplified, unconnected, with exit strokes). Uppercase optional later. All 32 letters.

**Stroke recording.** CustomPainter; sample touch at 60 Hz; store SVG-style polylines per stroke.

**Tolerance.** Generous: a child's stroke counts as "on path" if every sampled point is within ~25–35 px (~5–7 mm at typical tablet density) of the ideal centerline. Writing Wizard / iTrace use customizable tolerance; for a 5-year-old, ship the loose end of that range. Real research: 5–6 year olds get frustrated by tight tolerance and incorrect-stroke-order error states (Frontiers in Psychology 2018, "Child-Centered Design" — children expressed frustration when they had to correct stroke order).

**Stroke order.** *Soft* enforcement (already specified in PROJECT.md). Show animated stroke-order ghost before the child starts. If they go out of order, don't reject — accept the stroke, but next letter, replay the ghost. Don't make the child correct.

**Lift between strokes.** Most letterforms are 1–3 strokes. Allow the child to start the next stroke anywhere on the next stroke's path, not just the start point. Rigid start-point enforcement is a known frustration source.

**Off-path behavior.** Off-path = the painter shows the trail in a slightly desaturated color. Coming back on-path = trail returns to vibrant color. No "wrong" sound. Completion check is "did they hit each stroke's start and end region within tolerance" — not "every point was on path".

**Completion celebration.** Letter fills with a child-friendly color, a particle puff, narrator says the letter name + the example word. Optional: child's name in the celebration ("Frábært, Hugrún!").

**Crayon vs pen UX.** Use a thick brush stroke (~12–18 px), not a hairline. Thick strokes hide imprecision and look more like a crayon, which the child already understands. Writing Wizard's animated stickers/sound effects approach is the reference, but tone it down — Hugrún isn't sticker-driven.

**Stroke-order ghost timing.** Play the ghost once on letter entry (~1.5 s), then auto-fade. Replay on tap of an "ear" or "eye" icon (universal repeat affordance). Don't auto-replay every attempt — that becomes patronizing.

#### 4. CVC blending (post-MVP, in v1 scope)

**Words.** PROJECT.md lists *kýr, sól, hús, rós*. Note these are technically CVC by spelling but most are not pure C-V-C phonemically (Icelandic has long/short vowel distinctions and complex consonants). For age 5 this is fine — the *spelling* pattern is the lesson, not phonemic purity.

**Suggested expanded CVC list for Icelandic 5-year-olds** (3-letter, single-vowel, common, picturable):
- *sól* (sun), *hús* (house), *kýr* (cow), *rós* (rose), *bók* (book), *fót* (foot acc.), *kál* (cabbage), *mús* (mouse), *bíl* (car acc.), *súl* (column), *fús* (eager — abstract, skip), *kál*, *vín* (wine — skip), *sjón* (sight — 4 letters), *krá* (skip), *hár* (hair), *brauð* (skip — 5 letters), *rauð* (skip), *tré* (tree — but ends in vowel), *mey* (skip), *dís* (sprite/elf-girl), *gás* (goose), *lás* (lock), *nös* (nostril), *völl* (skip), *völur* (skip), *kýs* (skip — verb).

The reliably picturable, age-appropriate, true-spelling-CVC short list (≈ 8–12 words): *sól, hús, kýr, rós, bók, mús, hár, gás, lás, nös, dís*. The user's existing four (*kýr, sól, hús, rós*) is a perfectly good starter set. For more variety, add *bók, mús, hár, gás*.

**Mechanic.**
1. Show 3 letters, e.g. K–Ý–R. Show a faded image of a cow.
2. Child taps each letter in order. Each tap → letter zooms slightly, plays its phoneme (not letter name — for blending we want the sound).
3. After all 3 are tapped: short pause (~300 ms), then narrator blends slowly: "k... ý... r..." then quickly: "kýr!" Image fully de-fades to vibrant.
4. Re-tap any letter to hear its phoneme again. Re-tap the assembled word (or a "ear" icon) to hear the blend again.

**Phoneme vs name.** This is the one activity where letters speak their *phoneme*, not their *name*. The blending activity is the only place the distinction matters; tap-to-hear can stay on letter names (school convention).

**No "wrong" path.** Child can tap in any order; the activity just doesn't blend until all 3 are tapped. (Optional stricter: require left-to-right; soft-enforce by gently dimming letters that are "out of order". Probably skip the strictness for v1.)

#### 5. Subitizing (post-MVP, numbers room)

**Targets.** 1, 2, 3, 4, 5 dots.

**Patterns.** Use *multiple arrangements* for each quantity, not always the dice pattern. Research (Steve Wyborney, Math Coach's Corner) emphasizes *perceptual* subitizing requires varied arrangements: dice, line, random, finger-pattern. Cycle through them. Otherwise the child memorizes "this picture = 4" rather than recognizing the quantity.

**Flash duration.** 1–3 s for beginners; 0.5–1 s for confident recognition. Start at 2 s and shorten as the child shows speed. Don't time the *child's response* — the timer is only on the dot exposure.

**Mechanic.**
1. Tap to start a round (no auto-start — co-play context, child controls pace).
2. Dots flash for 2 s. Then they hide.
3. Three options appear (numerals 1–5, three of them). Child taps the one matching the count.
4. Wrong tap: gentle bounce; the dots flash again.
5. Correct tap: numeral grows, narrator says it, dots come back arranged neatly with each dot bouncing in sequence (audio: "einn, tveir, þrír... þrír!").

**No score, no streak.** ~5–8 rounds per session; child can leave any time.

**Variant.** "How many [pictures]?" using the child's personalized photos — show 3 photos of *their* dog and ask. This connects subitizing to one-to-one correspondence and is a natural place for personalization to shine in numeracy.

#### 6. One-to-one correspondence (post-MVP, numbers room)

**Mechanic.** Show 3–5 objects in a row (e.g. fish, ducks, the child's tagged photos). Tap each object once. Each tap → object jumps slightly, narrator says the next number ("einn... tveir... þrír!"). After last tap, narrator emphasizes: "Þrír! Það eru þrír [hlutur]" — *the last number said is the count.*

**Already-tapped state.** Tapped objects get a subtle highlight or count-bubble so the child can't double-count and lose their place.

**Reset.** "Try again" button (a circular arrow icon — universal symbol). One-tap resets without judgment.

**Gendered counting.** PROJECT.md note: use the gendered form when the object is pictured. Three dogs = "einn, tveir, þrír hundar" (masc); three houses = "eitt, tvö, þrjú hús" (neut); three girls = "ein, tvær, þrjár stelpur" (fem). This requires audio clips per (number, gender) — 5 numbers × 3 genders = 15 clips for counting words, plus the abstract masculine for "just counting" mode. Manageable.

**Integration with personalization.** Counting "your three trucks" with the child's photos is the strongest single emotional moment the numbers room can produce. Build with this in mind from day one.

#### 7. Addition with objects (post-MVP, numbers room)

**Scope.** Sums to 5 only. Maybe 10 later. No symbols ("+", "=") in the visual UI for v1 — just objects and a result.

**Mechanic.** Two groups of objects ("2 fiskar" + "1 fiskur"). Child taps "combine" (or drags one group toward the other). Animation: groups merge. Then count the combined group via one-to-one. Narrator: "einn, tveir, þrír. Þrír fiskar!"

**No equation display in v1.** Numerals appear above each group, but no "+" or "=". Keep the abstraction concrete. (This is the Endless Numbers / Khan Kids approach for early ages.)

**Variants.**
- "Make 5": child adds objects to a group until it reaches 5 (taps to drop one in). Each tap → object lands, count narrated.
- "Two groups": as above.

#### 8. Sequencing (post-MVP, numbers room)

**Mechanic.** Numerals 1–5 (or 1–10 later) shown shuffled. Child drags them to slots in order. Wrong slot = gently springs back to original position with no sound. Correct slot = locks in with narration ("einn!", "tveir!", "þrír!"). When all are placed: a bigger animation, full count read aloud.

**Reverse mode.** Show the numerals in order, but missing one (e.g. 1, 2, _, 4, 5). Drag the missing one in from a side tray.

**Tap-to-hear sequencing.** Like tap-to-hear letters, but with numerals in their gendered abstract form (masc.: einn, tveir, þrír…). Each tap plays the number name. This is the numbers-room equivalent of the MVP letter grid and probably the simplest first activity to ship in *Tölur*.

### Anti-Features (Commonly Built Elsewhere, Deliberately Excluded Here)

| Feature | Why Tempting | Why Don't | Hugrún Approach |
|---|---|---|---|
| **Stars / scores / points** | Standard kids-app retention mechanic; kids find them satisfying short-term | Replaces intrinsic curiosity with extrinsic chasing; conflicts with PROJECT.md core value; once introduced, removing them feels like a punishment | Already excluded. Replace with intrinsic feedback: animations, completion, narration. |
| **Streaks / daily-use mechanics** | Drives retention; standard in language apps | Adult mechanic. Stresses parents (not kids) and creates "oh no I forgot" guilt around a 5-year-old's tablet time | Already excluded. |
| **Levels / "you've unlocked X"** | Sense of progress | All 32 letters available always. Locking content insults the child and adds dev complexity. The build-first principle is "make the loop great", not gate it | Everything available always. |
| **Avatars / character customization** | GraphoGame uses this; the Endless monsters have a mild form | Pulls focus from the actual learning. Adds asset and persistence complexity for ~zero pedagogical value at age 5 | Skip. The narrator voice is the "character". |
| **Timers on child responses** | Can be framed as "fun pressure" | Creates fail states by another name. 5-year-olds need pacing freedom, especially in co-play where parents interject | Already excluded. Only use timers for stimulus exposure (e.g. subitizing flash), never on response. |
| **Voice recognition / mic input** | "Listen to me say it!" feels magical when it works | Brutal failure modes for a 5-year-old; Icelandic ASR for child voices is unproven; privacy concerns with audio capture | Excluded. Audio is one-way (app → child). |
| **Story mode with a narrative arc** | Engagement; Lingokids and Endless do this | Significant content cost; conflicts with "tap one letter, hear it" build-first principle | Skip in v1. The "story" is the example word's image. |
| **Tutorial / instructional intro** | Standard onboarding | Pre-readers can't read tutorials. Co-play means a parent will explain on first use anyway | Already excluded. Make affordances self-evident. |
| **Sentence-level reading** | Natural progression after CVC | Out of scope for age 5; PROJECT.md explicit | Already excluded. |
| **Rhyming games** | Universal in English-language preschool apps | Icelandic inflection makes this hard at this age; PROJECT.md explicit | Already excluded. |
| **Music / song-based learning (alphabet song, count song)** | Memorable; Khan Kids and Lingokids both use songs heavily | Songs are content-heavy to produce well; "alphabet song" with 32 letters in MMS order doesn't have an established Icelandic melody equivalent to the English one (the closest is multiple variants none dominant). High effort, unclear ROI | Defer. Could be a v2 feature; not in v1 scope. |
| **Multiplayer / shared device sessions** | Sibling use case | PROJECT.md excludes. One child, one device | Already excluded. |
| **Cloud sync of personalization** | "What if we lose the photos?" | Privacy regression; creates account / network requirement; overkill for one device | Excluded. Local backup via Drift export to a parent-controlled file is the safer alternative. |
| **Parent dashboard / progress reports** | Parents like data | Conflicts with no-scoring philosophy; if there's no score, what would it report? Time-on-task is creepy for a 5-year-old | Excluded. Co-play *is* the dashboard. |
| **Voiceover with multiple character voices** | More personality | Each new voice doubles the audio asset cost and review pass workload | Excluded. One narrator only — already in PROJECT.md. |
| **In-app letter games imported wholesale from English apps** | Easy content win | Letterforms, phoneme inventory, and example words are wrong for Icelandic. ð/þ have no English equivalent. The whole point is Icelandic-first | Excluded. All content authored for Icelandic. |

---

## Feature Dependencies

```
[Pre-baked TTS pipeline]
    └─> [Tap-to-hear MVP] (locked)
         └─> [Letter-to-word matching]
              └─> [Personalized photo hook in matching]
         └─> [CVC blending]
              └─> [Phoneme audio set] (separate from letter-name set)
    └─> [Tracing]
         └─> [Ítalíuskrift letterform asset library]
              └─> [Personalized name in tracing celebration]
    └─> [Numbers room: tap-to-hear numbers]
         └─> [Sequencing 1-5]
         └─> [One-to-one correspondence]
              └─> [Subitizing 1-5]
              └─> [Addition with objects]
                   └─> [Personalized object photos in counting]

[Personalization: photo picker + tag UI]
    ──enhances──> [Letter-to-word matching]
    ──enhances──> [One-to-one correspondence]
    ──enhances──> [Subitizing variant]

[Personalization: child name input] (MVP)
    ──enhances──> [Tracing celebration]
    ──enhances──> [Tap-to-hear (optional name in narrator prompts)]

[Parent gate (MVP)]
    └─> [Personalization settings] (post-MVP)
         └─> [Photo picker + tag UI] (post-MVP)
```

### Dependency Notes

- **TTS pipeline gates everything.** The build-time YAML→TTS→AAC→normalize pipeline must support: (a) static letter+word clips for MVP, (b) phoneme clips for blending, (c) gendered number-word clips for one-to-one, (d) name-templated clips for personalization, (e) parent-supplied photo→Icelandic-word audio (the hardest variant — needs either a curated pre-built lexicon or a runtime/build-time generation hook for parents). Plan for (a)–(d) explicitly; design (e) so a curated lexicon (~200 common nouns: pet names, toys, family terms, foods) ships in v1 and a free-text extension is a v2 feature.
- **Phoneme set ≠ letter-name set.** Letter names are used in tap-to-hear ("h" = "há"), phonemes in CVC blending ("h" = /h/). Both must exist. Two clips per letter minimum.
- **Photo personalization requires the matching activity.** No point having photos if they're never used. Letter-to-word matching is the natural first home; numeracy variants come later.
- **Tracing requires Ítalíuskrift letterform assets** (as either SVG paths or coordinates). Decide early: hand-author the 32 lowercase letterforms (~1–2 days of careful path work referencing Briem's *Ítalíuskrift* book), or sample from a font and manually clean. Do not generate from a generic Latin handwriting font — accent placement and ð/þ/æ specifics matter.
- **Child-name input gates personalized voice-over.** If the name lookup misses (uncommon name not in the pre-recorded set), fall back to plain inserted-name without inflection. Have a clear "your name isn't here yet" graceful path.

---

## MVP Definition

### Launch With (v1 MVP — already locked in PROJECT.md)

- [x] Two-room home screen (only *Stafir* active)
- [x] All 32 Icelandic letters in MMS order
- [x] Tap-to-hear: letter name + example word
- [x] Pre-baked AAC audio for every clip
- [x] ≤50 ms tap-to-feedback latency
- [x] iOS + Android tablet builds
- [x] Parent gate (hold-3s)
- [x] Child-name capture + use in narrator clips
- [x] No ads, no IAP, no analytics, no network during play

### Add After MVP Validation (Beyond MVP, still v1 scope)

- [ ] Letter-to-word matching activity
- [ ] Letter tracing (CustomPainter, Ítalíuskrift, soft stroke order, generous tolerance)
- [ ] CVC blending (*kýr, sól, hús, rós* — and probably *bók, mús, hár, gás* for variety)
- [ ] Numbers room: tap-to-hear numerals → sequencing → one-to-one → subitizing → addition
- [ ] Photo-tagged personalization (curated lexicon of ~200 nouns to start)
- [ ] Child's name in tracing celebration
- [ ] *Tölur* room unlocked

### Future Consideration (v2+)

- [ ] Free-text photo tagging (parent types their own Icelandic word, runtime/build-time TTS)
- [ ] Uppercase letterforms in tracing
- [ ] Numbers beyond 10
- [ ] Public-release readiness (privacy review, App Store metadata, support email)
- [ ] Optional alphabet song / counting song (only if Hugrún demonstrably wants it)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---|---|---|---|
| Tap-to-hear, 32 letters, MVP feel | HIGH | LOW | **P1** |
| Pre-baked audio + normalization pipeline | HIGH | MED | **P1** |
| Parent gate | MED | LOW | **P1** (compliance) |
| Child name in narration | HIGH | LOW | **P1** |
| Letter-to-word matching | HIGH | MED | **P2** |
| Letter tracing (Ítalíuskrift, soft stroke) | HIGH | HIGH | **P2** |
| CVC blending | HIGH | MED | **P2** |
| Numbers tap-to-hear / sequencing | MED | LOW | **P2** |
| One-to-one correspondence | HIGH | MED | **P2** |
| Subitizing 1–5 | HIGH | MED | **P2** |
| Addition with objects (sums to 5) | MED | MED | **P2** |
| Photo personalization (matching) | HIGH | HIGH | **P2** |
| Photo personalization (numeracy) | MED | MED | **P3** |
| Free-text parent-tag with TTS | MED | HIGH | **P3** |
| Uppercase tracing | LOW | MED | **P3** |
| Counting/alphabet songs | LOW | HIGH | **P3** |
| Sentence-level reading | — | — | OUT |
| Stars / scores / streaks | — | — | OUT |
| Voice recognition | — | — | OUT |

**Priority key.** P1 = required for the MVP shipped to Hugrún. P2 = required for "v1 complete", added in subsequent phases. P3 = future consideration. OUT = explicitly excluded.

---

## Competitor Feature Analysis

| Feature | GraphoGame | Khan Academy Kids | Endless Alphabet | Lingokids | Hugrún Approach |
|---|---|---|---|---|---|
| Full Icelandic alphabet (32 letters) | YES | NO (not localized) | NO | Partial (some Icelandic) | YES, MVP |
| Tap-to-hear | YES | YES | **Best-in-class** | YES | Endless-quality, baked audio |
| Phonics blending | YES (adaptive) | YES (curriculum) | YES (drag-to-spell) | YES | Manual tap-each-letter, narrator blends |
| Tracing | NO | YES | NO | YES | YES, MMS-aligned (Ítalíuskrift), soft stroke order |
| Subitizing | NO | YES (ten-frames) | NO (Endless Numbers does eye-counting) | Partial | Flash-card style, varied arrangements |
| One-to-one correspondence | NO | YES | YES (Endless Numbers) | YES | Tap each, last-number-said-is-count |
| Personalized photos | NO | NO | NO | NO | **YES — moat** |
| Personalized name in narration | NO | NO | NO | NO | **YES** |
| No fail / no score philosophy | Partial (rewards system) | YES | YES | Partial | YES, fully |
| Single narrator | NO | YES | NO (varied) | NO | YES |
| Co-play design | NO | Neutral | Neutral | NO | YES |
| Offline | YES | Partial | YES | Partial | YES, fully |
| Free / no IAP | YES | YES | One-time purchase | NO (subscription) | YES (no monetization) |
| MMS-aligned letterforms | Unknown | NO (Anglo) | NO | NO | YES (Ítalíuskrift) |
| Adaptive difficulty | YES (research-backed) | YES | NO | NO | NO (fixed; child sets pace) |

---

## Icelandic-Specific Considerations Called Out

1. **Alphabet order is fixed: a, á, b, d, ð, e, é, f, g, h, i, í, j, k, l, m, n, o, ó, p, r, s, t, u, ú, v, x, y, ý, þ, æ, ö.** Skip c, q, w, z (school convention since ~1980). The alphabet grid in MVP must use this order; do not anglicize.
2. **ð and þ are the make-or-break letters.** A cheap app gets these wrong (audio quality, example word, glyph rendering). High-quality phoneme audio for ð and þ is non-negotiable; manual review pass essential.
3. **Accented vowels are not optional or "alt forms".** á, é, í, ó, ú, ý, æ, ö are *separate letters* in Icelandic, not variants of a, e, i, o, u, y. Treat them as full first-class citizens in every grid, every list, every audio asset.
4. **Number grammar.** *Einn, tveir, þrír, fjórir, fimm* (masc.) is the school-convention abstract counting form for 1-2-3-4-5. When counting *specific gendered nouns*, declined forms (*ein/eitt*, *tvær/tvö*, *þrjár/þrjú*) are correct. Don't try to teach this — *just be consistent*. Audio asset matrix: 5 numerals × 3 genders + abstract masculine form = 20 clips for the first five numbers. Worth it.
5. **Handwriting model.** Ítalíuskrift (modern, simplified, slightly slanted, exit strokes) is the more contemporary MMS-published model and the recommended target. Skrift 1–7 is the older alternative. Per the *Primarium* reference, Iceland does not enforce a single national model — teachers choose — so Ítalíuskrift is *defensible* rather than *mandatory*. Briem (Gunnlaug S. E.) is the design authority; his book and online materials cover all 32 letterforms including diacritics.
6. **Letter names vs phonemes.** School convention: introduce by letter name first (e.g. *s* = "ess"). For blending, use the phoneme. The app needs both clip sets.
7. **Pronunciation review for TTS.** Tiro v2 voices and ElevenLabs both stumble on certain Icelandic combinations. Build the `pronunciation_overrides.yaml` file from day one. Common known issues: ð/þ before/after voiceless consonants, ll → /tl/ rule (e.g. *fjall* → "fjat-l"), preaspiration in *pp/tt/kk*. Manual review pass per clip is in PROJECT.md and is correct.
8. **Common children's words for example/CVC use.** *hundur, kötturinn/köttur, hús, sól, kýr, rós, mús, bók, fiskur, blóm, tré, eldur, vatn, brauð, mjólk, epli, banani, banani, gulrót, þeir, þá, ég* — pull from frequency lists for child-directed Icelandic, available via the Árnastofnun (Árni Magnússon Institute) and *íslensk málheild* corpora if a deeper word-frequency pass is wanted. For v1 the user's existing list plus a hand-curated 30-noun extension is sufficient.

---

## Sources

### Icelandic apps / market
- [GraphoGame lestrarleikur — Iceland impact](https://graphogame.com/blog/the-impact-of-graphogame-in-iceland-a-model-for-evidence-based-edtech/)
- [GraphoGame on App Store (Iceland)](https://apps.apple.com/is/app/graphogame-lestrarleikur/id6477287840)
- [GraphoGame on Google Play](https://play.google.com/store/apps/details?id=com.graphogroup.gg_icelandic)
- [LESA — Reading adventure for kids (launching fall 2026)](https://www.lesa.app/)
- [Læsir on App Store](https://apps.apple.com/us/app/l%C3%A6sir/id6446181462)
- [Orðalykill / Mussila WordPlay](https://mussila.com/ordalykill/)
- [Orðalykill on Google Play](https://play.google.com/store/apps/details?id=is.mussila.ordalykill)
- [Orðagull on Google Play](https://play.google.com/store/apps/details?id=is.rosamosi.ordagullremaster)
- [Moka Mera Lingua — Icelandic localization](https://mokamera.com/press/award-winning-educational-language-app-for-children-is-now-available-in-danish-icelandic-and-norwegian/)
- [Vala Leikskóli on App Store](https://apps.apple.com/is/app/vala-leiksk%C3%B3li/id1389133859)
- [123skoli.is — Stafainnlögn (teacher resource)](https://123skoli.is/products/stafainnlogn)
- [Reykjavík schools — approved educational solutions](https://reykjavik.is/en/gschools/parents/approved-educational-solutions)

### Global reference apps
- [Khan Academy Kids — overview](https://www.khanacademy.org/kids)
- [Khan Academy Kids review — Educational App Store](https://www.educationalappstore.com/app/khan-academy-kids)
- [Khan Academy Kids — Good Play Guide](https://www.goodplayguide.com/reviews/khan-academy-kids/)
- [Endless Alphabet — Originator](https://www.originatorkids.com/endless-alphabet/)
- [Endless Alphabet — Common Sense Media](https://www.commonsensemedia.org/app-reviews/endless-alphabet)
- [Endless Numbers — Originator](https://www.originatorkids.com/endless-numbers/)
- [Endless Numbers — Common Sense Education](https://www.commonsense.org/education/reviews/endless-numbers)
- [Lingokids review — Common Sense Media](https://www.commonsensemedia.org/app-reviews/lingokids-play-and-learn)
- [Writing Wizard — L'Escapadou](https://lescapadou.com/wp/en/writing-wizard-app/)
- [iTrace — handwriting practice](https://apps.apple.com/us/app/itrace-handwriting-practice/id645416621)

### Icelandic curriculum, language, handwriting
- [Miðstöð menntunar og skólaþjónustu (MMS)](https://mms.is/)
- [Iceland — Primarium handwriting education](https://primarium.info/countries/iceland/)
- [Ítalíuskrift — Primarium](https://primarium.info/handwriting-models/italiuskrift/)
- [Icelandic orthography — Wikipedia (alphabet order reference)](https://en.wikipedia.org/wiki/Icelandic_orthography)
- [MMS — Lestrarbækur fyrir 1.–4. bekk gátlisti 2024](https://mms.is/namsefni/lestrarbaekur-fyrir-born-i-1-4-bekk-gatlisti-2024)
- [Letter-sound knowledge in Icelandic 6-year-olds — ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0001691823001294)
- [Sérhljóðar / samhljóðar — 123skoli.is](https://123skoli.is/product/serhljodar-samhljodar-og-atkvaedi-orda)

### Pedagogy and child UX research
- [Child-Centered Design: Developing an Inclusive Letter Writing App — Frontiers in Psychology, 2018](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2018.02277/full)
- [Touch interaction for children aged 3 to 6 years — ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S1071581914001426)
- [Ability of children to perform touchscreen gestures — PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7303424/)
- [Design for Kids Based on Their Stage of Physical Development — Nielsen Norman Group](https://www.nngroup.com/articles/children-ux-physical-development/)
- [Number Sense, Fingers and Multi-Touch Apps in Preschool — Springer](https://link.springer.com/chapter/10.1007/978-3-032-16065-2_2)
- [Preschoolers' Dot Enumeration Abilities Are Markers of Arithmetic Competence — PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3979837/)
- [A theory for learning numbers without counting gains popularity — Hechinger Report](https://hechingerreport.org/proof-points-subitizing/)
- [Steve Wyborney — 100 subitizing slides & 10 challenge patterns](https://stevewyborney.com/2018/09/100-subitizing-slides-10-challenge-patterns/)
- [Math Coach's Corner — Using Dot Cards to Build Number Sense](https://www.mathcoachscorner.com/2013/07/dot-cards/)
- [Audio latency on Android — Google Android Developers Blog](https://android-developers.googleblog.com/2021/03/an-update-on-androids-audio-latency.html)

---

*Feature research for: Hugrún — Icelandic kids' literacy + numeracy app, ages 4–6, single-child / co-play*
*Researched: 2026-05-02*
