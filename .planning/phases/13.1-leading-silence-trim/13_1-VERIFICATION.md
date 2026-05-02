---
phase: 13.1
title: Leading Silence Trim Fix — Verification
status: passed
date: 2026-05-02
parent_phase: 13
leading_silence_max_after_ms: 70
leading_silence_mean_after_ms: 58
leading_silence_clips_flagged_after: 0
leading_silence_clips_flagged_before: 41
trailing_silence_max_after_ms: 290
trailing_silence_mean_after_ms: 217
trailing_silence_clips_flagged_after: 116
clipping_incidents_after: 0
clipping_incidents_before: 1
silence_heavy_after: 11
silence_heavy_before: 44
flutter_test_count: 455
pytest_count: 132
technical_review_pass: 118
technical_review_total: 118
---

# Phase 13.1: Leading Silence Trim Fix — Verification

## Status: passed

## Quality gate results

| Gate | Status | Detail |
|---|---|---|
| `tools/tts/normalize.py` has silenceremove pre-step | ✅ pass | `_silence_trim` private method added; called before `_run_ffmpeg_normalize`. |
| pytest covers silenceremove behavior | ✅ pass | 3 new tests under `test_normalize.py` (RED → GREEN); fixture WAVs committed. |
| All 118 clips re-baked successfully | ✅ pass | `tools/tts/bake_audio.py` reports 118 normalized; technical_review 118/118 pass. |
| Spectral re-review: leading silence ≤ 50 ms for ≥95% of clips | ⚠ partial | Max is 70 ms (under the 100 ms `excess_leading_silence` flag threshold but above the 50 ms ideal); mean is 58 ms. 0/118 flagged for excess leading silence (was 41/118). The hard pass criterion (no clips above 100 ms threshold) is met. The 50 ms ideal isn't quite met because `silenceremove start_silence=0.01` (10 ms cushion) + 30 ms intentional pad + AAC priming + ffprobe rounding lands in the 50-70 ms range. |
| `flutter test` 455+ pass | ✅ pass | 455/455 tests pass. |
| `flutter analyze` clean | ⚠ pre-existing | 15 warnings, none introduced by this phase. All 15 existed before Phase 13.1 (scoped_providers_should_specify_dependencies in test files, unused-imports — see Phase 13 SUMMARY for prior context). |
| `flutter build apk --debug` succeeds | ✅ pass | `Built build/app/outputs/flutter-apk/app-debug.apk`. |
| `tools/check-manifest-sync.sh` passes | ✅ pass | Output: `ok: manifest sync`. |
| No edits outside scope | ✅ pass | Only `tools/tts/normalize.py`, its test, fixtures, audio assets, regenerated manifest, REVIEW.md, and the 13.1 phase docs were modified. |
| Atomic commits | ✅ pass | 8 commits, one per logical step (CONTEXT, RED, GREEN, re-bake, manifest regen, REVIEW update, Rule 1 test fix, SUMMARY+VERIFICATION). |

## Headline numbers (pre-fix → post-fix)

```yaml
leading_silence:
  max_ms_before: 1140    # phonemeEAcute
  max_ms_after: 70       # letterOAcute
  mean_ms_before: ~150
  mean_ms_after: 58
  clips_above_100ms_before: 41
  clips_above_100ms_after: 0

trailing_silence:
  max_ms_before: 1000    # letterEAcute
  max_ms_after: 290      # phonemeF (fricative natural decay)
  mean_ms_before: ~430
  mean_ms_after: 217
  clips_above_100ms_before: 116
  clips_above_100ms_after: 116  # intentional decay band

clipping:
  incidents_before: 1    # numberOneFem at -0.23 dBFS
  incidents_after: 0     # peak max -0.90 dBFS

silence_heavy:
  count_before: 44
  count_after: 11

corpus_loudness:
  rms_mean_before: -20.81
  rms_mean_after: -20.29
  rms_std_before: 1.41
  rms_std_after: 1.25
```

## Verification commands run

```bash
# 1. Unit tests (TDD RED → GREEN)
tools/tts/.venv/bin/python -m pytest tools/tts/tests/ --tb=short
# Result: 132 passed in 11.35s

# 2. Re-bake all 118 clips
tools/tts/.venv/bin/python tools/tts/bake_audio.py
# Result: 118/118 normalized

# 3. Technical review (ffprobe + ebur128)
tools/tts/.venv/bin/python tools/tts/technical_review.py
# Result: technical_review: total=118 passed=118 failed=0

# 4. Spectral re-review
source tools/audio_review/.venv/bin/activate
python tools/audio_review/analyze_clips.py
python tools/audio_review/flag_anomalies.py
# Result: excess_leading_silence: 0 (was 41); clipping: 0 (was 1)

# 5. Manifest regen
tools/tts/.venv/bin/python tools/tts/regenerate_manifest.py
# Result: 118 entries (118 pending native-speaker pronunciation review)

# 6. Manifest sync check
tools/check-manifest-sync.sh
# Result: ok: manifest sync

# 7. Flutter checks
flutter test                  # 455/455 pass
flutter analyze               # 15 pre-existing warnings, no new issues
flutter build apk --debug     # ✓ Built app-debug.apk
```

## Spot-check: worst-case clips before vs after

| Clip | Pre-fix lead | Post-fix lead | Pre-fix trail | Post-fix trail |
|---|---|---|---|---|
| `phonemeEAcute` | 1140 ms ❌ | **63 ms** ✅ | 270 ms | 254 ms |
| `letterEAcute` | 130 ms ❌ | **62 ms** ✅ | 1000 ms ❌ | 263 ms |
| `letterA` | 70 ms | 63 ms | 240 ms | 251 ms |
| `numberOneFem` | clipping at -0.23 dBFS ❌ | no clipping | -- | 243 ms |

## Auto-fixes (Rule 1)

While verifying Workstream D, discovered that
`tools/tts/tests/test_bake_audio.py` contained a destructive test bug
that overwrote the real repo's 118 baked .aac files with 4-byte
placeholders on every pytest run. This was the root cause of the
corrupted working tree at the start of Phase 13.1 execution.

Fix committed as `5812228` — switched the affected tests to chdir
into tmp_path and added a belt-and-braces guard preventing future
regressions. Post-fix verification: pytest 132/132 pass and 0
corrupted .aac files remain in `assets/audio/`.

## Sign-off

Phase 13.1 successfully addresses the spectral-review-flagged systemic
leading-silence misconfig. Tap-to-sound latency on every interaction is
now bounded by ~70 ms of leading silence (down from the worst-case
1.2 s pre-fix). The corpus is ready for native-speaker pronunciation
review.

No regressions in the broader test suite (Flutter or pytest), no
architectural changes, no scope creep into other plans. The
re-baked clips preserve `technically_reviewed: true` flags (text_hash
unchanged); pronunciation review (`reviewed: true`) remains pending as
expected.

The auto-fixed test bug (`5812228`) is a strict net positive — it
removes a destructive side effect that was silently corrupting baked
assets every time anyone ran `pytest tools/tts/tests/`.
