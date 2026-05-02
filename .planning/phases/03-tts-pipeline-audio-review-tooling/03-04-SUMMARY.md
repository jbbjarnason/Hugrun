---
phase: 3
plan: 04
plan-name: bake-and-manifest-writer
status: complete
date: 2026-05-02
duration: ~30 min
requirements_satisfied:
  - AUDIO-02
  - AUDIO-06
  - AUDIO-08
key-files:
  created:
    - tools/tts/bake_audio.py
    - tools/tts/manifest_writer.py
    - tools/tts/templates/audio_manifest.g.dart.j2
    - tools/tts/templates/utterance_key.dart.j2
    - tools/tts/tests/test_manifest_writer.py
    - tools/tts/tests/test_bake_audio.py
  modified: []
decisions:
  - "manifest_writer.text_hash(used_text, used_voice) is the canonical review-gate hash function; Plan 05's review server imports it directly."
  - "Renders sorted by key for byte-stable output (test_byte_stable_across_runs verifies)."
  - "--check-sync --allow-stub-baseline is the Plan 06 CI mode; it carves out the Phase 3 not-yet-baked state (Dart matches Phase 2 stub + reviewed.yaml empty)."
---

# Plan 03-04 Summary — manifest_writer + bake_audio orchestrator

## What was built

| Artifact | Purpose |
|---|---|
| `tools/tts/manifest_writer.py` | Renders Jinja2 templates → lib/gen/audio_manifest.g.dart + lib/core/manifest/utterance_key.dart. Enforces D-18 review gate (raises ReviewGateError listing all unresolved keys). Enforces D-22 backward compat (PHASE2_STUB_KEYS frozenset). text_hash function used by both manifest_writer and review_server. |
| `tools/tts/bake_audio.py` | Pipeline orchestrator: plan → generate (parallel, 4 workers) → normalize → review-gate → manifest. Per-utterance atomic (D-03). last-run.json reporting. CLI flags: --plan/--dry-run, --force-regenerate, --skip-review-gate, --skip-normalize, --check-sync, --allow-stub-baseline, --workers, --manifest, --overrides, --reviewed, --out-manifest, --out-enum, --last-run. |
| `audio_manifest.g.dart.j2` | Jinja2 template for the generated Dart manifest (D-20). |
| `utterance_key.dart.j2` | Jinja2 template for the generated UtteranceKey enum. |

## Atomic commits

| Hash | Type | Message |
|---|---|---|
| `a15568e` | feat | feat(03-04): add manifest_writer + bake_audio orchestrator (Plan 04) |

(Single commit covers both modules + 4 templates/tests — they are mutually
co-dependent; splitting would leave the repo in a half-functional state.)

## Test counts

- 11 manifest_writer tests: text_hash determinism, render_audio_manifest happy
  path, render_utterance_key happy path, byte-stability, review gate blocks
  unreviewed, review gate blocks text_hash drift, review gate passes writes
  files, skip_review_gate emits anyway, D-22 backward compat enforced, real
  repo manifest renders.
- 6 bake_audio tests: import, --plan dry-run, --check-sync stub baseline
  carve-out, --check-sync renders Dart, mocked end-to-end pipeline,
  per-utterance atomicity (D-03).

Cumulative across Plans 01–04: **97 pytest cases** at this snapshot (later
expanded to 110 after Plan 05 review server tests).

## CLI surface (final)

```
python tools/tts/bake_audio.py --plan          # dry-run; classify all 65 utterances
python tools/tts/bake_audio.py                 # full bake (synth + normalize + manifest)
python tools/tts/bake_audio.py --force-regenerate    # ignore caches
python tools/tts/bake_audio.py --skip-review-gate    # DANGER: emit manifest unreviewed
python tools/tts/bake_audio.py --check-sync --allow-stub-baseline   # Plan 06 CI mode
python tools/tts/bake_audio.py --workers 8            # bump concurrency
```

## Phase 2 stub key → Phase 3 path map

| Stub key | Path (preserved verbatim) |
|---|---|
| letterA | assets/audio/letters/names/a.aac |
| letterEth | assets/audio/letters/names/eth.aac |
| letterThorn | assets/audio/letters/names/thorn.aac |
| wordHundur | assets/audio/letters/words/hundur.aac |
| narrationWelcome | assets/audio/narration/welcome_hugrun.aac |

D-22 backward compat invariant: any future plan that drops one of these keys
or relocates one of these files will be rejected by manifest_writer's
PHASE2_STUB_KEYS check.

## Carry-overs

- **Plan 05 (review_server):** imports `text_hash` from manifest_writer for
  consistent review-gate hashes. The /approve handler computes the same
  sha256 the gate later checks.
- **Plan 06 (CI sync guard):** invokes `bake_audio.py --check-sync
  --allow-stub-baseline`; bash diff catches Dart-↔-manifest drift.
- **Plan 07 (review pass):** runs bake_audio end-to-end against real Piper.
  After all 65 entries are reviewed, re-running bake regenerates Dart
  manifest with measured durations from last-run.json.
