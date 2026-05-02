# Phase 5: Letter-to-Word Matching - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto`

<domain>
## Phase Boundary

A letter-to-word matching activity in the Stafir room: image of an object appears, child taps the correct starting letter from 4 options. Wrong taps are silent no-ops. Correct taps celebrate with animation + audio. Activity is wired to consume personalized photos at ~40% frequency once Phase 10 lands.

**Requirements covered (4):** MATCH-01..04

</domain>

<decisions>
## Implementation Decisions

### Activity entry point

- **D-01:** Stafir room gets a second mode toggle. Phase 4's grid is "Letters" mode (default). New "Match" mode shows the matching activity. Toggle is an icon-only button at top-right of Stafir, hold-to-engage like the parent gate (3s hold to switch — keeps kid in current mode if accidentally pressed).
- **D-02:** Matching activity is a standalone screen `lib/features/stafir/matching/matching_activity.dart`. Renders one round at a time. Round = one image + 4 letter options.

### Round logic

- **D-03:** A round picks a random word from the manifest's example-word set (e.g. `wordHundur` → image `hundur.webp` → starts with `h`). The 4 letter options include the correct letter + 3 distractor letters chosen from `kIcelandicAlphabet` (random, distinct, exclude the correct one).
- **D-04:** Distractor letters avoid visually-similar pairs (e.g. don't pair `o` with `ó` if the correct is one of them — too easy to mis-tap; surface intent rather than test). Generator function with a small "exclude similar" rule.
- **D-05:** Round generator is `lib/features/stafir/matching/round_generator.dart`. Pure Dart, no Flutter imports. Returns `MatchingRound { Word target, List<IcelandicLetter> options, IcelandicLetter correctOption }`.
- **D-06:** Round count: infinite. After every round (correct OR explicit "next" via celebration), generate a new round. No round counter visible.

### Tap handling

- **D-07:** Wrong tap (D-04 in PROJECT.md / MATCH-02): completely silent. Tile DOES NOT shake, change color, or play sad sound. The tile briefly highlights on `onTapDown` (consistent with Phase 4 LetterTile feedback) and returns to neutral. NO audio plays. NO failure cue.
- **D-08:** Correct tap (MATCH-03): celebration animation (large checkmark + scale-up of selected tile + soft sparkle/burst — keep tasteful, not "stars and points") + audio cue. Audio cue = a short joyful narration ("Já! Þetta er h fyrir hundur!") OR a non-verbal positive sound. Use existing or new manifest entries:
  - `narrationCelebrationCorrect` (generic "Já! Vel gert!") — Phase 5 ships placeholder; Phase 3 can generate the real clip when manifest extended
  - The example word audio (already in manifest) — `wordHundur`, etc.
- **D-09:** After correct tap + celebration (~1.5s total), auto-advance to next round.

### No fail state, no scoring

- **D-10:** No round count visible. No score. No streak. No "n correct in a row." No timer.
- **D-11:** Wrong tap consequence = nothing changes. The child tries again (or doesn't — totally fine).

### Image source

- **D-12:** Phase 5 ships placeholder text-on-color images for the example words (consistent with Phase 4 stafir_room.dart's example word overlay). Real custom images come in a polish pass or via Phase 10 personalization.
- **D-13:** Photo support hook (MATCH-04): the round generator has a slot to query "is there a personalized photo for this tag?" When Phase 10 ships PHOTO-* features, photos override default placeholders for ~40% of rounds. Phase 5 implements the hook (an empty list of photo overrides + a `40%` Bernoulli switch); Phase 10 fills it.

### Layout & A11y

- **D-14:** Round layout: image fills upper 60% of screen (centered, 80% width). Below: 4 letter tiles in a row, each ≥2cm × 2cm. Same `LetterTile` widget from Phase 4 — reuses the locked palette, locked tap-target, locked animation behavior.
- **D-15:** Reuse `LetterTile` from Phase 4 directly. Don't duplicate.

### Test strategy

- **D-16:** Unit: round generator produces correct option always in the options list, distractors are distinct, similar-letter exclusion works. Pure Dart, easy to test exhaustively.
- **D-17:** Widget: MatchingActivity renders 1 image + 4 LetterTiles. Wrong tap → no audio fired (use FakeAudioEngine). Correct tap → celebration triggers + auto-advance.
- **D-18:** Integration: round flow over 3 rounds (tap wrong, tap correct, advance, tap correct, advance). Verify no exceptions, no audio overlap.

### Manifest dependency

- **D-19:** Phase 5 references existing manifest entries (mostly Phase 2 stub). When Phase 3's review pass completes and the manifest extends, more example words activate automatically (round generator iterates `kAudioManifest` keys). No hardcoded word list.
- **D-20:** Phase 5 needs ONE new manifest key: `narrationCelebrationCorrect`. Add to `manifest.yaml` as a manifest extension (Phase 3 owns the file but Phase 5 can append a single entry, then re-run pipeline OR ship Phase 5 with a placeholder fallback that plays the example-word audio as celebration + skip the dedicated celebration narration entirely).
- **D-21:** Pragmatic choice: Phase 5 SHIPS WITHOUT a celebration narration clip — uses the existing `wordHundur` (or other example word) as the celebration cue. Phase 3 can add `narrationCelebrationCorrect` later as a polish.

### Claude's Discretion

- Exact celebration animation curve / sparkle style — keep it tasteful, no "stars" or "rewards" iconography
- Distractor letter exclusion rule — Claude picks a sensible set
- Auto-advance timing (1.5s default; tunable)
- Round generator seed for tests (deterministic seed in tests; random in prod)

</decisions>

<canonical_refs>
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md` MATCH-01..04
- `.planning/ROADMAP.md` § Phase 5
- `.planning/phases/04-stafir-tap-to-hear-mvp/04-SUMMARY.md` — what's available to reuse (LetterTile, AudioEngine)
- `.planning/research/FEATURES.md` — matching activity research
- `.planning/research/SUMMARY.md` finding 6 (failure feedback grammar)
</canonical_refs>

<code_context>
- LetterTile widget from Phase 4 (lib/features/stafir/widgets/letter_tile.dart) — reuse directly
- AudioEngine from Phase 4 (lib/core/audio/audio_engine.dart) — reuse directly
- StafirRoom from Phase 4 — Phase 5 adds a mode toggle to it
- kIcelandicAlphabet from Phase 2 — letter pool for distractors
- audio_manifest.g.dart from Phase 3 — example word clips used in rounds

Integration:
- `lib/features/stafir/matching/` — new folder
- `lib/features/stafir/stafir_room.dart` — add mode toggle
- `pubspec.yaml` — no new deps expected
</code_context>

<specifics>
- "Tasteful celebration" — animation should feel intrinsic-rewarding, not gamified. No stars, no points, no sparkle storm.
- Correct example: a soft scale-up + checkmark fade-in + the example word audio replay. Done in 1.5 seconds.
- Wrong example: pure no-op + LetterTile's normal onTapDown animation only.
</specifics>

<deferred>
- Real custom imagery for example words → Phase 4 polish or Phase 10 personalization
- `narrationCelebrationCorrect` clip → Phase 3 manifest extension when convenient
- Photo override hook implementation → Phase 10 fills the slot
- Configurable difficulty (3 vs 4 vs 5 options) → not in v1; 4 is the magic number
</deferred>

---

*Phase: 5 — Letter-to-Word Matching*
*Context gathered: 2026-05-02*
