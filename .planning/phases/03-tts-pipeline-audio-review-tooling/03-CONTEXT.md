# Phase 3: TTS Pipeline & Audio Review Tooling - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto` (Claude picked recommended option for each gray area; decisions logged inline)

<domain>
## Phase Boundary

A reproducible Python pipeline that turns `manifest.yaml` (one entry per audio clip the app needs) into 100% native-speaker-reviewed, loudness-normalized AAC clips and a regenerated `lib/gen/audio_manifest.g.dart`, with `pronunciation_overrides.yaml` available from day one and a review UI that gates final asset bundling on entry-by-entry reviewer sign-off.

**Stack:**
- **Piper** (`rhasspy/piper`) — open-source Apache 2.0 on-device neural TTS, run locally as a build-time CLI. Icelandic voice: **Steinn** (male, Grammatek Símarómur). Replaces Tiro after the 2026-05-02 Tiro outage discovery — Tiro service is offline and the upstream repo is frozen since 2022.
- ffmpeg-normalize (EBU R128, -19 LUFS / -1 dBTP)
- ffmpeg (AAC-LC encoding, mono, 96 kbps, 48 kHz, M4A container)
- Python 3.x with `pyyaml` + `Jinja2` (no HTTP client needed — Piper is local CLI)
- A simple HTML or Flutter review UI

**TTS provider history:**
- v1 (planned): Tiro TTS via `tts.tiro.is` → service offline 2026-05-02
- v2 (current): Piper / Grammatek Símarómur, voice "Steinn", local CLI invocation
- Future: if Steinn quality is insufficient, fall back to Microsoft Azure Neural TTS (`is-IS-GudrunNeural`) per PROJECT.md

**Why Piper:**
- Apache 2.0 — no licensing risk for kids' app
- Runs entirely offline (no service availability concerns)
- Same architectural slot as Tiro (build-time generator → AAC clips ship as static assets)
- All other tooling (ffmpeg-normalize, manifest_writer, review UI, reviewed.yaml gate) unchanged

**Requirements covered (10):** AUDIO-01..10 (the entire Audio Pipeline category)

**NOT in this phase:** Generating real audio for all 32 letters + all example words (that work happens incrementally — Phase 3 ships the pipeline + a subset of clips for Phase 4 MVP; the rest follow as Phases 4–9 require). Phase 3 produces ~10–20 clips: all 32 letter names + a few example words sufficient to launch Phase 4's tap-to-hear MVP.

</domain>

<decisions>
## Implementation Decisions

### Pipeline Architecture

- **D-01:** Python pipeline lives at `tools/tts/`. Layout:
  ```
  tools/tts/
    bake_audio.py            # main entry point: reads manifest.yaml, runs full pipeline
    tiro_client.py           # Tiro TTS HTTP client wrapper
    normalize.py             # ffmpeg-normalize + ffmpeg encode wrapper
    manifest_writer.py       # generates lib/gen/audio_manifest.g.dart from manifest.yaml + reviewed metadata
    review_server.py         # local HTTP server for the review UI
    requirements.txt         # Python deps: requests/httpx, pyyaml, Jinja2 (for manifest gen)
    README.md                # how to run, dependencies, troubleshooting
  manifest.yaml              # single source of truth for all utterances (top-level repo file)
  pronunciation_overrides.yaml  # SSML/phoneme overrides per utterance key (top-level)
  reviewed.yaml              # reviewer sign-off log (top-level, committed; one entry per utterance key + voice + version)
  ```
- **D-02:** Pipeline runs in stages, each idempotent and resumable:
  1. **Plan stage:** read `manifest.yaml`, compute the full set of expected `UtteranceKey`s and asset paths
  2. **Generate stage:** for each utterance not yet present (or whose source text changed since last run), call Tiro TTS with the appropriate text + voice + SSML/override
  3. **Normalize stage:** for each newly-generated raw clip, run ffmpeg-normalize at -19 LUFS / -1 dBTP, then encode to AAC-LC mono 96 kbps M4A
  4. **Review gate:** for each clip not yet flagged `reviewed: true` in `reviewed.yaml`, BLOCK with a clear error message linking to the review UI
  5. **Manifest stage:** regenerate `lib/gen/audio_manifest.g.dart` from `manifest.yaml` + asset paths
