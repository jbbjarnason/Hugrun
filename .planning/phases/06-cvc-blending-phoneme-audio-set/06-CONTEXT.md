# Phase 6: CVC Blending & Phoneme Audio Set - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto`

<domain>
## Phase Boundary

A CVC (consonant-vowel-consonant) blending activity covering ≥8 starter words: kýr, sól, hús, rós, bók, mús, hár, gás. Separate phoneme audio set for all 32 letters (distinct from letter-name set used in tap-to-hear). Child taps each letter in order → hears each letter's phoneme → narrator blends the full word.

**Requirements covered (3):** CVC-01..03

</domain>

<decisions>
## Implementation Decisions

### Phoneme audio set (extends manifest.yaml)

- **D-01:** New `UtteranceKey` enum entries for phonemes — naming pattern `phonemeA, phonemeAcute, phonemeB, ..., phonemeOumlaut` (32 keys). Asset paths: `assets/audio/letters/phonemes/{slug}.aac`. Manifest type: `kind: phoneme`.
- **D-02:** Phoneme text in manifest.yaml uses Piper phoneme markup (eSpeak SAMPA-style) for authenticity:
  - For consonants: `/h/`, `/k/`, `/m/` (the unvoiced phoneme)
  - For vowels: short pure-vowel `/a/`, `/i/`, `/u/`
  - For diacritic vowels: `/a:/` (long), `/au/` (diphthong) — verify with reviewer
- **D-03:** Phoneme manifest entries committed to manifest.yaml as Phase 6 plan task. Bake pipeline runs to generate AAC clips. **Review pass for new phoneme clips** is `human_needed` (same as Phase 3 review gate).
- **D-04:** All 32 phonemes baked. Phase 6 ships `wordKýr, wordSól, wordHús, wordRós, wordBók, wordMús, wordHár, wordGás` if not already in manifest from Phase 3 (some may be — Phase 3 baked 32 example words).

### CVC word data model

- **D-05:** `lib/core/cvc/cvc_word.dart` — `CvcWord { String word, IcelandicLetter c1, IcelandicLetter v, IcelandicLetter c2, UtteranceKey wordClip }`. Pure Dart (lib/core).
- **D-06:** `lib/core/cvc/cvc_words.dart` — const list of 8+ CVC words. Each ships with c1/v/c2 broken down to phoneme keys.
- **D-07:** Phoneme key resolution: `IcelandicLetter.assetSlug → UtteranceKey.phoneme${PascalCase(slug)}`. A small helper enum-lookup function.

### CVC Activity widget

- **D-08:** `lib/features/stafir/cvc/cvc_activity.dart`. Reuses StafirRoom mode toggle pattern from Phase 5 — Stafir room now has 3 modes: Letters / Match / CVC.
- **D-09:** Round shows the word's image at top. Below: 3 LetterTiles in a row representing c1, v, c2. Each tile starts neutral (no audio).
- **D-10:** Tap order: child taps c1 → AudioEngine plays `phoneme_c1`. Tap v → plays `phoneme_v`. Tap c2 → plays `phoneme_c2`. After all 3 are tapped, narrator plays `wordClip` (the full blended word).
- **D-11:** Order does NOT need to be left-to-right — child can tap any letter first. After all 3 are tapped (regardless of order), the blend plays. Soft enforcement only; the activity celebrates ANY completion.
- **D-12:** Already-tapped letters show a soft visual cue (subtle highlight) so the child can see what's done. Untapped letters are normal.
- **D-13:** After blend plays, ~2s pause, then auto-advance to next CVC round.
- **D-14:** Wrong order = no penalty. Tapping a tile twice = replay its phoneme.

### Mode toggle expansion

- **D-15:** Phase 5's mode toggle expands from 2 modes (Letters/Match) to 3 (Letters/Match/CVC). Use a cycle: hold to advance through modes Letters → Match → CVC → Letters.
- **D-16:** Each mode change requires 3-second hold. Kid-mode safe.

### Test strategy

- **D-17:** Unit: CVC word data model integrity (each word's phoneme keys exist in manifest), phoneme key resolver function.
- **D-18:** Widget: CvcActivity renders 3 LetterTiles + image, taps fire correct phoneme keys, blend plays after 3 taps.
- **D-19:** Integration: full CVC flow over 2 rounds.

### Manifest extension protocol

- **D-20:** Phase 6 modifies manifest.yaml. Pipeline must be re-run to bake new phoneme clips. Per Phase 3 architecture, this is `python tools/tts/bake_audio.py`. Phoneme review pass IS REQUIRED — pipeline blocks until reviewer approves all new entries via the review server.
- **D-21:** Until phoneme clips are reviewed, CvcActivity gracefully falls back: missing-clip path plays nothing (consistent with Phase 4's `kAudioManifest[key] == null` handling). Activity is functional structurally but silent for unreviewed clips.

### Claude's Discretion

- Exact CVC word selection beyond the 8 listed (research suggests these from Icelandic primary curriculum)
- Visual tap-order cue style (subtle highlight, not bright outline)
- Auto-advance timing

</decisions>

<canonical_refs>
- `.planning/PROJECT.md`, `REQUIREMENTS.md` CVC-01..03, ROADMAP § Phase 6
- `.planning/phases/03-tts-pipeline-audio-review-tooling/03-SUMMARY.md` — pipeline + manifest extension protocol
- `.planning/phases/05-letter-to-word-matching/05-SUMMARY.md` — mode toggle pattern to extend
- `.planning/research/FEATURES.md` — CVC blending research, Icelandic curriculum word lists
</canonical_refs>

<code_context>
- Reuses LetterTile, AudioEngine, ParentGateController from Phases 1/4
- Reuses Stafir mode toggle from Phase 5 — extends 2→3 modes
- Pattern: `lib/features/stafir/cvc/` parallel to `lib/features/stafir/matching/`
- manifest.yaml extension: same protocol as Phase 3
</code_context>

<deferred>
- Multi-syllable blending — out of v1 scope
- Visual phoneme symbols (IPA) on tiles — out of scope, kid sees only the letter glyph
- Reading direction enforcement — soft order only
</deferred>

---

*Phase: 6 — CVC Blending & Phoneme Audio Set*
*Context gathered: 2026-05-02*
