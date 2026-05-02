---
status: human_needed
phase: 3
date: 2026-05-02
pending:
  - "Jon listens to 65 Piper Steinn audio clips via the review UI (Plan 05)"
  - "Jon clicks Approve / Re-record for each clip until reviewed.yaml is fully populated"
  - "Re-run python tools/tts/bake_audio.py with reviewed.yaml fully populated; review gate passes; lib/gen/audio_manifest.g.dart regenerates with 65 entries"
  - "Atomic ship commit (Plan 07 Task 4): regenerated Dart + populated reviewed.yaml + any pronunciation_overrides.yaml entries"
---

# Phase 3 Verification — human_needed

## Why human_needed

Phase 3's pipeline is operationally complete. 65 real Piper Steinn audio clips
exist under `assets/audio/...` and are committed. The review gate (D-18)
correctly blocks the manifest regeneration until every clip has been
listened-to + signed-off by a native Icelandic speaker (research finding 2 —
mandatory 100% native-speaker review).

The verification cannot complete autonomously because the review pass is a
human listening activity that an executor agent cannot perform.

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

Listen to all 65 clips with headphones in a quiet room. Pay particular
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

This regenerates `lib/gen/audio_manifest.g.dart` (5→65 entries) and
`lib/core/manifest/utterance_key.dart` (5→65 enum members). Review gate
passes; `last-run.json` will show `manifest_written: true`.

### 3. Atomic ship commit (Plan 07 Task 4)

```bash
git add lib/gen/audio_manifest.g.dart \
        lib/core/manifest/utterance_key.dart \
        reviewed.yaml \
        pronunciation_overrides.yaml
git commit -m "feat(03-07): ship Phase 3 — 65 reviewed Piper Steinn clips + regenerated audio manifest"
```

After this commit:
- `bash tools/check-manifest-sync.sh` transitions from
  `skip(03-06): Phase 3 pipeline has not yet been run end-to-end` to
  `ok: manifest sync` automatically (the Dart no longer matches the Phase 2
  stub).
- All AUDIO-* requirements satisfied.
- Phase 3 status flips to `complete`.

## What is currently passing

- `python -m pytest tools/tts/tests/` (110 tests across schema, validate_manifest,
  piper_spike, piper_client, normalize, manifest_writer, bake_audio, review_server).
- `flutter test` (96 tests; some are from Phase 4 in parallel).
- `flutter analyze` (no issues).
- `bash tools/check-no-tracking.sh` (no banned packages).
- `bash tools/check-asset-paths.sh` (65 AAC paths conform to D-06).
- `bash tools/check-manifest-sync.sh` (exits 0 with `skip(03-06):` —
  correctly identifying the not-yet-baked carve-out).
- `bash tools/check-manifest-sync_test.sh` (self-test — 2 cases pass).
- `python tools/tts/check_deps.py` (4 binaries + 4 modules + 2 voice files
  green).

## What is currently NOT verifiable autonomously

- Pronunciation correctness for every Icelandic letter name + example word.
  This requires a native speaker listening session.
- Welcome narration "Hugrún" pronunciation correctness.
- Whether Steinn's voice quality is ear-acceptable for the kid's app target
  audience.
