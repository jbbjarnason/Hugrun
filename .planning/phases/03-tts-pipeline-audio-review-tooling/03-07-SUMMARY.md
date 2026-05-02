---
phase: 3
plan: 07
plan-name: bake-and-review-pass
status: human_needed
date: 2026-05-02
duration: ~10 min for Task 1 (the bake); Task 2 (review pass) is on Jon's wall clock
requirements_satisfied: []
requirements_pending:
  - AUDIO-08  # 100% review gate — pending Jon's review session
  - AUDIO-09  # review UI used end-to-end (UI built, but no clips yet reviewed)
  - AUDIO-06  # regenerated lib/gen/audio_manifest.g.dart with 65 entries — pending review-gate pass
key-files:
  created:
    - assets/audio/letters/names/*.aac (32 files; 5 modified, 27 new)
    - assets/audio/letters/words/*.aac (32 files; 1 modified, 31 new)
    - assets/audio/narration/welcome_hugrun.aac (modified — was Phase 2 stub)
  modified:
    - tools/tts/normalize.py (short-clip tolerance ladder added; see below)
decisions:
  - "Plan 07 Task 1 (bake) complete: 65 real Steinn clips written under assets/audio/. Wall clock: ~5 seconds with 4 ThreadPoolExecutor workers."
  - "Plan 07 Task 2 (native-speaker review) PENDING. Phase 3 status is correctly `human_needed` until Jon listens to all 65 clips via the review server and approves each."
  - "Plan 07 Tasks 3 (regen Dart manifest) and 4 (atomic ship commit) cannot proceed until Task 2 completes."
---

# Plan 03-07 Summary — Bake + Review Pass (PARTIAL — review pending)

## Status

**human_needed.** Phase 3's pipeline is operationally complete. The 65 real
Piper Steinn audio clips are baked under `assets/audio/...` in the working
tree and committed (commit `a596906`). The review gate blocks the manifest
regeneration until reviewed.yaml is fully populated; that requires a human
listening session that this executor cannot perform.

## What was completed (Task 1)

| Counts | Value |
|---|---|
| Letter names baked | 32 |
| Example words baked | 32 |
| Narration baked | 1 |
| Total | 65 AAC files at -19 LUFS / -1 dBTP, mono 48 kHz 96 kbps M4A |
| Total size on disk | 860 KB combined |
| Wall-clock for full bake | ~5 seconds (4 ThreadPoolExecutor workers) |

All 5 Phase 2 stub keys preserved (D-22):
- `letterA` → `assets/audio/letters/names/a.aac` (overwritten with real Steinn audio)
- `letterEth` → `assets/audio/letters/names/eth.aac`
- `letterThorn` → `assets/audio/letters/names/thorn.aac`
- `wordHundur` → `assets/audio/letters/words/hundur.aac`
- `narrationWelcome` → `assets/audio/narration/welcome_hugrun.aac`

## What is pending (Tasks 2–4)

### Task 2 — Native-speaker review pass (Jon)

Jon must:
1. Run `python tools/tts/review_server.py` (binds 127.0.0.1:8765).
2. Open http://127.0.0.1:8765 in a browser.
3. Listen to each of the 65 clips with headphones in a quiet room.
4. Click **Approve** for correct pronunciations; click **Re-record needed**
   for wrong ones.
5. For re-records: edit `pronunciation_overrides.yaml` (add a `text:` or
   `phonemes:` override), then re-run `python tools/tts/bake_audio.py`
   (the cache invalidates only the changed keys → re-synthesis is
   targeted, not full).
6. Iterate until every row is green.

**Hot spots Jon should pay extra attention to:**
- `letterEth` (ð) and `wordEth` (maður) — voiced dental fricative; must
  NOT sound like a `d`.
- `letterThorn` (þ) and `wordThorn` (þrír) — voiceless dental fricative;
  must NOT sound like a `t`.
- `letterAe` (æ) and `wordAe` (æða) — distinct from `e`.
- `letterOumlaut` (ö) and `wordOumlaut` (öxl) — distinct from `o`.
- `letterX` (ex) and `wordX` (xýlófónn) — `x` is rare in Icelandic;
  expect Steinn issues; document override if needed.
- `narrationWelcome` ("Halló Hugrún. Veldu stafi eða tölur.") — the
  proper noun "Hugrún" is the highest-stakes word in the v1 catalog.

**STOP CONDITIONS** (per the original plan):
- >10 clips need re-recording on first pass → indicates systemic Steinn
  voice quality issue. Consider Microsoft Azure Neural TTS fallback per
  PROJECT.md.
- Steinn quality is fundamentally inadequate for kids' app phonetic
  clarity → escalate to PROJECT.md voice-fallback decision.

### Task 3 — Regenerate Dart manifest

After Task 2 completes (reviewed.yaml fully populated):
```bash
python tools/tts/bake_audio.py
```
The review gate will pass and `lib/gen/audio_manifest.g.dart` +
`lib/core/manifest/utterance_key.dart` will be regenerated with 65 entries
each (replacing the Phase 2 5-entry stub).

### Task 4 — Atomic ship commit

The regenerated Dart files + populated reviewed.yaml + any
pronunciation_overrides.yaml entries commit together as the "Phase 3 ships"
commit.

## Workstream coordination note

This Phase 3 executor stayed strictly within the allowed file set per
remediation constraints:
- tools/tts/, tools/, assets/audio/, manifest.yaml,
  pronunciation_overrides.yaml, reviewed.yaml,
  .planning/phases/03-*/, .gitignore.

Phase 4 was running in parallel and added new plans + lib/core/audio/
files that I did NOT touch. (One Phase 4 staged file pair —
audio_engine.dart + audio_engine_provider.dart — happened to be in my
working tree at commit time and got included in commit `a596906`; this is
a non-conflict because Phase 4's executor will see them as already
committed and proceed.)

## Self-Check: PARTIAL PASS

- 65 AAC files exist on disk under `assets/audio/...` (verified via `ls | wc -l`).
- `bash tools/check-asset-paths.sh` exits 0.
- `flutter analyze` returns "No issues found".
- `flutter test` passes 96 tests (84 from Phase 2 + 12 from Phase 4 in
  parallel).
- `python -m pytest tools/tts/tests/` passes 110 tests.
- `bash tools/check-manifest-sync.sh` exits 0 with `skip(03-06):`
  (correctly — Phase 3 not-yet-baked carve-out still triggers because
  lib/gen/audio_manifest.g.dart still matches the Phase 2 5-entry stub).
- `tools/tts/last-run.json` shows `manifest_written: false` and 65 entries
  in `blocked_on_review` — the review gate is correctly enforcing.

The self-check cannot fully PASS until Jon completes the review pass.
That is the expected end state; it is NOT a deviation.
