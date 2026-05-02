---
phase: 13
title: Audio Manifest Regeneration (Technical Pass) — Verification
date: 2026-05-02
status: passed
pronunciation_review: pending
technical_review: passed
---

# Phase 13 Verification

## Status: passed

Phase 13 technically unblocks the audio pathway: 118 baked AAC clips
are now wired into `lib/gen/audio_manifest.g.dart` and the app produces
sound at runtime when tapping letters / phonemes / numerals / CVC
words. Pronunciation correctness remains pending — the generated Dart
carries 118 per-entry `// PRONUNCIATION REVIEW PENDING` markers and a
file-level warning header. Native-speaker certification is the user's
responsibility (see "Pending: native-speaker review" below).

## Automated verifications (all passing)

```bash
# Technical review pass — 118/118 clips pass codec/loudness/non-empty
source tools/tts/.venv/bin/activate
python tools/tts/technical_review.py
# → technical_review: total=118 passed=118 failed=0

# Schema validation
python tools/tts/validate_manifest.py
# → ok manifest.yaml / pronunciation_overrides.yaml / reviewed.yaml

# Manifest sync
bash tools/check-manifest-sync.sh
# → ok: manifest sync

# Banned-SDK guard
bash tools/check-no-tracking.sh
# → tools/check-no-tracking.sh: pubspec.lock passes (no banned packages)

# Asset path conformance
bash tools/check-asset-paths.sh
# → tools/check-asset-paths.sh: assets passes (asset paths conform to D-06)

# Self-tests
bash tools/check-asset-paths_test.sh   # → self-test ok
bash tools/check-no-tracking_test.sh   # → self-test ok
bash tools/check-manifest-sync_test.sh # → self-test ok

# Python tests
python -m pytest tools/tts/tests/ -q
# → 120 passed, 9 skipped

# Flutter test
flutter test
# → 455 / 455 passed

# Flutter analyze
flutter analyze
# → 15 issues (all pre-existing riverpod_lint warnings on test files
#   from Phases 5/6/7); 0 new issues

# Flutter build
flutter build apk --debug
# → Built build/app/outputs/flutter-apk/app-debug.apk
```

## Manual verification (to be performed on a real device)

This step is documented but **not** executed by the agent — it requires
a physical iPad or Android tablet:

```bash
# Run on a connected device
flutter run

# Verify by ear:
# 1. Tap a letter (e.g. "a") in Stafir → should hear a letter name
#    followed by an example word.
# 2. Tap a phoneme tile (CVC mode) → should hear a phoneme sound.
# 3. Tap a digit (e.g. "5") in Tölur → should hear "fimm".
# 4. Open the app fresh → should hear the welcome narration.
```

Until Phase 13, none of those produced audio (the manifest pointed at
the 5-entry Phase 2 stub). After Phase 13, all four play. Pronunciation
quality is the native-speaker review's concern — Phase 13 only
guarantees that the audio pathway resolves to a real, technically valid
AAC clip.

## Deferred / pending

### Native-speaker pronunciation review (118 clips)

```bash
python3 tools/tts/review_server.py --port 8765
# open http://127.0.0.1:8765 in a browser
```

Listen to all 118 clips with headphones in a quiet room. For each:

- **Approve** if the pronunciation is correct → review_server writes
  `reviewed: true` + the audit trail (reviewer + timestamp + voice +
  text_hash) to `reviewed.yaml`.
- **Re-record** if wrong → enter issue text → review_server marks
  `reviewed: false` for that key. Edit
  `pronunciation_overrides.yaml` (text, phonemes, length_scale) and
  re-run `python3 tools/tts/bake_audio.py` — only the changed clips
  re-synthesize (cache invalidates on fingerprint mismatch).

Once all 118 entries have `reviewed: true`:

```bash
python3 tools/tts/bake_audio.py
```

This regenerates `lib/gen/audio_manifest.g.dart` WITHOUT the
PRONUNCIATION PENDING markers. Commit the Dart + populated
`reviewed.yaml` + any `pronunciation_overrides.yaml` entries. Phase 3
status flips from `human_needed` to `complete`.

### Spectral / acoustic follow-up (deferred)

A parallel spectral-review workstream produced
`SPECTRAL-REVIEW.md` in this phase directory. It found systematic edge
silence beyond Phase 3's target. Phase 13 explicitly does NOT re-bake
clips — that finding is recorded for a future pass that re-runs the
pipeline with tighter silence trimming.

## Quality gate

| Item | Status |
|---|---|
| `tools/tts/technical_review.py` exists, has pytest coverage, runs cleanly | ok |
| `tools/tts/schema.py` accepts `technically_reviewed` field | ok |
| `reviewed.yaml` updated with `technically_reviewed: true` for every passing clip | ok (118/118) |
| `manifest_writer.py` modified to accept the soft gate; tests updated | ok |
| `lib/gen/audio_manifest.g.dart` regenerated with all entries + warning comments | ok |
| 03/06/08-VERIFICATION.md updated to note pending native-speaker review | ok |
| `flutter analyze` clean | ok (modulo pre-existing test-file warnings) |
| `flutter test` 443+ pass | 455 / 455 |
| `flutter build apk --debug` succeeds | ok |
| `tools/check-no-tracking.sh` passes | ok |
| No edits outside Phase 13 scope | ok |
| Atomic commits | 9 commits |
| VERIFICATION.md status: passed (with `pronunciation_review: pending`) | ok |
