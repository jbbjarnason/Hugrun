---
phase: 06
plan: 06-02
title: CVC core data model + activity widget
subsystem: stafir-cvc
status: complete
date: 2026-05-02
tags: [phase-6, cvc, flutter, widget, riverpod, tdd, pure-dart]
requires:
  - phase-3 manifest contract (UtteranceKey + AudioAsset)
  - phase-4 LetterTile + AudioEngine
  - phase-6 plan 01 manifest.yaml extension
provides:
  - CvcWord value class (lib/core/cvc/cvc_word.dart)
  - kCvcWords const list (lib/core/cvc/cvc_words.dart) — 8 starter words
  - phonemeKeyForSlug resolver (lib/core/cvc/phoneme_resolver.dart)
  - CvcActivity widget (lib/features/stafir/cvc/cvc_activity.dart)
  - cvcWordPoolProvider + cvcCurrentWordProvider Riverpod bindings
  - 35 new UtteranceKey enum entries (32 phoneme + 5 reused word + 3 new word)
key-files:
  created:
    - lib/core/cvc/cvc_word.dart (78 lines)
    - lib/core/cvc/cvc_words.dart (89 lines)
    - lib/core/cvc/phoneme_resolver.dart (105 lines)
    - lib/features/stafir/cvc/cvc_activity.dart (172 lines)
    - lib/features/stafir/cvc/cvc_providers.dart (39 lines)
    - test/core/cvc/cvc_word_test.dart (87 lines, 5 tests)
    - test/core/cvc/cvc_words_test.dart (62 lines, 7 tests)
    - test/core/cvc/phoneme_resolver_test.dart (66 lines, 10 tests)
    - test/features/stafir/cvc/cvc_activity_test.dart (220 lines, 12 tests)
  modified:
    - lib/core/manifest/utterance_key.dart (5 → 45 enum entries)
    - test/core/manifest/audio_manifest_test.dart (restructured for new posture)
    - tools/check-domain-purity.sh (added lib/core/cvc to DOMAIN_PATHS)
decisions:
  - D-05 CvcWord shape: { word, c1, v, c2, wordClip }
  - D-06 Pure-Dart core; lib/core/cvc covered by check-domain-purity.sh
  - D-07 Phoneme key resolver: slug → PascalCase → phoneme<X>
  - D-08 cvc/ parallel to matching/ in lib/features/stafir
  - D-09 Round = image (top 55%) + 3 LetterTiles in a row
  - D-10 Per-letter phoneme on tap; blend after 3 taps
  - D-11 Soft order — no left-to-right enforcement
  - D-12 Tapped letters fade to opacity 0.55
  - D-13 Auto-advance after 2s
  - D-14 Re-tap replays phoneme; blend does NOT re-fire
  - D-21 Silent fallback for unreviewed clips
metrics:
  tdd-cycles: 4 (RED+GREEN ×2 — core domain + widget)
  unit-tests-added: 22 (B.1)
  widget-tests-added: 12 (B.2)
  enum-entries-added: 40 (5→45)
  flutter-test-pass: 263 / 263 (was 224 pre-Phase-6)
  flutter-analyze: 7 warnings (all riverpod_lint scoped-providers, same family
    as 5 documented Phase 5 warnings)
  domain-purity: passes
---

# Phase 6 Plan 06-02 — CVC core data model + activity Summary

## What this plan ships

Workstream B. The CVC blending activity's domain types AND the widget that
renders them. Two TDD red→green cycles:

1. **B.1: pure-Dart core** (`lib/core/cvc/`) — CvcWord value class,
   kCvcWords const list, phonemeKeyForSlug resolver. 22 RED tests
   (CW1..CW5, W1..W7, PR1..PR10).

2. **B.2: CvcActivity widget** (`lib/features/stafir/cvc/`) — the activity
   widget + Riverpod providers. 12 RED widget tests (C1..C12).

Both cycles closed cleanly. The full test suite is 263/263 passing.

## What was built (the CVC loop)

```
StafirRoom (in cvc mode after the toggle cycles)
  ↓
CvcActivity mounts
  ↓
Watches cvcCurrentWordProvider — picks 1 of 8 from kCvcWords
  ↓
Renders:
  ┌──────────────────────────────────┐
  │      [round image — word.word]    │   ~55% height
  │                                    │
  ├──────────────────────────────────┤
  │   [LetterTile c1] [c1 v] [c2]     │   3 LetterTiles in row
  └──────────────────────────────────┘
  ↓
Child taps tile (any order — D-11 soft)
  ↓
phonemeKeyForSlug(letter.assetSlug) → UtteranceKey.phoneme<X>
  ↓
audioEngine.play(phonemeKey) — silent if clip missing (D-21)
  ↓
tappedPositions.add(position) — visual cue: tile fades to 0.55 opacity
  ↓
[third tap completes the round]
  ↓
audioEngine.play(word.wordClip) — the full blend audio
  ↓
Auto-advance Timer (2s) → ref.invalidate(cvcCurrentWordProvider)
  ↓
Round resets, tappedPositions cleared, new word picked
  ↓
[Loop continues — infinite rounds, no counter, no score]
```

