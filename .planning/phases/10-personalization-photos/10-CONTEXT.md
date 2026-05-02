# Phase 10: Personalization — Photo System - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** `--auto`

<domain>
## Phase Boundary

Parent uploads photos via parent settings, tags each with one Icelandic noun from a curated lexicon. Tagged photos override stock images in Stafir matching activity (~40% frequency) and Tölur numeracy activities. Drift v1 → v2 schema migration adds `photo_tags` and `activity_log` tables. **This is the moat feature** — no Icelandic-market competitor does this.

**Requirements covered (7):** PHOTO-01..07

</domain>

<decisions>
## Implementation Decisions

### Drift v2 schema migration

- **D-01:** Drift schema bumps to `schemaVersion = 2`. Two new tables:
  - `photo_tags { id INTEGER PK, image_path TEXT, lexicon_entry_id INTEGER FK, created_at INTEGER }` — one row per parent-uploaded photo
  - `activity_log { id INTEGER PK, activity_type TEXT, timestamp INTEGER }` — for parent companion (deferred to v2 features but the table exists from this migration)
- **D-02:** Migration: `MigrationStrategy(onUpgrade: stepByStep(from1To2: (m, schema) async { ... }))`. Phase 1's stepByStep scaffolding makes this a clean addition.
- **D-03:** `drift_dev schema dump 2` snapshot to `drift_schemas/v2.json`. Migration test using `schemaAt(1)` populates v1 data, runs migration, asserts v2 round-trips.
- **D-04:** Backward compat: existing `child_profiles` row migrates without modification. Existing user data preserved.

### Curated lexicon

- **D-05:** `lib/core/lexicon/lexicon.dart` — pure Dart const list of ~200 Icelandic nouns covering common kid-relevant categories: family members, pets, food, vehicles, body parts, household objects, animals, clothing.
- **D-06:** Each entry: `LexiconEntry { String word, Gender gender, UtteranceKey audioKey, String defaultImagePath, IcelandicLetter startingLetter }`. Pure Dart, no Flutter imports.
- **D-07:** Entries reference manifest UtteranceKeys for audio. Phase 10 may need to extend manifest.yaml with ~100-200 noun entries; ship Phase 10 with the lexicon model + a smaller starter set (~30 nouns) wired up; full 200-entry set is a polish pass.

### Photo upload UI

- **D-08:** `lib/features/parent_settings/photo_upload/photo_upload_screen.dart`. Reachable from ParentSettingsScreen (Phase 4). Lists existing tagged photos, "Add photo" button.
- **D-09:** Add flow:
  1. Tap "Add photo" → `image_picker` package opens camera or gallery
  2. After picking, show a list of lexicon entries (paginated/searchable in Icelandic)
  3. Tap a lexicon entry to tag the photo
  4. Photo saved to `path_provider.getApplicationDocumentsDirectory()/hugrun_photos/{uuid}.jpg`, downsized to 1024px max edge, JPEG q=85
  5. Drift `photo_tags` row created
- **D-10:** Edit/delete existing photos: long-press a photo in the list → "Delete" or "Re-tag" options.

### Photo persistence + bounds

- **D-11:** Image downsizing via `image` package (pure Dart): max 1024px edge, JPEG quality 85. Bounded DB size.
- **D-12:** All paths stored relative to app documents directory. App reinstall = photos lost (acceptable; no cloud sync per PROJECT.md).

### Override hooks (Phases 5/9 integration)

- **D-13:** `PhotoOverrideSource` (Phase 5 stub interface) gets a real implementation `DriftPhotoOverrideSource` that queries `photo_tags` for entries matching the requested lexicon word. Returns the `image_path` if available, else `null` (round generator falls back to stock).
- **D-14:** Override frequency = 40% per round (PROJECT.md MATCH-04). Implemented via `Random.nextDouble() < 0.4` Bernoulli; per-round.
- **D-15:** Phase 9 numeracy activities (correspondence, subitizing, addition) also accept photo overrides for the depicted nouns (e.g. parent's dog photo → "Tveir [pet] koma"). Same override interface.

### Test strategy

- **D-16:** Unit: lexicon entry integrity, photo_tags DAO CRUD, image downsize correctness.
- **D-17:** Widget: PhotoUploadScreen flow with mocked image_picker.
- **D-18:** Migration test: schemaAt(1) populates v1 data → run migration → assert v2 schema correct + child_profile preserved.
- **D-19:** Integration: full photo flow (upload → tag → see in matching activity) using a fixture image.

### Privacy & no-network

- **D-20:** Photos NEVER leave the device. `tools/check-no-tracking.sh` may need extension to ensure no upload calls in image-handling code.
- **D-21:** No EXIF stripping in v1 — photos stored as-is. v2 hardening could strip EXIF for additional privacy.

### Pubspec additions

- **D-22:** New deps: `image_picker: ^X.X` (camera/gallery), `image: ^X.X` (downsize), `path_provider: ^X.X` (already may be present), `uuid: ^X.X` (for filenames). Verify versions at install. Re-run `tools/check-no-tracking.sh`.

### Claude's Discretion

- Exact starter lexicon list (~30 nouns)
- Pagination vs search vs alphabetical-grid in lexicon picker
- Photo grid vs list in PhotoUploadScreen

</decisions>

<canonical_refs>
- `.planning/PROJECT.md`, `REQUIREMENTS.md` PHOTO-01..07
- `.planning/phases/01-skeleton-drift-schema/01-SUMMARY.md` — Drift schema scaffolding
- `.planning/phases/05-letter-to-word-matching/05-SUMMARY.md` — PhotoOverrideSource interface
- `.planning/research/PITFALLS.md` Pitfall #11 (App Store Kids Category 5.1.4(b) — parental consent for photo collection beyond a hold-gate; for v2 public release path)
</canonical_refs>

<code_context>
- Reuses ParentGate from Phase 1 (PhotoUploadScreen behind gate)
- Reuses ParentSettingsScreen entry from Phase 4
- Reuses Drift AppDatabase, child_profiles_dao patterns
- Reuses Phase 5's PhotoOverrideSource interface (Phase 5 ships EmptyPhotoOverrideSource; Phase 10 ships DriftPhotoOverrideSource)
- New: lib/core/lexicon/, lib/features/parent_settings/photo_upload/
- pubspec.yaml: image_picker, image, uuid deps
- drift_schemas/v2.json: new schema snapshot
</code_context>

<deferred>
- Free-text photo tagging (parent types own Icelandic word + runtime TTS) → v2 (PERS-V2-01)
- Multi-child profiles → v2 (out of v1 scope per PROJECT.md)
- Cloud backup/sync → explicitly out of scope
- EXIF stripping → v2 hardening
- Apple Kids Category compliance review (App Store 5.1.4(b)) → v2 release path (REL-02)
- Parent-companion review screen showing what child has been tapping → v2 (PARENT-V2-01)
</deferred>

---

*Phase: 10 — Personalization Photo System*
*Context gathered: 2026-05-02*
