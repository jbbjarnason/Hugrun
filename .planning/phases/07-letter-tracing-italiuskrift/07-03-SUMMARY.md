---
phase: 07
plan: 07-03
title: TracingActivity widget + Riverpod providers
status: complete
date: 2026-05-02
tags: [phase-7, tracing, widget, riverpod, tdd]
requirements_satisfied:
  - TRACE-03  # soft stroke-order via package's hintAfterStrokes default
  - TRACE-04  # no failure state, no timer (asserted by widget tests)
  - TRACE-05  # celebration narration on completion (D-14 fallback chain)
requirements_pending:
  - TRACE-02  # tolerance calibration on Hugrún's tablet (manual checkpoint)
metrics:
  test-delta: +8 (widget tests)
  files-created: 3 (provider, activity, celebration helper)
  riverpod-providers-added: 2 (traceData FutureProvider; tracingCurrentLetter Notifier)
---

# Plan 07-03: TracingActivity widget + Riverpod providers — Summary

The Phase 7 letter-tracing activity. Composes the `stroke_order_animator`
package's `StrokeOrderAnimator` for the currently-active letter; on
round-complete fires celebration audio via AudioEngine and auto-advances
to a new random letter. No fail state, no timer, no progress UI.

## What was built

### lib/features/stafir/tracing/tracing_activity.dart (~180 lines)

`TracingActivity` is a `ConsumerStatefulWidget` with `TickerProviderStateMixin`
(required by the package's controller). State management:
- Reads the initial letter from `tracingCurrentLetterProvider`.
- Watches `traceDataProvider` (FutureProvider<Map<Letter, Glyph>>) and
  rebuilds the controller when the active glyph changes.
- Owns the `StrokeOrderAnimationController` lifecycle — disposes on
  unmount and on letter change.
- `onQuizCompleteCallback` fires `AudioEngine.play(celebration key)`
  + schedules a 1.2-second timer to advance to a different letter via
  `pickDifferentLetter`.

Test hooks (public; `@visibleForTesting`):
- `debugCurrentLetter` getter.
- `debugCompleteForTesting()` — re-enters the round-complete path
  without needing the package's private completion machinery.
- `debugWrongStrokeForTesting()` — explicitly a NO-OP. Encodes the
  TRACE-03 contract: wrong-stroke fires zero audio, zero negative UI.

`LetterTracingPolicy` — const class wrapping the 3 calibration knobs
(brushWidth=18, hintAfterStrokes=5, autoAdvanceDelay=1.2s). Pinned in
code so future calibration sessions on Hugrún's tablet edit one place.

### lib/features/stafir/tracing/trace_data_provider.dart (~95 lines)

Two providers (Riverpod 3.x patterns):
- `@Riverpod(keepAlive: true) Future<Map<Letter, TraceGlyph>> traceData(Ref)`
  — async loader; reads all 32 JSONs from rootBundle on first
  subscription; parsed map cached forever. Tests override with
  `Future.value(fixtureMap)` and skip the asset bundle entirely.
- `@Riverpod(keepAlive: true) class TracingCurrentLetter` — notifier
  wrapping the active letter. `build()` picks at random from
  `kIcelandicAlphabet`; `.set(letter)` advances the round.

Plus `pickDifferentLetter(exclude)` — biases against same-letter repeats
(loops up to 32 times to find a different letter; safety bound).

### lib/features/stafir/tracing/tracing_celebration.dart (~30 lines)

`selectCelebrationKey()` — D-14 fallback chain:
1. `narrationCelebrationTracing` if it exists in the enum (Phase 3
   review pipeline will add this when a celebration clip is baked).
2. `narrationWelcome` as the always-present soft fallback.

The lookup uses runtime `UtteranceKey.values.where(...)` to detect the
preferred symbol's presence — same pattern as
`selectWelcomeNarrationKey`. AudioEngine's missing-clip stub-fallback
silently no-ops if the chosen key is absent from `kAudioManifest`.

## Tests (8 passing)

- T0a: `selectCelebrationKey` returns a non-null UtteranceKey.
- T0b: returned key is either `narrationCelebrationTracing` (if in enum)
  or `narrationWelcome` (fallback).
- T1: activity mounts a `StrokeOrderAnimator` for the active letter.
- T2: no LinearProgressIndicator/CircularProgressIndicator/error
  icons / cancel icons in the widget tree.
- T3: no instruction-y Text widgets ("try", "start", "begin").
- T4: simulated quiz-complete fires AudioEngine.play with the
  celebration key.
- T5: after completion, the active letter changes (auto-advance picks
  a different letter within 5 attempts — guards against the rare
  same-letter re-roll).
- T6: simulated wrong-stroke fires NO audio and produces NO error
  chrome.

## Architectural commitments — preserved

- **Reuse-not-duplicate** — AudioEngine, ParentGateController (via
  StafirModeToggle wrapping it), kIcelandicAlphabet, the existing
  StafirRoom switch arm pattern. No fork-and-modify.
- **No fail-state UI** — 0 stars, 0 trophies, 0 score numbers, 0 timers.
  Tests T2, T3, T6 all assert.
- **Soft order (TRACE-03)** — relies on the package's
  `hintAfterStrokes=5` default behavior; activity never blocks input.
- **D-14 silent fallback** — `narrationCelebrationTracing` not in the
  enum yet (Phase 7 stays out of the manifest review pipeline);
  activity is structurally functional but plays the welcome clip in
  the meantime — exactly the documented contract.

## Deviations from plan

### Library API surface (minor)
The research dump described the package's controller with
`hintAfterStrokes` parameter — confirmed in source. Tolerance algorithm
is a four-check rule (length + start + end + direction), exactly as
documented. **No deviations.**

### Riverpod 3.x scoping (minor)
Initial draft used `StateProvider` / `Override` types from Riverpod 2;
the 3.x family in this project has dropped those. **Adapted:** switched
`tracingCurrentLetterProvider` to `@Riverpod` Notifier-class codegen;
test override pattern uses a `_ForcedLetterNotifier` subclass.
Documented inline.

## Files changed

### Created (lib/)
- `lib/features/stafir/tracing/tracing_activity.dart`
- `lib/features/stafir/tracing/trace_data_provider.dart`
- `lib/features/stafir/tracing/trace_data_provider.g.dart` (gitignored)
- `lib/features/stafir/tracing/tracing_celebration.dart`

### Created (test/)
- `test/features/stafir/tracing/tracing_activity_test.dart`

## Commits

- `f904a11 test(07-03): add failing tests for TracingActivity widget (RED)`
- `8d365ac feat(07-03): implement TracingActivity widget + Riverpod providers (GREEN)`
- `65bb880 refactor(07): remove unused imports + dead code from Phase 7 tests/widget`

## Self-Check: PASSED
