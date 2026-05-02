# Stack Research

**Domain:** Offline-first Flutter kids' educational app (Icelandic literacy + numeracy, ages ~5)
**Researched:** 2026-05-02
**Confidence:** HIGH on Flutter ecosystem versions (verified against pub.dev / official docs); MEDIUM on Tiro TTS API specifics (public OpenAPI spec at tts.tiro.is reachable but not fetchable here — see "Open Verification Items"); HIGH on the ElevenLabs licensing finding, which is the single most consequential result of this research.

---

## TL;DR

- **Flutter 3.41 stable / Dart 3.9** is the current channel. Pin both to a known tagged version with `fvm` so Hugrún's tablet doesn't get bricked by a SDK churn day.
- **Riverpod 4.x with code generation** (`@riverpod` annotations, `riverpod_generator`) — Riverpod 3.x has been superseded; 4.x is current stable. *Note: user prompt asked "2.x or 3.x?" — answer is 4.x.* The Notifier API replaces `StateNotifier`; legacy providers are imported from `flutter_riverpod/legacy.dart`.
- **Drift 2.32+** with `drift_flutter ^0.3.0` (handles SQLite bundling + path setup). `sqlite3_flutter_libs` is no longer needed since drift 2.32 — `drift_flutter` pulls it in transitively.
- **just_audio 0.10.x + audio_session 0.2.x** with `AudioPlayer` per-mechanic pool (one player kept warm for letter sounds, one for word audio) using preloaded `AudioSource.asset`. **Do not** use `just_audio_background` — kids' app, no lockscreen/CarPlay UX needed, and it pulls in iOS background-audio entitlements that complicate App Store review.
- **Tiro TTS first, NOT ElevenLabs.** ElevenLabs' Prohibited Use Policy explicitly prohibits "Services to make available bundled solutions that target anyone under the age of 13." Hugrún is 5. **An app that ships ElevenLabs-generated audio for a 5-year-old's app is a Terms of Service violation.** This invalidates the user's "evaluate in parallel" plan. See "ElevenLabs Section" below — this is the single most important finding.
- **LUFS target: -19 LUFS integrated, -1 dBTP true peak**, mono. Lower than streaming standards (-16 LUFS) because tablet speakers + kids = "loud enough at 50% volume, no clipping at 100%."
- **Audio output: 48 kHz mono AAC at ~96 kbps**, not stereo. Halves bundle size, and there's nothing stereo about a single narrator voice. Use ffmpeg's native AAC encoder or `libfdk_aac` if available.

---

## Recommended Stack