## Pure-Dart core (B.1)

### CvcWord

```dart
class CvcWord {
  const CvcWord({required word, required c1, required v, required c2,
                 required wordClip});
  final String word;
  final IcelandicLetter c1;
  final IcelandicLetter v;
  final IcelandicLetter c2;
  final UtteranceKey wordClip;

  List<IcelandicLetter> get letters => [c1, v, c2];
  // ==, hashCode, toString
}
```

Hand-written value class (NOT Freezed — small enough that the manual
implementation is clearer than codegen). 5 tests cover storage, the
`.letters` convenience, equality, hashCode parity, toString shape.

### kCvcWords (the 8 starters)

| Word | c1 | v | c2 | wordClip | Source |
|------|----|----|---|----------|--------|
| kýr | k | ý | r | wordK | Phase 3 example_word reused |
| sól | s | ó | l | wordS | Phase 3 example_word reused |
| hús | h | ú | s | wordHus | Phase 6 NEW (cvc/) |
| rós | r | ó | s | wordR | Phase 3 example_word reused |
| bók | b | ó | k | wordB | Phase 3 example_word reused |
| mús | m | ú | s | wordM | Phase 3 example_word reused |
| hár | h | á | r | wordHar | Phase 6 NEW (cvc/) |
| gás | g | á | s | wordGas | Phase 6 NEW (cvc/) |

7 tests cover: ≥8 entries, contains the 8 names, c1/v/c2 = word[0..2],
wordClip references valid UtteranceKey, reuse-vs-new key distinction,
no duplicates.

### phonemeKeyForSlug

32-arm switch from `IcelandicLetter.assetSlug` to
`UtteranceKey.phoneme<PascalCase>`. Returns null for empty/unknown — same
posture as `letterToUtteranceKey` (Phase 4).

10 tests cover: each diacritic case (a, a_acute, eth, thorn, o_umlaut,
ae, y_acute), null cases, and a comprehensive "every alphabet member
resolves" test that iterates kIcelandicAlphabet.

### UtteranceKey enum extension

| Group | Count | Purpose |
|-------|-------|---------|
| Phase 2 stub | 5 | letterA, letterEth, letterThorn, wordHundur, narrationWelcome |
| Phase 6 phoneme | 32 | phonemeA..phonemeOumlaut |
| Phase 6 reused word | 5 | wordK, wordS, wordM, wordR, wordB |
| Phase 6 new word | 3 | wordHus, wordHar, wordGas |
| **Total** | **45** | |

