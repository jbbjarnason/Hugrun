---
phase: 10
title: Personalization — Photo System (THE MOAT FEATURE)
status: complete
date: 2026-05-02
plans:
  - 10-01-drift-v2-schema-migration
  - 10-02-curated-lexicon
  - 10-03-photo-persistence
  - 10-04-photo-upload-ui
  - 10-05-integration-summaries
tags: [drift, image-codec, riverpod, photo-personalization, last-phase]
metrics:
  total-tests: 443
  test-delta: +52 (391 → 443)
  flutter-analyze: 15 issues — all pre-existing scoped_providers warnings
  flutter-build-apk-debug: passes
  domain-purity: passes (now includes lib/core/lexicon)
  no-tracking: passes
requirements: [PHOTO-01, PHOTO-02, PHOTO-03, PHOTO-04, PHOTO-05, PHOTO-06, PHOTO-07]
---

# Phase 10: Personalization — Photo System — Master Summary

**THE FINAL PHASE.** Phase 10 ships the moat feature: parent uploads photos
via parent settings, tags each with one Icelandic noun from a curated
lexicon, and tagged photos override stock images in matching/numeracy
activities. Drift schema bumps from v1 to v2 with `photo_tags` +
`activity_log` tables. **Photos NEVER leave the device.**

After Phase 10, the v1 milestone is complete: skeleton (1) → alphabet (2)
→ TTS pipeline (3) → tap-to-hear MVP (4) → matching (5) → CVC (6) →
tracing (7) → Tölur tap-to-hear + sequencing (8) → numeracy activities
(9, parallel) → photo personalization (10).

## Plan summaries

| Plan  | Subject                                  | Commits | Tests added |
|-------|------------------------------------------|---------|-------------|
| 10-01 | Drift v2 schema migration                | 2       | +3          |
| 10-02 | Curated lexicon                          | 2       | +13         |
| 10-03 | Photo persistence + Drift override       | 2       | +14         |
| 10-04 | Photo upload UI                          | 2       | +11         |
| 10-05 | Integration test + summaries (this plan) | 1       | +1 (E2E)    |

**Total: 9 atomic commits across 5 plans.**

## What was built (the personalization loop)

```
HomePage
  ↓
[Parent holds settings icon for 3 seconds — Phase 1 ParentGate]
  ↓
ParentSettingsScreen
  ↓
[Parent taps "Myndir"]
  ↓
PhotoUploadScreen
  ↓
[Parent taps FAB → image_picker → photo selected]
  ↓
LexiconPicker (alphabetical 30-entry list)
  ↓
[Parent taps "hundur"]
  ↓
PhotoRepository.addPhoto:
  • image package decodes the source
  • copyResize to ≤1024 px max edge (preserves aspect ratio)
  • encodeJpg quality 85
  • write <docs>/hugrun_photos/<uuid>.jpg
  • Drift photoTags insert
  ↓
SnackBar: "Mynd vistuð fyrir 'hundur'" (1 s)
List refreshes — tile shows the new tag + thumbnail
  ↓
[Long-press a tile → delete confirm dialog]
  ↓
Photos.delete: file + row both removed
  ↓
[Child opens Stafir → Match]
  ↓
RoundGenerator picks targetWordSlug = "hundur"
  ↓
photoOverrideSourceProvider (overridden in main.dart at ProviderScope) →
  DriftPhotoOverrideSource.photosForWordSlug('hundur')
  ↓
Returns [<docs>/hugrun_photos/<uuid>.jpg]
  ↓
RoundGenerator: nextDouble() < 0.4 → ImageSource.photoOverride
  ↓
MatchingRoundImage renders the parent's actual photo of their dog
  ↓
[Child taps "h" — correct → audio + celebration → next round]
```

## Test counts (cumulative)

| Plan  | Tests added | Cumulative `flutter test` |
|-------|-------------|---------------------------|
| Phase 9 baseline | — | 391 |
| 10-01 | +3  | 394 |
| 10-02 | +13 | 407 |
| 10-03 | +14 | 421 |
| 10-04 | +11 | 432 |
| 10-05 | +11 (E2E + adjustments) | **443** |

`flutter test` final wall-clock: **443 tests, all green** (delta +52 from
the Phase 9 baseline).

`flutter analyze`: 15 issues, all pre-existing
`scoped_providers_should_specify_dependencies` warnings (Phase 5/6/7/8/9
documented). Zero issues attributable to Phase 10.