### Core Technologies (User-Locked — versions verified)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter | 3.41.5 stable | App framework, iOS + Android | Latest stable as of Feb 2026; widget renderer is Impeller on iOS (default since 3.24) and gradually rolling on Android in 3.41. Pin via `fvm` to lock the SDK to one version per repo. |
| Dart | 3.9 (bundled with Flutter 3.41) | Language | Bundled — no separate install. Null-safe, sound, sealed classes (used heavily by Riverpod 4 & freezed 3). |
| flutter_riverpod | ^3.3.1 (or 4.x — see note) | App state | User-locked. **Confidence note:** pub.dev page shows flutter_riverpod 3.3.1 as latest stable, but `riverpod_generator 4.0.3` requires riverpod 4.x. Verify against `pub.dev/packages/flutter_riverpod/versions` at install time — the ecosystem is mid-migration in early 2026. Use whichever pair aligns. |
| riverpod_annotation | ^4.0.2 | `@riverpod` codegen annotations | Required for code-generated providers. Pair with `riverpod_generator`. |
| riverpod_generator | ^4.0.3 | Build-time provider generation | Eliminates `Provider.family`/`Provider.autoDispose` boilerplate. With code-gen, write `@riverpod Stream<List<Letter>> letters(LettersRef ref)` and the family/autoDispose modifiers are inferred from function signature. Worth the codegen overhead even on a small app. |
| drift | ^2.32.1 | SQLite ORM, type-safe | User-locked. Reactive streams pair naturally with Riverpod's `StreamProvider`. Migrations are explicit (no auto-migrate magic), which suits a kids' app where schema is small but stable. |
| drift_dev | ^2.32.1 | Drift codegen | Required at build time only (dev_dependency). |
| drift_flutter | ^0.3.0 | Flutter platform glue | Provides `driftDatabase()` helper that handles `path_provider` + SQLite bundling. As of drift 2.32, this replaces the explicit `sqlite3_flutter_libs` dependency. |
| just_audio | ^0.10.5 | Audio playback | User-locked. Flutter Favorite. Supports `AudioSource.asset` with preload, `ConcatenatingAudioSource` for gapless letter+word playback, and per-player state streams that integrate with Riverpod cleanly. |
| audio_session | ^0.2.3 | Audio session config | Required companion. Configure once at app start with a *custom* config (NOT the bundled `.music()` or `.speech()` presets — see Audio Session Configuration below). |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| freezed | ^3.2.3 | Immutable data classes, sealed unions | All domain models (`Letter`, `Word`, `AudioClip`, `TraceStroke`, etc.). Sealed unions for activity state machines. |
| freezed_annotation | ^3.2.0 | `@freezed` annotations | Pair with `freezed`. |
| json_serializable | ^6.9.4 | JSON codegen | For the build-time YAML manifest → Dart enum/asset-map generation pipeline (parsed via `yaml` package, then serialized). Not needed at runtime since there are no API calls during play. |
| build_runner | ^2.10.4+ | Codegen orchestrator | Required for riverpod_generator, drift_dev, freezed, json_serializable, flutter_gen_runner. The Dec 2025 build_runner rewrite roughly 2x'd codegen speed — worth being on a recent version. |
| flutter_gen_runner | ^5.x | Type-safe asset references | Generates `Assets.audio.letters.a()` instead of `'assets/audio/letters/a.aac'` strings. Critical for an app with ~200–400 audio clips — string typos in asset paths are the #1 source of "why is no sound playing on this one letter" bugs. Build-runner-based; integrates cleanly with the existing codegen pipeline. |
| path_provider | ^2.1.x | Filesystem paths | Pulled transitively by `drift_flutter`. Direct usage only if you store user photos for personalization (post-MVP). |
| flutter_lints | ^6.0.0 | Recommended lints | Latest version requires Flutter 3.35/Dart 3.9 minimum — aligned with Flutter 3.41. Use as-is, no need for `very_good_analysis` or `lint` for a solo project. |
| yaml | ^3.x | YAML manifest parsing | Used by the *build pipeline* (Python or Dart script) that reads the utterance manifest. Not bundled at runtime. |

### Animation & Interaction (Post-MVP per project scope)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rive | ^0.14.6 | Character animation | User-locked, deferred to post-MVP. 0.14.x is the current stable — do not pin to 0.13.x (older runtime, incompatible with newer Rive editor exports). 0.14.x bundles `rive_native` which downloads prebuilt native libraries at build time — first build will be slow. |
| (none — built-in) | — | CustomPainter for tracing | User-locked, post-MVP. Flutter framework, no package needed. See Pitfalls section for performance notes. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| fvm | Flutter SDK version pinning | Solo project on a personal machine — Flutter SDK version drift will cost you 30 minutes one day. Pin via `fvm use 3.41.5` and commit `.fvmrc`. |
| ffmpeg | Audio re-encoding to AAC | Use the system `ffmpeg` (Homebrew on macOS) — no Flutter package needed since this is a build-time tool. |
| ffmpeg-normalize | Loudness normalization | Python tool. Settings: `--normalization-type ebu --target-level -19 --true-peak -1 --keep-loudness-range-target` for kids' content. (See LUFS section below for rationale.) |
| Python 3.11+ | Build pipeline | Manifest YAML → Tiro API → ffmpeg → AAC → asset map. Single script, ~200 lines. |
| build_runner watch | Codegen during dev | `dart run build_runner watch -d` — `-d` skips conflict prompts. |
| Xcode 15+ / Android Studio Hedgehog+ | Native builds | Flutter 3.41 requires Xcode 15+ for iOS 17 SDK. |

### NOT Recommended (despite Patrol/melos/mason being trendy)