The 5 Phase 2 stub entries are preserved for D-22 backward compat. The 40
new entries exist as enum identifiers but the Phase 2 `kAudioManifest`
still maps only the 5 stub keys — `AudioEngine.play()` falls back silently
for the 40 new keys per D-21. The audio_manifest_test.dart was restructured
to test this posture (new test: "Phase 6 phoneme + new word keys are NOT
in the Phase 2 stub manifest (D-21)").

## CvcActivity widget (B.2)

### State machine

```
State:
  Set<int> _tappedPositions;     // {0, 1, 2}
  bool _blendPlayed;             // false → true after 3rd tap
  Timer? _advanceTimer;          // 2s post-blend → reset

On tap (position p, letter l):
  1. play(phonemeKeyForSlug(l.assetSlug))  // ALWAYS, even on retap
  2. if _blendPlayed: return
  3. _tappedPositions.add(p)
  4. if _tappedPositions.length == 3:
       play(word.wordClip)
       _blendPlayed = true
       _advanceTimer = Timer(2s, _resetRound)

On _resetRound:
  _tappedPositions.clear()
  _blendPlayed = false
  ref.invalidate(cvcCurrentWordProvider)  // pick new word
```

### Reuse, not duplicate

| Reused element | Source | How |
|---------------|--------|-----|
| LetterTile | Phase 4 (lib/features/stafir/widgets/) | Mounted 3× per round, with cvc-tile-N-{slug} keys for test targeting |
| AudioEngine | Phase 4 (lib/core/audio/) | via audioEngineProvider |
| kIcelandicAlphabet | Phase 2 (lib/core/alphabet/) | `kIcelandicAlphabet.indexOf()` for tile palette |
| ParentGateController hold semantics | Phase 1, used via Phase 5 toggle | Indirectly via StafirModeToggle (Plan 06-03) |
| Image placeholder pattern | Phase 5 (`MatchingRoundImage`) | Inline `_CvcRoundImage` mirrors the text-on-color stock pattern |

No new tile widget. No new audio dispatch path.

### Riverpod providers

```dart
@Riverpod(keepAlive: true)
List<CvcWord> cvcWordPool(Ref ref) => kCvcWords;

@Riverpod(keepAlive: true)
CvcWord cvcCurrentWord(Ref ref) {
  final pool = ref.watch(cvcWordPoolProvider);
  return pool[Random().nextInt(pool.length)];
}
```

Tests override `cvcCurrentWordProvider` directly to force a deterministic
round. Auto-advance calls `ref.invalidate(cvcCurrentWordProvider)` to
trigger a fresh random pick.

## Critical invariants enforced by tests

### Layout (C1, C2)
- 3 LetterTiles (NOT 4 like matching). C1.
- Tiles render in [c1, v, c2] order. C2.

### Tap → phoneme (C3, C4, C12)
- Tapping any tile fires its phoneme via AudioEngine. C3, C4.
- Works across multiple words (kýr, hús). C12.

### Soft order (C5)
- c2-first is accepted. No "wrong order" feedback. C5.

### Blend gate (C6, C8, C9)
- Blend fires only after ALL 3 tapped — any order. C6.
- 2/3 tapped does NOT fire blend. C8.
- Re-tap after completion does NOT re-fire blend. C9.

### Replay (C7)
- Re-tapping an already-tapped letter replays its phoneme. D-14. C7.

### No-fail UX (C10, C11)
- Zero error/close/progress UI. C10.
- Zero English-style instruction text. C11.

## Deviations from plan

1. **`CvcWord` is a hand-written value class (not Freezed).** The plan
   text mentions "freezed if using" — for a 5-field value class with
   trivial equality, `@freezed` adds 100+ lines of generated code for
   ~10 lines of payload. Hand-written ==/hashCode/toString are clearer
   here. (Same pattern as `AudioAsset` in lib/core/manifest/.)

2. **Image area is an inline private `_CvcRoundImage` widget**, not a
   separate file. The matching activity has `MatchingRoundImage` as a
   public widget because tests find it by Type. CVC tests don't need
   that specificity, so keeping it inline reduces file count and matches
   the simpler shape of the CVC round.

3. **`audio_manifest_test.dart` restructured** instead of just bumped.
   The original had `expect(UtteranceKey.values.length, 5)` and an
   exhaustive switch — both incompatible with the 5→45 enum extension.
   New posture: per-group invariants (Phase 2 stub vs. Phase 6 extension)
   that are explicit about which keys belong where. The D-21 silent
   fallback contract gets its own test.

4. **`fix(03)` commit landed before the Phase 6 work.** Discovered
   during Workstream A: the 65 Phase-3 AAC clips on disk were 4-byte
   stubs from Phase 2 — Phase 3 baked but never staged. Auto-fix per
   Rule 1; documented in 06-01-SUMMARY.

## Quality gate

- [x] CvcWord + kCvcWords + phonemeResolver are pure Dart (no flutter import)
- [x] tools/check-domain-purity.sh covers lib/core/cvc/ and passes
- [x] CvcActivity renders 3 LetterTiles + image
- [x] Tap-order tolerance (D-11) verified (C5)
- [x] Blend plays after 3 taps in any order (C6)
- [x] Re-tap replays phoneme, does NOT re-fire blend (C7, C9)
- [x] No fail UI / no instructions (C10, C11)
- [x] LetterTile reused — `find.byType(LetterTile).evaluate().length == 3`
- [x] AudioEngine reused via audioEngineProvider override
- [x] Atomic commits (4 commits: 2 RED + 2 GREEN)
- [x] flutter analyze: 7 warnings (all riverpod_lint scoped-providers, documented)
- [x] flutter test all-pass (263/263)

## Self-Check: PASSED

- lib/core/cvc/cvc_word.dart exists ✓
- lib/core/cvc/cvc_words.dart exists ✓
- lib/core/cvc/phoneme_resolver.dart exists ✓
- lib/features/stafir/cvc/cvc_activity.dart exists ✓
- lib/features/stafir/cvc/cvc_providers.dart exists ✓
- 4 commits in this plan visible in git log:
  - `603b78a` test(06-02): RED tests for CVC core data model
  - `ed50f41` feat(06-02): implement CVC core data model (GREEN)
  - `de9efd4` test(06-02): RED tests for CvcActivity widget
  - `a94e485` feat(06-02): implement CvcActivity widget + providers (GREEN)
- All 22 + 12 = 34 new tests pass ✓
- Full suite 263/263 ✓
- check-domain-purity.sh passes ✓
