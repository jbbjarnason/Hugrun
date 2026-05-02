---
phase: 03-tts-pipeline-audio-review-tooling
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - tools/tts/README.md
  - tools/tts/requirements.txt
  - tools/tts/check_deps.py
  - tools/tts/tiro_spike.py
  - tools/tts/tests/__init__.py
  - tools/tts/tests/test_check_deps.py
  - tools/tts/.gitignore
  - .gitignore
  - pubspec.yaml  # only if needed for asset list note
autonomous: false  # contains a human-verify checkpoint on Tiro reachability
requirements:
  - AUDIO-10
user_setup:
  - service: tiro_tts
    why: "Verify Tiro TTS API reachability + capture exact voice IDs / endpoints / SSML support / rate limit headers before any pipeline code is written (D-06, D-15). All later plans depend on the findings of this spike."
    env_vars:
      - name: TIRO_API_KEY
        source: "Tiro TTS contact — only required if the live curl call returns 401/403. Public service appears unauthenticated per research/STACK.md (MEDIUM confidence). Leave unset unless the spike proves otherwise."
    dashboard_config:
      - task: "Capture Tiro voice ID strings (exact casing for Diljá v2), output formats, SSML support, observed rate limits"
        location: "Live curl against https://tts.tiro.is/v0/speech/synthesize and OpenAPI doc at https://tts.tiro.is — record findings in tools/tts/README.md"

must_haves:
  truths:
    - "ffmpeg, ffmpeg-normalize, and Python 3.11+ are installed locally and on PATH; their versions are recorded in tools/tts/README.md"
    - "Running `python tools/tts/check_deps.py` returns exit 0 with all green checks AFTER all binaries are installed; returns non-zero with actionable messages BEFORE installation"
    - "Running `python tools/tts/tiro_spike.py` against the live Tiro endpoint produces a valid raw-PCM (or WAV) audio file for the test phrase, OR exits with a clear escalation message that the user has acted on (D-06)"
    - "tools/tts/README.md documents the exact Tiro endpoint URL, the exact Diljá v2 voice ID string (verbatim, including casing/diacritics), the verified output format(s), whether SSML is supported, and the observed/conservative rate limit"
    - "tools/tts/requirements.txt pins Python deps (requests OR httpx, pyyaml, jinja2, pytest) at known-good versions"
  artifacts:
    - path: tools/tts/README.md
      provides: "Tiro API findings (endpoint, voice IDs, SSML, rate limits) + dependency install instructions + troubleshooting"
      contains: "Diljá v2"
    - path: tools/tts/requirements.txt
      provides: "Pinned Python dependency list"
      contains: "pyyaml"
    - path: tools/tts/check_deps.py
      provides: "Dependency verification entrypoint (--check-deps mode per D-29)"
      exports: ["main"]
    - path: tools/tts/tiro_spike.py
      provides: "One-shot Tiro verification script (D-06)"
      exports: ["main"]
    - path: tools/tts/tests/test_check_deps.py
      provides: "pytest coverage for check_deps logic (does not require real ffmpeg/Tiro)"
      contains: "def test_"
  key_links:
    - from: tools/tts/check_deps.py
      to: ffmpeg, ffmpeg-normalize, Python deps, optional TIRO_API_KEY
      via: "subprocess.run + shutil.which + import probes"
      pattern: "shutil\\.which\\(['\"]ffmpeg"
    - from: tools/tts/tiro_spike.py
      to: https://tts.tiro.is/v0/speech/synthesize
      via: "requests.post / httpx.post with VoiceId=Diljá v2 (or verified ID)"
      pattern: "tts\\.tiro\\.is"
---

<objective>
Establish the Phase 3 tooling baseline before any pipeline code is written:

1. Install ffmpeg + ffmpeg-normalize locally, install Python deps into a venv (or via pipx), and ship a `--check-deps` script (D-28, D-29) that fails LOUDLY if anything is missing.
2. Run a one-shot Tiro TTS verification spike (D-06) that hits the live `tts.tiro.is` endpoint, captures the exact voice ID string for Diljá v2, confirms output format(s), checks SSML support, and notes any observed rate limits — all documented in `tools/tts/README.md`.
3. **STOP and escalate** if Tiro is unreachable, if Diljá v2 cannot be invoked, or if ffmpeg/ffmpeg-normalize cannot be installed. Plans 02–07 depend on this plan succeeding.

