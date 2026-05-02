---
status: human_needed
phase: 3
date: 2026-05-02
phase13_update: 2026-05-02
pronunciation_review: pending
technical_review: passed
pending:
  - "Jon listens to 118 Piper Steinn audio clips via the review UI (Plan 05) — UNCHANGED by Phase 13"
  - "Jon clicks Approve / Re-record for each clip until reviewed.yaml has reviewed: true for every entry"
  - "Re-run python tools/tts/bake_audio.py with reviewed.yaml fully populated; native-speaker review gate passes; lib/gen/audio_manifest.g.dart regenerates without the PRONUNCIATION REVIEW PENDING markers"
  - "Atomic ship commit: regenerated Dart + populated reviewed.yaml + any pronunciation_overrides.yaml entries"
---

> **Phase 13 update (2026-05-02):** The technical review pass has run.
> All 118 baked clips meet format / loudness / non-empty specs and are
> marked `technically_reviewed: true` in `reviewed.yaml`. The
> regenerated `lib/gen/audio_manifest.g.dart` carries 118 entries plus
> per-entry `// PRONUNCIATION REVIEW PENDING` markers. The app now
> plays audio at runtime, but **pronunciation correctness is still
> pending native-speaker review**. Native-speaker pronunciation review
> is the user's responsibility; the path below is unchanged.

# Phase 3 Verification — human_needed

## Why human_needed

Phase 3's pipeline is operationally complete. 118 real Piper Steinn audio
clips (32 letter names, 35 example words including 3 CVC additions, 32
phonemes, 18 numerals, 1 narration) exist under `assets/audio/...` and are
committed. The review gate (D-18) correctly blocks the **strict** manifest
regeneration until every clip has been listened-to + signed-off by a native
Icelandic speaker (research finding 2 — mandatory 100% native-speaker review).

Phase 13 introduced a **soft gate** (`technically_reviewed: true`) that
unblocks runtime audio without certifying pronunciation. The app now plays
sound for every UtteranceKey at runtime, but each entry's audio comment
carries a `// PRONUNCIATION REVIEW PENDING` marker until the native-speaker
pass runs.

The native-speaker verification cannot complete autonomously because the
review pass is a human listening activity that an executor agent cannot
perform.

## Pivot from Tiro to Piper (2026-05-02)

The original Phase 3 plan targeted the Tiro TTS API. Plan 01's verification
spike returned HTTP 404 against every documented endpoint; the Tiro service
is offline (CNAME points to talgreinir.is, the Tiro STT React app — the
upstream `icelandic-lt/tiro-tts` repo last commit is 2022-09).

Pivoted to **Piper** (Apache 2.0 on-device neural TTS, voice
`is_IS-steinn-medium` from Grammatek Símarómur, packaged at
`huggingface.co/rhasspy/piper-voices`). Piper runs entirely offline, has no
API keys, and supports the same architectural slot Tiro held (build-time
generator → AAC clips ship as static assets). All ffmpeg-normalize, manifest
writer, review UI, and CI guard tooling was reused unchanged.

## Pending items

### 1. Native-speaker review pass (Jon)

```bash
python tools/tts/review_server.py --port 8765
# open http://127.0.0.1:8765 in a browser
```

Listen to all 118 clips with headphones in a quiet room. Pay particular
attention to:

| Hot spot | Why |
|---|---|
| `letterEth` (ð) + `wordEth` (maður) | Voiced dental fricative — must NOT sound like 'd' |
| `letterThorn` (þ) + `wordThorn` (þrír) | Voiceless dental fricative — must NOT sound like 't' |
| `letterAe` (æ) + `wordAe` (æða) | Distinct from 'e' |
| `letterOumlaut` (ö) + `wordOumlaut` (öxl) | Distinct from 'o' |
| `letterX` (ex) + `wordX` (xýlófónn) | x is rare in Icelandic — likely needs override |
| `narrationWelcome` ("Halló Hugrún. Veldu stafi eða tölur.") | Proper noun "Hugrún" — highest-stakes |

For each clip:
- **Approve** if pronunciation is correct → review_server writes
  reviewed.yaml entry with `reviewed: true` + sha256 text_hash.
- **Re-record needed** if wrong → enter issue text → review_server marks
  `reviewed: false`. Then edit `pronunciation_overrides.yaml` and add an
  entry like:
  ```yaml
  overrides:
    letterEth:
      text: "eð"   # text substitution alternative
    letterEth:
      length_scale: 1.1   # slow down for clarity
  ```
  Re-run `python tools/tts/bake_audio.py` — only the changed clips
  re-synthesize (cache invalidates because used_text or length_scale
  changed → fingerprint mismatch → fresh piper call).

### 2. Pipeline re-run after review

Once `reviewed.yaml` has every key with `reviewed: true`:

```bash
python tools/tts/bake_audio.py
```

This regenerates `lib/gen/audio_manifest.g.dart` (118 entries already;
the regen will REMOVE the `// PRONUNCIATION REVIEW PENDING` markers
once the native-speaker pass approves each clip). Review gate passes;
`last-run.json` will show `manifest_written: true`.

After Phase 13: the manifest already has 118 entries with the soft
gate. Native-speaker approval just lifts the per-entry warning
comments (the audio path is already exercised end-to-end).

### 3. Atomic ship commit (Plan 07 Task 4 — post Phase 13)

```bash
git add lib/gen/audio_manifest.g.dart \
        lib/core/manifest/utterance_key.dart \
        reviewed.yaml \
        pronunciation_overrides.yaml
git commit -m "feat(03-07): ship Phase 3 — 118 native-speaker-reviewed Piper Steinn clips"
```

After this commit:
- `bash tools/check-manifest-sync.sh` already prints `ok: manifest sync`
  after Phase 13 (soft gate); the native-speaker pass simply removes
  the per-entry warning comments from the regenerated Dart.
- All AUDIO-* requirements satisfied.
- Phase 3 status flips to `complete`.

## What is currently passing

- `python -m pytest tools/tts/tests/` (120 tests; +10 Phase-13 technical-
  review + +4 Phase-13 schema + +5 Phase-13 manifest-writer soft-gate).
- `flutter test` (455 tests).
- `flutter analyze` (15 pre-existing riverpod_lint warnings on test files
  documented from Phase 5/6/7; no new issues).
- `flutter build apk --debug` succeeds.
- `bash tools/check-no-tracking.sh` (no banned packages).
- `bash tools/check-asset-paths.sh` (118 AAC paths conform to D-06).
- `bash tools/check-manifest-sync.sh` (`ok: manifest sync` — Phase 13
  soft gate accepted).
- `bash tools/check-manifest-sync_test.sh` (self-test — 2 cases pass).
- `python tools/tts/check_deps.py` (4 binaries + 4 modules + 2 voice files
  green).
- `python tools/tts/technical_review.py` (118/118 pass).

## What is currently NOT verifiable autonomously

- Pronunciation correctness for every Icelandic letter name + example word.
  This requires a native speaker listening session.
- Welcome narration "Hugrún" pronunciation correctness.
- Whether Steinn's voice quality is ear-acceptable for the kid's app target
  audience.