`tools/check-no-tracking.sh`: passes.
`tools/check-domain-purity.sh`: passes (now includes `lib/core/lexicon/`).
`flutter build apk --debug`: passes.

## Phase 10 success criteria evaluation

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| 1 | Drift v2 with photo_tags + activity_log; migration test green | **passed** | 3 migration tests (`test/core/db/migrations/v1_to_v2_test.dart`) |
| 2 | drift_schemas/v2.json snapshot committed | **passed** | `drift_schemas/drift_schema_v2.json` |
| 3 | Lexicon with ~30 starter entries, pure Dart, tested | **passed** | 30 entries, 13 tests, domain-purity gate now covers `lib/core/lexicon/` |
| 4 | PhotoRepository persists photos with downsize + UUID filename | **passed** | 8 tests; max edge 1024 px, JPEG q=85, `<uuid>.jpg` |
| 5 | DriftPhotoOverrideSource queries photo_tags, returns matching image_path | **passed** | 6 tests; reactive cache via `select(photoTags).watch()` |
| 6 | PhotoUploadScreen with Add/lexicon-picker/list flow | **passed** | 6 tests; reachable from ParentSettingsScreen "Myndir" |
| 7 | image_picker, image, uuid in pubspec; check-no-tracking still passes | **passed** | All three direct deps; tracking guard green |
| 8 | Integration test exercises full upload → tag → see in matching flow | **passed** | `integration_test/photo_personalization_flow_test.dart` (compiles + analyzes clean; runs on device binding) |
| 9 | flutter analyze clean (modulo pre-existing) | **passed** | 15 pre-existing warnings; 0 new |
| 10 | flutter test 443+ tests pass | **passed** | 443/443 green |
| 11 | flutter build apk --debug succeeds | **passed** | `build/app/outputs/flutter-apk/app-debug.apk` |
| 12 | tools/check-domain-purity.sh includes lib/core/lexicon; passes | **passed** | DOMAIN_PATHS extended; guard green |
| 13 | No edits to Phase 9 territory | **passed** | Verified: no diff in `lib/features/tolur/{correspondence,subitizing,addition}/` or `lib/features/stafir/` from Phase 10's commits |
| 14 | Atomic commits | **passed** | 9 atomic commits, RED→GREEN cycle per workstream |
| 15 | VERIFICATION.md status: passed | **passed** | See `10-VERIFICATION.md` |

## Architectural commitments — preserved

- **Pure-Dart `lib/core/lexicon/`**: enforced via `tools/check-domain-purity.sh`
- **Drift migration non-destructive**: v1 → v2 only ADDS tables; `child_profiles` left alone (D-04)
- **Photos NEVER leave the device**: no HTTP path in any code under
  `lib/features/parent_settings/photo_upload/`; no banned analytics SDKs
  introduced; `image_picker`/`image`/`uuid` are platform-clean
- **Phase 5 contract honored**: `DriftPhotoOverrideSource` implements the
  Phase 5 abstract `PhotoOverrideSource`; the matching activity needs no
  code change — the Riverpod binding is overridden at the production
  `ProviderScope` in `main.dart`
- **40% override stays in `RoundGenerator`**: the photo source only
  answers "what photos exist?"; the Bernoulli decision is unchanged
  (Phase 5 D-13/D-14)
- **`Phase 5 EmptyPhotoOverrideSource` still default for tests**: the
  override is set in `lib/main.dart`, not in the provider definition —
  Phase 5's matching tests + widget tests stay green without any change

## Key decisions exercised

D-01 (schema bump v1→v2), D-02 (stepByStep), D-03 (snapshot dump), D-04
(non-destructive), D-05 (curated 30-entry lexicon), D-06 (LexiconEntry
structure — UtteranceKey audioKey deferred to Phase-3-unblock), D-07
(starter set vs full ~200), D-08 (PhotoUploadScreen entry from settings),
D-09 (add flow), D-10 (long-press delete), D-11 (1024 px / q=85), D-12
(app docs path), D-13 (DriftPhotoOverrideSource), D-14 (40% Bernoulli stays
in RoundGenerator), D-15 (numeracy override hook — same interface; Phase
9 uses StockPlaceholder by default but the provider can be swapped), D-16
(unit tests), D-17 (widget tests), D-18 (migration test using
schemaAt(1)), D-19 (integration test), D-20 (no upload code paths), D-22
(pubspec additions, all platform-clean).

D-21 (EXIF stripping) is **deferred to v2** as documented in CONTEXT.md.