| Library | Why Skip For This App |
|---------|----------------------|
| melos | Single-package repo. Melos is for monorepos with multiple Dart packages. Adds CI complexity for zero benefit. |
| mason | Brick-based scaffolding. Useful for teams with many similar projects. Solo build with ~3 screens — manual scaffolding is faster. |
| patrol | Native UI testing framework. Powerful but heavyweight (1.5GB iOS simulator overhead, native test runner config per platform). For a no-network single-screen-and-mechanics app, `flutter_test` widget tests + `integration_test` for tap-to-audio timing are sufficient. Add patrol only if you hit a wall the standard tools can't reach. |
| just_audio_background | Kids' app does not need lockscreen / CarPlay / smart watch / background audio. Adding it requires `UIBackgroundModes: audio` on iOS and a foreground service on Android — both will trigger App Store reviewer questions ("why does this children's app run audio in background?"). |
| any analytics SDK | Out of scope per PROJECT.md, and a known App Store rejection vector for kids-category apps (Apple's "Kids Category" rules forbid third-party analytics that share data). |
| go_router / auto_route | Two screens. Use `Navigator 1.0` with `MaterialPageRoute`. Adding a routing framework for two screens is pure overhead. (Reconsider if/when activities expand to 6+ screens.) |

---

## Tiro TTS — API Specifics

**License:** Apache 2.0 (verified — funded by Iceland's Ministry of Education, Science and Culture under "Language Technology for Icelandic 2019-2023"; permissive commercial license). Hosted at `tts.tiro.is`.

**Endpoint:** OpenAPI 2 spec is published at `tts.tiro.is` (the spec endpoint location wasn't directly fetchable during research — verify the path manually with `curl https://tts.tiro.is/v0/openapi.json` or browse to the live docs UI).

**Backends:** Three — `Fastspeech2MelganBackend`, `Espnet2Backend`, `PollyBackend` (AWS Polly proxy). The v2 voices use ESPnet2.

**Voices (all 8 exposed by tts.tiro.is, all Icelandic):**

| Voice | Gender | Engine | Notes |
|-------|--------|--------|-------|
| Diljá | F | FastSpeech2 + MelGAN | Original |
| **Diljá v2** | F | ESPnet2 FastSpeech2 + Multiband MelGAN | **Recommended primary narrator** — current best-in-class neural Icelandic female voice |
| Álfur | M | FastSpeech2 + MelGAN | Original |
| Álfur v2 | M | ESPnet2 FastSpeech2 + Multiband MelGAN | Current male equivalent |
| Bjartur | M | ESPnet2 | Current generation |
| Rósa | F | ESPnet2 | Current generation |
| Karl | M | AWS Polly proxy | Polly's standard Icelandic voice — fallback only, lower naturalness |
| Dóra | F | AWS Polly proxy | Polly's standard Icelandic voice — fallback only |

**Recommendation:** Use **Diljá v2** as the single narrator voice for the entire app (per PROJECT.md "one primary narrator voice"). Keep Álfur v2 in reserve in case Diljá v2 mispronounces a specific letter or word and the override doesn't fix it — sometimes a different voice's prosody gets a tricky case right.

**Input formats:** Plain text or SSML. SSML supported per the README — use the `<phoneme alphabet="ipa" ph="...">` tag for pronunciation overrides on names (e.g., "Hugrún" if the default pronunciation isn't right). The `ice-g2p` companion library (Apache 2.0, by Grammatek) is the canonical way to generate IPA/SAMPA phoneme strings for Icelandic if SSML alone isn't enough.

**Output formats:** MP3, Ogg Vorbis, raw 16-bit PCM. **Get raw PCM, then re-encode to AAC via ffmpeg** — gives you the highest-quality starting point for the loudness-normalize → AAC pipeline. (MP3 → AAC re-encode is a lossy-to-lossy transcode and audibly degrades the result on a kids' tablet at 50% volume.)

**Authentication:** Public service appears to require no API key — it is a free government-provided service. **MEDIUM confidence**: the tts.tiro.is README does not document any auth scheme, and CLARIN-hosted services are typically open. **Action item before relying on this:** test with a `curl -X POST https://tts.tiro.is/v0/speech/synthesize ...` and confirm. If they have introduced a key requirement, request one via tiro.is contact.

**Rate limits:** Not documented in the README or CLARIN listing. **Mitigation regardless of policy:** the build pipeline runs once per content change (rare — adding a new word, fixing a pronunciation), generating ~200–400 short clips. Rate-limit the script to 1 request per second with a `sleep 1` and you're safe under any reasonable throttle. Cache successfully-generated clips by content hash so you only re-generate what changed.

**Speech marks:** Tiro can return word-level timing offsets alongside audio. Not needed for tap-to-hear MVP, but useful later for word-blend animation ("highlight each letter as the word is spoken").

---

## ElevenLabs — DO NOT USE for this app

**Critical finding (HIGH confidence, multiple sources):**

ElevenLabs' Prohibited Use Policy states: *"Users are prohibited from making the Services available to anyone under the age of 13, or anyone between the ages of 13–18 without first obtaining parental or guardian consent, **or otherwise using the Services to make available bundled solutions that target anyone under the age of 13.**"*

Hugrún is 5. The app explicitly targets a 5-year-old (and, if released, other young children). Bundling ElevenLabs-generated audio in this app **violates ElevenLabs' Prohibited Use Policy**, which makes it a Terms of Service violation. This applies regardless of paid plan tier — commercial licensing covers commercial *use*, not commercial use *targeting under-13 audiences*.

**Implication:** The user's locked decision to "evaluate Tiro and ElevenLabs in parallel for v1" should be **revisited.** ElevenLabs is off the table. This needs to be flagged in PITFALLS.md and surfaced to the user before any audio generation work begins.

**For the record (in case the policy is re-read or interpreted differently):**

| Aspect | Detail |
|--------|--------|
| Icelandic support | Eleven v3 model only (released GA March 2026). Earlier models (Multilingual v2, Flash v2.5) do *not* support Icelandic. |
| Quality for Icelandic | Reports mixed. 70+ language support is breadth-first; Icelandic is in the long tail and "may have lower fidelity." Diljá v2 from Tiro is likely competitive or better for Icelandic specifically, despite ElevenLabs' overall quality lead in English. |
| Commercial license | Available from Starter ($5/month) — but moot, see prohibited use above. |
| Voice cloning | Possible — but cloning a child's voice (or a voice intended for children) is in further restricted territory under both ElevenLabs ToS and Iceland's GDPR-implementing legislation. |

**If you ever want a commercial fallback to Tiro,** evaluate Microsoft Azure Neural TTS (has Icelandic) or Google Cloud TTS (limited Icelandic). Both have clearer kids'-app licensing positions than ElevenLabs. But you don't need a fallback — Tiro is the right choice on quality, license, and politics.

---

## Audio Pipeline Specifics

### LUFS Target

**-19 LUFS integrated, -1 dBTP true peak, mono.**

Rationale:
- Streaming standards (-16 LUFS for Spotify/YouTube, -23 LUFS for EBU broadcast) are tuned for adult listeners with normal volume habits and stereo content.
- Kids' apps are different: a 5-year-old will probably set the tablet volume to 100%. If clips are mastered at -16 LUFS with peaks at -1 dBTP, individual loud sounds (a cheerful "rétt!") can hit ~93 dB SPL at the tablet speaker. That's loud-loud for a tablet held close to the face.
- -19 LUFS gives ~3 dB headroom below streaming standard. The child sets the volume; the app doesn't surprise them.
- Mono because there is one narrator. Stereo doubles the bundle size for zero perceptible benefit on a tablet's small speaker pair.

`ffmpeg-normalize` invocation:

```bash
ffmpeg-normalize input.wav \
  --normalization-type ebu \
  --target-level -19 \
  --loudness-range-target 7 \
  --true-peak -1 \
  --keep-loudness-range-target \
  --audio-codec aac \
  --audio-bitrate 96k \
  --sample-rate 48000 \
  --output-extension m4a \
  -o output.m4a
```

**Per-clip safeguard:** After normalization, run a final pass that checks integrated LUFS is within ±0.5 of target and dBTP < -0.5. Reject clips outside this window — usually means the source clip had silence padding that skewed measurement.

### Audio Format

- **AAC-LC at 96 kbps, 48 kHz, mono, in M4A container.**
- AAC-LC is hardware-decoded on every iOS device since 2007 and every Android device since ~2013 — zero CPU impact.
- 96 kbps mono is transparent for spoken-voice content (anything above ~80 kbps is, for mono speech).
- 48 kHz matches what iOS/Android audio stacks run natively — avoids resampling at playback time.
- M4A (.m4a) over .aac raw stream because M4A carries the duration metadata `just_audio` needs to start playback without scanning.

### Asset Preloading Strategy

For tap-response under 50ms (PROJECT.md requirement):

1. **At app start**, instantiate one `AudioPlayer` for letter sounds, kept warm for the lifetime of the *Stafir* room.
2. When the user opens *Stafir*, **preload the current screen's set** (32 letters = ~32 short clips, ~50 KB each = ~1.6 MB) into a `Map<String, AudioSource>` using `AudioSource.asset(...)` (which is preloaded by default per just_audio's API).
3. On tap, call `player.setAudioSource(audioSourceMap[letter])` then `player.play()` — both synchronous on a preloaded asset.
4. Keep the player set up with a *single* configured audio session — do not re-configure per tap.
5. **Do NOT** decode 200+ AAC files to PCM at app start to "go faster" — bundle size of decoded PCM is ~10x AAC, and AAC-LC decode latency on an iOS or Android tablet is sub-millisecond.

### Audio Session Configuration

Use a **custom** session config, not `.music()` or `.speech()`:

- `.music()` ducks other apps' music — wrong for an educational app where a parent might be playing music in the background.
- `.speech()` is for navigation/voice assistants — wrong category, may cause iOS to lower the volume in some interrupt scenarios.

Custom config (paraphrased):
- iOS: `AVAudioSessionCategory.playback` with `.mixWithOthers` option — lets parents' background music keep playing.
- Android: `AudioFocusGain` (transient may, but for short tap sounds gain is fine) with `usage = USAGE_GAME` and `contentType = CONTENT_TYPE_SPEECH`.

Configure once in `main()` after `WidgetsFlutterBinding.ensureInitialized()` and before the first `runApp`.

---

## Build Pipeline (Out-of-Repo Tooling)

The audio generation pipeline runs **outside Flutter**, in a Python script. Recommended stack:

| Component | Tool | Why |
|-----------|------|-----|
| YAML parsing | `pyyaml` | Standard, stable. |
| HTTP to Tiro | `httpx` (async) | Lets you parallelize calls to Tiro safely with a semaphore (e.g., max 2 concurrent). |
| Manifest hashing | `hashlib.sha256` over `(text, voice, ssml_overrides)` | Cache key for "have I generated this clip before?" |
| Audio processing | `ffmpeg-normalize` (Python wrapper) which calls `ffmpeg` | Single tool for normalize + AAC encode. |
| Asset map output | YAML or JSON manifest written to `assets/audio/manifest.yaml` | Read at app startup, parsed by a generated Dart class. |

Pseudocode flow per utterance:

```
for each utterance in manifest.yaml:
    hash = sha256(utterance.text + utterance.voice + utterance.ssml_overrides)
    if cached_clip_exists(hash):
        skip
    raw_pcm = tiro_synthesize(text=utterance.text, voice=utterance.voice, format="pcm")
    normalized_aac = ffmpeg_normalize(raw_pcm, target=-19_LUFS, peak=-1_dBTP, codec="aac", bitrate="96k")
    write_to(f"assets/audio/{utterance.category}/{utterance.id}.m4a")
    record_in_asset_map(hash, path)
```

A **post-generation manual review pass** is non-negotiable for a kids' app — the script should also produce an HTML page that plays each clip with its expected text label, so a human (you, the parent) can listen and flag mispronunciations in `pronunciation_overrides.yaml` before shipping.

---

## Installation

```yaml
# pubspec.yaml — runtime dependencies
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.3.1   # verify against pub.dev at install — see note in table
  riverpod_annotation: ^4.0.2
  drift: ^2.32.1
  drift_flutter: ^0.3.0
  just_audio: ^0.10.5
  audio_session: ^0.2.3
  freezed_annotation: ^3.2.0
  yaml: ^3.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.10.4
  riverpod_generator: ^4.0.3
  drift_dev: ^2.32.1
  freezed: ^3.2.3
  json_serializable: ^6.9.4
  flutter_gen_runner: ^5.10.0
```

```bash
# Build pipeline (outside Flutter)
pip install pyyaml httpx ffmpeg-normalize
brew install ffmpeg

# Flutter SDK pin
fvm install 3.41.5
fvm use 3.41.5

# Codegen
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs

# Audio generation (run when manifest changes)
python tools/generate_audio.py
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Tiro TTS | Microsoft Azure Neural TTS (Icelandic) | If Tiro's quality plateaus and you need a commercial paid alternative. Azure has Icelandic voices ("Gudrun", "Gunnar") with similar neural quality and commercial licensing that does not exclude under-13 apps. |
| Tiro TTS | Recording a real human Icelandic narrator | The "right" answer if budget allows — a $500–1500 voiceover session gives you 200–400 high-quality clips with no SSML pronunciation guesswork. Worth considering if Tiro Diljá v2 mispronounces too many of the chosen example words. |
| Drift | Hive / Isar | **Don't.** User explicitly chose Drift. Isar 4.x is unreleased / unmaintained as of 2026. Hive 2.x doesn't fit relational kid-progress data. |
| just_audio | audioplayers | `audioplayers` is more lightweight but lacks `ConcatenatingAudioSource` (gapless playlists), which becomes important when CVC blending arrives in post-MVP. just_audio is the strictly-superior choice. |
| flutter_gen | Manual asset constants | Manual works for ~10 assets. Breaks down at 200–400 audio clips. flutter_gen is the right tool. |
| Riverpod codegen | Manual provider declarations | Riverpod 4.x's manual provider syntax is workable but verbose. Codegen is worth the build_runner setup for ~50+ providers. (For a tiny app you could go without — but `freezed` and `drift_dev` already require build_runner, so the marginal cost is zero.) |
| CustomPainter for tracing | A pre-built drawing package (`scribble`, `flutter_painter`) | These exist but are aimed at adult drawing apps with layers/colors/erase — overkill for letter-shape tracing where you want strict control over stroke matching against a reference path. CustomPainter is correct. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| ElevenLabs | Prohibited Use Policy excludes apps targeting under-13 audiences. ToS violation regardless of plan. | Tiro TTS (Diljá v2) |
| just_audio_background | Adds iOS background audio entitlement & Android foreground service — App Store kids-category review red flags, no UX benefit | just_audio alone |
| StateNotifier (Riverpod 2.x pattern) | Deprecated in Riverpod 3+. Lives in `flutter_riverpod/legacy.dart` for migration only. | `Notifier` / `AsyncNotifier` via `@riverpod` codegen |
| sqlite3_flutter_libs (direct dep) | Drift 2.32+ no longer needs it as a direct dependency; `drift_flutter` handles bundling. Manual inclusion can cause version conflicts with sqlite3 4.x. | `drift_flutter ^0.3.0` only |
| Hive / Isar | User chose Drift. Isar 4 unreleased; Hive 2 inadequate for relational data; Drift is the active, maintained, type-safe choice. | drift |
| MP3 audio assets | AAC has better quality at the same bitrate; both iOS and Android decode AAC in hardware; M4A container has duration metadata so playback starts faster. | AAC in M4A container |
| Stereo audio assets | Single narrator, mono recording; doubles bundle size for zero perceptible benefit on tablet speakers. | Mono |
| -16 LUFS or louder normalization | Children + tablets at 100% volume = sustained 90+ dB SPL near face. | -19 LUFS / -1 dBTP |
| go_router for two screens | Routing framework overhead with no benefit at this app size. | Built-in `Navigator` with `MaterialPageRoute` |
| Analytics SDKs (Firebase Analytics, Mixpanel, etc.) | App Store Kids category prohibition; PROJECT.md "no analytics SDKs" constraint. | None — no analytics. |
| `setAudioSources(sources, preload: true)` with > ~50 sources | Known just_audio issue (#1485) — large preload sets throw on some Android devices. | Preload per-screen subset (32 letters max), not entire app's audio at once. |

---

## Stack Patterns by Variant

**If MVP only (Stafir tap-to-hear, single screen):**
- Skip Rive, skip CustomPainter, skip ConcatenatingAudioSource.
- Single `AudioPlayer`, preload all 32 letter clips at *Stafir* entry, swap audio source on tap.
- Total runtime dependencies: flutter_riverpod, drift, drift_flutter, just_audio, audio_session, freezed_annotation. Six packages.

**If post-MVP with CVC blending (`kýr`, `sól`):**
- Add `ConcatenatingAudioSource` from just_audio for letter1 → letter2 → letter3 → blend (gapless).
- Add letter-level highlighting synced to `player.positionStream` (60 Hz tick).
- No new packages needed.

**If post-MVP with tracing:**
- CustomPainter + GestureDetector with `onPanStart/onPanUpdate/onPanEnd`.
- Wrap `CustomPaint` in `RepaintBoundary` to prevent parent rebuilds from triggering repaints.
- Sample stroke points to a `Path` (cumulative), and compute distance-to-reference-path on `onPanEnd`. Don't compute distance per-frame — that's what kills 60Hz on slow tablets.
- See PITFALLS.md.

**If post-MVP with personalization (parent uploads photos):**
- Add `image_picker ^1.x` (camera/gallery)
- Add `image ^4.x` (resize to ~1024px max dimension on save — protects Drift DB size)
- Photos stored as files in app documents directory; Drift stores only the path + tag. Don't put image bytes in SQLite.

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| flutter 3.41.5 | Dart 3.9 | Bundled. |
| flutter_lints 6.0.0 | Flutter 3.35+ / Dart 3.9+ | Aligned with target Flutter version. |
| riverpod_generator 4.0.3 | riverpod_annotation 4.0.2, riverpod 4.x | The package family must move together. Don't mix `riverpod_annotation 4.x` with `flutter_riverpod 3.x` — runtime errors. |
| drift 2.32.1 | drift_dev 2.32.1, sqlite3 ^3.0 | Drift 2.32.0+ explicitly drops `sqlite3_flutter_libs` requirement. Verify your transitive deps don't pin it. |
| drift_flutter 0.3.0 | drift 2.32+, path_provider 2.x | Internal; users typically don't pin path_provider. |
| just_audio 0.10.5 | audio_session 0.2.x | Documented compatible pair. |
| rive 0.14.6 | rive_native 0.1.6 | rive package transitively pulls rive_native. Don't pin rive_native directly. |
| build_runner 2.10.4 | dart 3.9+ | Recent build_runner has 2x speed improvements; older versions work but slower. |
| flutter_gen_runner 5.x | build_runner 2.12+ | Required for the post-process builder pattern flutter_gen now uses. |

---

## Open Verification Items

These should be confirmed before locking the build pipeline. Confidence currently MEDIUM:

1. **Tiro TTS authentication.** Public service appears unauthenticated, but the live OpenAPI spec at `tts.tiro.is` should be inspected to confirm. Action: `curl -X POST https://tts.tiro.is/v0/speech/synthesize -H 'content-type: application/json' -d '{"Text":"halló","VoiceId":"Diljá_v2","OutputFormat":"pcm","SampleRate":"16000","Engine":"standard"}'` — if it returns audio, no auth needed.
2. **Tiro TTS rate limits.** Not documented. Pipeline rate-limits itself to 1 req/sec defensively.
3. **Tiro voice ID exact strings.** The voice list shows "Diljá v2" with a space; the API likely expects an underscore or specific ID like `Diljá_v2` or `dilja_v2`. Verify against the OpenAPI spec.
4. **Riverpod major version.** flutter_riverpod 3.x vs 4.x is mid-migration on pub.dev in early 2026. Run `dart pub outdated` and pin whichever pair is internally consistent — ideally 4.x family across the board.
5. **iOS Impeller vs Skia for CustomPainter tracing.** Impeller (default on iOS in 3.41) handles complex `Path` operations differently from Skia. Test stroke rendering performance on actual hardware before the post-MVP tracing milestone.

---

## Sources

### Authoritative — HIGH confidence
- [pub.dev/packages/flutter_riverpod](https://pub.dev/packages/flutter_riverpod) — flutter_riverpod 3.3.1 stable
- [pub.dev/packages/riverpod_generator](https://pub.dev/packages/riverpod_generator) — riverpod_generator 4.0.3 stable
- [pub.dev/packages/drift](https://pub.dev/packages/drift) — drift 2.32.1 stable
- [pub.dev/packages/drift_flutter](https://pub.dev/packages/drift_flutter) — drift_flutter 0.3.0 stable
- [pub.dev/packages/just_audio](https://pub.dev/packages/just_audio) — just_audio 0.10.5 stable, gapless support, ConcatenatingAudioSource
- [pub.dev/packages/audio_session](https://pub.dev/packages/audio_session) — audio_session 0.2.3 stable
- [pub.dev/packages/rive](https://pub.dev/packages/rive) — rive 0.14.6 stable
- [docs.flutter.dev/release/release-notes](https://docs.flutter.dev/release/release-notes) — Flutter 3.41.5 stable Feb 2026
- [riverpod.dev — 3.0 migration guide](https://riverpod.dev/docs/3.0_migration) — breaking changes from 2.x → 3.x (further changes in 4.x)
- [github.com/icelandic-lt/tiro-tts](https://github.com/icelandic-lt/tiro-tts) — voices, output formats, SSML support, Apache 2.0 license
- [elevenlabs.io/use-policy](https://elevenlabs.io/use-policy) — Prohibited Use Policy excluding under-13 bundled solutions
- [help.elevenlabs.io — supported languages](https://help.elevenlabs.io/hc/en-us/articles/13313366263441-What-languages-do-you-support) — Icelandic supported in v3 model only
- [elevenlabs.io/docs/overview/models](https://elevenlabs.io/docs/overview/models) — Eleven v3 is the only model with Icelandic
- [github.com/grammatek/ice-g2p](https://github.com/grammatek/ice-g2p) — Icelandic G2P for SSML phoneme overrides
- [github.com/slhck/ffmpeg-normalize](https://github.com/slhck/ffmpeg-normalize) — EBU R128 LUFS normalization tool
- [pub.dev/packages/flutter_lints](https://pub.dev/packages/flutter_lints) — flutter_lints 6.0.0 stable

### Supplementary — MEDIUM confidence
- [repository.clarin.is — Tiro TTS web service 22.10](https://repository.clarin.is/repository/xmlui/handle/20.500.12537/268) — government archive, confirms permissive license intent
- [github.com/ryanheise/just_audio — issue #131 gapless playlists](https://github.com/ryanheise/just_audio/issues/131) — gapless platform notes
- [github.com/ryanheise/just_audio — issue #1485 setAudioSources preload](https://github.com/ryanheise/just_audio/issues/1485) — large preload set issue
- [pub.dev/packages/freezed](https://pub.dev/packages/freezed) — freezed 3.2.3 stable
- [riverpod.dev — what's new in 3.0](https://riverpod.dev/docs/whats_new) — Notifier API, AsyncValue.value rename, automatic retry
- [github.com/FlutterGen/flutter_gen](https://github.com/FlutterGen/flutter_gen) — flutter_gen current usage

### Confidence by Section

| Section | Confidence | Why |
|---------|------------|-----|
| Flutter SDK + core packages versions | HIGH | Verified against pub.dev / docs.flutter.dev directly. |
| Riverpod 3.x vs 4.x | MEDIUM | Mid-migration on pub.dev as of early 2026 — versions table flags this; verify at `pub get` time. |
| Drift setup, drift_flutter | HIGH | Direct pub.dev verification, drift 2.32 release notes explicit. |
| just_audio + audio_session | HIGH | Direct pub.dev + GitHub issue verification. |
| Rive 0.14.x for post-MVP | HIGH | Direct pub.dev verification. |
| Tiro TTS — license, voices, formats, SSML | HIGH | GitHub README + CLARIN repository archive. |
| Tiro TTS — auth, rate limits, exact voice IDs | MEDIUM | OpenAPI spec at tts.tiro.is wasn't fetchable in this research session; fields require live verification. Listed in "Open Verification Items." |
| ElevenLabs — Icelandic in v3 only | HIGH | ElevenLabs docs explicit. |
| ElevenLabs — under-13 prohibition | HIGH | ElevenLabs Prohibited Use Policy, direct quote. |
| LUFS target -19 / -1 dBTP for kids | MEDIUM | Reasoned from EBU R128 standards + general loudness/SPL math; no kids'-app-specific industry standard found. Tunable based on listening tests on Hugrún's tablet. |
| AAC/M4A audio format choice | HIGH | Standard mobile-platform best practice. |
| Audio session config — custom not preset | MEDIUM | Reasoned from `audio_session` README + just_audio docs; preset behavior is documented but the "kids' app" choice is design judgment. |

---

*Stack research for: Hugrún — offline-first Flutter kids' Icelandic literacy + numeracy app*
*Researched: 2026-05-02*
