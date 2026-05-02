---
phase: 08
plan: 08-01
title: Number Audio Model + Manifest Extension
status: complete
date: 2026-05-02
tags: [phase-8, numbers, manifest, tdd]
metrics:
  tests-added: 15
  utterancekey-entries-added: 18
  manifest-utterances: 100 → 118 (+18)
  baked-aac-clips: 18 new (review pending)
---

# Phase 8 Plan 01: Number Audio Model + Manifest Extension

Pure-Dart number domain (`lib/core/numbers/`) with `IcelandicNumber`,
`kIcelandicNumbers`, `numberAudioKey`, plus 18 new `UtteranceKey` entries
and 18 numeral utterances baked through the Phase 3 pipeline.

## Workstream

A from `08-CONTEXT.md`.

## TDD cycle

| Cycle | Subject | Commit |
|-------|---------|--------|
| RED   | IcelandicNumber + kIcelandicNumbers + numberAudioKey | `49a8b15` |
| GREEN | Pure-Dart implementation + enum extension + domain-purity allow | `c50dab8` (approx — see git log) |
| GREEN | manifest.yaml + bake (review-pending) | second feat(08-01) |

(Hashes drift; consult `git log --oneline` for exact values.)

## What was built

### `lib/core/numbers/`
- `gender.dart` — pure-Dart `Gender` enum (masculine/feminine/neuter).
- `icelandic_number.dart` — `IcelandicNumber` value class. Holds value
  (1..10), masculine/feminine/neuter (nullable), invariant.
- `numbers.dart` — const `kIcelandicNumbers` list (10 entries). 1..4 ship
  full M/F/N + invariant=masculine; 5..10 ship `invariant` only (M/F/N
  null per NUM-02).
- `number_audio_resolver.dart` — `numberAudioKey(value, gender)` →
  `UtteranceKey`. Throws RangeError on value outside 1..10.

### `lib/core/manifest/utterance_key.dart`
- 18 new entries: `numberOne{Masc,Fem,Neut}` … `numberFour{Masc,Fem,Neut}`,
  `numberFive`..`numberTen`. The 4 masculine variants double as the
  invariant for 1..4 abstract counting (NUM-03); 5..10 has no gender
  variants (NUM-02).

### `manifest.yaml`
- 100 → 118 utterances. New `kind`s: `numeral_masculine`,
  `numeral_feminine`, `numeral_neuter`, `numeral_invariant`. Asset paths:
  - `assets/audio/numbers/masculine/{einn,tveir,thrir,fjorir}.aac`
  - `assets/audio/numbers/feminine/{ein,tvaer,thrjar,fjorar}.aac`
  - `assets/audio/numbers/neuter/{eitt,tvo,thrju,fjogur}.aac`
  - `assets/audio/numbers/{fimm,sex,sjo,atta,niu,tiu}.aac`

### `tools/tts/schema.py`
- `ALLOWED_KINDS` extended with `numeral_invariant` (the 3 gendered kinds
  were already allowed from an earlier extension; only the invariant was
  missing).

### `tools/check-domain-purity.sh`
- Allow-list extended with `lib/core/numbers`.

### `assets/audio/numbers/`
- 18 baked AAC clips, normalized at -19 LUFS via Piper + ffmpeg-normalize
  through the existing Phase 3 pipeline.

## Tests

15 new pure-Dart tests in `test/core/numbers/icelandic_number_test.dart`:

- N1..N3: model invariants.
- K1..K7: `kIcelandicNumbers` integrity (10 entries, 1..4 gendered, 5..10
  invariant-only, key uniqueness).
- R1..R5: resolver correctness for masculine/feminine/neuter on 1..4
  and invariant on 5..10; RangeError on out-of-range.

`flutter test test/core/numbers/icelandic_number_test.dart` → all 15 pass.

## Pipeline review-gate posture

`bake_audio.py` ran end-to-end:
- 118/118 utterances synthesized via Piper (Steinn voice).
- 118/118 normalized.
- `manifest_written: False` — review gate (D-19) blocks Dart manifest
  emission until `reviewed.yaml` is filled in via
  `python3 tools/tts/review_server.py`.

The 18 new keys are intentionally absent from `kAudioManifest` until the
review pass completes. `AudioEngine.play()` falls back silently per
Phase 4 D-22/D-23. Audio plays once Jon completes review.

## Deviations from plan

1. **Inline schema extension** (Rule 3 — blocking): the plan said the
   3 gendered numeral kinds were already in `ALLOWED_KINDS`, which was
   true; but the new `numeral_invariant` kind for 5..10 was NOT in the
   schema. Added it before bake. Single-line diff to `schema.py`.

2. **Pipx-installed tools needed PATH adjustment** (Rule 3 — blocking):
   `piper` and `ffmpeg-normalize` are installed via pipx into
   `~/.local/bin/` which is not on the Claude shell's default PATH.
   Worked around by `export PATH="$HOME/.local/bin:$PATH"` for the bake
   call. Documented for future bake runs.

3. **Phase 7 file leakage in commit** (caught + remediated): the first
   `feat(08-01)` commit accidentally included
   `test/core/tracing/glyph_loader_test.dart` (Phase 7's territory).
   Soft-reset the commit, staged files individually by name, recommitted
   without the Phase 7 file. Future Phase 8 commits explicitly stage
   files individually rather than glob-staging.

## Self-Check: PASSED

- [x] `lib/core/numbers/{gender,icelandic_number,numbers,number_audio_resolver}.dart` exist
- [x] 18 new `UtteranceKey` entries present
- [x] `manifest.yaml` has 118 entries; schema validates
- [x] 18 AAC clips on disk (total = 11 in assets/audio/numbers/* including
      empty .gitkeep markers)
- [x] `tools/check-domain-purity.sh` passes
- [x] Test suite: 263 → 278 (+15 new in this plan)
