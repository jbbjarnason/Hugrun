---
phase: 03-tts-pipeline-audio-review-tooling
plan: 07
type: execute
wave: 6
depends_on: ["03-04", "03-05", "03-06"]
files_modified:
  - assets/audio/letters/names/*.aac           # 32 files
  - assets/audio/letters/words/*.aac           # 32 files
  - assets/audio/narration/welcome_hugrun.aac  # 1 file (overwrites Phase 2 placeholder)
  - lib/gen/audio_manifest.g.dart              # regenerated (post-review)
  - lib/core/manifest/utterance_key.dart       # regenerated (32 → 65 enum entries)
  - reviewed.yaml                              # populated entry-by-entry by Plan 05's UI
  - pronunciation_overrides.yaml               # may grow during review pass
  - test/core/manifest/audio_manifest_test.dart  # extended for 65-entry exhaustive checks
  - tools/tts/last-run.json  # not committed (gitignored)
autonomous: false
requirements:
  - AUDIO-02
  - AUDIO-03
  - AUDIO-04
  - AUDIO-05
  - AUDIO-06
  - AUDIO-08
  - AUDIO-09
user_setup:
  - service: tiro_tts
    why: "Plan 07 makes ~65 live calls to Tiro Diljá v2. TIRO_API_KEY required ONLY if Plan 01 confirmed Tiro requires auth (currently MEDIUM-confidence: appears unauthenticated)."
    env_vars:
      - name: TIRO_API_KEY
        source: "Tiro TTS contact (only if Plan 01's spike proved auth is required)"

must_haves:
  truths:
    - "Running `python tools/tts/bake_audio.py` end-to-end against live Tiro produces 65 AAC files under assets/audio/ — all -19 LUFS / -1 dBTP, AAC-LC mono 96 kbps 48 kHz M4A, 30 ms leading silence, no LUFS rejects"
    - "Plan 05's review server has been started and the user (Jon) has approved or marked re-record on every one of the 65 utterances; reviewed.yaml is complete with reviewed: true for every manifest key (or has overrides queued in pronunciation_overrides.yaml for re-record requests)"
    - "After review pass + any re-record cycles, `python tools/tts/bake_audio.py` regenerates lib/gen/audio_manifest.g.dart and lib/core/manifest/utterance_key.dart with all 65 entries"
    - "test/core/manifest/audio_manifest_test.dart is extended to cover 65 entries (was 5 in Phase 2) — exhaustive switch, all paths exist on disk, all paths conform to D-06"
    - "After Plan 07 completes, tools/check-manifest-sync.sh switches from `skip(03-06):` to `ok: manifest sync` (the not-yet-baked carve-out no longer triggers)"
    - "flutter test passes the new ≥17-entry audio_manifest_test (5 pre-existing + ≥12 new exhaustive checks); flutter build apk --debug still succeeds"
  artifacts:
    - path: assets/audio/letters/names/*.aac
      provides: "32 letter-name AAC clips (one per Icelandic letter)"
      min_lines: 0  # binary files
    - path: assets/audio/letters/words/*.aac
      provides: "32 example-word AAC clips"
    - path: assets/audio/narration/welcome_hugrun.aac
      provides: "Welcome narration (overwrites Phase 2 placeholder)"
    - path: lib/gen/audio_manifest.g.dart
      provides: "Regenerated 65-entry compile-time manifest (replaces Phase 2's 5-entry hand-written stub)"
      contains: "letterA"
    - path: lib/core/manifest/utterance_key.dart
      provides: "Regenerated 65-entry UtteranceKey enum (replaces Phase 2's 5-entry hand-written enum)"
      contains: "enum UtteranceKey"
    - path: reviewed.yaml
      provides: "Reviewer sign-off log — 65 reviewed: true entries"
      contains: "letterA"
  key_links:
    - from: lib/gen/audio_manifest.g.dart
      to: assets/audio/letters/names/*.aac, assets/audio/letters/words/*.aac, assets/audio/narration/welcome_hugrun.aac
      via: "Each kAudioManifest entry's path field points to a real AAC file on disk"
      pattern: "assets/audio/"
    - from: test/core/manifest/audio_manifest_test.dart
      to: kAudioManifest + UtteranceKey
      via: "Exhaustive switch test + File(path).existsSync() loop"
      pattern: "kAudioManifest|UtteranceKey"
---

<objective>
Run the Phase 3 pipeline end-to-end for the first time, complete the native-speaker review pass, and ship the regenerated manifest:

1. **Run `python tools/tts/bake_audio.py`** against the live Tiro TTS API. The pipeline calls Diljá v2 for all 65 utterances → ~65 raw WAVs cached in `_raw/` → ~65 AAC files written under `assets/audio/...` → review gate BLOCKS the manifest write because reviewed.yaml is empty.

2. **Open the review UI** (`python tools/tts/review_server.py`). Listen to every clip in a quiet room with headphones (per research finding 2 — mandatory 100% native-speaker review). Per utterance:
   - **Approve** if pronunciation is correct → reviewed.yaml gains an entry with `reviewed: true` + text_hash.
   - **Re-record** if pronunciation is wrong → reviewed.yaml records `reviewed: false` + issue text; the user manually edits `pronunciation_overrides.yaml` to add an SSML or text-substitution override (Plan 03's tiro_client picks it up); re-run `bake_audio.py` to re-synthesize that key only (cache invalidates because the override changed `used_text`).
   - Iterate until every clip is approved.

3. **Re-run `python tools/tts/bake_audio.py`** with reviewed.yaml fully populated. The review gate now passes. `manifest_writer` regenerates `lib/gen/audio_manifest.g.dart` (5 entries → 65 entries) and `lib/core/manifest/utterance_key.dart` (5 enum members → 65). `assets/audio/letters/names/eth.aac`, `letters/words/hundur.aac`, `narration/welcome_hugrun.aac` overwrite the Phase 2 placeholder bytes with real audio.

4. **Extend `test/core/manifest/audio_manifest_test.dart`** to cover the 65-entry world:
   - `kAudioManifest.length == 65`
   - `UtteranceKey.values.length == 65`
   - All 65 paths exist on disk (`File(asset.path).existsSync()`)
   - All 65 paths conform to D-06 (`assets/audio/[a-z0-9._/-]+\.aac`)
   - The Phase 2 stub keys (`letterA, letterEth, letterThorn, wordHundur, narrationWelcome`) are still present (D-22 invariant — guard against future regressions)
   - Exhaustive switch on UtteranceKey returns the right asset for each
   - All 32 example-word entries' `starts_with` field matches the first letter of the spoken word (cross-checked via a manifest.yaml read at test time — keeps the invariant honest as words change)

5. **Verify CI guard switches state**: `bash tools/check-manifest-sync.sh` no longer prints `skip(03-06):` — it runs the full check and exits 0 with `ok: manifest sync`.

6. **Verify Flutter build**: `flutter build apk --debug` and `flutter build ios --no-codesign --debug` succeed with the regenerated manifest + 65 real AAC files.

This plan is **autonomous: false** — Task 2's review pass is a human-driven activity that may take 30–90 minutes depending on how many re-records are needed. Phase 3 will status as `human_needed` until the review pass completes; this is acknowledged and acceptable per the planning context.

Output:
- 65 real AAC files committed to `assets/audio/` (overwriting the 5 Phase 2 placeholders).
- Regenerated `lib/gen/audio_manifest.g.dart` (5 → 65 entries) committed.
- Regenerated `lib/core/manifest/utterance_key.dart` (5 → 65 enum members) committed.
- Populated `reviewed.yaml` (65 reviewed: true entries) committed.
- Possibly populated `pronunciation_overrides.yaml` (re-record overrides) committed.
- Extended `test/core/manifest/audio_manifest_test.dart` covering the 65-entry invariants.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-CONTEXT.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-01-SUMMARY.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-02-SUMMARY.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-03-SUMMARY.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-04-SUMMARY.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-05-SUMMARY.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-06-SUMMARY.md
@manifest.yaml
@reviewed.yaml
@pronunciation_overrides.yaml
@tools/tts/README.md
@lib/gen/audio_manifest.g.dart  # Phase 2 stub — about to be overwritten
@test/core/manifest/audio_manifest_test.dart  # Phase 2 — to be extended
@.planning/research/PITFALLS.md  # Pitfall 1 — mandatory review

<interfaces>
<!-- The full Phase 2 audio_manifest_test.dart structure that this plan extends. -->

Phase 2 test file structure (extend, do not replace):
```dart
// test/core/manifest/audio_manifest_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/manifest/audio_asset.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/gen/audio_manifest.g.dart';

void main() {
  group('audio manifest', () {
    test('contains all UtteranceKey values', () { ... });
    test('all paths exist on disk', () { ... });
    test('all paths conform to D-06', () { ... });
    test('getAudioAsset returns correct asset for each key', () { ... });
    test('exhaustive switch covers every key', () { ... });
    // ... 8 tests in Phase 2
  });
}
```

After Plan 07, the test file should have additional tests like:
```dart
test('manifest has exactly 65 entries (Phase 3)', () {
  expect(kAudioManifest.length, 65);
  expect(UtteranceKey.values.length, 65);
});

test('Phase 2 stub keys are preserved (D-22 invariant)', () {
  const stubKeys = [
    UtteranceKey.letterA,
    UtteranceKey.letterEth,
    UtteranceKey.letterThorn,
    UtteranceKey.wordHundur,
    UtteranceKey.narrationWelcome,
  ];
  for (final k in stubKeys) {
    expect(kAudioManifest.containsKey(k), isTrue, reason: 'Phase 2 stub key $k missing');
  }
});

test('letter-name asset paths follow letters/names/{slug}.aac', () { ... });
test('example-word asset paths follow letters/words/{slug}.aac', () { ... });
test('starts_with matches the first letter of every example word', () {
  // Read manifest.yaml at test time. Use package:yaml.
  // For each entry with kind=='example_word':
  //   - load text + starts_with
  //   - assert text.startsWith(starts_with) (Icelandic-correct, NOT ASCII-collapsed)
});
```

Tiro real-call cost estimate (informational, not a constraint):
- 65 calls × ~2–3 seconds per call (with 1 req/sec rate limit + Tiro server response time) = ~3–5 minutes wall clock for the synthesis stage.
- Normalize stage: ~65 × ~0.5–1 seconds per ffmpeg pass = ~1–2 minutes.
- Manual review: ~10–30 seconds per clip × 65 = 11–32 minutes uninterrupted; longer with re-record cycles.
- Re-record cycles: each problem word triggers (override edit) → (single-utterance bake) → (re-listen). Budget 5–10 problem words × ~3 minutes each = 15–30 minutes.
- Total Plan 07 budget: 60–90 minutes for the human-in-the-loop portion.

The full Plan 07 commit count is therefore high-variance (4–10 commits) and split across two contexts: the executor's session (Tasks 1, 3, 4 — automated) and the user's review session (Task 2 — manual, may span days).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Run bake_audio.py end-to-end (synthesis + normalize, BLOCKED on review gate)</name>
  <files>
    assets/audio/letters/names/*.aac     # 32 files
    assets/audio/letters/words/*.aac     # 32 files
    assets/audio/narration/welcome_hugrun.aac
    tools/tts/_raw/                      # gitignored — local cache only
    tools/tts/last-run.json              # gitignored
  </files>
  <action>
    1. **Pre-flight checks**:
       - `python3 tools/tts/check_deps.py` → exit 0.
       - `python3 tools/tts/validate_manifest.py` → exit 0.
       - `python3 tools/tts/bake_audio.py --plan` → see classification: 60 keys TO_GENERATE (the new ones); 5 keys CACHED-or-TO_REGENERATE depending on whether the Phase 2 placeholder bytes match the cache fingerprint (they likely don't, since they're identical 15-byte blobs not real Tiro output — bake_audio will regenerate them).

    2. **Confirm Tiro readiness**:
       - Re-run `python3 tools/tts/tiro_spike.py` once to confirm Tiro is still reachable + Diljá v2 still exists. (Network conditions may have changed since Plan 01.)
       - If Tiro is unreachable now: STOP, escalate. The user may need to wait until Tiro is available or pivot to Azure Neural TTS (PROJECT.md fallback).

    3. **Run end-to-end**:
       ```bash
       python3 tools/tts/bake_audio.py 2>&1 | tee tools/tts/_raw/last-run.log
       ```
       Expected behavior:
       - Synthesis stage: 65 successful Tiro calls (or fewer if any 4xx/5xx — record failures and retry the failed keys with `python3 tools/tts/bake_audio.py --keys "<failed_keys_csv>"` if such a flag is implemented; otherwise full retry uses cache so failed keys re-attempt).
       - Normalize stage: 65 successful normalizations. **The ±0.5 LU reject (D-11) is the load-bearing test of normalize**. If any clip fails this check, investigate: (a) is Tiro returning extremely quiet output for some inputs? (b) is the source clip too short for ffmpeg-normalize to measure? Fix per-clip via override (e.g. force a longer text, or add SSML pause) — do NOT relax the ±0.5 LU bound.
       - Review gate: BLOCKS. last-run.json shows `manifest_written: false` and `blocked_on_review: [<all 65 keys>]`. Exit code is 1.

    4. **STOP CONDITIONS** (escalate to user):
       - >5 utterances fail Tiro synthesis (suggests systemic problem: rate limit, auth change, voice removed).
       - >2 utterances fail normalize ±0.5 LU reject (suggests source-quality issue across many clips, not a single bad word).
       - Pipeline crashes with an unhandled exception (this is a Plan 03 / Plan 04 bug to file before continuing).

    5. **Verify the AAC files exist**:
       ```bash
       ls assets/audio/letters/names/ | wc -l   # → 33 (32 + .gitkeep)
       ls assets/audio/letters/words/ | wc -l   # → 33
       ls assets/audio/narration/                # → welcome_hugrun.aac + .gitkeep
       ```

    6. **Verify the AAC files conform to D-06 path conventions** (Phase 2's existing CI guard):
       ```bash
       bash tools/check-asset-paths.sh
       ```
       Expected: ok. Bake_audio's manifest_writer writes paths from manifest.yaml (validated by Plan 02 schema), which are already D-06 compliant.

    7. **Do NOT commit yet** — Tasks 2 and 3 produce the real reviewed manifest. The current AAC files are baked but unreviewed; committing now without reviewed.yaml entries would leave the repo in a state where `bash tools/check-manifest-sync.sh` would FAIL (the not-yet-baked carve-out detects "Dart matches stub AND reviewed empty"; once the AAC files are baked AND committed without review, the carve-out no longer matches and the guard would demand reviewed.yaml).

       Instead, leave the AAC files uncommitted in the working tree. Task 2's review server reads them from disk (which works regardless of git state). After Task 3 completes, all four artifact groups (AAC files + reviewed.yaml + audio_manifest.g.dart + utterance_key.dart) commit together as one atomic "Phase 3 ships" commit (Task 4).

    Atomic commit count for Task 1: 0 (no commits — synthesis output sits in working tree until reviewed).
  </action>
  <verify>
    <automated>ls -1 assets/audio/letters/names/*.aac | wc -l | grep -qE '^\s*32\s*$' && ls -1 assets/audio/letters/words/*.aac | wc -l | grep -qE '^\s*32\s*$' && ls assets/audio/narration/welcome_hugrun.aac && bash tools/check-asset-paths.sh && python3 -c "import json; r=json.load(open('tools/tts/last-run.json')); assert r['stages']['manifest_written'] is False; assert len(r['stages']['blocked_on_review']) == 65"</automated>
  </verify>
  <done>
    65 real AAC files exist in the working tree under `assets/audio/...`. `tools/tts/last-run.json` reports `manifest_written: false` with all 65 keys in `blocked_on_review`. `lib/gen/audio_manifest.g.dart` is unchanged from Phase 2's 5-entry stub. `bash tools/check-asset-paths.sh` passes.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Native-speaker review pass — Jon listens to every clip and signs off</name>
  <what-built>
    65 real Tiro Diljá v2 audio clips are baked under `assets/audio/...`. The review server is ready to display them. Phase 3's review gate is blocking the manifest regeneration until reviewed.yaml is fully populated. The pipeline is operationally complete — the only remaining work is the human review per research finding 2 ("mandatory 100% native-speaker review of every audio clip — no spot-checks").
  </what-built>
  <how-to-verify>
    1. Start the review server:
       ```bash
       python3 tools/tts/review_server.py --port 8765
       ```
    2. Open http://127.0.0.1:8765 in a browser. Confirm 65 rows render, each with an audio player and Approve / Re-record buttons.
    3. **Quiet room. Headphones.** Per research PITFALL #1: a single botched ð / þ / æ / loanword destroys trust. Listen to each clip with full attention. The reviewer is the user (Jon) per D-30.
    4. For each utterance:
       - **Pronunciation correct** → click Approve. The row turns green; the next unreviewed row scrolls into view automatically.
       - **Pronunciation wrong** → click Re-record. Enter the issue ("ð sounds like d", "vowels clipped", "Hugrún name pronounced wrong", etc.). Then manually edit `pronunciation_overrides.yaml` to add an override:
         ```yaml
         overrides:
           letterEth:
             ssml: '<phoneme alphabet="ipa" ph="ɛð">eð</phoneme>'   # if Tiro SSML works (Plan 01 verified)
           # OR fall back to text substitution if SSML unsupported:
           wordHundur:
             text: "hund-ur"
         ```
         Save the file.
       - After all re-records are queued, in a separate terminal, re-run `python3 tools/tts/bake_audio.py` (the cache will regenerate ONLY the affected keys because `used_text` changed → fingerprint mismatch → cache miss). The new clips overwrite under `assets/audio/...`. Refresh the browser. Listen again. Approve.
       - Iterate until every row is green.

    5. **Pay particular attention to**:
       - `letterEth` (ð) — must be the voiced dental fricative, not a `d` sound.
       - `letterThorn` (þ) — must be the voiceless dental fricative, not a `t` sound.
       - `letterAe` (æ) — distinct from `e`.
       - `letterOumlaut` (ö) — distinct from `o`.
       - `letterX`, `wordX` — Icelandic rarely uses x word-initially; expect mispronunciation, expect to need an override.
       - Words containing `Hugrún` (specifically `narrationWelcome`) — proper noun, hot spot for TTS errors.
       - Pre-aspiration in double consonants (e.g. `hattur`, `kötturinn` — not in this manifest, but watch for it if present in any phrase).
       - Any English/Danish phonology bleeding through (research PITFALL #1).

    6. **STOP CONDITIONS** (escalate, not auto-resolve):
       - >10 clips need re-recording on first pass → indicates systemic Tiro voice issue. Consider whether Diljá v2 is the right narrator (PROJECT.md backup: Álfur v2 / Bjartur / Rósa, or Microsoft Azure Gudrun/Gunnar fallback).
       - A clip's pronunciation is debated (e.g. is the spoken letter name "be" or "bé"? "ess" or "es"?) — escalate to a second native speaker if available; otherwise pick the form most consistent with current MMS materials and document the choice in `notes` of the reviewed.yaml entry.
       - Tiro returns degraded quality on a re-synthesis (rate limited, voice update mid-session, etc.) — pause and resume later.

    7. After every row is green:
       - Check the status endpoint: `curl http://127.0.0.1:8765/status` should return `{"total": 65, "reviewed": 65, "blocked": 0, ...}`.
       - Stop the review server (Ctrl-C).
       - Type **approved** below to release Tasks 3 and 4.

    8. If you abandon the review pass (e.g. need to come back tomorrow): commit `reviewed.yaml` and `pronunciation_overrides.yaml` partial state IF you've done a meaningful chunk; mention "partial review pass — N/65 reviewed" in the commit message. The manifest writer still won't run (review gate still blocks), but you don't lose the work-in-progress sign-offs. The CI guard's not-yet-baked carve-out will continue to skip until the full pass completes (because lib/gen/audio_manifest.g.dart still matches the Phase 2 stub).
  </how-to-verify>
  <resume-signal>Type "approved" once reviewed.yaml has reviewed: true for all 65 keys (and any re-records are resolved). Otherwise describe what's blocking and pause.</resume-signal>
</task>

<task type="auto">
  <name>Task 3: Re-run bake_audio with full reviewed.yaml → regenerate Dart manifest + extend tests</name>
  <files>
    lib/gen/audio_manifest.g.dart           # 5 → 65 entries
    lib/core/manifest/utterance_key.dart    # 5 → 65 enum members
    test/core/manifest/audio_manifest_test.dart   # +≥7 new tests
  </files>
  <action>
    1. **Re-run the pipeline** with reviewed.yaml fully populated:
       ```bash
       python3 tools/tts/bake_audio.py
       ```
       Expected behavior:
       - Plan stage: 65 entries CACHED (no Tiro calls — `_raw/` cache + AAC outputs all match fingerprints).
       - Normalize stage: skipped for cached entries (the AAC files already exist on disk and pass the cache check).
       - Review gate: PASSES — every key has reviewed: true with matching text_hash.
       - Manifest stage: `lib/gen/audio_manifest.g.dart` and `lib/core/manifest/utterance_key.dart` regenerated with 65 entries each, sorted alphabetically by key for diff stability.
       - last-run.json: `manifest_written: true`, exit code 0.

    2. **Verify the regenerated files**:
       ```bash
       grep -c 'UtteranceKey\.' lib/gen/audio_manifest.g.dart    # → 130 (65 entries × ~2 mentions each)
       grep -cE '^  [a-z][A-Za-z0-9]+,' lib/core/manifest/utterance_key.dart  # → 65
       ```

    3. **Verify Phase 2 backward compatibility (D-22)** — the 5 stub keys are still present:
       ```bash
       for k in letterA letterEth letterThorn wordHundur narrationWelcome; do
         grep -q "UtteranceKey\.$k" lib/gen/audio_manifest.g.dart || echo "MISSING: $k"
         grep -q "^  $k," lib/core/manifest/utterance_key.dart || echo "MISSING ENUM: $k"
       done
       ```
       Empty output = ok.

    4. **Extend `test/core/manifest/audio_manifest_test.dart`**:

       Read the existing Phase 2 test file. Keep all existing test cases (they should still pass). ADD the following tests inside the existing `group('audio manifest', ...)`:

       ```dart
       test('manifest has exactly 65 entries (Phase 3)', () {
         expect(kAudioManifest.length, 65);
         expect(UtteranceKey.values.length, 65);
       });

       test('all UtteranceKey values are mapped (no gaps)', () {
         for (final key in UtteranceKey.values) {
           expect(kAudioManifest.containsKey(key), isTrue, reason: 'Missing manifest entry for $key');
         }
       });

       test('Phase 2 stub keys preserved (D-22)', () {
         const stub = [
           UtteranceKey.letterA,
           UtteranceKey.letterEth,
           UtteranceKey.letterThorn,
           UtteranceKey.wordHundur,
           UtteranceKey.narrationWelcome,
         ];
         for (final k in stub) {
           expect(kAudioManifest.containsKey(k), isTrue);
         }
         // Path stability — the regenerated paths for stub keys MUST match the Phase 2 paths
         expect(kAudioManifest[UtteranceKey.letterA]!.path, 'assets/audio/letters/names/a.aac');
         expect(kAudioManifest[UtteranceKey.letterEth]!.path, 'assets/audio/letters/names/eth.aac');
         expect(kAudioManifest[UtteranceKey.letterThorn]!.path, 'assets/audio/letters/names/thorn.aac');
         expect(kAudioManifest[UtteranceKey.wordHundur]!.path, 'assets/audio/letters/words/hundur.aac');
         expect(kAudioManifest[UtteranceKey.narrationWelcome]!.path, 'assets/audio/narration/welcome_hugrun.aac');
       });

       test('all 65 audio asset files exist on disk', () {
         for (final asset in kAudioManifest.values) {
           expect(File(asset.path).existsSync(), isTrue, reason: '${asset.path} missing on disk');
         }
       });

       test('all 65 paths conform to D-06 (lowercase ASCII slug + .aac)', () {
         final regex = RegExp(r'^assets/audio/[a-z0-9._/-]+\.aac$');
         for (final asset in kAudioManifest.values) {
           expect(regex.hasMatch(asset.path), isTrue, reason: 'Path ${asset.path} violates D-06');
         }
       });

       test('every asset has a non-zero approximateDuration', () {
         for (final asset in kAudioManifest.values) {
           expect(asset.approximateDuration.inMilliseconds, greaterThan(0));
         }
       });

       test('letter-name entries land under letters/names/', () {
         // Reads manifest.yaml at test time to know which keys are letter_name
         // (alternative: hand-list — but parsing keeps it honest as Phases 6/8 add new kinds)
         // ... implementation reads File('manifest.yaml'), uses package:yaml ...
       });

       test('example-word starts_with matches first letter', () {
         // Read manifest.yaml; for each kind=='example_word' entry,
         // assert text.startsWith(starts_with) — Icelandic-correct (þrír starts with þ).
       });
       ```

       Add `package:yaml: ^3.1.2` to `pubspec.yaml` `dev_dependencies` if not already present (research/STACK.md notes yaml is already pulled in for the build pipeline; if it's not in dev_dependencies, add it). Run `flutter pub get`.

    5. **Run** `flutter test test/core/manifest/audio_manifest_test.dart` — all tests pass (5 pre-existing + ≥7 new).

    6. **Run** `flutter analyze` — no issues. The regenerated `audio_manifest.g.dart` and `utterance_key.dart` should pass the project's analysis_options (the Jinja2 templates were authored to match Phase 2's lint-clean style).

    7. **Run** `bash tools/check-manifest-sync.sh` — no longer prints `skip(03-06):`. Should print `ok: manifest sync` and exit 0 (the not-yet-baked carve-out no longer triggers because Dart now has 65 entries, not 5).

    8. **Run** `bash tools/check-asset-paths.sh` — passes against the 65 real AAC paths.

    Atomic commit count for Task 3: 1 (the regenerated Dart files + extended test file commit together — they are coupled).
    Commit:
    `feat(03-07): regenerate audio_manifest.g.dart + utterance_key.dart with 65 reviewed clips; extend exhaustive tests`
  </action>
  <verify>
    <automated>flutter test test/core/manifest/audio_manifest_test.dart && flutter analyze && bash tools/check-manifest-sync.sh && bash tools/check-asset-paths.sh && grep -c 'UtteranceKey\.' lib/gen/audio_manifest.g.dart | awk '$1 >= 65 {exit 0} {exit 1}'</automated>
  </verify>
  <done>
    `lib/gen/audio_manifest.g.dart` has 65 entries; `lib/core/manifest/utterance_key.dart` has 65 enum members; both keep all 5 Phase 2 stub identifiers. `flutter test test/core/manifest/audio_manifest_test.dart` passes ≥12 tests. `bash tools/check-manifest-sync.sh` exits 0 with `ok: manifest sync` (no longer skipped). `bash tools/check-asset-paths.sh` passes.
  </done>
</task>

<task type="auto">
  <name>Task 4: Commit the 65 AAC files + regenerated Dart + reviewed.yaml + overrides as one atomic Phase 3 ship</name>
  <files>
    assets/audio/letters/names/*.aac
    assets/audio/letters/words/*.aac
    assets/audio/narration/welcome_hugrun.aac
    lib/gen/audio_manifest.g.dart
    lib/core/manifest/utterance_key.dart
    reviewed.yaml
    pronunciation_overrides.yaml
    test/core/manifest/audio_manifest_test.dart
  </files>
  <action>
    1. **Final pre-commit checks** — all should pass:
       ```bash
       flutter test                       # all 84+ tests, including the new 65-entry exhaustive checks
       flutter analyze                    # No issues found
       dart format --set-exit-if-changed .   # 0 changed
       bash tools/check-no-tracking.sh    # ok
       bash tools/check-asset-paths.sh    # ok
       bash tools/check-manifest-sync.sh  # ok: manifest sync
       bash tools/check-domain-purity.sh  # ok (lib/core/manifest still pure-Dart)
       flutter build apk --debug          # succeeds
       flutter build ios --no-codesign --debug   # succeeds
       ```

    2. **Stage the changes**. Note: `_raw/` and `last-run.json` are gitignored and must NOT appear in `git status`:
       ```bash
       git add assets/audio/letters/names/*.aac
       git add assets/audio/letters/words/*.aac
       git add assets/audio/narration/welcome_hugrun.aac
       git add lib/gen/audio_manifest.g.dart
       git add lib/core/manifest/utterance_key.dart
       git add reviewed.yaml
       git add pronunciation_overrides.yaml   # only if non-empty (re-records were queued)
       git add test/core/manifest/audio_manifest_test.dart
       git add pubspec.yaml pubspec.lock      # if package:yaml was added in Task 3
       git status                              # confirm only intended files staged
       ```

    3. **Commit**:
       ```
       feat(03-07): ship Phase 3 — 65 reviewed Tiro Diljá v2 clips + regenerated audio manifest

       - 32 letter-name AAC clips + 32 example-word AAC clips + welcome narration
       - All clips: -19 LUFS / -1 dBTP, AAC-LC mono 96 kbps 48 kHz M4A, 30 ms silence pad
       - reviewed.yaml: 65 reviewed: true entries with text_hash; review gate passes
       - lib/gen/audio_manifest.g.dart regenerated (5 → 65 entries; D-22 backward compat preserved)
       - lib/core/manifest/utterance_key.dart regenerated (5 → 65 enum members)
       - test/core/manifest/audio_manifest_test.dart: +7 exhaustive checks (count, paths exist, D-06,
         Phase 2 stub keys preserved, every key mapped, non-zero durations, kind-vs-folder consistency)
       - tools/check-manifest-sync.sh now ENFORCES (no longer in Phase-3-not-yet-baked skip mode)

       Plan: .planning/phases/03-tts-pipeline-audio-review-tooling/03-07-PLAN-bake-and-review-pass.md
       AUDIO-02..06, AUDIO-08, AUDIO-09 satisfied (AUDIO-10 was Plan 01).
       AUDIO-01, AUDIO-07 satisfied by Plan 02 (manifest.yaml + overrides file from day one).
       AUDIO-03 (LUFS reject ±0.5 LU) is enforced in Plan 03's normalize.py and exercised here.
       ```

    4. **Verify post-commit state**:
       - `git log -1 --stat` shows the expected file set.
       - `bash tools/check-manifest-sync.sh` still passes.
       - `git status` is clean (no tracked-but-modified files).

    Atomic commit count for Task 4: 1 (the big "Phase 3 ships" commit).

    Total Plan 07 atomic commits: 2 (Task 3's regen commit + Task 4's full ship commit). Tasks 1 and 2 produce uncommitted state that Task 4 absorbs.

    Tasks 1, 3, 4 are mechanical — Task 2 is the human-driven activity that takes hours. The wave-6 "Plan 07 in progress" status is acknowledged as `human_needed` in the SUMMARY.

    Some operators prefer splitting Task 3's commit and Task 4's commit; that's fine, but a single atomic ship commit is preferable here because the AAC bytes, the regenerated Dart, and the populated YAML are mutually dependent — splitting them would briefly leave the repo in a state where check-manifest-sync.sh fails (Dart has 65 entries but AAC files are uncommitted, or vice versa). The single-commit form is the safest atomic operation.
  </action>
  <verify>
    <automated>git status --porcelain | grep -vE '^\?\?\s+(tools/tts/_raw/|tools/tts/last-run\.json)' | wc -l | grep -qE '^\s*0\s*$' && bash tools/check-manifest-sync.sh && flutter test && flutter analyze</automated>
  </verify>
  <done>
    Single commit lands all 65 AAC files + regenerated Dart + populated reviewed.yaml + extended test file. `git status` is clean except for ignored `_raw/` + `last-run.json`. All CI guards pass. `flutter test` includes the 65-entry exhaustive checks. `flutter build apk --debug` and `flutter build ios --no-codesign --debug` succeed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Tiro live API → local pipeline | Same as Plan 03; this plan is the first time we issue 65 calls in one session. |
| Reviewer (Jon) → reviewed.yaml | The review gate's correctness depends on the reviewer being a real native Icelandic speaker (D-30). |
| Generated Dart → Flutter build | Phase 4+ inherits whatever this plan ships; mistakes here propagate to Hugrún hearing the wrong sound. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-07-01 | Tampering | A clip is approved without being heard (button-mashing) | mitigate | Review UI is single-clip-at-a-time; the auto-advance design encourages listening. Cultural mitigation: Jon understands research PITFALL #1; the review pass is the entire point of Phase 3, not a checkbox to clear. |
| T-03-07-02 | Spoofing | bake_audio.py invoked with `--skip-review-gate` to ship without review | mitigate | Plan 06's CI guard re-renders the manifest WITHOUT the skip flag. If Jon ships unreviewed audio in a commit, CI catches it before merge. (Solo dev → no PR review, but CI fails the build either way.) |
| T-03-07-03 | Information disclosure | Hugrún's name pronounced wrong + shipped + Hugrún hears it | mitigate | `narrationWelcome` is flagged in manifest.yaml notes_for_reviewer as a hot spot. Review pass instructions explicitly call out Hugrún's name. |
| T-03-07-04 | Repudiation | Reviewer disputes an approval months later | accept | reviewed.yaml records timestamp + reviewer name + text_hash. Sufficient audit trail for a solo project. |
| T-03-07-05 | Tampering | Tiro voice updated mid-review (e.g. Diljá v3 ships) → some reviewed clips no longer match | mitigate | text_hash field includes voice ID; if the voice ID changes in manifest.yaml, every reviewed.yaml entry's hash mismatches and the gate fails. Forces a fresh review pass — which is the correct behavior per research PITFALL #1 ("re-review on every TTS provider/voice version change"). |
| T-03-07-06 | Denial of service | Tiro rate-limits during the bake run → partial output | mitigate | Plan 03's TiroClient retries 429 with backoff; Plan 04's bake_audio is per-utterance atomic + cache-resumable. A failed run resumes where it stopped. |
| T-03-07-07 | Tampering | The 65 AAC files commit is so large that git rejects it / blows up GitHub | mitigate | 65 × ~50 KB = ~3.25 MB total. Git/GitHub limit is 100 MB per file; we're 4 orders of magnitude under. No mitigation needed. |
| T-03-07-08 | Information disclosure | reviewed.yaml committed with reviewer's full name visible in public repo | accept | Repo is private during v1 development. If/when public release happens (REL-* in v2), strip the name field or replace with a pseudonym. Track in v2 backlog. |
| T-03-07-09 | Tampering | Re-record cycle creates an override that Tiro silently doesn't apply (SSML not actually supported) | mitigate | Plan 02's validate_overrides emits a WARNING when ssml is used and the README says SSML is unsupported. Reviewer reads the warning and falls back to text-substitution. |

</threat_model>

<verification>
- 65 AAC files exist under `assets/audio/...` and pass `bash tools/check-asset-paths.sh`
- `lib/gen/audio_manifest.g.dart` has 65 entries, includes all 5 Phase 2 stub keys
- `lib/core/manifest/utterance_key.dart` has 65 enum members, includes all 5 Phase 2 stub identifiers
- `reviewed.yaml` has reviewed: true for all 65 keys
- `pronunciation_overrides.yaml` either empty (no re-records needed — unlikely) or contains the SSML/text overrides actually used
- `flutter test` passes (84 pre-existing + ≥7 new = ≥91)
- `flutter analyze` returns "No issues found"
- `dart format --set-exit-if-changed .` returns 0 changed
- `bash tools/check-manifest-sync.sh` exits 0 with `ok: manifest sync` (no longer in skip mode)
- `bash tools/check-no-tracking.sh`, `tools/check-asset-paths.sh`, `tools/check-domain-purity.sh`, `tools/check-flutter-version.sh` all pass
- `flutter build apk --debug` and `flutter build ios --no-codesign --debug` succeed with the regenerated manifest
- `git status` clean (only `_raw/` + `last-run.json` ignored)
- Phase 3 success criteria 1, 2, 3 from ROADMAP § Phase 3 are all satisfied (success criterion 4, "Tiro auth/voice/rate verified", was satisfied by Plan 01)
</verification>

<success_criteria>
1. AUDIO-02 (pipeline reads manifest + calls Tiro Diljá v2 + saves output) — exercised end-to-end against live Tiro.
2. AUDIO-03 (LUFS normalized at -19 LUFS / -1 dBTP, ±0.5 LU reject) — every clip passes the reject filter.
3. AUDIO-04 (AAC-LC mono 96 kbps 48 kHz M4A) — every shipped clip's ffprobe metadata matches.
4. AUDIO-05 (20–50 ms leading silence) — every shipped clip has 30 ms silence pad.
5. AUDIO-06 (committed lib/gen/audio_manifest.g.dart, no runtime parse) — 65 entries, deterministic, byte-stable across re-runs.
6. AUDIO-08 (100% review gate) — 65 reviewed: true entries with valid text_hashes; gate enforced.
7. AUDIO-09 (review UI lets reviewer sign off entry-by-entry) — used to populate reviewed.yaml.
8. D-22 backward compatibility — Phase 2's 5 stub keys are still in the regenerated manifest at the same paths.
9. CI guard transitions out of "skip" state — `bash tools/check-manifest-sync.sh` enforces from this plan onward.
10. Phase 3 success criteria 1, 2, 3 from ROADMAP all met.
</success_criteria>

<output>
After completion, create `.planning/phases/03-tts-pipeline-audio-review-tooling/03-07-SUMMARY.md` covering:
- 2 atomic commits (regen + ship)
- Wall-clock time of the synthesis stage (informational; Phase 6 will re-run for phonemes)
- Number of re-record cycles needed (e.g. "5/65 clips required override; SSML worked for 3, text-substitution for 2")
- The final overrides shipped in pronunciation_overrides.yaml
- Wall-clock time of the review session (for retrospective baselining)
- Carry-over to Phase 4 (Stafir MVP):
  - lib/gen/audio_manifest.g.dart is now the authoritative source for AudioEngine warm-pool keys
  - All 32 letter-name + 32 example-word clips are real audio (not 100ms silence)
  - narrationWelcome is real Diljá v2 audio of "Halló Hugrún. Veldu stafi eða tölur." — Phase 4's first-screen greeting
- Carry-over to Phase 6 (CVC blending): same pipeline runs again with phoneme-kind manifest entries; review pass reused
- Phase 3 retrospective: did the review-gate friction match expectations? Did the cache invalidation work for re-records? Did Tiro stay reliable over the 65-call run?
</output>