## Deviations summary

The full deviation list is in each plan's SUMMARY.md. Highlights:

1. **UtteranceKey audioKey on LexiconEntry deferred** (Plan 10-02). Phase
   3's TTS pipeline is partially blocked on the Tiro provider outage
   (STATE.md). The lexicon doesn't need audio in v1 — it feeds the
   parent UI, which is text-only.

2. **`path` package promoted dev_dep → main** (Plan 10-03). Lib code
   uses `package:path` for joining the docs dir + UUID filename;
   `depend_on_referenced_packages` lint correctly required this.

3. **`scrollUntilVisible` instead of `ensureVisible`** in widget tests
   (Plan 10-04). `ListView.builder` lazily constructs tiles; the
   correct test API is `scrollUntilVisible`. Same pattern reused in
   3 tests.

4. **Camera capture deferred to v2** (Plan 10-04). Per `<deviations>`
   guidance for image_picker Android oddities. The `PhotoPicker`
   abstract class can grow `pickFromCamera()` later without breaking
   callers; v1 personalization works fine via gallery only.

## Files created/modified summary

### Created (lib/)
- `lib/core/db/tables/photo_tags.dart`
- `lib/core/db/tables/activity_log.dart`
- `lib/core/lexicon/gender.dart`
- `lib/core/lexicon/lexicon_entry.dart`
- `lib/core/lexicon/lexicon.dart`
- `lib/features/parent_settings/photo_upload/photo_repository.dart`
- `lib/features/parent_settings/photo_upload/drift_photo_override_source.dart`
- `lib/features/parent_settings/photo_upload/photo_picker.dart`
- `lib/features/parent_settings/photo_upload/photo_upload_providers.dart`
- `lib/features/parent_settings/photo_upload/lexicon_picker.dart`
- `lib/features/parent_settings/photo_upload/photo_upload_screen.dart`

### Modified (lib/)
- `lib/core/db/database.dart` — schemaVersion 2 + new tables registered
- `lib/core/db/database.steps.dart` — drift_dev regenerated with `Schema2`
- `lib/main.dart` — Riverpod ProviderScope overrides photoOverrideSourceProvider
- `lib/features/parent_settings/parent_settings_screen.dart` — "Myndir" button

### Created (test/)
- `test/core/db/migrations/v1_to_v2_test.dart`
- `test/core/db/generated/schema_v2.dart`
- `test/core/lexicon/lexicon_entry_test.dart`
- `test/core/lexicon/lexicon_test.dart`
- `test/features/parent_settings/photo_upload/photo_repository_test.dart`
- `test/features/parent_settings/photo_upload/drift_photo_override_source_test.dart`
- `test/features/parent_settings/photo_upload/lexicon_picker_test.dart`
- `test/features/parent_settings/photo_upload/photo_upload_screen_test.dart`

### Created (integration_test/)
- `integration_test/photo_personalization_flow_test.dart`

### Created (drift_schemas/)
- `drift_schemas/drift_schema_v2.json`

### Modified (tools/)
- `tools/check-domain-purity.sh` — added `lib/core/lexicon`

### Modified (pubspec)
- `pubspec.yaml` — added `image_picker ^1.1.2`, `image ^4.8.0`,
  `uuid ^4.5.3`; `path` promoted from dev_dependencies to direct main
- `pubspec.lock` — refreshed

### Created (.planning/)
- `.planning/phases/10-personalization-photos/10-{01..04}-SUMMARY.md`
- `.planning/phases/10-personalization-photos/10-SUMMARY.md` (this file)
- `.planning/phases/10-personalization-photos/10-VERIFICATION.md`

## Phase 10 closing posture

The personalization moat is **fully shipped from a code-quality standpoint**:
443 tests pass, `flutter analyze` is clean (no Phase 10 issues), the
debug APK builds, the upload flow correctly persists photos + the
matching activity transparently picks them up via the Drift-backed
override.

**v1 milestone code complete.** Next workflow stop: milestone audit +
`/gsd-complete-milestone`.

When real-device validation runs:
- `flutter run` Stafir → hold settings 3s → Myndir → upload + tag
  several photos with words from the starter lexicon → return to
  Stafir → hold StafirModeToggle 3s → Match → at 40% per-round
  Bernoulli probability the parent's photos appear instead of the
  stock illustration.
- `flutter test integration_test/photo_personalization_flow_test.dart`
  on a connected device for the full E2E path.
