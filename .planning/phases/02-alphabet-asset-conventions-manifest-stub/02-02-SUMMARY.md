---
phase: 2
plan: 2
title: Audio manifest stub + asset folder skeleton + 5 placeholder AAC clips
status: complete
tags: [audio, manifest, assets, stub, codegen]
date: 2026-05-02
duration: ~15 min
requires:
  - phase-2 plan 01 (UtteranceKey contract is independent but the phase
    convention shares the alphabet slug semantics)
  - phase-1 flutter_gen_runner (5.14.1)
provides:
  - lib/core/manifest/utterance_key.dart (UtteranceKey enum, 5 entries)
  - lib/core/manifest/audio_asset.dart (AudioAsset value class)
  - lib/gen/audio_manifest.g.dart (kAudioManifest map + getAudioAsset helper, hand-written stub)
  - 5 placeholder AAC files under assets/audio/{letters,narration}/
  - 10-folder D-05 asset skeleton with .gitkeep placeholders
  - pubspec.yaml flutter.assets enumerating all 10 folders
  - tools/check-domain-purity.sh extension covering lib/core/manifest/
affects:
  - phase-3 Python TTS pipeline regenerates lib/gen/audio_manifest.g.dart
    against the same UtteranceKey identifiers
  - phase-4 AudioEngine + Stafir UI compile against UtteranceKey symbols
key-files:
  created:
    - lib/core/manifest/utterance_key.dart
    - lib/core/manifest/audio_asset.dart
    - lib/gen/audio_manifest.g.dart
    - tools/generate_placeholder_aac.dart
    - test/core/manifest/audio_manifest_test.dart
    - assets/audio/letters/names/a.aac
    - assets/audio/letters/names/eth.aac
    - assets/audio/letters/names/thorn.aac
    - assets/audio/letters/words/hundur.aac
    - assets/audio/narration/welcome_hugrun.aac
    - 10 .gitkeep files under assets/{audio,images}/
  modified:
    - pubspec.yaml (flutter.assets list)
    - tools/check-domain-purity.sh
  removed:
    - assets/.gitkeep (replaced by per-folder .gitkeep)
decisions:
  - AAC generation strategy = copy-fixture (15-byte minimal ADTS frame
    via tools/generate_placeholder_aac.dart). ffmpeg not installed locally;
    Homebrew install would have exceeded the 5-minute budget per the
    execution prompt. Phase 3 owns ffmpeg formally.
  - >
    Dropped the `package:meta/meta.dart` `@immutable` annotation on
    AudioAsset to avoid adding a direct dependency the project doesn't
    otherwise need. The const constructor + final fields + manual ==
    deliver the same immutability guarantees.
metrics:
  tests_added: 8 (2 UtteranceKey + 4 kAudioManifest + 2 getAudioAsset)
  commits: 3
  aac_file_size: 15 bytes each (5 files; identical byte-for-byte)
---

# Phase 2 Plan 02: Audio Manifest Stub Summary

**One-liner:** Hand-written `lib/gen/audio_manifest.g.dart` exposing 5
`UtteranceKey` entries mapped to placeholder AAC files, locking the manifest
contract Phase 3's TTS pipeline regenerates against and Phase 4's AudioEngine
imports — D-08 / D-09 / D-10 / D-11 fully met.

## Commits

| Hash | Type | Message |
|---|---|---|
| `05e6b8a` | RED | `test(02-02): scaffold assets/ folder skeleton + pubspec asset list + failing audio_manifest tests (RED)` |
| `47dba92` | GREEN | `feat(02-02): hand-write audio_manifest.g.dart stub + 5 placeholder AAC clips + manifest types (GREEN)` |
| `d0e6fbd` | REFACTOR | `chore(02-02): no-op REFACTOR pass — manifest stub already minimal` |

## AAC generation strategy

