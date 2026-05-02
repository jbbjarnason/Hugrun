# Phase 9: Numeracy Activities (One-to-One, Subitizing, Addition) - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto`

<domain>
## Phase Boundary

Three numeracy activities in the Tölur room: one-to-one correspondence (tap-to-count), subitizing 1-5 (instant quantity recognition), and addition with objects (no `+` symbol — narrated additions). All extend Tölur's mode toggle pattern from Phase 8.

**Requirements covered (3):** NUM-04, 05, 07

</domain>

<decisions>
## Implementation Decisions

### One-to-one correspondence (NUM-04)

- **D-01:** `lib/features/tolur/correspondence/correspondence_activity.dart`. Round shows N pictured objects (N ∈ 1..5). Child taps each in sequence; voice counts ("einn... tveir... þrír..."). Last number narrated equals total.
- **D-02:** Picture-object counting uses GENDER of the depicted noun (Phase 8 helper `numberAudioKey(value, Gender)` handles this). Phase 9 uses pre-existing example-word images from Phase 4/5 (e.g. hundur is masculine, kýr is feminine).
- **D-03:** Round picks a noun from manifest, picks a count 1..5, generates that many copies of the noun's image, scrambled in the round area.
- **D-04:** Tap each object → voice counts in sequence. After all tapped, narrator says "[Count] [noun-plural]!" via `narrationCountResult` clip OR concatenates existing keys. Phase 9 ships using existing audio (no new manifest clips required).
- **D-05:** Wrong order = no penalty. Tap a previously-tapped object = no-op (object stays "counted").

### Subitizing (NUM-05)

- **D-06:** `lib/features/tolur/subitizing/subitizing_activity.dart`. Round flashes 1-5 dots in varied arrangements (dice pattern, line, random, finger pattern) for 1-3 seconds, then asks the child to tap the matching numeral from 5 options (1, 2, 3, 4, 5).
- **D-07:** Dot arrangements rotate to prevent visual memorization (research): dice (canonical for 1-6), line (left-to-right), random scatter, finger pattern (mimicking hand-counting).
- **D-08:** Flash duration: 1.5 seconds default (research range 1-3s). Tunable via const.
- **D-09:** No fail state. Wrong tap = no-op (consistent with Phase 5 matching). Correct tap = same celebration pattern as matching/CVC.

### Addition with objects (NUM-07)

- **D-10:** `lib/features/tolur/addition/addition_activity.dart`. Round narrates "Tveir hundar koma." Two dog images appear. Then "Einn hundur kemur til viðbótar." One more appears. Voice asks "Hversu margir hundar?" (How many dogs?) Child taps the answer numeral from 5 options.
- **D-11:** Sums limited to ≤5 in v1 (research). Pre-baked narration for ~5-10 common scenarios. Phase 9 ships placeholder narrations using existing manifest entries; new addition-specific narrations queued for next manifest pass.
- **D-12:** No `+` symbol shown. No equation. Just images and audio narration.
- **D-13:** Wrong tap = silent. Correct tap = celebration + auto-advance.

### Mode toggle expansion

- **D-14:** TolurMode enum extends from 2 modes (TapToHear / Sequence) to 5 (TapToHear / Sequence / Correspondence / Subitizing / Addition). 3-second hold cycles all 5.
- **D-15:** OR: simplify to a "shuffle mode" approach — Tölur has just 2 modes (TapToHear / Activity), and "Activity" rotates through Sequence → Correspondence → Subitizing → Addition randomly between rounds. **Pick this approach** — keeps the toggle simple for the kid; activity variety happens automatically.

### Test strategy

- **D-16:** Unit tests for round generators (correspondence, subitizing arrangement, addition scenario) — pure Dart.
- **D-17:** Widget tests for each activity — mocked AudioEngine, no fail state assertions.
- **D-18:** Integration test exercising the activity rotation in Tölur's "Activity" mode.

### Manifest extensions

- **D-19:** Phase 9 may need new narrations:
  - `narrationHowManyMasculine` ("Hversu margir [object]?")
  - `narrationHowManyFeminine` ("Hversu margar [object]?")
  - `narrationHowManyNeuter` ("Hversu mörg [object]?")
  - Number of object-specific narrations grows quickly. Pragmatic: ship Phase 9 using existing manifest entries (welcome, celebration) as a fallback, and queue full narration set as a polish pass.
- **D-20:** No bake pipeline required for Phase 9 if we use only existing clips.

### Claude's Discretion

- Exact dot arrangements + flash timing
- Activity rotation policy (random, weighted, etc.)
- Whether to ship full narration set or use fallbacks

</decisions>

<canonical_refs>
- `.planning/PROJECT.md`, `REQUIREMENTS.md` NUM-04, 05, 07
- `.planning/phases/08-tolur-tap-to-hear-sequencing/08-SUMMARY.md` — Tölur architecture, mode toggle
- `.planning/research/FEATURES.md` — subitizing pedagogy, dot arrangements
</canonical_refs>

<code_context>
- Reuses NumberTile (from Phase 8), AudioEngine, Phase 5 MatchingCelebration
- Reuses example-word images from Phase 4/5
- Pattern: lib/features/tolur/{correspondence,subitizing,addition}/ parallel to matching/cvc/

</code_context>

<deferred>
- Sums > 5 → v2
- Subtraction activity → v2 (PROJECT.md mentions PHOTOS-V2-01 type item)
- Object-specific narrations for all nouns × all numbers × all genders → polish pass via Phase 3 pipeline extension
</deferred>

---

*Phase: 9 — Numeracy Activities*
*Context gathered: 2026-05-02*
