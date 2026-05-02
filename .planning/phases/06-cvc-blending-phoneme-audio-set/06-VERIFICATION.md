---
phase: 06
title: CVC Blending & Phoneme Audio Set — Verification
date: 2026-05-02
status: human_needed
---

# Phase 6 Verification

Phase 6 closes with `human_needed` status. The Phase 6 code is fully
shipped and tested; the phoneme + CVC AAC clips are baked, normalized,
and committed; but the **native-speaker review pass** for the new audio
has not yet been performed. Until it is, `lib/gen/audio_manifest.g.dart`
remains the Phase 2 stub and the new keys fall back silently per D-21.

## Verifications complete (no human action needed)

### Code quality

- [x] `flutter test`: 263 / 263 pass.
- [x] `flutter analyze`: 7 warnings (all `riverpod_lint`
  `scoped_providers_should_specify_dependencies` in test files — same
  family of 5 warnings already documented in Phase 5's verification).
- [x] `flutter build apk --debug`: succeeds.
- [x] `bash tools/check-domain-purity.sh`: passes (`lib/core/cvc` added
  to DOMAIN_PATHS, all files Flutter-free).
- [x] `bash tools/check-asset-paths.sh`: passes.
- [x] `bash tools/check-no-tracking.sh`: passes (no banned packages added).
- [x] `bash tools/check-manifest-sync.sh`: passes (correctly skips with
  the stub-baseline carve-out — Phase 2 stub vs. extended-stub state).

### Pipeline

- [x] `python3 tools/tts/bake_audio.py`: 100 / 100 utterances normalized
  successfully.
- [x] Pipeline review gate (D-18) blocks `lib/gen/audio_manifest.g.dart`
  regeneration — exactly the planned end state.
- [x] No auto-approval in `reviewed.yaml`.

### Architectural commitments

- [x] `lib/core/cvc/` is pure Dart (no `package:flutter` imports).
- [x] CvcActivity reuses LetterTile (Phase 4) — verified by `find.byType
  (LetterTile).evaluate().length == 3` in tests.
- [x] CvcActivity reuses AudioEngine via `audioEngineProvider` override.
- [x] StafirRoom mode toggle (3s hold) extended cleanly to 3 modes — no
  duplicate hold-gate logic.
- [x] No fail-state UI: `expect(find.byIcon(Icons.error), findsNothing)`
  + zero progress indicators (C10).
- [x] No instruction text: `expect(asciiTextFound, isEmpty)` (C11).
- [x] Soft order tolerance: c2-first tap path tested (C5).
- [x] Replay on re-tap: phoneme replays, blend does NOT re-fire (C7, C9).

### Integration test

- [x] `integration_test/stafir_cvc_flow_test.dart` compiles clean
  (`flutter analyze`: 0 issues on the file). Walks the full child flow:
  letters → match → cvc, tap c2 → c1 → v out-of-order, blend fires,
  auto-advance resets state.
- [ ] Integration test EXECUTED on a real device. (Same posture as
  Phase 5's `stafir_matching_flow_test.dart` — device required to run;
  not blocked by this build.)

## Verifications pending human action

### Phoneme + new CVC clip review pass (CVC-02)

**Required for**: shipping CVC-02 (32 phoneme audio set) and the runtime
audibility of the CVC blending activity.

**How**:
1. Run the review server:
   ```bash
   python3 tools/tts/review_server.py --port 8765
   ```
2. Open `http://127.0.0.1:8765/` in a browser. Headphones, quiet room.
3. Listen to all 100 clips. Pay particular attention to the 32 phoneme
   clips: they should sound like the SOUND, not the LETTER NAME.
4. For phonemes that come out as the letter NAME (likely many consonants
   under raw-glyph input), edit `pronunciation_overrides.yaml`:
   ```yaml
   overrides:
     phonemeT:
       phonemes: "[[t]]"   # eSpeak phoneme markup
     phonemeK:
       phonemes: "[[kh]]"
   ```
   and re-run `python3 tools/tts/bake_audio.py` (only changed clips
   re-bake — idempotent cache).
5. Iterate until every clip is approved.
6. Once `reviewed.yaml` is fully populated with `reviewed: true` entries,
   `bake_audio.py` writes the regenerated
   `lib/gen/audio_manifest.g.dart` (100-entry compile-time map) and
   regenerates `lib/core/manifest/utterance_key.dart`.
7. Hand-merge: Phase 6's enum extension (40 added entries) was added by
   hand to the stub `utterance_key.dart`. The pipeline regen will produce
   a superset; verify with `git diff` that no enum identifiers were lost
   then commit.
8. Commit the regenerated Dart files + ship.

**Estimated time**: 1–2 hours of focused listening + 30 min of override
iteration (best case; could be longer if Steinn produces unusable
consonant sounds).

### Phase 3 review pass (carryover)

The 65 re-baked Phase 3 letter-name and example-word clips ALSO need
approval. Same review server, same workflow. Already on the books from
Phase 3's `human_needed` SUMMARY — Phase 6 doesn't add work here, just
notes that both passes will likely happen in one session.

## Quality gate (consolidated)

| Item | Status |
|------|--------|
| manifest.yaml extended (32 phoneme + 3 CVC) | ✓ |
| `bake_audio.py` ran end-to-end, review gate blocks | ✓ |
| Pure-Dart core (`lib/core/cvc/`) | ✓ |
| CvcActivity widget — 3 tiles, blend after 3 taps, soft order | ✓ |
| StafirMode 3-mode cycle | ✓ |
| Integration test compile-clean | ✓ |
| `flutter analyze` modulo 7 documented warnings | ✓ |
| `flutter test` 263 / 263 | ✓ |
| `flutter build apk --debug` | ✓ |
| `tools/check-domain-purity.sh` updated + passing | ✓ |
| Atomic per-task commits | ✓ |
| Plan + master + verification SUMMARYs written | ✓ |
| **CVC-02: phoneme audio set reviewed** | **PENDING (human action)** |
| Phase 3 review pass (carryover) | PENDING (human action) |

## Recommended next phase

**Phase 7 (Letter Tracing)** can begin in parallel with the audio review
pass. Tracing is purely a visual / gesture-based activity (CustomPainter,
no audio dependency), so the Phase 6 silent-fallback state does not block
Phase 7. The audio review pass can happen async whenever Jon has a quiet
room and an hour or two.
