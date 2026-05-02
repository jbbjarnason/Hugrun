---
phase: 04
plan: 06
subsystem: home + welcome
tags: [flutter, riverpod, audio, phase-4]
key-files:
  created:
    - lib/features/home/welcome_narration_controller.dart
    - lib/features/home/welcome_narration_keys.dart
    - test/features/home/welcome_narration_controller_test.dart
    - test/features/home/welcome_narration_keys_test.dart
  modified:
    - lib/features/home/home_page.dart
    - test/features/home/home_page_test.dart
    - test/app/app_test.dart
decisions: [D-18, D-19, D-20, D-21]
---

# Phase 4 Plan 06: Welcome narration — Summary

The personalization payoff. Hugrún opens the app and hears "Halló Hugrún"
once. If a different child's name is set, hears the name-less "Halló"
variant (post-Phase-3) or falls back to the canonical clip with a debug
warning (Phase 2 stub state).

## Welcome narration flow

```
HomePage.initState
  → addPostFrameCallback
      → ref.read(welcomeNarrationControllerProvider.notifier).maybeFireOnce()

WelcomeNarrationController.maybeFireOnce
  → if _fired: return                       // D-19 once-per-session
  → _fired = true                            // claim BEFORE await for concurrency safety
  → name = await childNameProvider.future    // D-21 single-shot snapshot
  → key = selectWelcomeNarrationKey(name)
  → unawaited(audioEngine.play(key).catchError(swallow))   // fire-and-forget
```

`selectWelcomeNarrationKey` is pure:
- `name == 'Hugrún'` → `UtteranceKey.narrationWelcome` (the pre-baked Hugrún clip)
- otherwise → `UtteranceKey.values.where((k) => k.name == 'narrationWelcomeGeneric').firstOrNull` (post-Phase-3)
- if generic absent (Phase 2 stub) → fallback to `narrationWelcome` with debug warning

Reflection-style enum lookup means **no code change is required** when Phase 3 ships `narrationWelcomeGeneric` — the function starts returning the new key automatically.

## Tests added (9)

| File | Count | Coverage |
|------|-------|----------|
| welcome_narration_keys_test.dart | 5 | canonical → narrationWelcome, non-canonical → generic-or-fallback, null/empty/case-mismatch handled |
| welcome_narration_controller_test.dart | 4 | dispatches narrationWelcome for 'Hugrún', once-per-session (D-19), no re-trigger on name change (D-21), exception-safe |

## Decisions exercised

- **D-18:** Welcome narration uses child's name. Canonical 'Hugrún' → narrationWelcome; other → narrationWelcomeGeneric.
- **D-19:** Plays once per app session (controller's `_fired` flag survives navigation; HomePage initState calls `maybeFireOnce` on every mount but the second call is a no-op).
- **D-20:** childNameProvider watched by settings + read-via-future by welcome controller.
- **D-21:** No mid-session re-narration. Controller reads via `.future` (snapshot) NOT `.watch`; once-flag claimed before await.

## Requirements

- **PERS-03:** child's name used in at least one voice-over (welcome). Phase 2 stub state plays canonical clip for all names with debug warning; Phase 3 swap-in activates the generic variant for non-Hugrún names.

## Atomic commits

| Commit | Subject |
|--------|---------|
| 4e22da1 | test(04-06): add failing tests for welcome narration once-per-session controller |
| cfd510d | feat(04-06): once-per-session welcome narration with name-aware variant selection |

## Deviations

**[Rule 1 - Bug] Added `.catchError` to AudioEngine.play unawaited future.** The plan's `try/catch` on the synchronous code path doesn't catch errors that occur asynchronously inside the unawaited Future. Without the catch, a thrown error from a fake test engine surfaces as a zone-level uncaught exception. Wrapped the `.play()` Future in `.catchError` so test errors are swallowed cleanly.

**[Rule 1 - Bug] Tests need `_primeChildName` helper.** `childNameProvider.future` doesn't complete in unit tests because the in-memory Drift stream's first emission is async and the test container disposes before the listener subscribes. The helper adds an explicit `container.listen` first, waits for emission, then runs the controller logic.

**[Rule 1 - Bug] HugrunApp test (`test/app/app_test.dart`) needed Drift override.** Phase 1's app_test instantiates HugrunApp directly. Now that HomePage depends on childNameProvider (via WelcomeNarrationController), the default `appDatabaseProvider` runs and tries to open a real Drift DB which fails in widget tests. Added in-memory DB override + noop AudioEngine.

**Widget test "Welcome narration fires once on home mount" deferred to Plan 04-07.** The widget-test variant doesn't surface the Drift stream emission inside the fake-async window. The unit-level controller test verifies the dispatch, and Plan 04-07's integration_test runs against a real binding where the stream emission works.

Self-check: welcome_narration_controller + selectWelcomeNarrationKey + HomePage initState wiring all landed; 9 tests pass at unit level; 165 total tests pass.
