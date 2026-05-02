# Phase 8: Tölur Tap-to-Hear & Sequencing - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto`

<domain>
## Phase Boundary

Tölur (numbers) room with digits 1–10 tap-to-hear (mirroring Stafir's tap mechanic), gendered audio variants for 1–4 (masculine/feminine/neuter; 5–10 has single form per Icelandic grammar), abstract counting uses masculine convention, plus a sequencing activity (drag numerals into order; find the missing number).

**Requirements covered (5):** NUM-01, 02, 03, 06, 08

</domain>

<decisions>
## Implementation Decisions

### Tölur room — basic structure

- **D-01:** `lib/features/tolur/tolur_room.dart` replaces Phase 1's placeholder. Layout: 10 number tiles (digits 1–10) in a row or 2-row grid. Reuse same tile pattern as `LetterTile` from Phase 4 — create `NumberTile` widget that's nearly identical.
- **D-02:** Tap any digit → AudioEngine plays numeral audio (masculine form for abstract counting per CONTEXT D-03 below). Same warm-pool, same synchronous visual feedback as Stafir.
- **D-03:** Abstract counting uses masculine form (NUM-03). Picture-object counting uses object's gender (Phase 9). Tap-to-hear in Tölur is abstract → masculine.

### Number audio model

- **D-04:** New `UtteranceKey` entries for numerals:
  - 1–4 with gender variants: `numberOneMasc, numberOneFem, numberOneNeut, numberTwoMasc, numberTwoFem, numberTwoNeut, numberThreeMasc, numberThreeFem, numberThreeNeut, numberFourMasc, numberFourFem, numberFourNeut` (12 keys for 1–4 × M/F/N)
  - 5–10 single form: `numberFive, numberSix, numberSeven, numberEight, numberNine, numberTen` (6 keys)
  - Total: 18 numeral keys
- **D-05:** Manifest entries with `kind: numeral_masculine`, `numeral_feminine`, `numeral_neuter`, `numeral_invariant`. Asset paths:
  - `assets/audio/numbers/masculine/{einn,tveir,thrir,fjorir}.aac`
  - `assets/audio/numbers/feminine/{ein,tvaer,thrjar,fjorar}.aac`
  - `assets/audio/numbers/neuter/{eitt,tvo,thrju,fjogur}.aac`
  - `assets/audio/numbers/{fimm,sex,sjo,atta,niu,tiu}.aac` (no gender folder for invariant 5+)
- **D-06:** Phase 8 extends `manifest.yaml` with these 18 entries. Bake pipeline runs to generate clips. Review pass is `human_needed` (consistent with Phase 3 protocol).

### Pure-Dart number model

- **D-07:** `lib/core/numbers/icelandic_number.dart`:
  ```
  class IcelandicNumber {
    final int value; // 1..10
    final UtteranceKey masculine; // null for 5+
    final UtteranceKey? feminine;
    final UtteranceKey? neuter;
    final UtteranceKey invariant; // == masculine for 1–4 abstract; the only key for 5+
  }
  const List<IcelandicNumber> kIcelandicNumbers = [...]; // 10 entries
  ```
- **D-08:** Helper: `UtteranceKey numberAudioKey(int value, Gender gender)` for picture-object counting (Phase 9). Phase 8 uses `numberAudioKey(value, Gender.masculine)` for abstract.

### Sequencing activity (NUM-06)

- **D-09:** `lib/features/tolur/sequencing/sequencing_activity.dart`. Reuses StafirRoom mode toggle pattern (extends Tölur with mode: TapToHear / Sequence).
- **D-10:** Round shows: 5 numerals in a row, ONE missing, others scrambled. Child drags numerals to fill gaps in order. Or: numerals shown out of order → drag to sort 1..5.
- **D-11:** Two variants of sequencing rounds:
  - **Sort:** all 5 numerals shown scrambled, drag to sort
  - **Fill missing:** 4 numerals shown in order with one gap, drag candidate numerals to fill
- **D-12:** Drag-and-drop via Flutter's `Draggable` + `DragTarget`. Soft acceptance: only accept correct numeral (gentle pushback for wrong numerals — animates back to source, no audio penalty).
- **D-13:** Round complete = celebration animation (reuses Phase 5's celebration component if convenient). Auto-advance to next round.
- **D-14:** No fail state. Wrong drops snap back. No score.

### Mode toggle

- **D-15:** Tölur's mode toggle: TapToHear / Sequence. 3-second hold to switch. Reuses pattern from Stafir (Phase 5's mode toggle).

### Test strategy

- **D-16:** Unit: IcelandicNumber model integrity, numberAudioKey resolver.
- **D-17:** Widget: TolurRoom renders 10 NumberTiles, taps fire correct keys (FakeAudioEngine), SequencingActivity drag-sort flow.
- **D-18:** Integration: Tölur full flow (tap-to-hear → mode toggle → sequencing → complete round).

### Manifest extension

- **D-19:** Phase 8 modifies `manifest.yaml` with 18 numeral entries. Run `bake_audio.py`. Review gate blocks final manifest regeneration until approved (consistent with Phase 3 / 6 protocol).

### Claude's Discretion

- Sequencing round count: 5 numerals (most common kid app pattern). Could be 3, 5, or 10 — pick 5.
- Drag-and-drop animation curves
- Visual style of drop targets

</decisions>

<canonical_refs>
- `.planning/PROJECT.md`, `REQUIREMENTS.md` NUM-01, 02, 03, 06, 08
- `.planning/ROADMAP.md` § Phase 8
- `.planning/phases/04-stafir-tap-to-hear-mvp/04-SUMMARY.md` — pattern to mirror for numbers
- `.planning/phases/05-letter-to-word-matching/05-SUMMARY.md` — mode toggle + activity widget pattern
- `.planning/phases/03-tts-pipeline-audio-review-tooling/03-SUMMARY.md` — manifest extension protocol
- `.planning/research/FEATURES.md` — number gender, subitizing, sequencing UX
- `.planning/research/SUMMARY.md` Finding 3 (no C/Q/W/Z; same applies — use right number forms)
</canonical_refs>

<code_context>
- Reuses LetterTile pattern → NumberTile (very similar; extract base if convenient)
- Reuses AudioEngine, ParentGateController, mode toggle pattern from Stafir
- `lib/features/tolur/` — currently a placeholder from Phase 1, fill with real code
- `lib/core/numbers/` — new pure-Dart folder
- `lib/core/alphabet/` is the parallel for letters

Integration:
- pubspec.yaml — no new deps
- manifest.yaml — extend
- assets/audio/numbers/ — new folder structure
- tools/check-domain-purity.sh — add lib/core/numbers/ to allow-list
</code_context>

<deferred>
- One-to-one correspondence (NUM-04) — Phase 9
- Subitizing 1–5 (NUM-05) — Phase 9
- Addition with objects (NUM-07) — Phase 9
- Numbers 11+ — out of v1 scope per PROJECT.md
</deferred>

---

*Phase: 8 — Tölur Tap-to-Hear & Sequencing*
*Context gathered: 2026-05-02*
