# Pitfalls Research

**Domain:** Icelandic literacy + numeracy app for a 5-year-old (Flutter, iOS + Android tablets), built for one child first, optionally shipped publicly later.
**Researched:** 2026-05-02
**Confidence:** HIGH for App Store requirements, Riverpod/Drift/just_audio behavior, child-UX research, Icelandic grammar rules. MEDIUM for Tiro TTS specifics (docs are sparse) and ElevenLabs licensing for kids' apps (terms ambiguous, requires direct verification).

> Each pitfall has: severity tag (CRITICAL / IMPORTANT / NICE-TO-AVOID), the failure mode, why it happens, prevention, warning signs, and which roadmap phase should own the prevention. Cross-cutting tables (debt patterns, integration gotchas, store-compliance, "looks-done-but-isn't") are at the bottom.

---

## Critical Pitfalls

### Pitfall 1: TTS mispronunciation slips into the bundled audio [CRITICAL]

**What goes wrong:**
A clip with a wrong pronunciation (`þ` collapsed to `t`, `ð` rendered as `d`, `æ` as `a`, double consonants softened, a loanword like *jeppi* or *píanó* mispronounced, or a proper noun like *Hugrún* itself broken) ships baked into the AAC bundle. It cannot be fixed without an app update. Hugrún hears it; an Icelandic-speaking parent who tries the app later hears it; trust collapses immediately. Icelandic has no native-speaker tolerance for "close enough" — a single botched `ð` reads as foreign.

**Why it happens:**
TTS systems trained on Icelandic still struggle with: (a) **þ/ð** (especially word-medial ð), (b) **æ** vs **e**, (c) **ö** vs **o**, (d) **double consonants and pre-aspiration** (`hattur`, `kötturinn`), (e) **loanwords** that schools teach with Icelandic-adapted pronunciation but TTS may render with English/Danish phonology, (f) **proper nouns and names** that aren't in the model's lexicon (the child's own name, the dog's name). Generating 200–400 clips and "spot-checking" guarantees that 5–20 will be wrong and you won't catch them.

