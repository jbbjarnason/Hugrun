---
phase: 08
status: human_needed
date: 2026-05-02
---

# Phase 8 Verification

## Status: `human_needed`

The 18 new numeral AAC clips need a native-Icelandic-speaker review pass
before they can be wired into `kAudioManifest` and played back to
Hugrún.

## What's blocking

`reviewed.yaml` has no entries for the 18 keys:

- `numberOneMasc`, `numberTwoMasc`, `numberThreeMasc`, `numberFourMasc`
- `numberOneFem`, `numberTwoFem`, `numberThreeFem`, `numberFourFem`
- `numberOneNeut`, `numberTwoNeut`, `numberThreeNeut`, `numberFourNeut`
- `numberFive`, `numberSix`, `numberSeven`, `numberEight`,
  `numberNine`, `numberTen`

Until they are reviewed, `tools/tts/bake_audio.py` blocks Dart manifest
emission (the D-19 review gate, same posture as Phase 3 and Phase 6).

## What's not blocking

All Phase 8 code is **functionally and structurally complete**:

- 348 tests pass (`flutter test`).
- `flutter analyze` clean (modulo known riverpod_lint warnings on test
  files, same family Phase 5/6/7 documented).
- `flutter build apk --debug` succeeds.
- `tools/check-domain-purity.sh`, `tools/check-asset-paths.sh`, and
  `tools/check-no-tracking.sh` all pass.
- Tap-to-hear surface dispatches `numberAudioKey(value, masculine)`
  to AudioEngine for digits 1..10. The play call hits the
  silent-fallback path (Phase 4 D-22, D-23) until the manifest
  regenerates.
- Sequencing activity renders correctly + accepts correct drops +
  rejects wrong drops silently + celebrates on completion +
  auto-advances.
- TolurMode toggle swaps body between TapToHear and Sequence on a
  3-second hold.
- Integration test (`integration_test/tolur_flow_test.dart`) is
  compile-clean and exercises the full flow.

## How to unblock

1. Run the audio review server:
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   python3 tools/tts/review_server.py
   ```
2. Open the local web URL printed by the server.
3. Listen to each of the 18 numeral clips. For each one approve / reject.
   - Approve when the clip clearly says the right Icelandic numeral
     (e.g. `numberOneMasc` should be /ɛitn/ "einn", not the digit
     name "one" or the feminine "ein").
   - Reject if Steinn produced the wrong word, mispronounced the
     diphthong, or the loudness feels off.
4. After all 18 are approved, re-run the bake:
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   python3 tools/tts/bake_audio.py
   ```
5. Confirm `lib/gen/audio_manifest.g.dart` now contains entries for the
   18 numeral keys.
6. Run `flutter test` to confirm.
7. Run on a tablet and tap each digit — verify audio plays at perceived
   tap latency (NUM-01 mirrors STAFIR-02; same warm-pool path).

## Hot spots for the reviewer

| Key | Text | Notes |
|-----|------|-------|
| `numberOneMasc` | einn | Silent-N pronunciation; should NOT sound like "ein" |
| `numberTwoFem` | tvær | /tvai̯r/ — diphthong distinct from masculine "tveir" /tvei̯r/ |
| `numberThreeNeut` | þrjú | Voiceless dental fricative þ; review carefully |
| `numberFourMasc` | fjórir | "fjórir" not "fjórar" (fem) |
| `numberSeven` | sjö | /sjœ/ — vowel quality matters |
| `numberEight` | átta | /au̯hta/ — preaspiration is distinctive |

## Phase 8 close criteria

- [x] All 4 plans executed with TDD RED/GREEN cycles
- [x] 348 tests passing
- [x] `flutter analyze` clean (modulo documented warnings)
- [x] `flutter build apk --debug` succeeds
- [x] Domain purity, asset paths, no-tracking guards all green
- [x] No edits to Phase 7 territory
- [x] Atomic commits per RED/GREEN cycle
- [ ] **NUM-02 review** (this document — pending)

When the reviewer pass completes and the manifest regenerates, NUM-02
ships and the Tölur room becomes audibly functional alongside the
already-functional Stafir room.