Purpose: Every later plan in Phase 3 (manifest schema, Tiro client, normalize wrapper, manifest writer, review UI, CI guard, end-to-end run) consumes Tiro auth/voice-ID/format/SSML facts and assumes ffmpeg + ffmpeg-normalize are on PATH. Building any of those before this verification has succeeded means rewriting if assumptions turn out wrong (research STACK.md flags Tiro auth/rate limits/voice-ID strings as MEDIUM confidence and explicitly lists them as Open Verification Items).

Output:
- `tools/tts/README.md` with the verified facts (voice ID, endpoint, output formats, SSML, rate limit) and dependency install instructions.
- `tools/tts/requirements.txt` (pinned deps).
- `tools/tts/check_deps.py` (the `--check-deps` entrypoint per D-29) + `tools/tts/tests/test_check_deps.py`.
- `tools/tts/tiro_spike.py` (one-shot verification script).
- `tools/tts/.gitignore` for `_raw/`, `__pycache__/`, `.pytest_cache/`, the venv directory.
- ffmpeg + ffmpeg-normalize installed locally; versions recorded in the README.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/03-tts-pipeline-audio-review-tooling/03-CONTEXT.md
@.planning/phases/02-alphabet-asset-conventions-manifest-stub/02-SUMMARY.md
@.planning/research/SUMMARY.md
@.planning/research/STACK.md
@.planning/research/PITFALLS.md

<interfaces>
<!-- Phase 2 outputs that constrain Phase 3 ergonomics — provided here so the executor does not need to re-explore the codebase. -->

From lib/core/manifest/utterance_key.dart (Phase 2 stub — must remain backward-compatible per D-22):
```dart
enum UtteranceKey {
  letterA,
  letterEth,
  letterThorn,
  wordHundur,
  narrationWelcome,
}
```

From lib/core/manifest/audio_asset.dart (Phase 2 — Phase 3 keeps this shape):
```dart
class AudioAsset {
  const AudioAsset({required this.path, required this.approximateDuration});
  final String path;
  final Duration approximateDuration;
}
```

From .gitignore (Phase 2 line 45 — already has the exception for the generated manifest, do NOT remove this):
```
**/*.g.dart
**/*.gen.dart
**/*.freezed.dart
!lib/gen/audio_manifest.g.dart
```