**How to avoid:**
- **Mandatory 100% native-speaker review** of every utterance before bundling. No spot checks. A parent who is a native Icelandic speaker listens to every clip in a quiet room with headphones.
- Maintain `pronunciation_overrides.yaml` from day one. Every override entry points to either an SSML `<phoneme alphabet="ipa">` block or an ice-g2p phonetic spelling.
- For Tiro TTS: use the [grammatek/tts-frontend pipeline](https://github.com/grammatek/tts-frontend) and [ice-g2p](https://github.com/grammatek/ice-g2p) for problem words rather than fighting the TTS engine.
- Re-review on every TTS provider/voice version change. Tiro voice IDs (`Diljá v2`, `Álfur v2`) imply v1 existed and changed — assume future version bumps will silently shift pronunciation.
- Generate a small **diagnostic set** of known-problem words (`þú`, `ðar` words, `æ`-words, double consonants, `Hugrún`, target loanwords) and run it on every TTS version change as a regression check.

**Warning signs:**
- "I'll review the clips later" — later doesn't come.
- Override file is empty or has < 5 entries (statistically impossible to be right at 200+ clips).
- Generation pipeline has no human-in-the-loop checkpoint.
- New voice version arrived and was adopted without re-review.

**Phase to address:**
Phase 1 (TTS pipeline) — bake the review step into the pipeline before the alphabet is recorded. The pipeline must refuse to emit a final asset bundle until every clip has a `reviewed: true` flag.

---

### Pitfall 2: Icelandic alphabet order or letter set drifts from school convention [CRITICAL]

**What goes wrong:**
The app teaches the alphabet in a different order than what Hugrún sees in school, or includes/excludes letters incorrectly. School and *menntamálastofnun*/*Miðstöð menntunar og skólaþjónustu* materials use the modern 32-letter set: **A Á B D Ð E É F G H I Í J K L M N O Ó P R S T U Ú V X Y Ý Þ Æ Ö**. (No C, Q, W, Z in the modern school alphabet — Z was officially dropped from Icelandic orthography in 1973, and pre-1980 schoolbooks listed C, Q, W, X, Z that are no longer taught.) Including Z, putting Æ before Þ (the historical pre-1980 order placed Þ Æ Ö at the end; but some sources still list 36-letter old order including C/Q/W/Z), or omitting Ð/Þ produces an immediate "this isn't the alphabet I learn at school" reaction from the child.

**Why it happens:**
- Stack Overflow / generic "Icelandic alphabet" lookups still return the historical 36-letter list.
- Wikibooks and tourist sites often list both old and new orders.
- Developers familiar with Nordic languages may default to a Norwegian/Swedish-flavored ordering.
- The letters Ð, Þ, Æ, Ö are easy to typo or misorder when transcribing.

**How to avoid:**
- Source the canonical 32-letter ordered list **from a current Icelandic primary-school textbook or Menntamálastofnun/MMS material**, not from English-language Wikipedia or tourist guides.
- Validate the list against [Icelandic orthography on Wikipedia (Icelandic-language version)](https://is.wikipedia.org/wiki/%C3%8Dslenska_stafr%C3%B3fi%C3%B0) and have a native speaker confirm before bundling assets.
- Store the alphabet as a single typed Dart constant `kIcelandicAlphabet` in one place; never let phase teams introduce parallel orderings.
- Write a unit test asserting the 32-letter order and that no C/Q/W/Z appear in the bundled letter activities.

**Warning signs:**
- Letter count is 36 or 26 (wrong), not 32.
- C, Q, W, or Z appear anywhere in the alphabet activity.
- Æ appears before Þ in the ordering (modern is Þ → Æ → Ö).
- Asset folder structure uses ASCII-only filenames with transliterated letters (eg `th.aac`) — early sign that someone is working around encoding rather than handling Icelandic correctly.

**Phase to address:**
Phase 0 (project setup) — define `kIcelandicAlphabet` and add a verification test before any letter content is built.

---

### Pitfall 3: Failure feedback that a 5-year-old reads as "you failed" despite no explicit score [CRITICAL]

**What goes wrong:**
The PROJECT.md mandates "no failure states, no scores, no instructions to read." But research on early-literacy apps shows that **excessive corrective animation/sound** (a sad sound, a head-shake, a "try again" voice that sounds disappointed, a red flash, an X mark, a character looking down) all read to a 4–6yo as failure even with no score. Conversely, **excessive celebratory feedback after correct answers** (sparkly rainbows, character squealing) creates extrinsic-reward dependence and "undermines intrinsic motivation" ([Hirsh-Pasek et al. / Joan Ganz Cooney findings](https://www.edweek.org/teaching-learning/bad-teaching-for-preschoolers-there-are-lots-of-apps-for-that/2018/08)). Either direction kills the "discoverable, no-fail" promise.

**Why it happens:**
- Designers default to mimicking patterns from popular kids' apps (Monkey Preschool, ABCmouse) which are heavily testing-based.
- "No score" is interpreted as "no number on screen" but the failure signal sneaks in via tone-of-voice, color, or animation.
- Co-play parent watching may unconsciously want feedback for *them* ("did she get it right?") and the design absorbs that pressure.

**How to avoid:**
- **Define the feedback grammar explicitly in design**: only two states for any tap — *intrinsic acknowledgement* (the thing makes its sound, the letter highlights, the count happens) and *no-op* (taps off-target do nothing, no sound, no color). No "wrong" feedback exists at all.
- Voice-over tone for the narrator must be **neutral-warm, not cheerful-encouraging** — record/select voices that sound like a calm aunt, not a TV show host. If using TTS, pick the most neutral voice variant (Tiro `Diljá v2` reportedly more neutral than `Rósa`; A/B test on the actual child).
- For matching/sequencing activities (Phase 2+): a wrong tap should produce the *same* sound as a correct tap on that target (it just doesn't progress the activity), not a different "wrong" sound.
- User-test on Hugrún: watch her face. If she looks discouraged, the feedback is wrong even if no explicit "wrong" exists.

**Warning signs:**
- Any negative-valence sound effect (descending pitch, minor key, short "uh-uh") in the project.
- Child stops tapping after a sequence of off-target taps. Means she's reading the silence as failure.
- Voice-over script contains "let's try again," "almost," "good try" — all of which encode failure as the antecedent.
- Any animation depicts a character looking sad, surprised, or disappointed.

**Phase to address:**
Phase 1 (tap-to-hear MVP) — establishes the feedback grammar that all later phases inherit. Get this wrong here and every activity has the same flaw.

---

### Pitfall 4: Tap latency exceeds ~50ms and feels cheap [CRITICAL]

**What goes wrong:**
PROJECT.md sets a < ~50ms perceived latency bar. Reality with `just_audio` on Android is that **the very first playback of a short clip starts a few hundred ms in**, missing the head of the audio ([just_audio issue #941](https://github.com/ryanheise/just_audio/issues/941)). On iOS, AVAudioSession activation on first play adds 50–200ms. Asset decoding from disk on first access also adds 50+ms. A child taps `H`, hears nothing for 300ms, then hears `…undur` instead of `Hundur`. The app feels cheap and unresponsive; the child doesn't trust that her tap "worked."

**Why it happens:**
- `just_audio` decodes the asset on first `setAsset` call.
- iOS AVAudioSession is inactive by default and activation has cost.
- Android short-clip playback has known leading-silence issue.
- AAC at low bitrates can introduce an encoder priming delay (~20–50ms) at the head of every clip.

**How to avoid:**
- **Pre-warm**: at app start, instantiate one `AudioPlayer` per concurrent voice, call `setAsset` with the first clip (or a silent priming clip), `pause()` immediately. Activates the session, decoder, and buffer pools.
- **Pool players**: keep 2–4 long-lived `AudioPlayer` instances and round-robin across them. Creating a new player per tap is fatal to latency.
- **Use `audio_session` package** to configure the iOS category to `playback` (allows silent-switch override appropriate for kids' apps) and pre-activate at app launch.
- **Pad each AAC clip with 20–50ms of silence at the head** during the build pipeline. This both masks the encoder priming delay and absorbs any cold-start head-clipping. Loudness-normalize *after* padding.
- **Visual feedback fires synchronously with the tap**, independently of audio readiness. The letter highlights/scales the instant the gesture is detected; the audio plays as fast as it can. This way even a 100ms audio latency doesn't read as unresponsive.
- Test latency with a high-speed camera or screen-recording at 240fps on the actual tablet. Don't trust the simulator or your subjective perception.

**Warning signs:**
- The first tap after app open feels different from subsequent taps.
- Hugrún taps a letter, then taps it again before the sound finishes — means the first tap didn't register as having "happened" perceptually.
- Audio file headers show no leading silence padding.
- Single-shared `AudioPlayer` is being torn down and recreated per tap.

**Phase to address:**
Phase 1 (tap-to-hear MVP) — this *is* the MVP loop. If it doesn't feel right here, no later feature compensates.

---

### Pitfall 5: Audio loudness inconsistency across clips [CRITICAL]

**What goes wrong:**
Some clips are noticeably louder than others. The child is on a tablet at a fixed system volume; a soft clip is inaudible, a loud clip startles her. Compounds with parent co-play (parent set the volume comfortable; one clip blasts). Worse, mixing clips from two TTS providers (Tiro vs ElevenLabs) without normalization guarantees inconsistency since the providers ship at different reference levels.

**Why it happens:**
- TTS engines do not produce uniform LUFS output.
- Different voices (Diljá vs Álfur) have different inherent loudness.
- Different utterance lengths produce different perceived loudness even at equal peak.
- Manual ad-hoc normalization ("sounds about right") doesn't catch the long tail.

**How to avoid:**
- **Standardize on a target LUFS in the pipeline**. For mobile kids' content, `-16 LUFS integrated, -1 dBTP true peak` is the right target. This matches Apple Music's mobile target ([reference](https://auphonic.com/blog/2013/01/07/loudness-targets-mobile-audio-podcasts-radio-tv/)) and is louder than the EBU R128 -23 LUFS broadcast standard (broadcast is wrong for tablets; -14 LUFS streaming-music targets are too loud for sustained kid use). `-16 LUFS / -1 dBTP` is a reasonable compromise: audible at typical tablet volumes, not painful at max.
- Use [`ffmpeg-normalize`](https://github.com/slhck/ffmpeg-normalize) with EBU R128 mode targeting `-16 LUFS / -1 dBTP / 11 LRA`.
- **Normalize after** any silence padding or clip-trim, not before.
- Measure all clips post-normalization and reject any that deviate > ±1 LU from target — it means the clip had too little signal (mostly silence) or clipping.
- **Listen test on the actual tablet at the actual volume Hugrún uses.** -16 LUFS in the studio is not the same perceived loudness on a 7" tablet at 50% volume.

**Warning signs:**
- No `loudnorm` or `ebu` step in the asset pipeline.
- Manual `-af volume=0.8` kind of adjustments in ffmpeg commands.
- ElevenLabs and Tiro clips coexist without re-normalization.
- "Just turn the device volume up/down" is the user-facing answer.

**Phase to address:**
Phase 1 (TTS pipeline). Same phase as Pitfall 1 — they share the build pipeline.

---

### Pitfall 6: App Store Kids Category compliance failures (Apple Guidelines 1.3, 5.1.4) [CRITICAL — only if shipping publicly]

**What goes wrong:**
PROJECT.md says "release publicly later" is a possibility. The personalization feature ("parent uploads photos and tags them with Icelandic words") triggers App Store Review Guideline 5.1.4(b): apps in the Kids Category collecting photos/videos/drawings from minors require **verifiable parental consent, not just a parental gate**. The hold-3-seconds parent gate is sufficient for *gating links/purchases* (Guideline 1.3) but **insufficient for collecting personal data including child-photo uploads**. Submission gets rejected; rebuild required. ([Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/))

Additional landmines from same guidelines:
- **No third-party analytics SDKs at all** — already covered by PROJECT.md "no analytics SDKs," good.
- **No IDFA / device identifiers** — no analytics SDK = no IDFA = good.
- **Privacy policy required** even for purely-local apps in Kids Category.
- **"For Kids" / "For Children" wording in App Store metadata is reserved for Kids Category** — using it elsewhere triggers 2.3.8 rejection.
- **Crash-reporting SDKs (Sentry, Firebase Crashlytics) are third-party analytics** under Apple's interpretation and are restricted in Kids Category. Even Apple's own MetricKit is the safer choice.

**Why it happens:**
- Builders read Guideline 1.3 (parental gate), think it covers everything, miss 5.1.4(b) (parental consent for data collection — different and stricter).
- "It's all on-device, no network" is correctly safe technically but Apple still requires a privacy policy explaining that.
- Crash reporting feels like ops, not analytics; Apple disagrees.
- The personalization feature (photos) is exactly the trigger for the strictest rules.

**How to avoid:**
- **If shipping publicly**: decide *now* whether to enter the Kids Category. The category brings discoverability among parents but tightens every constraint.
- For photo upload personalization (deferred feature): treat it as **on-device only, never transmitted** — and document this in the privacy policy. This is the safest interpretation; even still, Apple may require explicit parental consent UI distinct from the parental gate.
- **No crash reporting SDKs**. Use platform-native: iOS MetricKit, Android Play Console crash reports — these are first-party and acceptable. Or accept no crash visibility and rely on direct user feedback (acceptable for n=1 → small audience).
- Write the privacy policy *before* submission, not after rejection. Host it on a static page (GitHub Pages is fine).
- Avoid "For Kids" / "For Children" / "For Babies" in App Store metadata unless committed to Kids Category. Use "for ages 4-6" or descriptive language.
- Read [Apple's Kids Category developer page](https://developer.apple.com/app-store/kids-apps/) and the [Helping Protect Kids Online 2025 PDF](https://developer.apple.com/support/downloads/Helping-Protect-Kids-Online-2025.pdf) before any submission.
- Apple's 2025 rating change introduced new bands (4+, 9+, 13+, 16+, 18+) and a more comprehensive questionnaire — answer truthfully; misrepresentation triggers rejection on resubmission.

**Warning signs:**
- Any third-party SDK in pubspec.yaml that touches network (firebase_*, sentry_flutter, mixpanel_*, amplitude_*, posthog_*).
- Photo upload feature without an explicit consent flow.
- App Store metadata draft uses "for kids."
- No privacy policy URL drafted.
- Plan assumes "we'll figure out store review when we get there."

**Phase to address:**
Phase 0 (decide Kids Category yes/no) and a dedicated Phase 6 or final-phase **Store Compliance** before any submission. Do not let store review be the first time these constraints are tested.

---

### Pitfall 7: Riverpod scope/rebuild mistakes that destroy audio timing [CRITICAL]

**What goes wrong:**
A widget rebuild triggered by a Riverpod state change tears down and recreates the `AudioPlayer`, or invalidates a provider mid-playback, causing audio to cut, duplicate, or trigger latency on the next tap. Symptoms compound with Pitfall 4 (latency).

**Why it happens:**
- Holding `AudioPlayer` in a `StateProvider` whose `state` rebuilds on dependency changes.
- Using `ref.read` inside `build` (anti-pattern: stale data, no rebuild on change) ([codewithandrea.com](https://codewithandrea.com/articles/flutter-state-management-riverpod/)).
- Putting `AudioPlayer` in a non-`autoDispose` provider but rebuilding the parent `ProviderScope` ([Riverpod issue #4661 reports a 3.2.0 regression](https://github.com/rrousselGit/riverpod/issues/4661) where every frame triggered ProviderScope rebuild).
- Scoped `ProviderScope.overrides` in route transitions invalidating audio provider unintentionally ([Riverpod issue #1298](https://github.com/rrousselGit/riverpod/issues/1298)).
- Using a `StreamProvider` for audio events that builds widgets that rebuild on every event.

**How to avoid:**
- **`AudioPlayer` lives in a top-level `Provider` (not `autoDispose`, not scoped)**, instantiated in `main()` and never recreated. Hold it via a `Provider<AudioPlayer>((ref) => AudioPlayer())` and dispose only in `ref.onDispose` at app shutdown.
- **`select` for granular subscriptions** — never `ref.watch(bigStateProvider)` and pull a sub-field; use `ref.watch(bigStateProvider.select((s) => s.field))` so the widget only rebuilds on the field change.
- **Pin Riverpod to a known-good version**. Riverpod has had multiple regressions in 3.x. If on 3.x, pin exactly and verify on the test device that frame-rate is steady at 60fps with audio playing.
- Use Riverpod's code generator (`@riverpod`) for type safety, but be aware of the [build_runner / analyzer constraint conflicts](https://github.com/rrousselGit/riverpod/issues/4364) (Riverpod 3.0.3 test deps may pin analyzer < 8.0.0 conflicting with other generators).
- Never instantiate an `AudioPlayer` in a `build` method, ever, under any circumstance.
- Use Flutter DevTools "Repaint Rainbow" + "Performance overlay" to confirm no rebuild storms during audio playback.

**Warning signs:**
- `AudioPlayer` constructor inside any `build()`, any provider with `autoDispose`, or any function called per tap.
- `ref.read` inside `build`.
- Audio cuts when navigating between screens.
- Frame rate drops below 60fps when audio plays.
- Hot reload causes audio glitches that go away on full restart (sign of state-leak between hot reloads — fine in dev but indicates fragile lifecycle).

**Phase to address:**
Phase 1 (tap-to-hear MVP). Get the audio provider lifecycle right at MVP; later phases just add activities on top.

---

### Pitfall 8: Drift schema migration that loses Hugrún's progress data [IMPORTANT, escalates to CRITICAL once she has data she cares about]

**What goes wrong:**
A Drift schema change in version 2 of the app (adding a column, changing a type, restructuring a table for tags/personalization) ships without a migration, or with a destructive migration that wipes the existing local DB. Hugrún's tracked progress, parent-uploaded photos, and personalization tags are gone. There's no cloud backup (by design — PROJECT.md says no cloud). She notices.

**Why it happens:**
- "It's local, just delete and recreate" feels acceptable in dev → leaks to release.
- Drift's codegen sees only the *current* schema; migrations need to be hand-written based on a snapshot of the *previous* schema ([Drift migration testing docs](https://drift.simonbinder.eu/migrations/tests/)).
- Schema version not bumped on a real change → Drift doesn't run any migration → mismatch at runtime → exception or silent drift.
- `schemaAt(version)` migration tests not written → migrations look right but break on real data.

**How to avoid:**
- **Use Drift's schema export/snapshot from version 1**: `drift_dev schema dump` after each release. Commit the snapshot files.
- **Bump `schemaVersion` for any schema change**, even trivial ones.
- **Write a migration test for every version transition** using `schemaAt(N)` — insert real-shaped data at vN, run migration, assert data still there at vN+1.
- **Never use destructive `onCreate` re-runs** as a "migration" in production. The pattern of "drop everything and recreate" is fine in dev, fatal in prod.
- For any user-uploaded content (photos when personalization ships): store the photo files on the filesystem, only paths in Drift. Migrations affect rows, not files.
- Keep a backup-export feature in the parent settings ("export Hugrún's data as JSON") — even if no UI to import, having the export means data isn't lost if a migration goes wrong.

**Warning signs:**
- `schemaVersion` hasn't changed but tables have.
- No `migrations/` folder or no `schemaAt` tests.
- A team member asks "do we even need migrations? It's just one user."
- `MigrationStrategy.onCreate` does work that should be in `onUpgrade`.

**Phase to address:**
Phase 0 (project setup) — Drift schema versioning policy + first snapshot export. Phase 2+ (when first schema change happens) — first real migration test.

---

### Pitfall 9: Tracing tolerance miscalibrated for a 5yo's motor skills [IMPORTANT — when tracing arrives in Phase 3+]

**What goes wrong:**
Tracing is **too strict**: Hugrún's wobbly trace falls outside the tolerance band, the line resets or "rejects" her input, she tries again, fails again, walks away. Or **too loose**: any tap-and-drag anywhere completes the letter, no learning signal, she figures out it's not real. Either failure mode kills the activity. Research notes that "self-correcting" tracing apps are useful but the tolerance must be tuned to age — and adult-sized tolerance is wrong for 5yos.

**Why it happens:**
- Developers test on themselves (adult fine motor), tune to that, then a 5yo can't make the band.
- Stroke-order enforcement that hard-resets on out-of-order strokes is frustrating for an age that doesn't yet conceptualize stroke order.
- 5yo motor research suggests tap-target areas of **2cm × 2cm minimum** ([NN/g children UX physical development](https://www.nngroup.com/articles/children-ux-physical-development/)); tracing tolerance bands need similar generosity.

**How to avoid:**
- **Tolerance band: 50–60% of the letter's stroke width on each side** as a starting point, configurable in dev. Test with Hugrún and observe — adjust per session.
- **Soft stroke-order**: visual hint (the "next" stroke pulses gently) but no hard rejection. PROJECT.md already says "soft stroke-order enforcement, Menntamálastofnun handwriting model" — keep it soft.
- **Generous endpoint snap**: if the trace ends within ~30% of stroke length to the endpoint, accept it as complete.
- **No "fail" outcome ever.** If she can't complete the letter, the letter just doesn't complete; tapping again restarts; nothing scolds.
- Use [CustomPainter with `shouldRepaint` returning false unless the stroke buffer changed](https://docs.flutter.dev/perf/best-practices) — every-frame repaint will tank perf on cheap tablets.
- Pre-render the letter outline + glyph as a static layer; only the user's stroke is dynamically painted.
- Use [`RepaintBoundary`](https://docs.flutter.dev/perf/best-practices) around the tracing canvas to isolate from the rest of the UI tree.
- Sample touch input at the OS native rate (60Hz on most tablets, 120Hz on iPad Pro) — don't artificially throttle.

**Warning signs:**
- Hugrún's trace gets rejected and she retries the same letter → tolerance too strict.
- She "scribbles" any direction and the activity completes → tolerance too loose / no constraint at all.
- Frame rate drops while tracing → painter is doing too much per frame.
- Stroke order enforcement causes her to get "stuck" on letters with multiple strokes (B, F, H, K, X).

**Phase to address:**
Phase 3 (tracing) — own the tolerance calibration with real testing. PROJECT.md correctly defers tracing past MVP; respect that order.

---

### Pitfall 10: Number-grammar gender inconsistency [IMPORTANT — when numbers room ships]

**What goes wrong:**
The numbers room counts objects but the voice-over uses the wrong gender form: says *einn hús* (mas. + neuter noun) instead of *eitt hús*; or *tveir kýr* instead of *tvær kýr*. Worse: the abstract counting list (used as a recitation track) flips between *einn, tveir, þrír* (masculine) and *ein, tvær, þrjár* (feminine) inconsistently. Icelandic-speaking parents notice immediately. PROJECT.md has the right rule already — *"at age 5, use masculine for abstract counting (matching school convention); use the correct gendered form when counting specific pictured objects. Don't try to teach the grammar — just be consistent."* Pitfall is failing to operationalize that rule in the data model.

**Why it happens:**
- Numbers 1–4 decline by gender and case in Icelandic; numbers 5+ don't decline. Easy to forget that 1, 2, 3, 4 need three forms.
- A naive `numbers.yaml` with one form per number gets it wrong half the time.
- Mixing pre-recorded audio of "*tveir*" with a picture of two ewes (*ær* — feminine) reads as "the app doesn't speak Icelandic right."

**How to avoid:**
- **Data model: every counted object has a grammatical gender tag** (`m` / `f` / `n`).
- **Audio assets are generated per gendered form for 1–4**: `einn.aac`, `ein.aac`, `eitt.aac`, `tveir.aac`, `tvær.aac`, `tvö.aac`, `þrír.aac`, `þrjár.aac`, `þrjú.aac`, `fjórir.aac`, `fjórar.aac`, `fjögur.aac`. For 5+ a single asset suffices.
- **Abstract counting (recitation) uses masculine** as PROJECT.md specifies. This is a fixed track.
- **Object counting picks gender from the object tag** at runtime. The pipeline guarantees the correct asset is picked.
- **Lint check / unit test**: every object in the picture set has a gender tag; the audio bundle has all six gendered forms for 1–4.
- Have a native speaker review every counting voice-over with the picture of the object to confirm agreement is right.

**Warning signs:**
- A single `one.aac` / `two.aac` / `three.aac` / `four.aac` in the bundle (only one form per number — guaranteed wrong half the time).
- Object metadata has no gender field.
- A native-speaker tester says "it sounds wrong" and you can't immediately tell why.

**Phase to address:**
Phase 4+ (numbers room). PROJECT.md correctly defers this beyond MVP; the gender data model needs to be designed before any number content is recorded.

---

### Pitfall 11: ElevenLabs licensing surprise for kids' app [IMPORTANT]

**What goes wrong:**
ElevenLabs is used for some clips in v1, app ships, then licensing review reveals: (a) the free plan does not include commercial license, (b) the [ElevenLabs Prohibited Use Policy](https://elevenlabs.io/use-policy) or future ToS update bans use in apps directed at children under 16 (ElevenReader's terms already say "not designed for individuals under 16"), or (c) cost surprises when generating 200–400 clips at higher tiers. The provider pulls a voice or changes a voice in a version bump and the bundle becomes inconsistent.

**Why it happens:**
- ElevenLabs ToS is product-specific (ElevenReader is restricted under 16; the API may differ but ambiguity exists).
- Voice cloning licensing is more restrictive than synthetic-voice licensing.
- A cheap-tier subscription generates 400 clips fine but a regeneration cycle exhausts the credit.
- Voice IDs change between versions; "Diljá v2" implies v1 was deprecated.

**How to avoid:**
- **Read ElevenLabs Commercial License terms in full *before* generating production assets.** Specifically check: kids-app permission, commercial use under each plan, voice version stability commitments, content-rights-retention clauses.
- **Make Tiro the primary**: it's Icelandic government-funded and free-to-use, voices developed by Reykjavík University, with a clear research-to-production pipeline. Use ElevenLabs only for clips where Tiro quality is unacceptable AND licensing is clean.
- **Keep generated clips, not just the manifest**. Once you've generated and reviewed a clip, that's the asset; you don't need to regenerate. Treat the AAC files as source-of-truth.
- **Pin TTS provider versions in the manifest**: `tts_engine: "tiro"`, `voice_id: "Diljá-v2"`. If the voice ID disappears (Tiro upgrades to v3), regeneration is a deliberate decision, not silent.
- For any clip generated via ElevenLabs, archive the original WAV/MP3 alongside the AAC so a future re-encode doesn't require regeneration.

**Warning signs:**
- Generation script doesn't record which provider/voice/version produced each clip.
- Free-tier ElevenLabs API key in use for what's intended to be production assets.
- No archive of source TTS output (only the final compressed AAC).
- "We'll deal with licensing if we ship" — exactly when it's too late.

**Phase to address:**
Phase 1 (TTS pipeline) — settle provider choice and licensing before generating production assets. PROJECT.md correctly says "Tiro + ElevenLabs evaluated in parallel for v1; commercial/kids-app licensing must be checked before relying on it."

---

### Pitfall 12: "Build for one child" architecture that can't generalize, or generalizes too eagerly [IMPORTANT]

**What goes wrong:**
Two opposite failure modes:

(a) **Hardcoding for Hugrún everywhere**: `name = "Hugrún"` literal in voice-over scripts, image filenames `hugrun_dog.jpg`, gender assumptions, the dog's name baked in. When the question of "could we ship this?" arrives, the entire content layer needs rewriting. The personalization-as-moat insight is true, but personalization done as text substitution into pre-recorded audio is impossible (you can't TTS-substitute one word inside a static AAC clip).

(b) **Premature generalization**: building a multi-child, multi-language, configurable, plugin-based architecture for a single 5yo. Six months in, nothing ships, the architecture is the product, the child is an abstraction.

**How to avoid:**
- **Parameterize from day one** with a single child profile object — `{name, dog_name, photos, tagged_objects}` — backed by Drift. The MVP stores Hugrún's profile, but the *architecture* assumes one profile, not "Hugrún hardcoded."
- **Separate content asset paths by profile**: `assets/audio/letters/h.aac` (alphabet — universal, shared), `assets/audio/personalized/{profile_id}/name.aac` (personalized — per-profile). The personalized folder for Hugrún is generated at her profile creation; the folder structure is the same for any future user.
- **Audio templating**: voice-over slots that combine universal and personalized audio at playback time (`<universal_intro>` + `<personalized_name>`) rather than pre-rendering the combined sentence. This means the TTS for `Hugrún.aac` is a one-shot generation per profile, not per sentence.
- **Resist multi-child support, multi-language, accounts, sync, cloud** (PROJECT.md correctly excludes all of these). One child + parameterized profile is the right level.
- **Don't build the parent companion app, parent dashboard, or progress reports** unless you actually want to ship publicly. PROJECT.md correctly defers these.

**Warning signs:**
- Source code contains the literal string `"Hugrún"` outside config/profile data.
- Or, six months in, the app supports "potentially multiple children" but Hugrún hasn't played a polished MVP.
- Asset folder structure doesn't separate universal from personalized.
- Voice-over generation assumes pre-baked full sentences with the child's name embedded.

**Phase to address:**
Phase 0 (project setup) — establish the profile data model and audio path conventions before any content is generated.

---

### Pitfall 13: Asset bundle size bloat from uncompressed or over-compressed audio [IMPORTANT]

**What goes wrong:**
200–400 short AAC clips at the wrong bitrate add up. At 256 kbps, 400 × 2-second clips = ~26 MB; at 64 kbps mono, the same is 6.5 MB — but at 24 kbps the audio quality starts to degrade audibly on speech. iOS app size affects discoverability; Android cellular install limits historically capped at 150 MB. Worse: bundling uncompressed WAV "for quality" turns a small app into a 200+ MB monster.

**Why it happens:**
- "AAC is compressed, that's enough" — no, the bitrate matters.
- Forgetting to strip metadata/tags from the encoded files.
- Including both WAV (source) and AAC (production) in the bundle.

**How to avoid:**
- **Target: AAC-LC, mono, 22050 Hz sample rate, 64 kbps** for narration speech. Inaudible quality difference vs higher rates for spoken word; 4× smaller than 256 kbps stereo.
- **Strip metadata** in the ffmpeg pipeline (`-map_metadata -1`).
- **Source files (WAV/PCM) live outside the Flutter assets folder** — not in `assets/`, not in `pubspec.yaml`. Generate AAC into `assets/audio/`; commit source elsewhere or to git LFS.
- Run `flutter build apk --analyze-size` and `flutter build ios --analyze-size` periodically to catch size regressions.
- Consider splitting personalization-generated audio into a separate downloadable bundle if (and only if) the app ships publicly with personalization — but for the single-user MVP, ship everything.

**Warning signs:**
- Final IPA / APK > 80 MB without good reason.
- Audio assets folder has both `.wav` and `.aac` files.
- Bitrate set per-clip rather than at the encoder level.

**Phase to address:**
Phase 1 (TTS pipeline) — pipeline output bitrate/format decided here.

---

### Pitfall 14: Hidden cognitive load from animations that distract from the lesson [IMPORTANT]

**What goes wrong:**
Animations that are decorative rather than informative — bouncing letters, rainbow trails, shaking icons — split the child's attention. Research on educational apps for 3–5yos finds that "irrelevant enhancements" reduce learning ([PMC review of 171 preschool apps](https://pmc.ncbi.nlm.nih.gov/articles/PMC8916741/)). The app feels lively but doesn't teach.

**Why it happens:**
- Designers add motion because static feels unfinished.
- "Engagement" is conflated with "stimulation."
- Children's apps in the market are heavily over-animated, so designers calibrate to that baseline.

**How to avoid:**
- **Functional motion only**: motion that *encodes* information (the letter pulses on tap to confirm the tap happened; the count number scales up on the last tap to signal cardinality completion). Decorative motion is removed.
- **No motion during voice-over playback** of an instructional clip. The child needs to hear, not watch.
- **One animation at a time**: if the letter is highlighting, the background isn't doing anything else.
- Defer Rive integration (PROJECT.md already does) — Rive's strength is character animation, which is decorative-by-default. Add Rive only when there's a specific functional motion need.

**Warning signs:**
- Multiple things on screen are animating simultaneously.
- The screen feels "busy" in a screenshot.
- Designer says "we need to add some life to it" — that's the trap.
- A/B prototype test: does the child learn faster with the animation removed? If yes, remove it.

**Phase to address:**
Phase 1 (tap-to-hear MVP) — establishes the motion grammar.

---

### Pitfall 15: Voice-over pacing wrong for the 4–6 age band [IMPORTANT]

**What goes wrong:**
The narrator speaks at adult conversational pace (~180 wpm). A 5yo processes Icelandic at maybe 100–120 wpm; the word goes by before she's parsed it. Or the opposite: pacing slowed to 70 wpm and over-enunciated, sounds patronizing/creepy and the child tunes out. Or: cheery TV-show pace, which reads as fake to even a 5yo.

**Why it happens:**
- TTS default rates are tuned for adult listening.
- The *Diljá v2* / *Álfur v2* default rate may not match what works for a 5yo.
- Adult ear-tested pacing feels right to the adult; the child's ear is different.

**How to avoid:**
- **Target rate: ~110–130 wpm** for instructional content for 4–6yos. (No published Icelandic-specific number; this is from English children's-audio research transposed.)
- **TTS rate parameter: 0.85–0.95×** the default for narration; **1.0×** for letter-name-only utterances.
- **Insert micro-pauses** between letter and example word: `H. <100ms pause> Hundur.` not `H, Hundur` rapid-fire. The pause lets the child link the two without the join confusing her.
- **A/B test on Hugrún**: play two pacings, watch which one she repeats back correctly more often.
- **Avoid SSML `<emphasis>` over-use** — over-emphasized speech pattern is the patronizing tone that backfires.

**Warning signs:**
- Voice-over plays back to back without pauses.
- TTS rate parameter is at default with no consideration of age.
- The narrator sounds like a TV host or a flight safety video.

**Phase to address:**
Phase 1 (TTS pipeline + tap-to-hear MVP).

---

### Pitfall 16: "Discoverable through visuals/audio alone" failure when child genuinely can't figure something out [IMPORTANT]

**What goes wrong:**
PROJECT.md mandates "discoverable via visuals/audio." Sometimes the child can't figure out what to do — taps the screen randomly, walks away. The "no instructions" rule, taken absolutely, becomes a trap: there's no escape hatch.

When this is **a feature**: the child is encouraged to explore, the activity is genuinely tap-anywhere safe, and the only consequence of confusion is "she doesn't engage with this activity yet." This is fine for a single-child build — Hugrún will return when she's developmentally ready.

When this is **a bug**: the activity *requires* a specific gesture (tracing direction, sequencing order) that isn't visually obvious and the child stalls. Or the activity has multiple paths and the child doesn't perceive any.

**How to avoid:**
- **Demonstration-not-instruction**: when the activity opens, an animation *shows* the gesture once (a finger-trace icon does the first stroke; a hand taps the first object in a count). No words, no "now you do it." Just demonstration.
- **Gesture affordances are visually unambiguous**: tap targets pulse softly when idle (universal "I am tappable" signal). Drag targets show a light dotted-trail behind them. Trace lines have a subtle "start here" dot.
- **5-second rule**: if the child has not interacted within 5 seconds, repeat the demonstration (silently if voice-over already played; voice-over only plays once per activity load).
- **Co-play escape hatch**: PROJECT.md says co-play is assumed. Design assumes a parent is *available* nearby. If the child genuinely can't figure something out, the parent helps. Don't try to design out the parent — design *for* the parent.
- **Parent settings can lock specific activities** as "not introduced yet" so the child doesn't keep hitting an activity she's not ready for.

**Warning signs:**
- Child taps once and walks away — same activity, multiple sessions.
- Parent has to verbally explain what to do every time.
- Activity has a path that's only discoverable by reading text.
- No demonstration animation on activity load.

**Phase to address:**
Phase 1 sets the discovery grammar; every later activity phase verifies its activity is discoverable.

---

### Pitfall 17: Failure to plan for shipping-public surprises (Icelandic-parent scrutiny, support burden) [IMPORTANT — only if shipping publicly]

**What goes wrong:**
The app ships free to Iceland. ~90,000 Icelandic-speaking children under 10 means the addressable audience is tiny but vocal. Icelandic parents notice — and post about — pronunciation issues, alphabet errors, a single mis-gendered article. Icelandic Facebook groups and parent forums share the link rapidly because there are so few Icelandic kids' apps. Brigading isn't malicious; it's just that quality-control is community-enforced when you ship in a small-language market.

Adjacent problems: support burden (a single parent emailing about a glitch is 10% of your support volume); store-rating volatility from a tiny user base (one 1-star review tanks the average).

**Why it happens:**
- "Free, no analytics" doesn't mean "no users will engage" — it means you have no signal until someone emails or reviews.
- The Icelandic-speaking community is small enough that an app ostensibly for one child gets discovered.

**How to avoid (if shipping publicly is on the table):**
- **Ship via TestFlight / Play Store internal-testing first**, with a small handful of trusted Icelandic-parent friends. Catch the first round of issues there.
- **Native-speaker review pass before any public listing**. Not a friend who speaks Icelandic — multiple native speakers who critically evaluate every utterance.
- **Email support address on the parent settings screen**, with low expectations set ("I read every email but reply may take a week").
- **Don't ship a half-finished numbers room** — partial features get flagged as "buggy" even if they're labeled as preview.
- **Decline the Kids Category** at first launch if uncertain; "general" with 4+ rating reduces compliance surface and you can re-categorize later.
- **Ship the alphabet room only at first public launch**, even if numbers is partially built, to keep the "what does this app do?" answer crisp.

**Warning signs:**
- "We'll just put it on the App Store and see what happens" — you'll see what happens, and it'll cost you.
- No native-speaker QA pass before submission.
- Store metadata claims features (numbers, tracing, personalization) that aren't actually shipped.

**Phase to address:**
Phase pre-public-release (whatever phase that is — final phase before submission).

---

## Moderate Pitfalls

### Pitfall 18: iOS background audio configuration breaks foreground audio [NICE-TO-AVOID]

**What goes wrong:**
Adding `UIBackgroundModes: audio` to Info.plist (so audio "continues when locked") changes audio session behavior in subtle ways that can break foreground playback in ways hard to debug. ([Apple Developer Forums on Background AudioSession](https://developer.apple.com/forums/thread/734248))

**How to avoid:** This app does **not** need background audio. Don't add `UIBackgroundModes: audio`. Configure `audio_session` with `AVAudioSessionCategory.playback` (not `.ambient`) for proper silent-switch behavior, but keep the app foreground-only.

**Phase:** Phase 1.

---

### Pitfall 19: Hot-reload state corruption during dev causes false confidence [NICE-TO-AVOID]

**What goes wrong:**
A state bug shows up only after hot-reload, or shows up only after fresh launch. Riverpod / Drift / `just_audio` all have known hot-reload edge cases. You think it's fixed; it's not.

**How to avoid:** After any state-management or audio change, do a **full restart** before deciding "it works." Add `flutter run --no-fast-start` to the dev workflow when debugging lifecycle issues.

**Phase:** Continuous, every phase.

---

### Pitfall 20: Asset path case-sensitivity gotcha (iOS case-insensitive, real device case-sensitive) [NICE-TO-AVOID]

**What goes wrong:**
Filename `Hundur.aac` referenced as `assets/audio/words/hundur.aac` works on macOS Simulator (case-insensitive HFS+/APFS by default), fails on Linux CI / Android device (case-sensitive). ([Flutter issue #9539](https://github.com/flutter/flutter/issues/9539))

**How to avoid:** **All asset filenames lowercase, ASCII-safe**. For Icelandic letters: use `eth.aac` not `ð.aac`, `thorn.aac` not `þ.aac`, `ae.aac` not `æ.aac`. Map letter → filename in a single Dart constant. Add a CI check that asserts file existence with exact case.

**Phase:** Phase 0 (asset path conventions).

---

### Pitfall 21: build_runner ordering between drift_dev and riverpod_generator [NICE-TO-AVOID]

**What goes wrong:**
Both `drift_dev` and `riverpod_generator` are build_runner builders; their relative order matters when one depends on the other (typically: drift first, riverpod second, since providers wrap drift-generated DAOs). Cold-cache build is slow; conflicting outputs can produce stale `.g.dart` files.

**How to avoid:**
- Use `dart run build_runner build --delete-conflicting-outputs` for full builds.
- Use `dart run build_runner watch` during dev.
- If ordering issues appear, configure `build.yaml` with explicit `runs_before` between drift and riverpod builders.
- Pin compatible versions of `drift`, `drift_dev`, `riverpod`, `riverpod_generator`, `analyzer` together. Bump them as a set, not individually.

**Phase:** Phase 0 (project setup).

---

### Pitfall 22: Android tablet hardware variance — cheap tablet at 30 fps [NICE-TO-AVOID]

**What goes wrong:**
The dev Mac and a recent iPad render the app smoothly. A budget Android tablet (Hugrún's actual device, possibly) drops to 30 fps, especially with tracing.

**How to avoid:**
- **Test on the actual target tablet from Phase 1**, not just simulators.
- Use `flutter run --profile` and the DevTools performance overlay.
- Wrap heavy widgets in `RepaintBoundary`.
- For tracing in Phase 3: cap `CustomPainter` work to the new stroke segment only (don't repaint the whole letter every frame).
- Reduce screen density (`MediaQuery.devicePixelRatio` → render at 1.5× if device is 2.5×) for tracing canvas only, if performance demands.

**Phase:** Phase 1 (verify on device) and Phase 3 (when tracing arrives).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Bundle WAV instead of AAC because "we'll fix later" | No compression pipeline needed | App size 4–10× larger; release blocked | Never — the pipeline is small and gives loudness normalization for free |
| Hardcode `"Hugrún"` in voice-over scripts | Faster than profile-aware templating | Personalization-as-moat impossible without rewrite; can't ship publicly | Never — set up profile model in Phase 0 |
| Skip migration for Drift schema v2 | One less file to write | Lose Hugrún's data; no recovery | Never in production; OK in dev with `--reset-db` flag |
| Use ElevenLabs free tier for production assets | Free | Licensing breach if shipped commercially; voice changes | Only if you have written confirmation that free-tier output is licensable for your use |
| Spot-check TTS clips instead of full review | 10× faster review pass | 5–20 mispronunciations ship; trust collapses | Never — full review is the differentiator |
| Skip `audio_session` config, hope iOS defaults work | One package not installed | Silent-switch behavior wrong; interruption recovery broken | Acceptable only in earliest prototype before real device testing |
| One `AudioPlayer` shared across all clips | Simple model | Stutter, latency, race conditions on rapid taps | Acceptable for absolute-first prototype; replace with player pool in Phase 1 polish |
| No native-speaker review before shipping publicly | Faster to launch | Brigaded by Icelandic parents; reputation damaged | Never if shipping publicly |
| Skip parental-gate hold timer ("good enough is a single tap") | Simpler UI | Apple Kids Category rejection (Guideline 1.3) | Acceptable only if not shipping publicly to App Store |
| Use Firebase Crashlytics for crash reporting | Free, easy | App Store rejection in Kids Category (Guideline 5.1.4(b)) | Never if entering Kids Category; OK in non-Kids if PII-scrubbed |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|---|---|---|
| Tiro TTS API | Calling at runtime / per app launch | Generate at build time only; bake AAC files |
| Tiro TTS voice IDs | Assuming `Diljá-v2` is permanent | Pin in manifest; treat new version as breaking change |
| ElevenLabs API | Using free-tier output commercially | Verify commercial license + kids-app permission before any production use |
| ice-g2p / tts-frontend | Treating as drop-in replacement for SSML | Use as a phonetic-spelling source for `<phoneme>` tags or as raw input to Tiro |
| just_audio | Creating new player per tap | Long-lived pooled players; never re-instantiate |
| just_audio + Riverpod | Holding player in `autoDispose` provider | Plain `Provider`; dispose only at app shutdown |
| audio_session | Skipping configuration | Configure once at app launch; iOS category `playback`; pre-activate |
| Drift | No schema snapshots | Export schema after each release; commit snapshots; write migration tests |
| Drift + Flutter shared with Android host | Concurrent read/write conflicts ([Drift issue #2990](https://github.com/simolus3/drift/issues/2990)) | N/A here — Flutter app owns the DB exclusively |
| Riverpod generator | Mixing `@riverpod` with manual providers inconsistently | Pick one style; if mixing, use `@riverpod` for all new providers |
| Flutter assets | Non-ASCII filenames (`ð.aac`) | All filenames lowercase ASCII; map letter → filename in code |
| Apple App Store submission | Filing under Kids Category casually | Kids Category requirements are *permanent* once entered (deselecting later doesn't remove the requirements per Guideline 1.3) — decide deliberately |
| Apple privacy nutrition labels | "We don't collect anything" without filling out the form | Privacy nutrition label is required even for fully-local apps; fill out as "Data Not Collected" |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| New `AudioPlayer` per tap | Audio latency varies; occasional stutter; OOM on Android over long sessions | Pool 2–4 long-lived players | Within first 30 minutes of play |
| `setState` / Riverpod rebuild on audio progress events | Frame rate drops during playback | Use `select` with debouncing; don't bind UI to per-millisecond progress | Within first session |
| `CustomPainter.shouldRepaint` returns true always | Tracing tanks to 30 fps on cheap tablets | Cache the static letter outline; only repaint stroke layer; `shouldRepaint` returns true only on stroke buffer change | When tracing ships (Phase 3) |
| Large image assets at 4× density | App feels sluggish; install size huge | Use `flutter_image` with appropriate density variants (`1x`, `2x`, `3x`); compress images to WebP where supported | When image-heavy content arrives (Phase 2+, Numbers room) |
| Rebuilding entire screen on a single state change | Frame drops during animation | `RepaintBoundary` around stable subtrees; `select` for granular subscription | When activity screens get more complex |
| ProviderScope wrapping the whole app *and* re-rendering parent | All providers rebuild every frame ([Riverpod #4661](https://github.com/rrousselGit/riverpod/issues/4661)) | Single top-level ProviderScope; never wrap rebuilding widgets in another ProviderScope | At any time on Riverpod 3.2.0+ |

---

## Security / Privacy Mistakes (kids' app domain)

| Mistake | Risk | Prevention |
|---------|------|------------|
| Crash-reporting SDK that sends device info | App Store Kids Category rejection (5.1.4) + COPPA breach if shipped | No third-party crash SDKs; use MetricKit (iOS) / native (Android) only |
| Parent-uploaded photos transmitted off-device | COPPA + GDPR violation (the child is the data subject); App Store rejection | Photos are local-only, stored in app's documents directory; no upload, no cloud |
| Photo upload without explicit parental consent flow distinct from parental gate | Apple 5.1.4(b) — gate is not consent | Add an explicit "I consent to my child's photos being used in this app on this device only" flow |
| Logging child interactions to local file with PII | Even local PII can leak via backups; raises GDPR data-subject-rights questions | Don't log behavioral events. If you must, log anonymized session counters only |
| Third-party SDK (translation, image-recognition) that pings home | Network call during play violates PROJECT.md constraint and triggers App Store privacy review | Audit pubspec.yaml; no SDK with network access |
| Privacy policy missing / boilerplate | App Store rejection (Guideline 5.1.4 requires policy even for local-only kids' apps) | Write specific policy; host on stable URL; reference in App Store Connect |
| "For Kids" / "For Children" in App Store metadata without Kids Category submission | Apple Guideline 2.3.8 — terms reserved for Kids Category | Use age band ("ages 4–6") in description; let Apple's age rating handle the categorization |
| Default iOS keyboard on parent settings screen suggesting words / having predictive text | If Hugrún wanders into parent settings, the keyboard could surface arbitrary text | Not a real risk in this app since parent settings is hold-3-seconds gated, but make sure the parent settings screen does not auto-focus a text field that could pop the keyboard for a child |

---

## UX Pitfalls (specific to 4–6 age + Icelandic)

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Tap targets sized for adult fingers (44×44 pt) | Misses for shaky 5yo motor skills | **Minimum 80×80 pt (≈2cm)**, surrounded by passive-area buffer, on tablet ([NN/g](https://www.nngroup.com/articles/children-ux-physical-development/)) |
| Drag gestures requiring precision | Frustration, walks away | Tap-only for MVP; drag only when absolutely necessary; large drag targets with snap |
| Screen elements requiring two-finger gestures | 5yos rarely use multi-finger reliably | Single-finger gestures only |
| "Long press" gestures | 5yos either tap-and-release immediately or hold indefinitely; no calibrated long-press | Avoid long-press in child-facing UI; OK in parent gate (where the long-press is the intentional barrier) |
| Voice-over and music playing simultaneously | Splits attention; child misses the word | One audio source at a time during instruction; ambient music only during idle/transition states |
| Audio that loops if user idles | Feels nagging | Voice-over plays once per activity load; if child needs prompt, single tap on the activity element re-plays |
| Animations during voice-over | Visual draw away from auditory channel | Animations *bracket* voice-over (before / after), not during |
| Modal dialogs / popups | Kids don't process dismissal affordances | No modals in child-facing UI; navigation is direct (tap to enter, "back" gesture or home button to exit) |
| Off-screen elements requiring scroll | 5yos don't reliably understand scroll affordance | All activity content fits on screen; no scrolling in child-facing screens |
| Voice-over in adult tone or "cartoon kid voice" | Patronizing or fake | Calm, neutral-warm tone; the voice of a competent adult speaking respectfully to a child |
| Counting voice-over rushes through 1-2-3-…-10 | Child can't form cardinality (last number = total) connection | Pause between each count; the *last* number gets a slightly elongated emphasis to mark it as the answer |
| Letter says only "H" / "Á" / "Þ" without context | Letter name is abstract; no anchor | Letter name + example word (`H. Hundur.`) — PROJECT.md gets this right |
| Gendered counting form mismatched with object gender | Sounds wrong to Icelandic ear | Per-object gender tag drives form selection (see Pitfall 10) |
| Text instructions anywhere in child UI | 5yo can't read | PROJECT.md correctly excludes; verify in implementation no `Text()` widget in child screens shows non-decorative content (numbers, letters as glyphs are fine; sentences are not) |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces:

- [ ] **Alphabet activity ships** → Verify: all 32 letters present? alphabet order matches school? no C/Q/W/Z? all clips reviewed by native speaker? all loudness-normalized to -16 LUFS / -1 dBTP?
- [ ] **TTS pipeline ships** → Verify: every clip has a `reviewed: true` flag? `pronunciation_overrides.yaml` exists and has entries? regression diagnostic set runs on voice-version change?
- [ ] **Tap-to-hear works** → Verify: latency < 50ms on actual tablet measured at 240fps? player pool in use, not single-shared? cold-start head-of-clip not cut off? visual feedback fires synchronously with tap independent of audio?
- [ ] **Parent gate works** → Verify: hold timer survives accidental release? no way for child to brute-force? actually gates settings, not just a UI flourish? on iOS, if shipping Kids Category, gates all out-of-app links and any PII collection?
- [ ] **Personalization works** → Verify: profile model parameterized (no `"Hugrún"` hardcoded)? personalized audio in separate folder? photo storage local-only with no upload path? consent flow distinct from parental gate?
- [ ] **Drift schema** → Verify: schema snapshot exported? migration test for at least one transition? backup/export feature available? `schemaVersion` enforced?
- [ ] **Build runs on both platforms** → Verify: iOS build succeeds? Android build succeeds? on actual cheap Android tablet? landscape and portrait both? assets all loadable on case-sensitive filesystem (lowercase ASCII)?
- [ ] **App Store submission ready** (if shipping publicly) → Verify: privacy policy URL live? privacy nutrition label filled? Kids Category decision made deliberately? no third-party analytics/crash SDKs? metadata avoids "For Kids" unless Kids Category? all imagery 4+ rating?
- [ ] **No-fail UX honored** → Verify: no negative-valence sound in any clip? no animation depicts disappointment? off-target taps produce silence (not a "wrong" sound)? voice-over script contains no "try again" / "almost"?
- [ ] **Audio loudness uniform** → Verify: every clip ±1 LU of target? mixed-provider clips re-normalized? listened to on actual tablet at actual volume?
- [ ] **Numbers room (when it ships)** → Verify: every counted-object asset has gender tag? six gendered forms exist for 1–4? abstract counting uses masculine consistently? native speaker reviewed object-counting voice-overs?
- [ ] **Tracing (when it ships)** → Verify: tolerance band tested on actual 5yo? frame rate 60fps on cheap tablet? stroke-order is *soft* not enforced? no fail outcome possible?

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Mispronunciation in shipped clip | LOW | Add to `pronunciation_overrides.yaml`; regenerate clip; ship update |
| Mispronunciation in MULTIPLE clips discovered post-public-launch | MEDIUM | Issue silent update; consider posting "audio improvements" changelog (Icelandic parents will appreciate transparency) |
| Drift migration data loss | HIGH | Restore from device backup (iOS iCloud Backup includes app sandbox; Android Auto Backup similarly) — not perfect but partial; otherwise gone |
| App Store Kids Category rejection | MEDIUM | Read rejection text carefully; address each cited guideline; resubmit; expect 1-2 rejection cycles |
| Tap latency complaints | LOW–MEDIUM | Add player pool, pre-warming, head-padding to clips; release performance update |
| Wrong alphabet order shipped | LOW (catch quickly) → HIGH (Hugrún learns wrong order) | Hot-fix update; check what she's already memorized; minor re-learning cost |
| ElevenLabs licensing surprise after shipping | HIGH | Replace ElevenLabs clips with Tiro re-renders; emergency update; possibly app pull from store while fixing |
| Riverpod regression on version bump | LOW (caught in dev) → MEDIUM (caught after release) | Pin to known-good version; defer Riverpod upgrade until verified |
| Tracing too strict, child gives up | LOW | Loosen tolerance via parent-settings flag; ship update; observe Hugrún's response |
| Audio loudness drift across clips | LOW | Re-normalize entire bundle; ship update |

---

## Pitfall-to-Phase Mapping

| Pitfall | Severity | Prevention Phase | Verification |
|---------|----------|------------------|--------------|
| 1. TTS mispronunciation | CRITICAL | Phase 1 (TTS pipeline) | Native speaker signs off on every clip; `reviewed: true` flag enforced |
| 2. Alphabet order/letter set wrong | CRITICAL | Phase 0 (setup) | Unit test asserts 32 letters in canonical order; native speaker confirms |
| 3. Failure feedback misread | CRITICAL | Phase 1 (UX grammar) | Live observation of Hugrún; no negative-valence sounds in pipeline |
| 4. Tap latency > 50ms | CRITICAL | Phase 1 (MVP) | 240fps screen recording on target tablet measures < 50ms tap-to-feedback |
| 5. Loudness inconsistency | CRITICAL | Phase 1 (TTS pipeline) | All clips ±1 LU of -16 LUFS target; verified by ffmpeg-normalize report |
| 6. App Store Kids compliance | CRITICAL (if shipping) | Phase 0 + final pre-submission phase | Compliance checklist; privacy policy live; no banned SDKs |
| 7. Riverpod scope/rebuild errors | CRITICAL | Phase 1 (audio architecture) | DevTools shows steady 60fps with audio; no rebuild storms |
| 8. Drift migration data loss | IMPORTANT (escalates) | Phase 0 + every schema change | `schemaAt` migration test passes for every version transition |
| 9. Tracing tolerance miscalibrated | IMPORTANT | Phase 3 (tracing) | Hugrún completes 80%+ of trace attempts without retry |
| 10. Number gender inconsistency | IMPORTANT | Phase 4 (numbers) | Every object has gender tag; 6 gendered audio forms for 1–4 exist |
| 11. ElevenLabs licensing surprise | IMPORTANT | Phase 1 (TTS pipeline) | Written confirmation of license; provider/version pinned in manifest |
| 12. Build-for-one-child architecture rigidity / over-generality | IMPORTANT | Phase 0 (data model) | Profile model exists; no `"Hugrún"` literal in code; no multi-child scaffolding |
| 13. Asset bundle bloat | IMPORTANT | Phase 1 (TTS pipeline) | App size analysis; AAC at 64 kbps mono 22050 Hz |
| 14. Distracting animations | IMPORTANT | Phase 1 (UX grammar) | Motion-grammar review; only functional motion ships |
| 15. Voice-over pacing wrong | IMPORTANT | Phase 1 (TTS pipeline) | Pacing tested on Hugrún; rate parameter set deliberately |
| 16. Discoverability failure | IMPORTANT | Phase 1+ (every activity) | Demonstration animation on every activity load; observation of Hugrún's first-encounter behavior |
| 17. Public-shipping surprises | IMPORTANT (if shipping) | Pre-submission phase | TestFlight / Internal Testing run; multiple native speaker QA |
| 18. iOS background audio config break | NICE-TO-AVOID | Phase 1 | No `UIBackgroundModes: audio`; `audio_session` configured `playback` |
| 19. Hot-reload state corruption | NICE-TO-AVOID | Continuous | Full restart before any "it works" claim |
| 20. Asset path case sensitivity | NICE-TO-AVOID | Phase 0 | All filenames lowercase ASCII; CI check |
| 21. build_runner ordering | NICE-TO-AVOID | Phase 0 | Pinned versions; `build.yaml` if needed |
| 22. Cheap Android tablet performance | NICE-TO-AVOID | Phase 1 + Phase 3 | Profile-mode runs on actual target tablet; 60fps target |

---

## Sources

**App Store / Privacy:**
- [Apple App Review Guidelines (full)](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Kids Apps developer page](https://developer.apple.com/app-store/kids-apps/)
- [Apple "Helping Protect Kids Online" 2025 PDF](https://developer.apple.com/support/downloads/Helping-Protect-Kids-Online-2025.pdf)
- [Apple App Store Guidelines for Kids: The Parental Gate](https://medium.com/@laurentm/apple-ios-app-store-guidelines-for-kids-category-the-parental-gate-fa4ba10edd6f)
- [Capgo App Store Age Ratings Guide (2025 changes)](https://capgo.app/blog/app-store-age-ratings-guide/)
- [BuddyBoss: Resolving Guideline 1.3 Kids Safety](https://buddyboss.com/docs/app-store-guideline-1-3-safety-kids-category/)
- [COPPA Compliance Practical Guide 2025](https://blog.promise.legal/startup-central/coppa-compliance-in-2025-a-practical-guide-for-tech-edtech-and-kids-apps/)

**Flutter / Riverpod / Drift / just_audio:**
- [Riverpod 3.2.0 ProviderScope rebuild regression #4661](https://github.com/rrousselGit/riverpod/issues/4661)
- [Riverpod scoped provider rebuild issue #1298](https://github.com/rrousselGit/riverpod/issues/1298)
- [Riverpod analyzer dependency conflict #4364](https://github.com/rrousselGit/riverpod/issues/4364)
- [Code with Andrea: Flutter Riverpod 2.0 Ultimate Guide](https://codewithandrea.com/articles/flutter-state-management-riverpod/)
- [Drift migration testing](https://drift.simonbinder.eu/migrations/tests/)
- [Drift schema export and migrations](https://drift.simonbinder.eu/guides/migrating_to_drift/)
- [just_audio Android first-playback issue #941](https://github.com/ryanheise/just_audio/issues/941)
- [just_audio gapless playback #131](https://github.com/ryanheise/just_audio/issues/131)
- [audio_session package docs](https://pub.dev/packages/audio_session)
- [Flutter asset case sensitivity issue #9539](https://github.com/flutter/flutter/issues/9539)
- [Flutter CustomPainter performance issue #72066](https://github.com/flutter/flutter/issues/72066)
- [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices)
- [Flutter app size measurement](https://docs.flutter.dev/perf/app-size)

**Audio / Loudness:**
- [Auphonic: Loudness Targets for Mobile Audio](https://auphonic.com/blog/2013/01/07/loudness-targets-mobile-audio-podcasts-radio-tv/)
- [LUFS and Loudness Normalization explained](https://alexanderwright.com/blog/lufs-loudness-normalization-explained)
- [Google Conversational Actions Audio Loudness](https://developers.google.com/assistant/tools/audio-loudness)

**Icelandic Language / TTS:**
- [Tiro TTS GitHub](https://github.com/tiro-is/tiro-tts)
- [grammatek/ice-g2p](https://github.com/grammatek/ice-g2p)
- [grammatek/tts-frontend](https://github.com/grammatek/tts-frontend)
- [Icelandic orthography (Wikipedia, English)](https://en.wikipedia.org/wiki/Icelandic_orthography)
- [Icelandic Grammar (Wikipedia)](https://en.wikipedia.org/wiki/Icelandic_grammar)
- [Icelandic alphabet pronunciation (Preply)](https://preply.com/en/blog/icelandic-alphabet-and-pronunciation/)
- [Icelandic numbers grammar (Lingalot)](https://www.lingalot.com/numbers-in-icelandic/)
- [SSML phoneme tag with IPA (W3C)](https://www.w3.org/TR/speech-synthesis11/)
- [Microsoft Speech SSML Pronunciation](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-synthesis-markup-pronunciation)
- [ElevenLabs Terms of Service (non-EEA)](https://elevenlabs.io/terms-of-use)
- [ElevenLabs Prohibited Use Policy](https://elevenlabs.io/use-policy)
- [ElevenLabs commercial license / publishing FAQ](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform)

**Child UX / Early Literacy Research:**
- [NN/g — Design for Kids Based on Stage of Physical Development](https://www.nngroup.com/articles/children-ux-physical-development/)
- [Joan Ganz Cooney Center — Co-Play with Apps](https://joanganzcooneycenter.org/2017/11/01/playing-together-using-apps-to-augment-relationships-between-adults-and-children/)
- [Google Building for Kids — Designing Engaging Apps](https://developers.google.com/building-for-kids/designing-engaging-apps)
- [PMC: How educational are 'educational' apps for young children? (Four Pillars review of 171 apps)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8916741/)
- [EdWeek: Bad Teaching for Preschoolers? There Are Lots of Apps for That](https://www.edweek.org/teaching-learning/bad-teaching-for-preschoolers-there-are-lots-of-apps-for-that/2018/08)
- [Erikson Institute — Cardinality Principle](https://earlymath.erikson.edu/cardinality-set/)
- [Sarnecka & Wright — Cardinality and Equinumerosity](https://sites.socsci.uci.edu/~lpearl/courses/readings/SarneckaWright2013_ExactNumber.pdf)
- [The OT Toolbox — Tracing: Help or Hurt?](https://www.theottoolbox.com/to-trace-or-not-to-trace/)
- [W3C WCAG 2.5.5 Target Size](https://www.w3.org/WAI/WCAG21/Understanding/target-size.html)

---
*Pitfalls research for: Hugrún — Icelandic literacy + numeracy app for one 5-year-old (Flutter, possibly publicly shipped)*
*Researched: 2026-05-02*
