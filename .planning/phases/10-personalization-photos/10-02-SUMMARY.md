---
phase: 10
plan: 02
title: Curated lexicon
status: complete
date: 2026-05-02
tags: [lexicon, pure-dart, domain-purity]
requirements: [PHOTO-02]
---

# Plan 10-02 — Curated Lexicon

Phase 10 Workstream B. Pure-Dart lexicon under `lib/core/lexicon/` with the
30-entry starter set listed in the plan scope. Domain-purity guard extended
to enforce no Flutter imports under the new path.

## Atomic commits

| Hash      | Type | Subject                                                          |
|-----------|------|------------------------------------------------------------------|
| `d5802ff` | test | failing lexicon tests (RED)                                      |
| `acc5643` | feat | pure-Dart lexicon with 30 starter entries (GREEN)                |

## Files

### Created
- `lib/core/lexicon/gender.dart` — Icelandic noun gender enum
- `lib/core/lexicon/lexicon_entry.dart` — value class
- `lib/core/lexicon/lexicon.dart` — `kStarterLexicon` const list (30 entries) + `lookupLexiconEntry`
- `test/core/lexicon/lexicon_entry_test.dart` — 4 tests
- `test/core/lexicon/lexicon_test.dart` — 9 tests

### Modified
- `tools/check-domain-purity.sh` — added `lib/core/lexicon` to DOMAIN_PATHS

## Starter lexicon (30 entries)

Animals: hundur, köttur, kýr, hestur, fugl, fiskur, mús, kanína (8)
Food: epli, banani, brauð, mjólk, vatn (5)
Outdoors: sól, máni, tré, blóm (4)
Toys/household: bók, bíll, hús, bolti, dúkka, koddi, teppi, stóll (8)
Clothing: hattur, peysa, sokkar, skór (4)
Body: auga (1)

Each entry has gender (M/F/N) + canonical default image path under
`assets/images/letters/words/<slug>.webp`.

## Tests

- LexiconEntry: constructs, value equality, hashCode, inequality
- Gender enum: 3 values
- kStarterLexicon: ≥30 entries, unique words, lowercase, canonical paths,
  pure Icelandic chars (a-z + áðéíóúýþæö), every entry has gender
- `lookupLexiconEntry('hundur')` → masculine entry
- `lookupLexiconEntry('zzz_unknown')` → null

13 tests, all green. `tools/check-domain-purity.sh` passes —
`lib/core/lexicon/` is Flutter-free.

## Decisions exercised

- **D-05** Pure-Dart lexicon under `lib/core/lexicon/`; ~200 nouns
  reduced to a 30-entry starter set per CONTEXT D-07 ("ship Phase 10
  with the lexicon model + a smaller starter set")
- **D-06** Each entry: word, gender, defaultImagePath. The
  UtteranceKey audioKey field from D-06 is **deferred**: Phase 3's
  TTS pipeline does not yet emit noun audio for the full lexicon
  (Phase 3 is partially blocked on TTS provider per `STATE.md`). The
  parent-facing lexicon picker doesn't need audio playback in v1.

## Deviations

- **[Rule 4 (deferred, not architectural)]** UtteranceKey audioKey field
  on LexiconEntry is **not added** in v1. Per CONTEXT D-07, the full
  manifest extension is a polish pass. Adding the field now would
  require Phase 3's currently-blocked TTS pipeline (STATE.md
  documents the Tiro outage). The parent UI does not play audio for
  the lexicon entries. Future plans (post-Phase-3-unblock) can add
  the audio key without breaking value-class equality (defaulting
  field).