ffmpeg was NOT installed locally and Homebrew install of ffmpeg pulls in a
large dependency tree (lame, libass, x264, x265, libsdl2, libvpx,
libfdk-aac, ...). Per the prompt's 5-minute budget and the plan's explicit
fallback ("If ffmpeg isn't installed locally yet... use Dart-side or copy a
single tiny pre-existing AAC file in 5 places"), I chose the Dart-side
approach.

`tools/generate_placeholder_aac.dart` writes a 15-byte minimal ADTS frame
(7-byte ADTS header + 8-byte minimal silent payload) to all 5 target paths.
The byte sequence is identical across files — appropriate for a stub since
the D-11 tests only check `File.existsSync()` + path conventions, not audio
content.

| File | Size | SHA1 |
|---|---|---|
| `assets/audio/letters/names/a.aac` | 15 bytes | byte-identical |
| `assets/audio/letters/names/eth.aac` | 15 bytes | byte-identical |
| `assets/audio/letters/names/thorn.aac` | 15 bytes | byte-identical |
| `assets/audio/letters/words/hundur.aac` | 15 bytes | byte-identical |
| `assets/audio/narration/welcome_hugrun.aac` | 15 bytes | byte-identical |

Phase 3's Python pipeline replaces these with proper ffmpeg-rendered
silent-100ms or real-narrator clips.

## Test count delta

| | Before this plan | After this plan |
|---|---|---|
| `flutter test` | 76 (incl. plan 02-01) | **84** (+8 manifest) |

## D-11 assertions confirmed

- `UtteranceKey.values.length == 5` ✓
- `UtteranceKey.values.toSet()` equals `{letterA, letterEth, letterThorn, wordHundur, narrationWelcome}` ✓
- Every `UtteranceKey` maps to a non-null `AudioAsset` ✓
- Every manifest path resolves to a real file on disk (`File(path).existsSync()`) ✓
- Every manifest path matches `^[a-z0-9_./-]+\.aac$` and contains no `..`, no `//`, no leading `/` ✓
- Exact paths match the D-08 spot-check map ✓
- `getAudioAsset(key)` returns the same `AudioAsset` as `kAudioManifest[key]!` for every key ✓
- Exhaustive `switch` over `UtteranceKey` returns a non-empty path for every value ✓

## D-05 folder structure confirmed

```
assets/
  audio/
    letters/
      names/         a.aac, eth.aac, thorn.aac, .gitkeep
      words/         hundur.aac, .gitkeep
      phonemes/      .gitkeep        (Phase 6 destination)
    numbers/
      masculine/     .gitkeep        (Phase 8/9 destination)
      feminine/      .gitkeep        (Phase 8/9 destination)
      neuter/        .gitkeep        (Phase 8/9 destination)
    narration/       welcome_hugrun.aac, .gitkeep
  images/
    letters/
      words/         .gitkeep        (Phase 4 destination)
    numbers/         .gitkeep        (Phase 8 destination)
    ui/              .gitkeep        (Phase 4 destination)
```

## D-10 coexistence confirmed

`flutter_gen_runner` regenerated `lib/gen/assets.gen.dart` against the new
folder layout. It emits typed asset paths (e.g. `Assets.audio.letters.names.a
== 'assets/audio/letters/names/a.aac'`). The hand-written
`lib/gen/audio_manifest.g.dart` provides the typed `UtteranceKey →
AudioAsset` mapping (path + duration metadata). Both files coexist; Phase 3
regenerates `audio_manifest.g.dart` only.

## Domain purity confirmed

`lib/core/manifest/` files import only `dart:core` types — no
`package:flutter` and no `package:meta`. `tools/check-domain-purity.sh`
includes `lib/core/manifest` in `DOMAIN_PATHS` and confirms zero violations.

## Deviations from plan

### Deviation 1 [Rule 1 - Bug] — drop `@immutable` annotation to avoid spurious dep

**Found during:** Task 2 GREEN, after first `flutter analyze` run.

**Issue:** The plan's interface spec for `AudioAsset` recommended using
`@immutable` from `package:meta/meta.dart`. `meta` is a transitive dependency
of `flutter` but the analyzer (`depend_on_referenced_packages` lint) flags
indirect-import use as a warning when the package is not declared in
`pubspec.yaml` `dependencies`.

**Fix:** Removed the `@immutable` annotation entirely. The `const`
constructor + `final` fields + manual `operator ==` / `hashCode` deliver the
same immutability guarantees without needing the annotation. No new
dependency added.

**Files affected:** `lib/core/manifest/audio_asset.dart`.

**Commit:** Folded into `47dba92` (the GREEN commit) along with a docstring
noting the rationale.

### Deviation 2 [Plan-permitted] — ffmpeg fallback to copy-fixture

The plan explicitly permits this fallback when ffmpeg is absent. Documented
under "AAC generation strategy" above; not a true deviation.

## Self-Check: PASSED

- `lib/core/manifest/utterance_key.dart` — FOUND
- `lib/core/manifest/audio_asset.dart` — FOUND
- `lib/gen/audio_manifest.g.dart` — FOUND
- `test/core/manifest/audio_manifest_test.dart` — FOUND
- 5 AAC files — FOUND (each 15 bytes, non-zero size)
- 10 .gitkeep files (D-05 skeleton) — FOUND
- `pubspec.yaml flutter.assets` — FOUND, enumerates 10 folders
- `tools/check-domain-purity.sh` — FOUND, contains `lib/core/manifest`
- Commit `05e6b8a` (RED) — FOUND
- Commit `47dba92` (GREEN) — FOUND
- Commit `d0e6fbd` (REFACTOR) — FOUND
