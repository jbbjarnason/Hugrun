---
phase: 03-tts-pipeline-audio-review-tooling
plan: 04
type: execute
wave: 4
depends_on: ["03-03"]
files_modified:
  - tools/tts/bake_audio.py
  - tools/tts/manifest_writer.py
  - tools/tts/templates/audio_manifest.g.dart.j2
  - tools/tts/tests/test_bake_audio.py
  - tools/tts/tests/test_manifest_writer.py
  - tools/tts/last-run.json  # written by bake; not committed (gitignored)
  - tools/tts/.gitignore
autonomous: true
requirements:
  - AUDIO-02
  - AUDIO-06
  - AUDIO-08

must_haves:
  truths:
    - "Running `python tools/tts/bake_audio.py --plan` lists every utterance in manifest.yaml as one of {to-generate, cached, blocked-on-review, ready-to-emit} and exits 0 (planning is non-destructive)"
    - "Running `python tools/tts/bake_audio.py` end-to-end calls TiroClient.synthesize → Normalizer.normalize_to_aac → writes AAC files under assets/audio/ → writes lib/gen/audio_manifest.g.dart IFF every utterance is `reviewed: true` in reviewed.yaml"
    - "If ANY utterance in manifest.yaml lacks `reviewed: true` in reviewed.yaml, manifest_writer aborts with a non-zero exit and prints the list of unreviewed clips + the URL of the review server (D-18)"
    - "Generated lib/gen/audio_manifest.g.dart maintains backward compatibility with Phase 2's 5 stub keys (D-22) — the 5 enum identifiers (letterA, letterEth, letterThorn, wordHundur, narrationWelcome) appear in the regenerated file with the same paths"
    - "Generated lib/gen/audio_manifest.g.dart is byte-stable across re-runs given the same manifest.yaml + reviewed.yaml inputs (deterministic Jinja2 rendering, sorted keys) — verified by a test that runs the writer twice and diff-checks the output"
    - "tools/tts/last-run.json (gitignored) records per-utterance status for the most recent bake run"
  artifacts:
    - path: tools/tts/bake_audio.py
      provides: "Pipeline orchestrator: plan → generate → normalize → review-gate → manifest. Idempotent, resumable, atomic per-utterance (D-02, D-03)."
      exports: ["main", "BakePlan", "BakeStage", "run_pipeline"]
    - path: tools/tts/manifest_writer.py
      provides: "Generates lib/gen/audio_manifest.g.dart from manifest.yaml + reviewed.yaml + measured durations. Aborts on review-gate failure (D-18)."
      exports: ["write_audio_manifest", "ReviewGateError"]
    - path: tools/tts/templates/audio_manifest.g.dart.j2
      provides: "Jinja2 template — single source of truth for the generated Dart file's shape (D-20)"
      contains: "enum UtteranceKey"
    - path: tools/tts/tests/test_bake_audio.py
      provides: "Pytest coverage for bake orchestrator: planning, idempotency, atomic per-utterance, review-gate behavior"
      contains: "def test_"
    - path: tools/tts/tests/test_manifest_writer.py
      provides: "Pytest coverage for manifest_writer: review-gate enforcement, Phase 2 stub backward compat, byte-stability across re-runs, generated Dart parses with `dart analyze`"
      contains: "def test_"
  key_links:
    - from: tools/tts/bake_audio.py
      to: tools/tts/tiro_client.TiroClient + tools/tts/normalize.Normalizer
      via: "for entry in manifest: TiroClient.synthesize(entry, overrides) → Normalizer.normalize_to_aac(raw, target)"
      pattern: "TiroClient|Normalizer"
    - from: tools/tts/manifest_writer.py
      to: lib/gen/audio_manifest.g.dart
      via: "Jinja2 render of audio_manifest.g.dart.j2 → Path('lib/gen/audio_manifest.g.dart').write_text(rendered)"
      pattern: "lib/gen/audio_manifest\\.g\\.dart"
    - from: tools/tts/manifest_writer.py
      to: reviewed.yaml
      via: "for each manifest entry: assert reviewed.yaml.entries[key].reviewed == True AND reviewed.yaml.entries[key].text_hash == sha256(used_text + used_voice)"
      pattern: "reviewed\\.yaml|text_hash"
---

<objective>
Wire `tiro_client` + `normalize` (Plan 03) into the pipeline orchestrator and the generated Dart manifest writer:

1. **`tools/tts/bake_audio.py`** — the pipeline entry point per D-01, D-02, D-03:
   - Reads `manifest.yaml`, `pronunciation_overrides.yaml`, `reviewed.yaml`.
   - Plans: computes per-utterance status (`to-generate`, `cached`, `blocked-on-review`, `ready-to-emit`).
   - Generates: for each non-cached utterance, calls `TiroClient.synthesize(entry, overrides)` → produces raw WAV in `_raw/`.
   - Normalizes: for each freshly-generated raw, calls `Normalizer.normalize_to_aac(raw, target_aac)` → produces AAC under `assets/audio/`.
   - Review gate: if ANY utterance in manifest.yaml is missing from `reviewed.yaml.entries` OR has `reviewed: false` OR has a stale `text_hash`, BLOCK manifest emission and print actionable errors with a link to the review server (D-18).
   - Manifest stage: if review gate passes, hand off to `manifest_writer.write_audio_manifest(...)` which regenerates `lib/gen/audio_manifest.g.dart`.
   - Writes `tools/tts/last-run.json` summary (D-03).
   - CLI flags: `--plan` (read-only dry-run), `--force-regenerate` (ignore cache), `--skip-tiro` (use only existing _raw/ + run normalize + manifest), `--skip-review-gate` (DANGEROUS: emits manifest without review — only used by Plan 06's CI sync check).

2. **`tools/tts/manifest_writer.py`** — the Dart codegen step per D-20, D-21, D-22:
   - Reads manifest.yaml + reviewed.yaml + per-utterance measured durations (from bake's last-run.json or from re-probing the AAC files).
   - Enforces the review gate as a hard precondition (raises `ReviewGateError` if violated; D-18).
   - Renders `tools/tts/templates/audio_manifest.g.dart.j2` with sorted UtteranceKey entries and writes the result to `lib/gen/audio_manifest.g.dart` (D-21 — committed to git, the .gitignore exception from Phase 2 covers this).
   - Verifies the generated Dart is parseable by running `dart analyze lib/gen/audio_manifest.g.dart` post-write.
   - Verifies backward compat with Phase 2's 5 stub keys (D-22).

Purpose: AUDIO-02 (pipeline reads manifest + calls Tiro), AUDIO-06 (regenerated lib/gen/audio_manifest.g.dart committed, no runtime JSON parse), AUDIO-08 (100% reviewed gate before bundling).

This is the keystone of Phase 3. After Plan 04, the pipeline is operationally complete — Plans 05 (review UI) and 06 (CI sync guard) bolt on review tooling and CI enforcement; Plan 07 runs the pipeline end-to-end.

Output:
- `bake_audio.py` (~250 lines) + tests (≥10 cases, mocking TiroClient + Normalizer).
- `manifest_writer.py` (~120 lines) + tests (≥8 cases, including a "generated Dart parses + matches Phase 2 schema" test).
- Jinja2 template at `tools/tts/templates/audio_manifest.g.dart.j2`.

NOTE: Plan 04 does NOT itself run the full pipeline end-to-end against live Tiro — that is Plan 07's job. Plan 04 only verifies the orchestration and the manifest writer work in isolation, with `bake_audio.py --plan` and a mocked-Tiro/real-ffmpeg path producing the expected last-run.json shape.
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
@manifest.yaml
@pronunciation_overrides.yaml
@reviewed.yaml
@lib/gen/audio_manifest.g.dart  # current Phase 2 stub — Plan 04 overwrites this in Plan 07's run
@lib/core/manifest/utterance_key.dart
@lib/core/manifest/audio_asset.dart

<interfaces>
<!-- Phase 2's existing audio_manifest.g.dart is the contract Plan 04's regenerated file MUST satisfy. -->

Phase 2 stub `lib/gen/audio_manifest.g.dart` shape (must be preserved structurally):
```dart
// GENERATED FILE -- DO NOT EDIT MANUALLY
// Generated by tools/tts/bake_audio.py at <timestamp>
// Source: manifest.yaml + reviewed.yaml at the time of generation
// Maintains backward compatibility with Phase 2 stub keys (D-22)

import 'package:hugrun/core/manifest/audio_asset.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

const Map<UtteranceKey, AudioAsset> kAudioManifest = <UtteranceKey, AudioAsset>{
  UtteranceKey.<key>: AudioAsset(
    path: '<path>',
    approximateDuration: Duration(milliseconds: <ms>),
  ),
  // ... 65 entries total (sorted alphabetically by key for diff stability) ...
};

AudioAsset getAudioAsset(UtteranceKey key) => kAudioManifest[key]!;
```

The `lib/core/manifest/utterance_key.dart` enum file is ALSO regenerated (or, more conservatively, augmented). Phase 2 had only 5 entries; Plan 04 needs all 65. Two options:

**Option A (recommended)**: regenerate `lib/core/manifest/utterance_key.dart` from manifest.yaml — it becomes a generated file with a `// GENERATED FILE` header, and the .gitignore exception is widened to keep it (alongside `lib/gen/audio_manifest.g.dart`).

**Option B**: keep `utterance_key.dart` hand-written and append all new entries (still committed to git, normal Dart). The bake_audio writer asserts via diff that every manifest.yaml key is already a UtteranceKey enum member, and aborts with "add `letterB` to lib/core/manifest/utterance_key.dart" if not.

**Pick Option A** — keeps the source of truth in manifest.yaml. The `.gitignore` already has `!lib/gen/audio_manifest.g.dart`; we extend that pattern. We do NOT regenerate `audio_asset.dart` (it's a domain model, not enum data — stays hand-written, untouched).

D-21 says generated audio_manifest.g.dart is committed to git. We extend that rule to the regenerated UtteranceKey file. Update `.gitignore` to add `!lib/core/manifest/utterance_key.dart` (or move the file under `lib/gen/`).

**Path strategy** for the regenerated UtteranceKey enum:
- Move `lib/core/manifest/utterance_key.dart` → `lib/gen/utterance_key.g.dart` (under `lib/gen/` where generated files belong; Phase 2 already established `lib/gen/audio_manifest.g.dart` as a committed-generated location).
- Or keep at `lib/core/manifest/utterance_key.dart` but mark as generated. Both are fine; Option B keeps existing imports unchanged across the codebase.

**Recommendation: keep at `lib/core/manifest/utterance_key.dart`** — minimizes import churn. Add `// GENERATED FILE — DO NOT EDIT MANUALLY` header. Add `!lib/core/manifest/utterance_key.dart` exception to `.gitignore` (it currently doesn't match `**/*.g.dart` because of the filename, but adding it explicitly is safest).

Actually — even simpler. The Phase 2 file is named `utterance_key.dart` (no `.g.dart` suffix), so it is NOT matched by the `**/*.g.dart` gitignore rule. It's already being tracked normally. Plan 04 just keeps overwriting it in place; no .gitignore changes needed.

So the FINAL strategy is:
- `lib/gen/audio_manifest.g.dart` — generated by manifest_writer (Phase 2 already excepted in .gitignore).
- `lib/core/manifest/utterance_key.dart` — also generated by manifest_writer (filename does not match the .gitignore rule, no exception needed).
- `lib/core/manifest/audio_asset.dart` — hand-written, untouched by Plan 04.

bake_audio.py reads these from Plan 03:
```python
from .schema import validate_manifest, validate_overrides, validate_reviewed, ManifestEntry
from .tiro_client import TiroClient, SynthesisResult, TiroError, TiroAuthError, TiroRateLimitError
from .normalize import Normalizer, NormalizeResult, NormalizeError
```

last-run.json shape (D-03):
```json
{
  "started_at": "2026-05-02T15:00:00Z",
  "finished_at": "2026-05-02T15:08:30Z",
  "total_utterances": 65,
  "stages": {
    "to_generate": ["letterA", "letterB", ...],
    "cached": ["letterEth", ...],
    "generated_ok": ["letterA", "letterB", ...],
    "generated_failed": [{"key": "wordX", "error": "TiroAuthError: ..."}],
    "normalized_ok": ["letterA", ...],
    "normalized_failed": [{"key": "wordY", "error": "NormalizeError: LUFS -17.2 outside [-19.5, -18.5]"}],
    "blocked_on_review": ["letterA", "letterB", ...],  # missing from reviewed.yaml or reviewed: false
    "manifest_written": false  # true iff review gate passed and lib/gen/audio_manifest.g.dart was rewritten
  },
  "next_action": "Run python tools/tts/review_server.py and approve the 65 unreviewed clips at http://localhost:8765"
}
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: manifest_writer — Jinja2 template + review-gate enforcement + Phase 2 backward compat (TDD)</name>
  <files>
    tools/tts/manifest_writer.py
    tools/tts/templates/audio_manifest.g.dart.j2
    tools/tts/tests/test_manifest_writer.py
  </files>
  <behavior>
    Test 1 (RED): import fails — `from tools.tts.manifest_writer import write_audio_manifest`.
    Test 2: happy path — given a synthetic manifest with 3 entries + a reviewed.yaml with all 3 reviewed + a measured-durations dict, `write_audio_manifest` writes a Dart file matching a golden fixture (`tests/fixtures/expected_3_entry_manifest.dart`).
    Test 3: review gate REJECT — same manifest, but reviewed.yaml has only 2 entries reviewed → raises `ReviewGateError` whose message lists exactly the 1 unreviewed key + a hint pointing to `python tools/tts/review_server.py`.
    Test 4: text_hash drift REJECT — reviewed.yaml has all 3 entries reviewed but one entry's `text_hash` doesn't match `sha256(used_text + ":" + used_voice)`. Raises `ReviewGateError` mentioning the stale entry and instructing re-record.
    Test 5: byte-stability — calling `write_audio_manifest` twice with identical inputs produces byte-identical output (deterministic Jinja2 + sorted keys).
    Test 6: backward compat (D-22) — given the REAL manifest.yaml + a synthetic reviewed.yaml that has all 65 entries reviewed, the generated `lib/gen/audio_manifest.g.dart` contains entries for `letterA`, `letterEth`, `letterThorn`, `wordHundur`, `narrationWelcome` with the SAME paths as Phase 2's hand-written stub. Test extracts the paths via regex and compares.
    Test 7: generated UtteranceKey enum (`lib/core/manifest/utterance_key.dart`) contains exactly 65 enum members in sorted order, with the GENERATED FILE header.
    Test 8: generated Dart parses — write the manifest to a tmp file, run `dart analyze --no-fatal-warnings <tmp>` via subprocess, assert exit 0. Skipped (with a clear xfail/skip reason) if `dart` is not on PATH in CI; locally must pass.
  </behavior>
  <action>
    Per D-18, D-20, D-21, D-22.

    **Step A — RED**: write `test_manifest_writer.py` covering Tests 1–8. Build a small fixtures directory with: 3-entry synthetic manifest YAML, matching reviewed.yaml, expected Dart output. Run pytest, confirm RED. Commit:
    `test(03-04): add failing manifest_writer pytest harness`

    **Step B — GREEN**:

    Create `tools/tts/templates/audio_manifest.g.dart.j2`:
    ```jinja2
    // GENERATED FILE — DO NOT EDIT MANUALLY
    // Generated by tools/tts/bake_audio.py at {{ generated_at }}
    // Source: manifest.yaml + reviewed.yaml ({{ entries|length }} utterances)
    // Maintains backward compatibility with Phase 2 stub keys (D-22).
    //
    // To regenerate:
    //   python tools/tts/bake_audio.py
    //
    // The pipeline aborts before this file is rewritten if any utterance is
    // unreviewed (D-18 — review gate). Edit manifest.yaml + reviewed.yaml
    // and re-run; do NOT hand-edit this file.

    import 'package:hugrun/core/manifest/audio_asset.dart';
    import 'package:hugrun/core/manifest/utterance_key.dart';

    /// All audio assets referenced by Phase 3's regenerated manifest. Paths are
    /// project-relative and conform to D-06 (lowercase ASCII alphanumerics + . _
    /// - / only). Durations are real measurements from ffprobe (D-12).
    const Map<UtteranceKey, AudioAsset> kAudioManifest = <UtteranceKey, AudioAsset>{
    {%- for entry in entries %}
      UtteranceKey.{{ entry.key }}: AudioAsset(
        path: '{{ entry.asset }}',
        approximateDuration: Duration(milliseconds: {{ entry.duration_ms }}),
      ),
    {%- endfor %}
    };

    /// Type-safe lookup. Throws if the key is absent — manifest is exhaustive at
    /// compile time, so a missing entry is a programmer error, not a runtime
    /// fallback condition (D-08).
    AudioAsset getAudioAsset(UtteranceKey key) => kAudioManifest[key]!;
    ```

    Also create `tools/tts/templates/utterance_key.dart.j2`:
    ```jinja2
    // GENERATED FILE — DO NOT EDIT MANUALLY
    // Generated by tools/tts/bake_audio.py at {{ generated_at }}
    // Source: manifest.yaml ({{ keys|length }} entries)
    //
    // Pure-Dart domain enum for the audio manifest contract. Phase 1 D-08 +
    // Phase 2 D-13 require lib/core/manifest/ to stay Flutter-free; the audio
    // layer (Phase 4) imports this enum and the generated kAudioManifest map
    // without reaching into Flutter widgets.
    //
    // Phase 3 ({{ keys|length }} entries) replaces Phase 2's 5-entry stub but
    // keeps the original 5 identifiers (letterA, letterEth, letterThorn,
    // wordHundur, narrationWelcome) so existing Dart code continues to compile.

    enum UtteranceKey {
    {%- for key in keys %}
      {{ key }},
    {%- endfor %}
    }
    ```

    Implement `tools/tts/manifest_writer.py`:
    ```python
    import hashlib, json, subprocess
    from dataclasses import dataclass
    from datetime import datetime, timezone
    from pathlib import Path
    from jinja2 import Environment, FileSystemLoader, StrictUndefined

    from .schema import validate_manifest, validate_reviewed

    PHASE2_STUB_KEYS = frozenset({
        "letterA", "letterEth", "letterThorn", "wordHundur", "narrationWelcome"
    })

    class ReviewGateError(Exception): ...

    @dataclass
    class ManifestEntryWithDuration:
        key: str
        asset: str
        duration_ms: int

    def text_hash(used_text: str, used_voice: str) -> str:
        h = hashlib.sha256(f"{used_text}:{used_voice}".encode()).hexdigest()
        return f"sha256:{h}"

    def write_audio_manifest(
        manifest: dict,
        reviewed: dict,
        used_texts: dict[str, tuple[str, str]],   # key → (used_text, used_voice)
        durations_ms: dict[str, int],
        out_manifest_path: Path = Path("lib/gen/audio_manifest.g.dart"),
        out_enum_path: Path = Path("lib/core/manifest/utterance_key.dart"),
        templates_dir: Path = Path("tools/tts/templates"),
        generated_at: str | None = None,
        verify_dart_parse: bool = True,
    ) -> None: ...
    ```

    Function logic:
    1. Validate manifest + reviewed via schema.
    2. Review gate (D-18): for each `entry.key`:
       a. Assert `entry.key in reviewed["entries"]`.
       b. Assert `reviewed["entries"][entry.key]["reviewed"] is True`.
       c. Compute `expected_hash = text_hash(used_texts[key][0], used_texts[key][1])`; assert it equals `reviewed["entries"][entry.key]["text_hash"]`.
       Aggregate all failures, raise `ReviewGateError` with the full list (don't fail-fast on the first).
    3. Backward compat (D-22): assert `PHASE2_STUB_KEYS <= {entry.key for entry in manifest.utterances}`. Raise if any are missing.
    4. Build the Jinja2 contexts: sort entries alphabetically by key for diff stability. `entries = [ManifestEntryWithDuration(key=u['key'], asset=u['asset'], duration_ms=durations_ms[u['key']]) for u in sorted(manifest['utterances'], key=lambda u: u['key'])]`. `keys = [e.key for e in entries]`.
    5. Render both templates (`StrictUndefined` ensures missing template variables blow up loudly).
    6. Write both files atomically (write to `.tmp` then rename).
    7. If `verify_dart_parse`: run `dart analyze --no-fatal-warnings` on the two output files (subprocess); raise `ReviewGateError` (or a different error class) on parse failure.

    Run pytest, confirm GREEN. Commit:
    `feat(03-04): add tools/tts/manifest_writer.py with review-gate enforcement and Jinja2 templates`

    Atomic commit count for Task 1: 2 (RED + GREEN).
  </action>
  <verify>
    <automated>python3 -m pytest tools/tts/tests/test_manifest_writer.py -x</automated>
  </verify>
  <done>
    `pytest tools/tts/tests/test_manifest_writer.py` passes ≥8 tests. Templates exist under `tools/tts/templates/`. The review-gate REJECT, text_hash DRIFT REJECT, byte-stability, and Phase 2 backward-compat tests all pass. The `dart analyze` test passes locally (Phase 1 ensures `dart` is on PATH via fvm).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: bake_audio orchestrator — plan / generate / normalize / review-gate / manifest stages (TDD)</name>
  <files>
    tools/tts/bake_audio.py
    tools/tts/tests/test_bake_audio.py
    tools/tts/.gitignore
  </files>
  <behavior>
    Test 1 (RED): import fails — `from tools.tts.bake_audio import run_pipeline`.
    Test 2: `run_pipeline(manifest_path, overrides_path, reviewed_path, dry_run=True)` returns a `BakePlan` with stage='plan' and per-utterance status. No HTTP call, no ffmpeg call.
    Test 3: cache hit — when `_raw/{key}.wav` AND its sidecar exist with a matching fingerprint, the utterance lands in stage=cached; TiroClient.synthesize is NOT called for it.
    Test 4: cache miss — fresh run, TiroClient.synthesize IS called once per utterance (mocked); Normalizer.normalize_to_aac IS called once per utterance (mocked or real with tiny fixture).
    Test 5: per-utterance atomicity (D-03) — when one utterance's TiroClient.synthesize raises TiroAuthError, that utterance lands in `generated_failed` but the OTHER utterances still complete. The exception does NOT bubble up to fail the whole run.
    Test 6: per-utterance atomicity, normalize variant — when one utterance's Normalizer raises NormalizeError (LUFS reject), it lands in `normalized_failed` but other utterances still complete.
    Test 7: review gate BLOCK — synthetic reviewed.yaml is empty; `run_pipeline` runs all generate + normalize stages but `manifest_written = false` in last-run.json AND `lib/gen/audio_manifest.g.dart` is NOT modified. CLI exits non-zero.
    Test 8: review gate PASS — synthetic reviewed.yaml has all entries reviewed; manifest_written = true; lib/gen/audio_manifest.g.dart IS modified.
    Test 9: `--skip-tiro` flag — when `_raw/{key}.wav` exists for every utterance, `run_pipeline(skip_tiro=True)` skips the TiroClient stage entirely (no mocked HTTP needed); errors out CLEARLY if any raw is missing.
    Test 10: `--skip-review-gate` flag — DANGER mode used by Plan 06's CI sync check; emits manifest without review-gate enforcement. Test asserts that when this flag is set, the absence of reviewed.yaml entries does NOT block the manifest write (still requires generated AAC files to exist, though).
    Test 11: last-run.json schema — last-run.json after a run is valid JSON with all the documented fields and is gitignored.
  </behavior>
  <action>
    Per D-01, D-02, D-03, D-18.

    **Step A — RED**: write `test_bake_audio.py` covering Tests 1–11. Use `unittest.mock.patch` to inject mocked TiroClient + Normalizer. Use a `tmp_path`-based cache directory. Run pytest, confirm RED. Commit:
    `test(03-04): add failing bake_audio orchestrator pytest harness`

    **Step B — GREEN**: implement `tools/tts/bake_audio.py` (~250 lines):
    ```python
    """
    Pipeline orchestrator for Phase 3 TTS bake.

    Stages (D-02):
      1. Plan      — read manifest/overrides/reviewed; classify each utterance.
      2. Generate  — call TiroClient.synthesize for to_generate utterances.
      3. Normalize — call Normalizer.normalize_to_aac for newly generated raws.
      4. Review gate — assert every utterance is reviewed: true + text_hash matches.
      5. Manifest  — manifest_writer.write_audio_manifest if review gate passes.

    Atomic per utterance (D-03): a failure in any stage for one utterance is
    captured in last-run.json without aborting the run.
    """
    import argparse, json, logging, sys, time
    from dataclasses import dataclass, field
    from datetime import datetime, timezone
    from enum import Enum
    from pathlib import Path

    import yaml

    from .schema import validate_manifest, validate_overrides, validate_reviewed, ManifestEntry
    from .tiro_client import TiroClient, TiroError, TiroAuthError, TiroRateLimitError
    from .normalize import Normalizer, NormalizeError
    from .manifest_writer import write_audio_manifest, ReviewGateError, text_hash as compute_text_hash

    log = logging.getLogger("bake_audio")

    class BakeStage(str, Enum):
        TO_GENERATE = "to_generate"
        CACHED = "cached"
        GENERATED_OK = "generated_ok"
        GENERATED_FAILED = "generated_failed"
        NORMALIZED_OK = "normalized_ok"
        NORMALIZED_FAILED = "normalized_failed"
        BLOCKED_ON_REVIEW = "blocked_on_review"

    @dataclass
    class BakePlan:
        manifest: dict
        overrides: dict
        reviewed: dict
        per_utterance: dict[str, dict] = field(default_factory=dict)  # key → {stage, used_text, used_voice, target_path, duration_ms, error?}

        def to_last_run_json(self) -> dict: ...

    def run_pipeline(
        manifest_path: Path = Path("manifest.yaml"),
        overrides_path: Path = Path("pronunciation_overrides.yaml"),
        reviewed_path: Path = Path("reviewed.yaml"),
        *,
        dry_run: bool = False,
        force_regenerate: bool = False,
        skip_tiro: bool = False,
        skip_review_gate: bool = False,
        tiro_client: TiroClient | None = None,  # injectable for tests
        normalizer: Normalizer | None = None,
        last_run_path: Path = Path("tools/tts/last-run.json"),
    ) -> BakePlan: ...

    def main(argv=None) -> int: ...  # argparse + setup + run_pipeline + write last-run.json + exit code
    ```

    Implementation walkthrough:

    1. Read + validate all three YAML files. Read Tiro facts from `tools/tts/README.md` (parse the section markers programmatically — keep this brittle but visible) OR accept an env-var-overrideable config (cleaner). Recommended: explicit `--config` flag accepting a JSON config produced once by Plan 01; default config built from env vars `TIRO_BASE_URL`, `TIRO_SYNTHESIZE_PATH`, `TIRO_VOICE_DEFAULT`, with sensible defaults (`https://tts.tiro.is`, `/v0/speech/synthesize`, the verified Diljá v2 ID).

    2. Plan stage: for each entry, determine target asset path (`Path(entry["asset"])`) and check whether the AAC already exists AND matches the cache fingerprint. Status:
       - AAC exists AND fingerprint matches → CACHED.
       - AAC missing OR fingerprint mismatch OR `force_regenerate=True` → TO_GENERATE.
       Cache fingerprint here is computed from the same (used_text, used_voice) pair as Plan 03's tiro_client.

    3. If `dry_run=True`: write last-run.json with the plan, return.

    4. Generate stage: instantiate TiroClient (or use injected one). For each TO_GENERATE entry:
       - Try `tiro_client.synthesize(entry, overrides)`.
       - On TiroAuthError → record in GENERATED_FAILED, continue (per D-03 atomicity).
       - On TiroRateLimitError → record in GENERATED_FAILED, but ALSO halt remaining synthesis attempts for this run (rate limit = systemic problem). Log clearly.
       - On TiroError → record GENERATED_FAILED, continue.
       - On success → record GENERATED_OK, store `(used_text, used_voice, raw_path)`.

    5. Normalize stage: for each (CACHED | GENERATED_OK) entry:
       - Try `normalizer.normalize_to_aac(raw_path, target_path)`.
       - On NormalizeError → NORMALIZED_FAILED, continue.
       - On success → NORMALIZED_OK + record `duration_ms` from NormalizeResult.

    6. Review gate stage (skipped IFF `skip_review_gate=True`): for each NORMALIZED_OK entry, check reviewed.yaml. If missing or `reviewed: false` or `text_hash` mismatch → BLOCKED_ON_REVIEW. Aggregate all blocks; do NOT abort.

    7. Manifest stage: if (skip_review_gate OR no entries are BLOCKED_ON_REVIEW) AND we have NORMALIZED_OK durations for every manifest entry, call `write_audio_manifest(...)`. Otherwise skip and set `manifest_written: false` in last-run.json.

    8. Write last-run.json (D-03). Print human-readable summary to stdout. Exit 0 IFF (manifest_written OR dry_run); exit 1 otherwise.

    `argparse` with the documented flags. `--plan` is sugar for `--dry-run`. `--quiet/--verbose` for log level.

    Add `last-run.json` to `tools/tts/.gitignore`:
    ```
    last-run.json
    ```

    Run pytest, confirm GREEN. Commit:
    `feat(03-04): add tools/tts/bake_audio.py orchestrator with plan/generate/normalize/review/manifest stages`

    Atomic commit count for Task 2: 2 (RED + GREEN).

    Total Plan 04 atomic commits: 4.
  </action>
  <verify>
    <automated>python3 -m pytest tools/tts/tests/ -x && python3 tools/tts/bake_audio.py --plan</automated>
  </verify>
  <done>
    `pytest tools/tts/tests/` passes the cumulative ≥60 tests across Plans 01–04. `python tools/tts/bake_audio.py --plan` runs against the real `manifest.yaml`, classifies all 65 utterances (most as TO_GENERATE since real AAC files don't exist yet — except the 5 Phase 2 stub paths which exist as placeholder bytes; classification reports them honestly per the cache-fingerprint logic). Exit 0 in plan mode. `tools/tts/last-run.json` is created and gitignored.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| bake_audio.py → manifest.yaml + overrides + reviewed | Reads validated YAML; treats user-edited reviewed.yaml as the source of truth for the review gate. |
| manifest_writer.py → lib/gen/audio_manifest.g.dart + lib/core/manifest/utterance_key.dart | Generates Dart code that downstream Flutter compilation trusts implicitly. Errors here can break the build. |
| bake_audio.py → assets/audio/*.aac | Writes binary asset files that ship in the production app. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-04-01 | Tampering | reviewed.yaml hand-edited to mark unreviewed clips as reviewed | mitigate | text_hash field (D-17) ties review status to specific text+voice. Hand-flipping `reviewed: true` without a matching hash is detected and rejected by manifest_writer (Test 4). |
| T-03-04-02 | Spoofing | bake_audio runs with `--skip-review-gate` and ships unreviewed audio | mitigate | This flag is documented as DANGEROUS and used ONLY by Plan 06's CI sync check (which runs in a sandbox and does NOT commit the result). Pre-commit hook idea: warn if `--skip-review-gate` was the last invocation. Acceptable risk for a local dev pipeline with one developer. |
| T-03-04-03 | Repudiation | Generated lib/gen/audio_manifest.g.dart drifts from manifest.yaml without anyone noticing | mitigate | Plan 06 wires `tools/check-manifest-sync.sh` into CI: it re-runs manifest_writer with `--skip-review-gate` and asserts the output is byte-identical to the committed file. |
| T-03-04-04 | Tampering | Per-utterance failure cascades into a corrupted partial manifest | mitigate | D-03 atomicity: failures are recorded in last-run.json; manifest_writer is invoked ONLY if all entries have NORMALIZED_OK + review-passed status. Partial state never reaches lib/gen/. |
| T-03-04-05 | Information disclosure | last-run.json contains paths and timestamps but no PII | accept | last-run.json is gitignored; even if committed accidentally, contents are inert. |
| T-03-04-06 | Denial of service | Pipeline run takes 65 × (Tiro call + ffmpeg) minutes and a network blip kills it midway | mitigate | Caching + idempotency (D-02) means the next run resumes from where it stopped. last-run.json shows exactly which keys still need work. |
| T-03-04-07 | Elevation of privilege | manifest_writer outputs Dart that exec's arbitrary code | accept | Generated code only declares constants and a getter; no `eval`, no dynamic imports. Jinja2 is rendered with StrictUndefined to prevent silent template variable injection. |

</threat_model>

<verification>
- `python3 -m pytest tools/tts/tests/ -x` passes (cumulative across Plans 01–04)
- `python3 tools/tts/bake_audio.py --plan` exits 0, classifies all 65 utterances
- `python3 tools/tts/bake_audio.py --help` prints documented flags
- `flutter test` and `flutter analyze` still pass — Plan 04 has NOT yet regenerated lib/gen/audio_manifest.g.dart against real Tiro (that's Plan 07); the pre-existing Phase 2 stub still satisfies Phase 2 tests
- `tools/tts/last-run.json` is in `tools/tts/.gitignore`
- `bash tools/check-asset-paths.sh` passes (no real new AAC files yet)
</verification>

<success_criteria>
1. `tools/tts/manifest_writer.py` writes a deterministic, review-gate-enforced, Phase-2-backward-compatible Dart file from manifest.yaml + reviewed.yaml + measured durations. ≥8 tests cover all branches.
2. `tools/tts/bake_audio.py` orchestrates plan / generate / normalize / review / manifest stages with per-utterance atomicity. ≥11 tests cover all stages.
3. AUDIO-02 (pipeline reads manifest + calls Tiro Diljá v2), AUDIO-06 (regenerated lib/gen/audio_manifest.g.dart, no runtime parse), AUDIO-08 (review gate enforced) are all satisfied at the implementation level. Plan 07 will exercise them end-to-end.
4. The pipeline does not regenerate the real Dart manifest in this plan — that requires reviewed.yaml to be populated, which is Plan 07's job after Plan 05 ships the review UI.
</success_criteria>

<output>
After completion, create `.planning/phases/03-tts-pipeline-audio-review-tooling/03-04-SUMMARY.md` covering:
- 4 atomic commits
- bake_audio CLI surface (final flag list)
- manifest_writer template structure (link to the .j2 file)
- The exact Phase 2 stub key → Phase 3 path map (for review during Plan 07)
- Carry-over to Plan 05: review server writes to reviewed.yaml; the schema text_hash field is computed by `manifest_writer.text_hash(used_text, used_voice)` — the review server MUST use the same function
- Carry-over to Plan 06: CI sync check uses `bake_audio.py --skip-review-gate --skip-tiro --plan` to assert manifest.yaml ↔ audio_manifest.g.dart consistency
- Carry-over to Plan 07: bake_audio runs end-to-end against real Tiro for the first time
</output>
