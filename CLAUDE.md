<!-- GSD:project-start source:PROJECT.md -->
## Project

**Hugrún**

A focused Flutter app for Hugrún (age 5) that teaches Icelandic letters/reading and early numeracy. Two rooms — *Stafir* (letters) and *Tölur* (numbers) — built around four shared mechanics: tap-to-hear, tracing, matching, sequencing. Built for one child first, with the option to release publicly later.

**Core Value:** A five-year-old can pick up a tablet, tap, and learn — discoverable through visuals and audio alone, with no failure states, no scores, no instructions to read.

### Constraints

- **Tech stack — Flutter**: Cross-platform from day one (iOS + Android). Hugrún's tablet is the test device.
- **State management — Riverpod**: User-specified. Replaces any other state library mentioned in earlier notes.
- **Persistence — Drift (SQLite)**: User-specified. Replaces the Hive/Isar mention from the original plan.
- **Audio runtime — `just_audio` + `Ticker`**: For sync between audio and animation. Pre-loaded into memory, no disk read latency mid-tap, no network calls during play. Ever.
- **Animation — Rive (deferred), CustomPainter for tracing (deferred to post-MVP)**: Tracing requires full control; Rive for character animation when activities expand.
- **Testing — TDD with Marionette for E2E**: Test-driven development is the default workflow. Write unit/widget tests before implementation (red → green → refactor). Use Marionette as the end-to-end test framework for Flutter UI verification. Every phase plan should sequence test tasks before implementation tasks.
- **Privacy / safety**: No ads, no IAP, no analytics SDKs, no network calls during play, no accounts, no cloud, no sync.
- **Timeline**: ASAP playable for Hugrún. MVP cut is steps 1–2 of the build order (tap-to-hear prototype + full alphabet coverage). Other activities follow only after the loop is dialed in.
- **Audio quality**: Every clip loudness-normalized so no clip is louder than another. Manual pronunciation review pass required for every utterance. Mispronunciations get an entry in `pronunciation_overrides.yaml`.
- **Child UX bars**: Tap response < ~50ms perceived. No fail states. No timers. No scores. No text instructions. Forgiveness > correctness.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## TL;DR
- **Flutter 3.41 stable / Dart 3.9** is the current channel. Pin both to a known tagged version with `fvm` so Hugrún's tablet doesn't get bricked by a SDK churn day.
- **Riverpod 4.x with code generation** (`@riverpod` annotations, `riverpod_generator`) — Riverpod 3.x has been superseded; 4.x is current stable. *Note: user prompt asked "2.x or 3.x?" — answer is 4.x.* The Notifier API replaces `StateNotifier`; legacy providers are imported from `flutter_riverpod/legacy.dart`.
- **Drift 2.32+** with `drift_flutter ^0.3.0` (handles SQLite bundling + path setup). `sqlite3_flutter_libs` is no longer needed since drift 2.32 — `drift_flutter` pulls it in transitively.
- **just_audio 0.10.x + audio_session 0.2.x** with `AudioPlayer` per-mechanic pool (one player kept warm for letter sounds, one for word audio) using preloaded `AudioSource.asset`. **Do not** use `just_audio_background` — kids' app, no lockscreen/CarPlay UX needed, and it pulls in iOS background-audio entitlements that complicate App Store review.
- **Tiro TTS first, NOT ElevenLabs.** ElevenLabs' Prohibited Use Policy explicitly prohibits "Services to make available bundled solutions that target anyone under the age of 13." Hugrún is 5. **An app that ships ElevenLabs-generated audio for a 5-year-old's app is a Terms of Service violation.** This invalidates the user's "evaluate in parallel" plan. See "ElevenLabs Section" below — this is the single most important finding.
- **LUFS target: -19 LUFS integrated, -1 dBTP true peak**, mono. Lower than streaming standards (-16 LUFS) because tablet speakers + kids = "loud enough at 50% volume, no clipping at 100%."
- **Audio output: 48 kHz mono AAC at ~96 kbps**, not stereo. Halves bundle size, and there's nothing stereo about a single narrator voice. Use ffmpeg's native AAC encoder or `libfdk_aac` if available.
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
## Tiro TTS — API Specifics
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
## ElevenLabs — DO NOT USE for this app
| Aspect | Detail |
|--------|--------|
| Icelandic support | Eleven v3 model only (released GA March 2026). Earlier models (Multilingual v2, Flash v2.5) do *not* support Icelandic. |
| Quality for Icelandic | Reports mixed. 70+ language support is breadth-first; Icelandic is in the long tail and "may have lower fidelity." Diljá v2 from Tiro is likely competitive or better for Icelandic specifically, despite ElevenLabs' overall quality lead in English. |
| Commercial license | Available from Starter ($5/month) — but moot, see prohibited use above. |
| Voice cloning | Possible — but cloning a child's voice (or a voice intended for children) is in further restricted territory under both ElevenLabs ToS and Iceland's GDPR-implementing legislation. |
## Audio Pipeline Specifics
### LUFS Target
- Streaming standards (-16 LUFS for Spotify/YouTube, -23 LUFS for EBU broadcast) are tuned for adult listeners with normal volume habits and stereo content.
- Kids' apps are different: a 5-year-old will probably set the tablet volume to 100%. If clips are mastered at -16 LUFS with peaks at -1 dBTP, individual loud sounds (a cheerful "rétt!") can hit ~93 dB SPL at the tablet speaker. That's loud-loud for a tablet held close to the face.
- -19 LUFS gives ~3 dB headroom below streaming standard. The child sets the volume; the app doesn't surprise them.
- Mono because there is one narrator. Stereo doubles the bundle size for zero perceptible benefit on a tablet's small speaker pair.
### Audio Format
- **AAC-LC at 96 kbps, 48 kHz, mono, in M4A container.**
- AAC-LC is hardware-decoded on every iOS device since 2007 and every Android device since ~2013 — zero CPU impact.
- 96 kbps mono is transparent for spoken-voice content (anything above ~80 kbps is, for mono speech).
- 48 kHz matches what iOS/Android audio stacks run natively — avoids resampling at playback time.
- M4A (.m4a) over .aac raw stream because M4A carries the duration metadata `just_audio` needs to start playback without scanning.
### Asset Preloading Strategy
### Audio Session Configuration
- `.music()` ducks other apps' music — wrong for an educational app where a parent might be playing music in the background.
- `.speech()` is for navigation/voice assistants — wrong category, may cause iOS to lower the volume in some interrupt scenarios.
- iOS: `AVAudioSessionCategory.playback` with `.mixWithOthers` option — lets parents' background music keep playing.
- Android: `AudioFocusGain` (transient may, but for short tap sounds gain is fine) with `usage = USAGE_GAME` and `contentType = CONTENT_TYPE_SPEECH`.
## Build Pipeline (Out-of-Repo Tooling)
| Component | Tool | Why |
|-----------|------|-----|
| YAML parsing | `pyyaml` | Standard, stable. |
| HTTP to Tiro | `httpx` (async) | Lets you parallelize calls to Tiro safely with a semaphore (e.g., max 2 concurrent). |
| Manifest hashing | `hashlib.sha256` over `(text, voice, ssml_overrides)` | Cache key for "have I generated this clip before?" |
| Audio processing | `ffmpeg-normalize` (Python wrapper) which calls `ffmpeg` | Single tool for normalize + AAC encode. |
| Asset map output | YAML or JSON manifest written to `assets/audio/manifest.yaml` | Read at app startup, parsed by a generated Dart class. |
## Installation
# pubspec.yaml — runtime dependencies
# Build pipeline (outside Flutter)
# Flutter SDK pin
# Codegen
# Audio generation (run when manifest changes)
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
## Stack Patterns by Variant
- Skip Rive, skip CustomPainter, skip ConcatenatingAudioSource.
- Single `AudioPlayer`, preload all 32 letter clips at *Stafir* entry, swap audio source on tap.
- Total runtime dependencies: flutter_riverpod, drift, drift_flutter, just_audio, audio_session, freezed_annotation. Six packages.
- Add `ConcatenatingAudioSource` from just_audio for letter1 → letter2 → letter3 → blend (gapless).
- Add letter-level highlighting synced to `player.positionStream` (60 Hz tick).
- No new packages needed.
- CustomPainter + GestureDetector with `onPanStart/onPanUpdate/onPanEnd`.
- Wrap `CustomPaint` in `RepaintBoundary` to prevent parent rebuilds from triggering repaints.
- Sample stroke points to a `Path` (cumulative), and compute distance-to-reference-path on `onPanEnd`. Don't compute distance per-frame — that's what kills 60Hz on slow tablets.
- See PITFALLS.md.
- Add `image_picker ^1.x` (camera/gallery)
- Add `image ^4.x` (resize to ~1024px max dimension on save — protects Drift DB size)
- Photos stored as files in app documents directory; Drift stores only the path + tag. Don't put image bytes in SQLite.
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
## Open Verification Items
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
