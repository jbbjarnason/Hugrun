---
phase: 2
title: Alphabet, Asset Conventions & Manifest Stub
status: complete
plans: 3
plans_complete: 3
date: 2026-05-02
duration: ~35 min
requirements_satisfied:
  - FOUND-04 (canonical 32-letter Icelandic alphabet in MMS school order)
  - FOUND-05 (asset path conventions enforced by manifest + CI guard)
---

# Phase 2 Master Summary

## Wave-by-wave execution log

### Wave 1 — Plan 02-01 (alphabet) + Plan 02-03 (asset-paths-guard) — COMPLETE

Executed serially (the planner allowed parallel; serial added clarity for
inline review). 6 atomic commits total.

- **Plan 02-01:** 3 commits (RED `360df35` → GREEN `4606245` → REFACTOR
  `9584581`). +10 unit tests covering D-04 (length, MMS order, no-CQWZ,
  D-03 slug map, slug uniqueness, slug regex, name non-empty) plus
  freezed-model smoke (==, hashCode, copyWith). `lib/core/alphabet/`
  added to `tools/check-domain-purity.sh`. See `02-01-SUMMARY.md`.

- **Plan 02-03:** 3 commits (RED `59e9507` → GREEN `fba2879` → CI
  `4e3cdf6`). New `tools/check-asset-paths.sh` + self-test exercising 8
  cases (5 single-bad fixtures + bad-aggregate + good + empty). CI
  workflow extended with 2 new steps inside `analyze-and-test` (D-14 /
  D-15: no new jobs). See `02-03-SUMMARY.md`.

### Wave 2 — Plan 02-02 (manifest stub) — COMPLETE

3 atomic commits (RED `05e6b8a` → GREEN `47dba92` → REFACTOR `d0e6fbd`).
+8 unit tests covering D-11 (UtteranceKey enum count + identity, manifest
non-null, file existence, D-06 path-convention regex, exact-path spot
checks, getAudioAsset identity, exhaustive switch). 5 placeholder AAC
files (15-byte minimal ADTS frame, byte-identical) under `assets/audio/`.
`lib/gen/audio_manifest.g.dart` hand-written stub committed (per
`.gitignore` line 45 exception). `lib/core/manifest/` added to
`tools/check-domain-purity.sh`. See `02-02-SUMMARY.md`.

## Test count delta

| | Before Phase 2 | After Phase 2 |
|---|---|---|
| `flutter test` | 66 | **84** (+10 alphabet, +8 manifest) |
| `flutter analyze` | 0 issues | 0 issues |
| `dart format --set-exit-if-changed` | 0 changed | 0 changed |
| `flutter build apk --debug` | succeeded | **succeeded** |
| `flutter build ios --no-codesign --debug` | succeeded | **succeeded** |
| CI guard scripts passing | 4 (no-tracking + no-tracking-test + domain-purity + flutter-version) | **6** (+2: check-asset-paths + check-asset-paths-test) |

## Phase 2 success criteria evaluation

| # | Criterion | Status | Notes |
|---|---|---|---|
| 1 | `kIcelandicAlphabet` constant exists with all 32 letters in MMS school order; tests assert (a) length 32, (b) exact order, (c) no C/Q/W/Z, (d) D-03 slug map, (e) slug uniqueness, (f) slug regex | **PASSED** | 7 alphabet tests + 3 IcelandicLetter tests; full D-04 battery green |
| 2 | Asset path convention enforcement: `tools/check-asset-paths.sh` walks `assets/` and rejects any non-ASCII / uppercase / space / non-allowed-extension path; wired into CI | **PASSED** | 8 self-test cases (5 single-bad + 1 aggregate + 1 good + 1 empty), all match expected exit codes; CI YAML adds 2 steps inside `analyze-and-test` (no new jobs); `assets/` post-Plan-02-02 passes |
| 3 | Hand-written `lib/gen/audio_manifest.g.dart` with at least 3 placeholder UtteranceKey entries + matching placeholder AAC files, so AudioEngine and Stafir UI can compile against real `UtteranceKey`s before Phase 3's Python pipeline ships | **PASSED** | 5 entries (letterA, letterEth, letterThorn, wordHundur, narrationWelcome); 5 placeholder AAC files exist on disk; D-11 file-existence + path-convention tests green; `lib/gen/assets.gen.dart` regenerated, includes all 5 paths; `lib/core/manifest/` is Flutter-free |

All 3 criteria met.

## Atomic commits made (chronological)