Existing tools/ pattern (self-testing CI scripts, plain bash; e.g. tools/check-asset-paths.sh + tools/check-asset-paths_test.sh). Phase 3's Python tooling lives alongside under tools/tts/ but does not replace the bash convention.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Tooling baseline — install binaries + scaffold tools/tts/ with --check-deps (TDD)</name>
  <files>
    tools/tts/README.md
    tools/tts/requirements.txt
    tools/tts/check_deps.py
    tools/tts/tests/__init__.py
    tools/tts/tests/test_check_deps.py
    tools/tts/.gitignore
    .gitignore
  </files>
  <behavior>
    Test 1 (RED): `python -m pytest tools/tts/tests/test_check_deps.py` runs and fails because `tools/tts/check_deps.py` does not yet exist or does not yet export `check_binaries(required: list[str]) -> list[CheckResult]`.
    Test 2: `check_binaries(['ffmpeg', 'ffmpeg-normalize', 'python3'])` returns one CheckResult per binary with `.ok: bool`, `.found_path: str | None`, `.version: str | None`, `.message: str` — verified by mocking `shutil.which` and `subprocess.run` so the test does not need the real binaries.
    Test 3: `check_python_modules(['yaml', 'jinja2'])` returns equivalent CheckResults; missing modules surface `.ok=False` and a `pip install` hint in `.message`.
    Test 4: `check_env_vars(['TIRO_API_KEY'], required=False)` reports presence/absence without failing the run when `required=False` (per research finding that Tiro is likely unauthenticated; D-06 verifies).
    Test 5: `main(argv=['--check-deps'])` exits 0 only when every required check passes; non-zero with a single consolidated multi-line summary otherwise.
    Test 6: `main(argv=['--json'])` emits a single-line JSON document with all CheckResults — used by later automation hooks (no consumer in Phase 3, but cheap to ship and keeps the tool composable).
  </behavior>
  <action>
    Per D-01, scaffold `tools/tts/` exactly as specified in the CONTEXT.md folder layout (do NOT create bake_audio.py, tiro_client.py, normalize.py, manifest_writer.py, or review_server.py here — those are owned by later plans). Per D-28 + D-29:

    1. **RED commit**: write `tools/tts/tests/__init__.py` (empty) and `tools/tts/tests/test_check_deps.py` covering Tests 1–6 above. Tests should import from `tools.tts.check_deps`. Use a `conftest.py` (or a path append at the top of the test file) so pytest picks up the `tools/tts/` directory without requiring a wheel install. Run pytest, confirm RED. Commit:
       `test(03-01): add failing pytest harness for tools/tts/check_deps`
       (the commit explicitly references that ffmpeg / ffmpeg-normalize are not yet installed; tests must NOT depend on them).

    2. **Install binaries (manual / interactive)**: run `brew install ffmpeg` AND install `ffmpeg-normalize`. Per D-28 prefer `pipx install ffmpeg-normalize` (isolated venv, no global pip noise). If pipx is missing, `brew install pipx && pipx ensurepath` first. Fallback only if pipx truly cannot be used: `python3 -m pip install --user ffmpeg-normalize`.
       - **STOP CONDITION**: if `brew install ffmpeg` fails (network down, brew broken, OS unsupported), do NOT proceed. Escalate to the user with the exact error output. The pipeline is useless without ffmpeg.
       - **STOP CONDITION**: if `ffmpeg-normalize --version` fails after install, escalate.
       - Run `ffmpeg -version | head -1` and `ffmpeg-normalize --version` and capture the version strings. Record them in `tools/tts/README.md` (next step).

    3. **Python deps**: write `tools/tts/requirements.txt` pinning at minimum:
       ```
       requests==2.32.4
       pyyaml==6.0.2
       jinja2==3.1.4
       pytest==8.3.3
       ```
       (httpx is fine if you prefer; pick ONE HTTP client — Claude's discretion per D-decision; document the choice in README.md. Pin only if you ship at least one explicit upper bound; "==" is preferred for reproducibility.) Use Python 3.11+ (the system Python on macOS 14+ is fine; verify via `python3 --version`).
       - Create a venv (`python3 -m venv tools/tts/.venv`) OR document that pip-user install is acceptable. If using venv, add `.venv/` to `tools/tts/.gitignore`.
       - `pip install -r tools/tts/requirements.txt` (inside the venv if you chose that path).
       - **STOP CONDITION**: if pip install fails on the active Python, escalate.

    4. **GREEN commit**: write `tools/tts/check_deps.py` implementing the API the tests expect (`check_binaries`, `check_python_modules`, `check_env_vars`, `main`). Use `shutil.which` to locate binaries; use `subprocess.run([binary, '--version'], capture_output=True, text=True, timeout=5)` to capture versions (handle `FileNotFoundError`, non-zero exits, and timeouts). Use `importlib.util.find_spec` for module checks. Print human-readable output by default, JSON when `--json`. Exit 0 on full pass, 1 on any failure (or 2 for "missing optional that is requested but not strictly required" — Claude's discretion).

       The script's `--check-deps` (default) verification covers D-29:
       - ffmpeg, ffmpeg-normalize, python3 (>= 3.11)
       - Python modules: requests (or httpx — match what requirements.txt picked), yaml, jinja2, pytest
       - Env var: TIRO_API_KEY (optional unless the spike in Task 2 proves it's required)

       Run `python -m pytest tools/tts/tests/test_check_deps.py -x`. Confirm GREEN. Run `python tools/tts/check_deps.py` to verify the live machine reports all green. Commit:
       `feat(03-01): add tools/tts/check_deps.py + Python requirements pin`

    5. **README.md** — write `tools/tts/README.md` with the section skeleton below. The Tiro section is filled in by Task 2; here, fill in Setup + Troubleshooting + Versions:
       ```markdown
       # Hugrún TTS Pipeline

       Local-only Python pipeline that turns `manifest.yaml` into reviewed,
       loudness-normalized AAC clips and regenerates `lib/gen/audio_manifest.g.dart`.

       ## Status
       Phase 3 plan 01 — tooling baseline complete; Tiro spike pending Task 2.

       ## Setup
       1. `brew install ffmpeg`
       2. `pipx install ffmpeg-normalize` (or `pip install --user`)
       3. `python3 -m venv tools/tts/.venv && source tools/tts/.venv/bin/activate`
          (optional — pip-user install also works)
       4. `pip install -r tools/tts/requirements.txt`
       5. `python tools/tts/check_deps.py`  # all green

       ## Verified versions (2026-05-02)
       - ffmpeg: <captured>
       - ffmpeg-normalize: <captured>
       - python3: <captured>

       ## Tiro TTS facts
       (filled in by tools/tts/tiro_spike.py — see Task 2)

       ## Troubleshooting
       - "ffmpeg: command not found" → `brew install ffmpeg`
       - "ffmpeg-normalize: command not found" → `pipx install ffmpeg-normalize`
       - "ModuleNotFoundError: No module named 'requests'" → `pip install -r tools/tts/requirements.txt`
       - "TIRO_API_KEY not set" → only required if the spike proved Tiro requires auth (currently MEDIUM-confidence: appears unauthenticated)
       ```

    6. **`.gitignore` updates**:
       - Add `tools/tts/.gitignore` with: `_raw/\n__pycache__/\n*.pyc\n.pytest_cache/\n.venv/\n` (the `_raw/` rule satisfies D-08's "raw cache lives at tools/tts/_raw" + the deferred-ideas note that raw outputs are not committed).
       - Verify the repo `.gitignore` already excludes `**/*.g.dart` with the `!lib/gen/audio_manifest.g.dart` exception (it does, per Phase 2). Do NOT change this in Plan 01 — it is already correct.

    Atomic commit count for Task 1: 2 (RED + GREEN). README + gitignores ride along with GREEN since they are non-functional.

    Per Plan 02 onwards we use `from tools.tts.X import Y` import paths — make `tools/tts/__init__.py` empty if pytest discovery requires it. (Plan 01 may not strictly need it if `conftest.py` augments sys.path; choose the approach that keeps Plans 02–06 simplest.)
  </action>
  <verify>
    <automated>brew --version >/dev/null && which ffmpeg && which ffmpeg-normalize && python3 -m pytest tools/tts/tests/test_check_deps.py -x && python3 tools/tts/check_deps.py</automated>
  </verify>
  <done>
    `python3 tools/tts/check_deps.py` exits 0 with every check green on the local machine. `pytest tools/tts/tests/test_check_deps.py` passes (≥6 tests). `tools/tts/README.md` exists with versions filled in. The `_raw/` cache directory rule is in `tools/tts/.gitignore`. `.gitignore` for `lib/gen/audio_manifest.g.dart` exception is intact (Phase 2 invariant — verified, not changed).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Tiro TTS verification spike — live API call + findings into README (D-06, D-15)</name>
  <files>
    tools/tts/tiro_spike.py
    tools/tts/tests/test_tiro_spike.py
    tools/tts/README.md
    tools/tts/_raw/.gitkeep
  </files>
  <behavior>
    Test 1 (RED): pytest collects `test_tiro_spike.py`; the test for `build_request(text, voice_id, output_format)` fails because the function does not exist yet.
    Test 2: `build_request("halló", "Diljá v2", "pcm")` returns the correct JSON body for Tiro's `/v0/speech/synthesize` (per the OpenAPI spec inferred from research/STACK.md — fields `Text`, `VoiceId`, `OutputFormat`, optionally `SampleRate`, `Engine`).
    Test 3: `parse_response(content_type, body_bytes)` returns a normalized `(format: str, audio_bytes: bytes)` tuple for `audio/wav`, `audio/x-wav`, `audio/L16`, `application/octet-stream` (raw PCM), and `audio/mpeg` (MP3 fallback). Unknown content-types raise a clear `UnsupportedTiroResponseError`.
    Test 4: `mocked Tiro 200` integration test using `requests-mock` (or monkeypatching) returns a fake WAV header + 1 second of silence; `tiro_spike.main(...)` writes the bytes to `tools/tts/_raw/halló.<ext>` and prints a one-line success summary. (No real network in pytest.)
    Test 5: `mocked Tiro 401` test asserts that `main` exits non-zero and prints "TIRO_API_KEY missing or rejected — see tools/tts/README.md" without raising an unhandled exception.
    Test 6: `mocked Tiro 429` test asserts that `main` retries up to 3 times with exponential backoff (per D-07; verify by counting calls + checking that `time.sleep` is invoked with increasing values — patch `time.sleep`).

    NOTE: the **live** call is performed at execution time outside pytest (Action step below) and is what produces the README facts. pytest covers the script's logic deterministically.
  </behavior>
  <action>
    Per D-06: implement and run a one-shot Tiro spike. Per D-07: build in defensive rate limiting from day one. Per D-15: document SSML support after the live call.

    1. **RED commit**: write `tools/tts/tests/test_tiro_spike.py` covering Tests 1–6 above. Use `requests-mock` (add it to `requirements.txt` and re-pip-install) OR `unittest.mock.patch` on `requests.post`; either is fine. Run pytest, confirm RED. Commit:
       `test(03-01): add failing pytest harness for tools/tts/tiro_spike`

    2. **GREEN commit**: write `tools/tts/tiro_spike.py` with this CLI shape:
       ```
       python tools/tts/tiro_spike.py            # default: synthesize "halló" via Diljá v2 → tools/tts/_raw/spike-helloICELAND.wav
       python tools/tts/tiro_spike.py --list-voices  # GET /v0/voices (or whatever the OpenAPI endpoint is — verify and document)
       python tools/tts/tiro_spike.py --text "<phrase>" --voice "<id>" --format pcm
       ```
       Module-level functions:
       - `build_request(text: str, voice_id: str, output_format: str, sample_rate: int = 16000, engine: str = "standard") -> dict`
       - `parse_response(content_type: str, body: bytes) -> tuple[str, bytes]`
       - `synthesize(text, voice_id, *, base_url="https://tts.tiro.is", timeout=30.0, retry_429=3) -> tuple[str, bytes]` — wraps build_request + requests.post + retry/backoff
       - `list_voices(base_url="https://tts.tiro.is") -> list[dict]`
       - `main(argv=None) -> int`

       Default base URL: `https://tts.tiro.is`. Endpoint path is `/v0/speech/synthesize` per research/STACK.md but **the live call in step 3 may correct this**; if it does, update both the code default and `tools/tts/README.md`.

       Run pytest, confirm GREEN. Commit:
       `feat(03-01): add tools/tts/tiro_spike.py with build_request + retry/backoff`

    3. **LIVE call** (this is the actual D-06 verification — manual but scripted):
       - First, attempt `python tools/tts/tiro_spike.py --list-voices` (or `curl https://tts.tiro.is/v0/openapi.json | jq '.paths | keys'` if `--list-voices` doesn't map cleanly to a real endpoint). Capture the actual voice IDs Tiro exposes — pay particular attention to whether Diljá v2 is `Diljá v2`, `Diljá_v2`, `dilja_v2`, `Dilja_v2`, or another casing. STACK.md notes it expects something like `Diljá_v2` but flags this as unverified.
       - Then run `python tools/tts/tiro_spike.py --text "halló Hugrún" --voice "<verified Diljá v2 ID>" --format pcm`. The script must produce a real audio file at `tools/tts/_raw/spike-halloHugrun.wav` (or .pcm/.raw — preserve whatever Tiro returned).
       - **STOP CONDITIONS** (escalate to user, do NOT proceed to Plan 02):
         (a) Connection refused / DNS failure / 5xx storm — Tiro is down or unreachable from this network.
         (b) 401/403 with no obvious `TIRO_API_KEY` path — auth has changed since research; user must obtain a key from tiro.is or pivot to Azure Neural TTS (PROJECT.md fallback).
         (c) Diljá v2 not in the voice list — voice was renamed/removed; user must pick a replacement (Álfur v2 / Bjartur / Rósa) and re-confirm with PROJECT.md "one primary narrator voice".
         (d) Output format does not include raw PCM and does not include WAV — pipeline plans 03+ assume lossless input; if only MP3 is available, document and flag a future plan to revisit format choice (research STACK.md preference is raw PCM → ffmpeg → AAC to avoid lossy-to-lossy transcode).
       - **SSML check (D-15)**: send a small probe like `<speak><phoneme alphabet="ipa" ph="ðr">ðar</phoneme></speak>` (escape XML correctly in JSON). Record whether Tiro returns 200 with audibly different output, 200 with identical output (SSML silently dropped), or 4xx (SSML rejected). If SSML is unsupported, plan 02's `pronunciation_overrides.yaml` must accommodate text-substitution overrides instead (this is already foreseen in D-15).
       - **Rate-limit observation**: hit the synthesize endpoint 5x in 5s with the same payload; record observed response times + any 429s + any `Retry-After` headers. Document the conservative default in README.md (default 1 req/sec per D-07).

    4. **README update commit** — fill in the `## Tiro TTS facts` section of `tools/tts/README.md` with the verified facts, structured exactly so plans 02–04 can copy values without ambiguity:
       ```markdown
       ## Tiro TTS facts (verified 2026-05-02)

       - **Base URL**: https://tts.tiro.is
       - **Synthesize endpoint**: <verified path, e.g. /v0/speech/synthesize>
       - **List-voices endpoint**: <verified path>
       - **Auth**: <none | Bearer TIRO_API_KEY | other>
       - **Voice ID for narrator (Diljá v2)**: `<exact string>`
       - **Output formats supported**: <list, e.g. pcm, wav, mp3, ogg>
       - **Sample rate options**: <list>
       - **SSML support**: <yes / no / partial — describe>
       - **Rate limit observed**: <e.g. no 429s up to 5 req/s; conservative pipeline default = 1 req/s>
       - **Sample call**:
         ```bash
         curl -X POST https://tts.tiro.is/v0/speech/synthesize \
           -H 'content-type: application/json' \
           -d '{"Text":"halló","VoiceId":"<verified>","OutputFormat":"pcm","SampleRate":"16000"}' \
           --output tools/tts/_raw/spike.wav
         ```

       Sources: live call 2026-05-02 (see tools/tts/_raw/spike-halloHugrun.wav for the raw byte output, NOT committed per .gitignore).
       ```

       Commit:
       `docs(03-01): document Tiro TTS facts from live verification spike (D-06, D-15)`

    5. **Add `_raw/` placeholder + ensure it is gitignored**: create `tools/tts/_raw/.gitkeep` (empty file) so the directory exists; verify `tools/tts/.gitignore` already excludes the rest of `_raw/`. The .gitkeep itself is the only file under _raw/ that is committed.

    Atomic commit count for Task 2: 3 (RED + GREEN + docs/live-findings). The live call itself is not a commit — it produces uncommitted bytes under `_raw/`.
  </action>
  <verify>
    <automated>python3 -m pytest tools/tts/tests/ -x && grep -q "Voice ID for narrator (Diljá v2)" tools/tts/README.md && grep -qE "https://tts\.tiro\.is" tools/tts/README.md</automated>
  </verify>
  <done>
    pytest passes for both `test_check_deps.py` and `test_tiro_spike.py` (totaling roughly 12 tests). `tools/tts/README.md` has the Tiro facts section filled in with non-placeholder values for endpoint, voice ID, output formats, SSML support, and rate limit. `tools/tts/_raw/spike-halloHugrun.<ext>` exists locally (not committed). The user has heard the spike audio and confirmed the voice is Diljá v2 in Icelandic (sanity check) — captured in the human-verify checkpoint below.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: Human verify — Tiro spike audio is correct + green-light Plans 02–07</name>
  <what-built>
    Phase 3's tooling baseline + a real raw audio clip from Tiro Diljá v2 saying "halló Hugrún". This is the empirical proof that:
    1. The pipeline plans 02–07 can rely on Tiro reachability + Diljá v2 voice availability.
    2. ffmpeg + ffmpeg-normalize are installed and on PATH.
    3. README.md captures the exact API facts plans 02–04 will encode.

    No Dart code was modified. No assets/ files were modified. No `lib/gen/audio_manifest.g.dart` regeneration occurred (that is Plan 04's responsibility).
  </what-built>
  <how-to-verify>
    1. Run `python3 tools/tts/check_deps.py` — every line should be green; exit code 0.
    2. Run `python3 -m pytest tools/tts/tests/ -x` — both test files pass.
    3. Open the spike output (`tools/tts/_raw/spike-halloHugrun.wav` or whichever extension the Tiro response produced — the exact filename is printed by `tiro_spike.py`). Play it (`afplay tools/tts/_raw/spike-halloHugrun.wav` on macOS, or open in QuickTime).
    4. Confirm: the voice IS Icelandic, the voice IS recognizably Diljá v2 (compare with samples on https://tts.tiro.is if needed), the phrase IS "halló Hugrún" (or whatever text was synthesized), and the audio quality is acceptable as the v1 narrator. Critical sanity check on Hugrún's name in particular — research PITFALLS #1 specifically calls out that proper nouns are TTS pronunciation hot spots.
    5. Read `tools/tts/README.md` § "Tiro TTS facts" and confirm every field has a real value (no placeholders, no `<verified ...>` template strings remaining).
    6. If anything in steps 3–5 is wrong: type a problem description; the executor pauses and we rework before Plan 02 starts.
    7. If everything is correct: type **approved** to release Plans 02–07.

    **STOP / escalation criteria** (executor must surface, not the user):
    - Tiro returned 401/403 → user must obtain `TIRO_API_KEY` from tiro.is contact OR pivot to Azure Neural TTS.
    - Tiro returned only MP3 (no PCM/WAV) → flag in README as a known limitation; later plans must transcode MP3→PCM via ffmpeg before normalize.
    - Diljá v2 voice ID was not findable → halt and re-confirm narrator choice with the user against PROJECT.md "one primary narrator voice".
  </how-to-verify>
  <resume-signal>Type "approved" to release Plans 02–07. Otherwise describe what's wrong with the spike audio or the README facts.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| local Python → Tiro public HTTPS API | Outbound HTTP request crosses developer machine → tts.tiro.is. Untrusted input here is the *response* (server-controlled bytes); the request body is constructed locally from manifest YAML. |
| local filesystem → committed git history | Anything written under `tools/tts/_raw/` must NOT be committed. Raw Tiro outputs may include unreviewed audio that should not enter version control until reviewed (Plan 07). |
| OS shell → installer registries (Homebrew, pipx) | `brew install ffmpeg` and `pipx install ffmpeg-normalize` pull executables from public package registries. Trust model = standard Homebrew/pipx supply chain. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-01-01 | Information disclosure | `tools/tts/_raw/` raw Tiro outputs accidentally committed to git | mitigate | `.gitignore` excludes `_raw/` (verified by `git status` showing the spike file as ignored). README documents that raw outputs are pre-review and must not be shared. |
| T-03-01-02 | Tampering | ffmpeg-normalize / ffmpeg supplied via Homebrew/pipx | accept | Standard supply-chain trust. The macOS Homebrew formula and the pipx-installed `ffmpeg-normalize` are widely audited; alternate sourcing (vendored binary) is not warranted for a kids' app pipeline. |
| T-03-01-03 | Denial of service | Tiro API unreachable / rate-limited mid-spike | mitigate | Defensive 1 req/sec default + 3-retry exponential backoff (per D-07). STOP-condition escalation in Task 2 covers persistent unavailability — explicit user escalation, no silent fallback to a wrong voice. |
| T-03-01-04 | Spoofing | Tiro endpoint hijacked / MITM | accept | HTTPS to `tts.tiro.is` (TLS validated by `requests`/`httpx` defaults). Public service, no shared secret to steal beyond the API key (which Phase 3 reads from env, never logs). |
| T-03-01-05 | Information disclosure | `TIRO_API_KEY` (if it turns out to be required) leaked into logs / commits | mitigate | `tools/tts/check_deps.py` reports presence/absence of `TIRO_API_KEY` but never echoes its value. `tiro_spike.py` does not log request headers. README explicitly tells the user to set the env var via shell, not commit it. |
| T-03-01-06 | Repudiation | Spike was run against a production Tiro that mutated state | accept | Tiro's `/v0/speech/synthesize` is a stateless synthesis endpoint; no user state is mutated server-side. No signing/audit log is needed. |
| T-03-01-07 | Elevation of privilege | Plan 01 introduces a banned tracking SDK via Python deps | mitigate | Python deps live OUTSIDE `pubspec.lock`; they cannot trigger `tools/check-no-tracking.sh`. Verify by running the existing Phase 1 CI guard after Plan 01 lands — must remain green. (Plan 01 deliberately does NOT touch `pubspec.yaml` or `pubspec.lock`.) |

</threat_model>

<verification>
- `python3 tools/tts/check_deps.py` returns exit 0 with all green
- `python3 -m pytest tools/tts/tests/ -x` passes
- `tools/tts/README.md` Tiro facts section has no placeholder values
- `flutter test` still passes (Phase 2's 84 tests — Plan 01 does not touch Dart code so this is a regression check, not a new test count)
- `flutter analyze` returns "No issues found"
- `bash tools/check-no-tracking.sh` passes (Phase 3 introduces no banned SDKs into `pubspec.lock`)
- `bash tools/check-asset-paths.sh` passes (no new assets in Plan 01)
- `git status --ignored | grep tools/tts/_raw` shows `_raw/` files as ignored, never staged
- Human checkpoint approved
</verification>

<success_criteria>
1. ffmpeg + ffmpeg-normalize are installed locally; versions captured in `tools/tts/README.md`.
2. `tools/tts/check_deps.py` exists, has pytest coverage, and reports an all-green local environment.
3. `tools/tts/tiro_spike.py` exists, has pytest coverage with mocked Tiro responses, and has been run against the live Tiro endpoint to produce real bytes under `tools/tts/_raw/`.
4. `tools/tts/README.md` documents (verbatim, not as templates):
   - Tiro base URL + synthesize endpoint path + list-voices endpoint path
   - Auth model (verified by live call)
   - Diljá v2 voice ID exact string
   - Supported output formats
   - SSML support yes/no/partial
   - Observed rate limit + conservative pipeline default
5. The user has listened to the spike output and confirmed Diljá v2 is the correct narrator (human-verify checkpoint approved).
6. No regressions: `flutter test`, `flutter analyze`, `tools/check-no-tracking.sh`, `tools/check-asset-paths.sh` still pass.
7. AUDIO-10 ("Tiro TTS auth, voice ID strings, and rate limits are verified via live curl call; results documented in `tools/tts/README.md`") is satisfied.
</success_criteria>

<output>
After completion, create `.planning/phases/03-tts-pipeline-audio-review-tooling/03-01-SUMMARY.md` covering:
- Atomic commits made (target: 5 — RED check_deps, GREEN check_deps, RED tiro_spike, GREEN tiro_spike, docs/findings)
- Verified Tiro facts (copied from README — endpoint, voice ID, formats, SSML, rate limit)
- ffmpeg / ffmpeg-normalize / Python versions captured locally
- Any STOP-condition escalations encountered and how they were resolved
- Carry-overs to Plan 02 (e.g. "use `<verified voice ID>`", "Tiro returns format X so plan 03's normalize.py must transcode Y → AAC")
</output>