- **D-03:** All stages atomic per-utterance — a failure on one clip doesn't roll back the others. The pipeline produces a per-run report (`tools/tts/last-run.json`) summarizing what was generated, normalized, blocked-on-review, and emitted.

### manifest.yaml Format

- **D-04:** Single YAML file at the repo root. Schema:
  ```yaml
  version: 1
  voice: dilja_v2  # default voice; per-utterance override allowed
  language: is-IS
  utterances:
    - key: letterA          # → UtteranceKey.letterA in Dart
      text: "a"             # text Tiro receives
      asset: assets/audio/letters/names/a.aac
      kind: letter_name
    - key: letterEth
      text: "eð"
      asset: assets/audio/letters/names/eth.aac
      kind: letter_name
    - key: wordHundur
      text: "hundur"
      asset: assets/audio/letters/words/hundur.aac
      kind: example_word
      starts_with: h
    # ... etc
  ```
  - `key` matches a `UtteranceKey` enum entry in the generated Dart manifest
  - `text` is what Tiro receives (raw); SSML or phoneme override comes from `pronunciation_overrides.yaml`
  - `asset` is the relative path under repo root
  - `kind` is one of: `letter_name`, `example_word`, `phoneme` (Phase 6), `numeral_masculine`/`feminine`/`neuter` (Phase 8), `narration`, `celebration`
  - Optional metadata: `voice` (override), `tempo`, `pitch`, `notes_for_reviewer`

### Piper TTS Client (build-time, local)

