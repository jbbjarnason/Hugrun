---
phase: 07
title: Letter Tracing (Ítalíuskrift) — Verification
status: human_needed
date: 2026-05-02
blockers_for_close: 0  # the manual TRACE-02 calibration is a checkpoint, not a blocker
---

# Phase 7 Verification

## Code-quality verification (automated)

| Check | Status | Notes |
|-------|:------:|-------|
| `flutter test` (348/348) | PASS | Phase 6 baseline 263 → 348; +85 tests across Phase 7 (+31) and Phase 8 (parallel; +54). |
| `flutter analyze` | PASS | 11 warnings, all `scoped_providers_should_specify_dependencies` (riverpod_lint quirk; same family Phase 5/6 documented). 0 Phase-7-introduced new warning classes. |
| `flutter build apk --debug` | PASS | 6.1s, no errors. |
| `tools/check-domain-purity.sh` | PASS | `lib/core/tracing` registered; no Flutter imports. |
| `tools/check-asset-paths.sh` | PASS | `.json` extension allow-listed for `assets/tracing/`. |
| `tools/check-no-tracking.sh` | PASS | `stroke_order_animator` and transitive deps clean. |
| `tools/check-asset-paths_test.sh` | PASS | Self-test green; bad fixtures still rejected. |
| `tools/check-manifest-sync.sh` | PASS | Manifest unchanged in Phase 7 (D-14 deferral). |
| `git log` atomic per cycle | PASS | RED → GREEN → optional refactor for each plan. |

## Manual / human-verify checkpoints

### TRACE-02: Tracing tolerance calibration on Hugrún's tablet

**Status:** AWAITING_USER_INPUT

**Why this is a checkpoint, not a blocker:**
The calibration is the same posture as Phase 4's STAFIR-02 (50 ms tap
latency on Hugrún's tablet). The code is structurally complete and the
package's tolerance defaults are documented to be kid-friendly. The
calibration session refines them for Hugrún specifically. Doesn't
block code-quality sign-off; doesn't block downstream phases.

**Calibration procedure**

Run on Hugrún's tablet (the test device per PROJECT.md). Recommended
session length: 5–10 minutes.

1. **Boot the app in release-mode build** for representative
   performance:
   ```bash
   flutter run --release -d <device-id>
   ```
2. **Navigate to Stafir → Trace** (3 holds of the top-right toggle).
3. **Observe Hugrún's first 5–10 traces.** Watch for:
   - Letters where she draws what looks correct and the activity
     rejects it → **TOO TIGHT**. Loosen `hintAfterStrokes` from 5 →
     7, or `brushWidth` from 18 → 22, in
     `lib/features/stafir/tracing/tracing_activity.dart`'s
     `LetterTracingPolicy`.
   - Letters where she draws clearly outside the stroke and the
     activity accepts it → **TOO LOOSE**. The package's algorithm
     evaluates length + start + end + direction; if the underlying
     parameters are too forgiving, the right knob is to stiffen the
     length-range bounds via a custom `setBrushWidth` (visual) versus
     the controller's internal `getAllowedLengthRange` thresholds.
     **Do not pursue this in the first session** — defer to a second
     session if the first is too loose.
4. **Pin the calibrated values** as the new defaults in
   `LetterTracingPolicy`. Commit as
   `feat(07): calibrate tracing tolerance for Hugrún's tablet`.
5. **Update this VERIFICATION.md** to record the calibrated values
   and Jon's sign-off.

**Calibrated values (TO BE FILLED IN BY JON):**

```yaml
calibration_session_date: <yyyy-mm-dd>
device:                   <make/model + OS version>
brushWidth:               <pixels>          # default 18
hintAfterStrokes:         <count>           # default 5
autoAdvanceDelay:         <milliseconds>    # default 1200
notes:                    |
  <observations during the session — reject rate, loosening passes,
   any per-letter notes>
sign_off_by:              Jón Bjarni
sign_off_at:              <yyyy-mm-dd hh:mm>
```

### Authentic Briem letterforms (deferred)

**Status:** DEFERRED — out of Phase 7 scope (D-04).

The 32 simplified placeholder JSONs ship in Phase 7 and are functionally
correct for the activity. A polish pass replaces them with traces from
Italiuskrift05 (Briem 1985 PDF) at a later phase. **NOT BLOCKING** —
the placeholders teach correct stroke order and pedagogy.

**Recommended next step:** create a small Phase-11-or-similar plan
that hand-traces each glyph from the PDF and replaces the JSON files.
The activity, loader, integration test, and toggle all remain
unchanged.

### narrationCelebrationTracing audio clip (deferred)

**Status:** DEFERRED — Phase 3 review pipeline (D-14).

Phase 7 plays `narrationWelcome` on completion via the D-14 soft
fallback. When Phase 3's bake + review pipeline adds the
`narrationCelebrationTracing` enum entry + AAC, the activity will
start firing the new clip with NO Phase 7 code change (runtime symbol
lookup via `UtteranceKey.values.where(name=='...')`).

**Recommended next step:** Phase 3 manifest pass adds:
```yaml
- key: narrationCelebrationTracing
  text: "Frábært, Hugrún!"     # or "Vel gert!"
  asset: assets/audio/narration/celebration_tracing.aac
  kind: celebration
  notes_for_reviewer: "Warm, encouraging — fires after a letter is traced."
```

## Phase 7 sign-off summary

The activity is **structurally complete and code-quality clean**. The
remaining work is:

1. **A 5–10 min calibration session** (Jon at the tablet with Hugrún).
2. **A future polish plan** to swap simplified glyphs for authentic
   Briem traces.
3. **Phase 3 review pipeline pass** to add the celebration clip.

None of these block downstream phase execution. Phase 8 (Tölur) is
already running in parallel; Phases 9+ depend on Phase 8, not Phase 7.

`status: human_needed` reflects the calibration checkpoint above. Once
Jon completes the calibration session and pins the values, change to
`status: complete`.