| Hash | Plan | Phase | Type | Message (truncated) |
|---|---|---|---|---|
| `360df35` | 02-01 | RED | test | add failing alphabet + IcelandicLetter tests |
| `4606245` | 02-01 | GREEN | feat | IcelandicLetter freezed model + kIcelandicAlphabet (32 letters, MMS order) |
| `9584581` | 02-01 | REFACTOR | refactor | document alphabet row-grouping rationale |
| `59e9507` | 02-03 | RED | test | scaffold check-asset-paths fixtures + self-test |
| `fba2879` | 02-03 | GREEN | feat | add tools/check-asset-paths.sh enforcing D-06 conventions |
| `4e3cdf6` | 02-03 | CI | ci | wire check-asset-paths + self-test into analyze-and-test job |
| `05e6b8a` | 02-02 | RED | test | scaffold assets/ folder skeleton + pubspec asset list + failing audio_manifest tests |
| `47dba92` | 02-02 | GREEN | feat | hand-write audio_manifest.g.dart stub + 5 placeholder AAC clips + manifest types |
| `d0e6fbd` | 02-02 | REFACTOR | chore | no-op REFACTOR pass — manifest stub already minimal |

**Total: 9 atomic commits.**

## Files created / modified (consolidated)

**Created (substantive Dart):**
- `lib/core/alphabet/icelandic_letter.dart` (freezed model, pure Dart)
- `lib/core/alphabet/alphabet.dart` (32-letter const list)
- `lib/core/manifest/utterance_key.dart` (5-entry enum)
- `lib/core/manifest/audio_asset.dart` (value class)
- `lib/gen/audio_manifest.g.dart` (hand-written stub, committed via `.gitignore` exception)

**Created (tests):**
- `test/core/alphabet/alphabet_test.dart` (7 tests)
- `test/core/alphabet/icelandic_letter_test.dart` (3 tests)
- `test/core/manifest/audio_manifest_test.dart` (8 tests)

**Created (assets):**
- 5 placeholder AAC files (15 bytes each, identical) under `assets/audio/`
- 10 `.gitkeep` files forming the canonical D-05 folder skeleton

**Created (tooling):**
- `tools/check-asset-paths.sh`
- `tools/check-asset-paths_test.sh`
- `tools/generate_placeholder_aac.dart` (Dart helper for the AAC fallback)
- `tools/test-fixtures/bad-asset-paths/` (5 violation files + .gitkeep)
- `tools/test-fixtures/good-asset-paths/` (2 conforming files + .gitkeep)

**Modified:**
- `pubspec.yaml` (`flutter.assets` enumerates 10 folders)
- `tools/check-domain-purity.sh` (`DOMAIN_PATHS` += `lib/core/alphabet`, `lib/core/manifest`)
- `.github/workflows/ci.yml` (2 new steps in `analyze-and-test`)
- `lib/gen/assets.gen.dart` (regenerated by `flutter_gen_runner`; not committed per `.gitignore`)

**Removed:**
- `assets/.gitkeep` (replaced by per-folder `.gitkeep`s under D-05 layout)

## Phase-wide quality gate (post-execution)

```
=== flutter test ===                    84 tests, all passed
=== flutter analyze ===                 No issues found
=== dart format --set-exit-if-changed === 0 changed
=== check-domain-purity ===             domain layer is Flutter-free
=== check-asset-paths ===               assets passes
=== check-asset-paths_test ===          self-test ok
=== check-no-tracking ===               pubspec.lock passes
=== check-no-tracking_test ===          self-test ok
=== check-flutter-version ===           Flutter 3.41.9 matches .fvmrc
=== ci.yml YAML parse ===               OK
=== flutter build apk --debug ===       Built build/app/outputs/flutter-apk/app-debug.apk
=== flutter build ios --no-codesign --debug === Built build/ios/iphoneos/Runner.app
```

## Deviations summary

Three documented deviations across Phase 2; all auto-fixed under Rule 1 of
the deviation protocol; none required user escalation:

1. **Plan 02-01:** Generated `*.freezed.dart` not committed (project
   `.gitignore` policy overrides plan's "commit it" instruction). See
   `02-01-SUMMARY.md`.
2. **Plan 02-02:** ffmpeg fallback to copy-fixture (plan-permitted; ffmpeg
   not installed locally and Homebrew install would have exceeded the 5-min
   budget).
3. **Plan 02-02:** `@immutable` annotation dropped from `AudioAsset` to
   avoid adding a `package:meta` direct dependency. Manual `==` /
   `hashCode` + `const` constructor + `final` fields deliver the same
   immutability guarantees.

Plan 02-03 had zero deviations.

## Status

**3 of 3 plans complete.** All Phase 2 success criteria met. Phase 2's
output unblocks Phase 3 (Python TTS pipeline regenerates
`lib/gen/audio_manifest.g.dart` against the locked `UtteranceKey`
identifiers) and Phase 4 (Stafir grid renders `kIcelandicAlphabet`,
AudioEngine consumes `kAudioManifest`).
