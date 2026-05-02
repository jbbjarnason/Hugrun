---
phase: 06
plan: 06-01
title: Phoneme manifest extension
subsystem: tts-pipeline
status: human_needed
date: 2026-05-02
tags: [phase-6, tts, manifest, phoneme, cvc, piper, review-pending]
requires:
  - phase-3 manifest pipeline (manifest.yaml + bake_audio.py + reviewed.yaml gate)
provides:
  - 32 phoneme<X> entries in manifest.yaml
  - 3 new CVC word entries (wordHus, wordHar, wordGas)
  - 32 baked phoneme AAC clips at assets/audio/letters/phonemes/
  - 3 baked CVC AAC clips at assets/audio/cvc/
key-files:
  modified:
    - manifest.yaml (65 → 100 utterances)
    - pubspec.yaml (assets list extended with assets/audio/cvc/)
  created:
    - assets/audio/letters/phonemes/ (32 .aac clips)
    - assets/audio/cvc/ (3 .aac clips: hus, har, gas)
    - assets/audio/letters/phonemes/.gitkeep handled implicitly
  related-untracked-out-of-scope:
    - assets/audio/letters/names/*.aac (re-baked Phase 3 clips — committed
      as fix(03) to backfill the never-shipped real Steinn output)
decisions:
  - D-01 phoneme keys named phoneme<PascalCaseSlug>
  - D-02 phoneme text = raw letter glyph (Piper Steinn input);
          eSpeak markup overrides deferred to review pass
  - D-03 review gate (D-18) blocks Dart manifest regen — expected end state
  - D-04 hús, hár, gás are new; the other 5 CVC starters reuse existing wordX keys
metrics:
  manifest-entries-added: 35
  baked-clips-added: 35
  pipeline-runtime: ~13 seconds for 100 utterances on 4 workers
  review-state: 0 / 100 entries reviewed in reviewed.yaml
---

# Phase 6 Plan 06-01 — Phoneme manifest extension Summary

## What this plan ships

Workstream A. Extends the Phase 3 audio manifest with the audio Phase 6
needs, runs the bake pipeline end-to-end, lands the new AAC clips in the
working tree.

The pipeline correctly STOPS at the review gate (D-18). The shipped state
is `human_needed` — exactly the planned end state per Phase 6 D-03. No
auto-approval, no review-gate bypass.

## Manifest changes

`manifest.yaml`: 65 → 100 utterances (+35).

### Phoneme set (32 entries; D-01, D-02; CVC-02)

| Pattern | Asset Dir | Text Input | Reviewed |
|---------|-----------|-----------|----------|
| `phoneme<PascalCase>` | `assets/audio/letters/phonemes/` | raw letter glyph | NO (awaiting review pass) |

One phoneme entry per Icelandic letter. Naming follows the slug → PascalCase
convention used by the resolver:

- `phonemeA, phonemeAAcute, phonemeB, phonemeD, phonemeEth, phonemeE,
  phonemeEAcute, phonemeF, phonemeG, phonemeH, phonemeI, phonemeIAcute,
  phonemeJ, phonemeK, phonemeL, phonemeM, phonemeN, phonemeO, phonemeOAcute,
  phonemeP, phonemeR, phonemeS, phonemeT, phonemeU, phonemeUAcute, phonemeV,
  phonemeX, phonemeY, phonemeYAcute, phonemeThorn, phonemeAe, phonemeOumlaut`

Text input strategy (D-02): use the raw letter glyph. Piper Steinn produces
a usable approximation of the sound for vowels (a, e, i, o, u); for
consonants Steinn typically produces the LETTER NAME ("bé", "té") rather
than the unvoiced phoneme. Each consonant manifest entry carries a
`notes_for_reviewer:` field flagging this — the reviewer adds an entry to
`pronunciation_overrides.yaml` with eSpeak phoneme markup (e.g. `[[t]]`)
when the LETTER NAME is heard, then re-runs `bake_audio.py` for just that
key.

### CVC additions (3 entries; D-04)

| Key | Text | Asset | Reviewed |
|-----|------|-------|---------|
| `wordHus` | hús | `assets/audio/cvc/hus.aac` | NO |
| `wordHar` | hár | `assets/audio/cvc/har.aac` | NO |
| `wordGas` | gás | `assets/audio/cvc/gas.aac` | NO |

The other 5 of 8 CVC starter words (kýr, sól, mús, rós, bók) re-use the
Phase 3 `wordK / wordS / wordM / wordR / wordB` example_word entries — those
words happen to be the example_word for their leading letter. Phase 6
deliberately does NOT duplicate them.

A new asset directory was added: `assets/audio/cvc/` (Phase 5 added
`assets/audio/letters/words/`; Phase 6 keeps CVC blends separate from the
letter-name example words for clarity). `pubspec.yaml` was extended to
include the new directory.

## Pipeline run

```bash
$ python3 tools/tts/bake_audio.py --workers 4
started_at: 2026-05-02T17:13:12Z
finished_at: 2026-05-02T17:13:25Z
total: 100
  normalized: 100
manifest_written: False
next_action: REVIEW GATE BLOCKED:
  Review gate (D-18) blocks manifest emission. 100/100 unresolved:
    - letterA: not in reviewed.yaml
    - ...
```

13 seconds wall clock for 100 utterances on 4 ThreadPool workers. Every
clip normalized successfully (-19 LUFS / -1 dBTP, AAC-LC mono 96k 48k).
The review gate blocks `lib/gen/audio_manifest.g.dart` regen — exactly
the planned end state.

## Side-effect: Phase 3 backfill (out-of-scope auto-fix, Rule 1)

Discovered during `git status` after the bake: the 65 existing AAC clips
at `assets/audio/letters/names/*` and `assets/audio/letters/words/*` had
been committed as 4-byte Phase 2 stubs (from Plan 02-02), even though the
Phase 3 SUMMARY claims real Steinn clips were shipped. The Phase 3 Plan
07 Task 1 baking ran end-to-end but the resulting files were never staged.

This is a Phase 3 carryover bug (Rule 1: auto-fix bugs). The Phase 6 bake
re-generated them deterministically — so the working tree now has real
audio. This was committed separately as `fix(03):` (preceding the Phase 6
manifest commit) to keep the git history honest.

This is a no-op for runtime behavior: the Phase 2 stub `kAudioManifest`
still references only the 5 baseline keys, and AudioEngine.play falls back
silently for the new keys. Once the review pass repopulates the Dart
manifest, the real clips become reachable.

## D-21 silent-fallback contract preserved

The 35 new manifest entries exist in `manifest.yaml` and the AAC clips
exist on disk, but `lib/gen/audio_manifest.g.dart` and
`lib/core/manifest/utterance_key.dart` (the runtime contract) still
reference only the Phase 2 stub set + the Phase 6 enum extensions
introduced in Plan 06-02. The 35 new keys exist in the enum but are
absent from `kAudioManifest` — so `AudioEngine.play(phonemeA)` returns
silently per D-21. This is the documented behavior: until a native
Icelandic-speaker review pass approves the clips, the activity is
structurally functional but silent.

## What needs to happen next (review pass)

Async, separate session:

1. Jon launches the review server: `python3 tools/tts/review_server.py --port 8765`.
2. Headphones, quiet room, listen to all 100 clips. Pay attention to:
   - The 32 phoneme clips: do they sound like the SOUND, not the NAME?
   - The 3 new CVC clips (hús, hár, gás): are they pronounced cleanly?
   - The 65 re-baked Phase 3 clips: still good.
3. For phonemes that come out as the letter NAME, edit
   `pronunciation_overrides.yaml`:
   ```yaml
   overrides:
     phonemeT:
       phonemes: "[[t]]"  # eSpeak phoneme markup
   ```
4. Re-run `python3 tools/tts/bake_audio.py` — only changed clips re-bake
   (idempotent cache).
5. Once every clip is approved, `bake_audio.py` writes
   `lib/gen/audio_manifest.g.dart` (100-entry compile-time map) +
   regenerates `lib/core/manifest/utterance_key.dart`.
6. Commit the regenerated Dart files + ship.

## Quality gate

- [x] manifest.yaml: 65 → 100 utterances, schema valid
- [x] 32 phoneme + 3 CVC AAC clips on disk
- [x] Pipeline runs end-to-end without errors
- [x] Review gate blocks Dart manifest regen (expected)
- [x] No auto-approve in reviewed.yaml
- [x] pubspec.yaml updated with new asset directory
- [x] check-asset-paths.sh passes
- [x] check-manifest-sync.sh passes (correctly skips with stub-baseline carve-out)

## Self-Check: PASSED

- manifest.yaml extended (35 new entries) ✓
- 32 phoneme AAC clips committed ✓
- 3 CVC word AAC clips committed ✓
- pubspec.yaml asset list extended ✓
- Pipeline ran successfully (100/100 normalized) ✓
- Review gate blocks Dart manifest regen (verified by `next_action` output) ✓
- All 100 reviewed.yaml entries remain unreviewed (`reviewed.yaml` empty) ✓

Commits in this plan:
- `1ebd449` fix(03): commit real Steinn AAC clips that Phase 3 baked but did not commit
- `e3cc94c` feat(06-01): extend manifest.yaml with 32 phonemes + 3 CVC starter words
