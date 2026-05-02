---
phase: 3
plan: 02
plan-name: manifest-yaml-and-overrides
status: complete
date: 2026-05-02
duration: ~30 min
requirements_satisfied:
  - AUDIO-01
  - AUDIO-07
key-files:
  created:
    - manifest.yaml
    - pronunciation_overrides.yaml
    - reviewed.yaml
    - tools/tts/schema.py
    - tools/tts/validate_manifest.py
    - tools/tts/tests/test_schema.py
    - tools/tts/tests/test_validate_manifest.py
    - tools/tts/tests/fixtures/manifest_good.yaml
    - tools/tts/tests/fixtures/manifest_missing_field.yaml
    - tools/tts/tests/fixtures/manifest_duplicate_key.yaml
    - tools/tts/tests/fixtures/manifest_unknown_kind.yaml
    - tools/tts/tests/fixtures/manifest_bad_asset_path.yaml
    - tools/tts/tests/fixtures/overrides_good.yaml
    - tools/tts/tests/fixtures/overrides_invalid_field.yaml
    - tools/tts/tests/fixtures/reviewed_good.yaml
    - tools/tts/tests/fixtures/reviewed_bad_timestamp.yaml
  modified: []
decisions:
  - "Voice ID locked to `is_IS-steinn-medium` (matches the ONNX file basename)."
  - "wordI text 'ilmur' (scent) — avoids í-vs-i collision (initial fixture had 'ís' which starts with í, not i)."
  - "Mutually-exclusive override fields: text vs phonemes. Both length_scale and noise_scale allowed independently."
---

# Plan 03-02 Summary — manifest.yaml + Overrides + Schema Validator

## What was built

| Artifact | Purpose |
|---|---|
| `manifest.yaml` (D-04) | 65 entries (32 letter_name + 32 example_word + 1 narration); voice `is_IS-steinn-medium`. Phase 2 stub keys (letterA/Eth/Thorn, wordHundur, narrationWelcome) preserved with their original asset paths. |
| `pronunciation_overrides.yaml` (D-13) | Empty schema-valid file. Piper-flavored fields: text, phonemes, length_scale, noise_scale, ssml. |
| `reviewed.yaml` (D-17) | Empty schema-valid file. Approved entries require reviewer + ISO timestamp + voice + sha256 text_hash. |
| `tools/tts/schema.py` | Pure-stdlib validators. ALLOWED_KINDS frozenset, ASSET_PATH_REGEX, KEY_REGEX (camelCase). PHASE2_STUB_KEYS exported for downstream backward-compat checks. |
| `tools/tts/validate_manifest.py` | CLI wrapper. Default validates 3 repo-root files; single-file mode auto-detects validator from filename. |

## Atomic commits

| Hash | Type | Message |
|---|---|---|
| `14f827d` | RED   | test(03-02): RED — schema validator tests + good/bad YAML fixtures |
| `9c9d3c3` | GREEN | feat(03-02): GREEN — add tools/tts/schema.py validators (D-04, D-13, D-17) |
| `061634b` | feat  | feat(03-02): author manifest.yaml + overrides + reviewed + CLI validator |

(Combined RED+GREEN for Task 2 into one commit — the YAML files and the
contract tests are co-dependent and were authored together.)

## Test counts

- 14 schema unit tests (`test_schema.py`)
- 10 repo-level contract tests (`test_validate_manifest.py`)
- Cumulative across Plans 01 + 02: **57 pytest cases**

## Word picks (v1; Plan 07 review pass may override)

| Letter | Example word | Notes |
|---|---|---|
| a | api | ape/monkey |
| á | ár | year |
| b | bók | book |
| d | dúkka | doll |
| ð | maður | man (medial ð; rare word-initially) |
| e | epli | apple |
| é | él | snow shower |
| f | fiskur | fish |
| g | gata | street |
| h | hundur | dog (Phase 2 stub key wordHundur doubles as wordH per D-22) |
| i | ilmur | scent (chosen over 'ís' which starts with í) |
| í | íþrótt | sport |
| j | jól | Christmas |
| k | kýr | cow |
| l | lampi | lamp |
| m | mús | mouse |
| n | nef | nose |
| o | ostur | cheese |
| ó | ólafur | (proper noun) |
| p | pera | pear |
| r | rós | rose |
| s | sól | sun |
| t | tönn | tooth |
| u | uggi | fin |
| ú | úr | watch |
| v | vatn | water |
| x | xýlófónn | xylophone (rare; expect Steinn issues) |
| y | ylur | warmth |
| ý | ýta | to push |
| þ | þrír | three |
| æ | æða | vein |
| ö | öxl | shoulder |

## Carry-overs

- **Plan 03 (piper_client.py + normalize.py):** consumes `manifest.yaml` via
  `yaml.safe_load`. Override-priority logic should consult schema.py for
  field names and respect Piper-only fields (no SSML — pass-through).
- **Plan 04 (manifest_writer.py):** sorts utterances alphabetically by key
  for diff stability; computes text_hash for review-gate verification.
- **Plan 07 review pass:** word picks above are tentative. The review UI
  + manual review will identify mispronunciations; Jon edits
  `pronunciation_overrides.yaml` and re-runs bake.

## Self-Check: PASSED

- `python tools/tts/validate_manifest.py` exits 0.
- `pytest tools/tts/tests/` 57/57 passing.
- `bash tools/check-asset-paths.sh` still passes (no real new AAC files yet).
- 65-entry count via `grep -c '^  - key: ' manifest.yaml`.
- All 5 Phase 2 stub keys present at original paths (D-22).