- **D-05:** Piper installed via `brew install piper-tts` (recommended) OR `pipx install piper-tts`. Voice model `is_IS-steinn-medium.onnx` + `.json` config file downloaded from the Hugging Face Piper voices repo (`rhasspy/piper-voices`) and cached at `tools/tts/voices/is_IS-steinn-medium.onnx`. Voice file size ~30MB; committed to git LFS or downloaded by `tools/tts/setup_voice.sh` on first run (don't bloat regular git).
- **D-06:** First task is a Piper verification spike: install Piper, download Steinn voice, synthesize "halló" → WAV file → play it back manually (the executor logs the file path; user confirms quality at review-pass time). Findings documented in `tools/tts/README.md`. No network at runtime, no API keys, no rate limits. If Piper install fails or Steinn voice unavailable → STOP, escalate.
- **D-07:** No rate limiting needed (local CLI). Parallelizable: pipeline can synthesize multiple clips concurrently (limited by CPU cores). Default: 4 parallel workers.
- **D-08:** Piper outputs WAV (16-bit PCM 22050 Hz mono). Pipeline writes raw output to `tools/tts/_raw/{utterance_key}.wav`. ffmpeg-normalize reads from there. Cache key includes voice model version + text hash so re-runs are idempotent.

### Audio Normalization & Encoding

- **D-09:** ffmpeg-normalize invocation:
  ```
  ffmpeg-normalize tools/tts/_raw/{key}.wav \
    -t -19 \
    --tp -1 \
    -c:a aac \
    -b:a 96k \
    --extension m4a \
    -o assets/audio/.../{key}.aac
  ```
- **D-10:** After normalize, pad with 20–50 ms leading silence to mask encoder priming delay (research Finding 4):
  ```
  ffmpeg -i input.aac -af "adelay=30|30" -c:a copy padded.aac
  ```
- **D-11:** Reject clips that deviate >±0.5 LU from -19 LUFS after normalization (research Finding 5). Pipeline aborts with clear error if any clip fails this check.
- **D-12:** Codec: AAC-LC. Container: M4A. Mono. 96 kbps. 48 kHz. (Locked by research findings + PROJECT.md constraints.) Asset filename ends in `.aac` (the M4A container is implicit; the `.aac` extension is what Flutter just_audio expects).

### Pronunciation Overrides

- **D-13:** `pronunciation_overrides.yaml` schema (Piper-flavored):
  ```yaml
  version: 1
  overrides:
    letterEth:
      # Piper accepts eSpeak-style phoneme markup or raw text substitution
      text: "eð"  # default: send raw text
      phonemes: "/eð/"  # optional eSpeak phoneme override
    wordHundur:
      text: "hundur"
      rate: 0.95  # Piper supports length scale (1.0 = normal)
  ```
- **D-14:** Override file is consulted by `piper_client.py` before each synthesis call. If a key has an override, the override is applied as Piper CLI args (`--length-scale`, phoneme replacement) or as text substitution.
- **D-15:** Document Piper phoneme markup in `tools/tts/README.md` after voice verification (D-06). Piper supports limited prosody control via `--length-scale` and `--noise-scale`; for fine pronunciation control, use eSpeak-style phoneme spelling in the text input.

### Review UI & Sign-off Gate

- **D-16:** Local Python HTTP server at `tools/tts/review_server.py`. Renders a single-page HTML UI with one row per utterance:
  - Row shows: `key`, `text`, audio player (HTML5 `<audio>`), reviewer notes textarea, "Approve" + "Re-record needed" buttons
  - Approve writes `reviewed: true` + reviewer name + timestamp + voice version + utterance text hash to `reviewed.yaml`
  - Re-record writes a flag to `pronunciation_overrides.yaml` queueing a re-synth on next pipeline run
  - Bulk "Approve all" with confirmation
- **D-17:** `reviewed.yaml` schema:
  ```yaml
  version: 1
  entries:
    letterA:
      reviewed: true
      reviewer: "Jon"
      timestamp: "2026-05-02T14:30:00Z"
      voice: "dilja_v2"
      text_hash: "sha256:abc..."
      notes: ""
    letterEth:
      reviewed: false  # pending re-record
      issue: "ð pronunciation sounds like 'd' instead of voiced th"
  ```
- **D-18:** `bake_audio.py` checks `reviewed.yaml` before regenerating `audio_manifest.g.dart`. If ANY utterance lacks `reviewed: true`, the manifest writer aborts with a clear list of unreviewed clips and a link to the review server.
- **D-19:** Review UI runs locally only (`localhost:8765` by default). No auth, no remote access. Closed after review session.

### Manifest Generation (Replaces Phase 2's Hand-Written Stub)

- **D-20:** `manifest_writer.py` generates `lib/gen/audio_manifest.g.dart` using a Jinja2 (or simple string-template) template. Output:
  - Header: `// GENERATED FILE — DO NOT EDIT MANUALLY` + `// Generated by tools/tts/bake_audio.py at <timestamp>`
  - Imports
  - `enum UtteranceKey { ... }` — one entry per `manifest.yaml` utterance, sorted alphabetically for diff stability
  - `class AudioAsset { ... }` — same shape as Phase 2's stub
  - `const Map<UtteranceKey, AudioAsset> kAudioManifest = { ... }`
  - `AudioAsset getAudioAsset(UtteranceKey key) => ...`
- **D-21:** Generated file is committed to git (NOT gitignored) — Phase 2's `.gitignore` rule for `*.gen.dart` may need to be loosened to keep `audio_manifest.g.dart` versioned. Build reproducibility: anyone can clone and run `flutter build` without Python or Tiro keys.
- **D-22:** Phase 2's hand-written stub is overwritten by Phase 3's first successful pipeline run. Plan 03 must verify the generated file maintains backward compatibility with the 5 stub keys (`letterA, letterEth, letterThorn, wordHundur, narrationWelcome`) — these stay in `manifest.yaml` so existing Dart code referencing them continues to compile.

### CI Integration

- **D-23:** Pipeline does NOT run in CI by default — it requires Tiro API access + manual review. CI verifies only:
  1. `manifest.yaml` is valid YAML and conforms to schema
  2. `reviewed.yaml` has `reviewed: true` for every key in `manifest.yaml`
  3. `lib/gen/audio_manifest.g.dart` is in sync with `manifest.yaml` (re-running the manifest_writer with current `manifest.yaml` produces the same Dart output — git diff = empty)
- **D-24:** New CI script: `tools/check-manifest-sync.sh` enforces #3 above. Failure means someone updated `manifest.yaml` but didn't re-run the pipeline / commit the regenerated `audio_manifest.g.dart`.
- **D-25:** Optional CI job for the pipeline itself: `tts-bake` job, `if: github.event.label == 'rebake-audio'` — run only when explicitly labeled. Defer this to v2; Phase 3 ships local-only pipeline.

### Audio Pipeline Scope for Phase 3 vs Later

- **D-26:** Phase 3 ships:
  - All 32 letter-name clips (one per letter — `letterA, letterAcute, letterB, ..., letterOumlaut`)
  - One example word per letter for Phase 4 MVP (32 words, e.g. `wordHundur` for h, `wordKýr` for k)
  - Welcome narration (`narrationWelcome` — "Halló Hugrún" or similar)
  - Total: ~65 clips
- **D-27:** Phase 6 adds the phoneme set (32 more clips). Phase 8 adds gendered numeral clips (~24). Phase 5 may add celebration narrations. Each later phase extends `manifest.yaml` and re-runs the pipeline.

### ffmpeg / ffmpeg-normalize Installation

- **D-28:** Pipeline requires `ffmpeg`, `ffmpeg-normalize`, and `piper` on PATH plus the Steinn voice model file. ffmpeg + ffmpeg-normalize already installed (Phase 3 first attempt). Piper install: `brew install piper-tts` (preferred) or `pipx install piper-tts`. Voice download: `tools/tts/setup_voice.sh` fetches `is_IS-steinn-medium.onnx` + config from `huggingface.co/rhasspy/piper-voices` to `tools/tts/voices/`.
- **D-29:** Pipeline provides a `--check-deps` mode that verifies ffmpeg + ffmpeg-normalize + piper + voice model presence and prints actionable error messages. **No API keys** (local CLI).

### Reviewer Identity & Trust

- **D-30:** The reviewer is the user (Jon) personally. The "native speaker" requirement is satisfied by Jon being a native Icelandic speaker (or having one available). If Jon is not the native speaker, the review UI accepts a reviewer name field; whoever signs off is recorded in `reviewed.yaml`.
- **D-31:** No automated lint of pronunciation — review is purely human. Future enhancement (post-v1): a lightweight A/B comparison UI showing two voice candidates side-by-side.

### Claude's Discretion

- Exact Tiro API endpoint paths and voice ID string format (verify with curl per D-06)
- Whether to use `requests` or `httpx` (either works; pick one)
- HTML vs Flutter for review UI (HTML is simpler; Flutter would reuse app code)
- Whether to use Jinja2 or string-template for `audio_manifest.g.dart` generation (Jinja2 is more robust; string-template is simpler — pick what's idiomatic)

### Folded Todos

(None — no pre-existing todos.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md` AUDIO-01..10
- `.planning/ROADMAP.md` § Phase 3
- `.planning/phases/01-skeleton-drift-schema/01-SUMMARY.md` + `01-CONTEXT.md`
- `.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-CONTEXT.md` — D-08 (UtteranceKey enum keys must remain stable across the Phase 2 stub → Phase 3 generated transition)
- `.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-SUMMARY.md` (read after Phase 2 executes)

### Research
- `.planning/research/SUMMARY.md` — Findings 1, 2, 4, 5 (ElevenLabs banned, native-speaker review mandatory, latency padding, LUFS targets)
- `.planning/research/STACK.md` — Tiro TTS section: Apache 2.0, voice IDs, SSML support (medium-confidence — verify), rate limits (undocumented), AAC-LC mono 96 kbps M4A
- `.planning/research/PITFALLS.md` — Pitfall #1 (mispronunciation review), #5 (loudness drift), #15 (TTS API rate limits / version stability)
- `.planning/research/FEATURES.md` — letter names vs phonemes (different audio sets — Phase 6 phonemes use the same pipeline)

### External docs (verify at execution time)
- https://tts.tiro.is — Tiro TTS API homepage; OpenAPI spec (if available) is the authoritative voice ID source
- https://github.com/icelandic-lt/tiro-tts — GitHub README confirms Apache 2.0 license + voice list
- https://github.com/slhck/ffmpeg-normalize — EBU R128 normalization reference
- https://en.wikipedia.org/wiki/Loudness#EBU_R_128 — LUFS background

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (after Phase 2 ships)
- Phase 2's hand-written `lib/gen/audio_manifest.g.dart` defines the structure; Phase 3 overwrites it but maintains the 5 stub keys
- Phase 2's 5 placeholder AAC files at `assets/audio/...` are overwritten by Phase 3's real Tiro-generated clips
- Phase 2's `tools/check-asset-paths.sh` validates new assets without modification — Phase 3 just adds clips that already conform
- `tools/check-no-tracking.sh` and `tools/check-domain-purity.sh` patterns for self-testing CI scripts apply to Phase 3's `tools/check-manifest-sync.sh`

### Established Patterns
- TDD red→green→refactor — applies to Python code too (use `pytest` for the pipeline)
- Atomic commits per cycle
- Generated code committed to git for reproducibility
- Self-testing CI scripts with intentional bad fixtures
- `lib/core/` is pure Dart, no Flutter imports — Phase 3's Dart manifest only imports `package:flutter` if needed for `AssetBundle` (which it should NOT — keep manifest pure data)

### Integration Points
- `manifest.yaml` ← Phase 4 will reference its keys for AudioEngine cache warming
- `lib/gen/audio_manifest.g.dart` → consumed by Phase 4 AudioEngine (warm pool reads `kAudioManifest` paths)
- `pronunciation_overrides.yaml` → editable by Jon between review cycles
- `assets/audio/letters/names/` ← Phase 4 grid taps trigger letter-name playback
- `assets/audio/letters/words/` ← Phase 4 example word follows letter name
- `assets/audio/letters/phonemes/` ← Phase 6 CVC blending (manifest extended in Phase 6)
- `tools/tts/` ← stays local-only; CI does not need Tiro keys

</code_context>

<specifics>
## Specific Ideas

- Diljá v2 is the v1 narrator (locked in PROJECT.md); pipeline tasks must not silently swap to a different voice
- The "review every clip" requirement is non-negotiable per research Finding 2 — no shortcuts; pipeline blocks until reviewed.yaml is complete
- Welcome narration text idea: "Halló Hugrún. Veldu stafi eða tölur." ("Hello Hugrún. Choose letters or numbers.") — final wording is Jon's call during review
- Example word picks should be concrete, easily-imageable nouns the kid will recognize: hundur (dog), kýr (cow), sól (sun), bók (book), epli (apple), etc. Final list is Jon's call during review

</specifics>

<deferred>
## Deferred Ideas

- **Phoneme audio set** — Phase 6 (extends manifest.yaml with `kind: phoneme` entries)
- **Gendered numeral audio (1–4 × M/F/N)** — Phase 8 (extends manifest.yaml with `kind: numeral_*`)
- **Celebration narrations** — Phase 5 / 7 (matching success cue, tracing completion with child name)
- **Multi-voice support** — Phase 3 ships single-voice (Diljá v2). Future feature: A/B test voices per utterance.
- **CI rebake job** — D-25 explicit deferral. Phase 3 ships local pipeline only.
- **Free-text parent-tagged photo audio** — Phase 10+ (would need runtime TTS or pre-baked common-word fallback; out of v1 scope per PROJECT.md)
- **Lossless audio archive of raw Tiro outputs** — `tools/tts/_raw/` is .gitignored; future v2 feature might version these for re-encoding without re-synthesis

### Reviewed Todos (not folded)

None.

</deferred>

---

*Phase: 3 — TTS Pipeline & Audio Review Tooling*
*Context gathered: 2026-05-02*
