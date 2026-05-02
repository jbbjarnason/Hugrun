---
phase: 03-tts-pipeline-audio-review-tooling
plan: 03
type: tdd
wave: 3
depends_on: ["03-02"]
files_modified:
  - tools/tts/tiro_client.py
  - tools/tts/normalize.py
  - tools/tts/_raw/.gitkeep  # ensure dir exists
  - tools/tts/tests/test_tiro_client.py
  - tools/tts/tests/test_normalize.py
  - tools/tts/tests/fixtures/raw_silence_1s.wav
  - tools/tts/tests/fixtures/raw_loud_1s.wav
  - tools/tts/requirements.txt
autonomous: true
requirements:
  - AUDIO-02
  - AUDIO-03
  - AUDIO-04
  - AUDIO-05

must_haves:
  truths:
    - "tools/tts/tiro_client.py wraps Tiro HTTP synthesis with rate limiting, exponential-backoff retry on 429, override consultation, and idempotent caching to tools/tts/_raw/{key}.wav"
    - "tools/tts/normalize.py normalizes a raw audio file to -19 LUFS / -1 dBTP, encodes AAC-LC mono 96 kbps 48 kHz M4A, and pads with 20–50 ms leading silence"
    - "Running `python -m pytest tools/tts/tests/test_tiro_client.py tools/tts/tests/test_normalize.py` passes (≥18 tests) — Tiro is mocked; ffmpeg is real"
    - "normalize rejects clips that deviate >±0.5 LU from -19 LUFS after normalization (D-11) — dedicated test asserts the rejection"
    - "tiro_client respects the override priority order — pronunciation_overrides.yaml > manifest.yaml `text` — and surfaces the chosen text to the caller for hashing"
  artifacts:
    - path: tools/tts/tiro_client.py
      provides: "TiroClient class with synthesize(entry, overrides) → (raw_bytes, content_type, used_text, used_voice)"
      exports: ["TiroClient", "TiroError", "TiroRateLimitError", "TiroAuthError"]
    - path: tools/tts/normalize.py
      provides: "Normalizer class: normalize_to_aac(raw_path, target_path) → NormalizeResult(measured_lufs, true_peak, duration_ms)"
      exports: ["Normalizer", "NormalizeError", "NormalizeResult"]
    - path: tools/tts/tests/test_tiro_client.py
      provides: "Mocked-Tiro coverage: rate limiting, 429 retry, 401 surfacing, override priority, caching, voice override"
      contains: "def test_"
    - path: tools/tts/tests/test_normalize.py
      provides: "Real-ffmpeg coverage: LUFS hits target, true-peak below ceiling, silence pad applied, AAC-LC mono 96k 48k confirmed via ffprobe, ±0.5 LU reject path"
      contains: "def test_"
  key_links:
    - from: tools/tts/tiro_client.py
      to: tools/tts/schema.ManifestEntry
      via: "synthesize(entry: ManifestEntry, overrides: dict, ...) — entry comes straight from validated manifest.yaml"
      pattern: "ManifestEntry|entry: dict"
    - from: tools/tts/tiro_client.py
      to: tools/tts/_raw/{key}.wav
      via: "cache file written when synthesis succeeds; read by normalize.py downstream"
      pattern: "_raw/"
    - from: tools/tts/normalize.py
      to: ffmpeg-normalize CLI + ffprobe CLI
      via: "subprocess.run(['ffmpeg-normalize', ...]) and subprocess.run(['ffprobe', ...]) for measurement"
      pattern: "ffmpeg-normalize|ffprobe"
---

<objective>
Build the two pure-IO Python modules that do the actual audio work in the pipeline, with full pytest coverage:

1. **`tools/tts/tiro_client.py`** — HTTP wrapper around Tiro's synthesize endpoint that:
   - Reads a validated `ManifestEntry` + the parsed `pronunciation_overrides.yaml` dict.
   - Picks the right voice (per-utterance override → manifest default).
   - Picks the right text (override.ssml → override.text → entry.text).
   - Issues the request with TIRO_RATE_LIMIT (default 1 req/sec; D-07).
   - Retries 429 with exponential backoff (3 attempts max; D-07).
   - Surfaces 401/403 as a clean `TiroAuthError` (no silent retry).
   - Caches successful responses to `tools/tts/_raw/{key}.wav` (D-08) and returns `(raw_path, used_text, used_voice, content_type)` for the manifest writer to hash later (D-17 text_hash field).
   - Idempotent: if `_raw/{key}.wav` already exists AND its sidecar `_raw/{key}.meta.json` matches the current `(text, voice, override)` triple, skip the network call.

2. **`tools/tts/normalize.py`** — ffmpeg-normalize wrapper that:
   - Takes a raw audio path + a target AAC asset path.
   - Runs `ffmpeg-normalize` at -19 LUFS / -1 dBTP, encoding AAC-LC mono 96 kbps 48 kHz M4A (D-09, D-12).
   - Pads with 20–50 ms leading silence (D-10) — pick 30 ms as the default.
   - Re-measures the output via `ffprobe` / `ebur128` filter and returns the actual integrated LUFS + true peak.
   - **Rejects** clips that deviate >±0.5 LU from -19 LUFS (D-11) — raise `NormalizeError` so the caller (Plan 04 bake_audio.py) can mark the clip as failed.
   - Returns `NormalizeResult(measured_lufs: float, true_peak: float, duration_ms: int, sample_rate: int, channels: int, codec: str)` so the manifest writer can populate `AudioAsset.approximateDuration`.

Purpose: AUDIO-02 (Tiro pipeline), AUDIO-03 (LUFS reject ±0.5), AUDIO-04 (AAC-LC mono 96k 48k M4A), AUDIO-05 (silence pad) are the heart of the audio pipeline. Plan 04's bake orchestrator is glue around these two modules; if either is wrong, every clip is wrong.

This is a TDD plan because the I/O contracts are crisp:
- `synthesize(entry, overrides) → (raw_path, used_text, used_voice, content_type)` is testable against a mocked HTTP layer.
- `normalize_to_aac(raw_path, target_path) → NormalizeResult` is testable against real ffmpeg with controlled-loudness fixture inputs.

Output:
- 2 production modules with ≥18 pytest cases combined.
- 2 test fixture WAVs (silence + intentionally loud) used by normalize tests.
- `requirements.txt` augmented with `requests-mock` if needed.
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
@tools/tts/README.md  # Plan 01 verified Tiro facts
@manifest.yaml         # Plan 02 source of truth
@pronunciation_overrides.yaml
@.planning/research/STACK.md
@.planning/research/PITFALLS.md

<interfaces>
<!-- Plan 02's schema module is the input shape. Embedded so executor doesn't re-explore. -->

From tools/tts/schema.py (Plan 02):
```python
@dataclass
class ManifestEntry:
    key: str
    text: str
    asset: str
    kind: str
    starts_with: str | None = None
    voice: str | None = None
    tempo: float | None = None
    pitch: float | None = None
    notes_for_reviewer: str | None = None

ALLOWED_KINDS = frozenset({"letter_name", "example_word", "phoneme", "numeral_masculine", "numeral_feminine", "numeral_neuter", "narration", "celebration"})
```

Tiro facts from tools/tts/README.md (Plan 01 — VERIFIED):
- Base URL: `https://tts.tiro.is`
- Synthesize endpoint: `<verified path>` (read from README — typically `/v0/speech/synthesize`)
- Auth: `<verified — likely none>`
- Diljá v2 voice ID exact string: `<verified — read README>`
- Output formats: `<verified — pcm and/or wav, possibly mp3>`
- SSML support: `<verified yes/no>`
- Conservative rate limit: `1 req/s` (D-07 default; the README's observed rate may relax this)

Override priority for synthesize (D-14):
1. If `pronunciation_overrides.yaml` has an entry for `entry.key` AND it has `ssml`: send `Text=<ssml string>`, mark `used_text` as the SSML.
2. Else if it has `text`: send `Text=<override text>`, mark `used_text` as the override text.
3. Else: send `Text=entry.text`, mark `used_text` as `entry.text`.

Voice priority:
1. `entry.voice` (per-utterance override) if set.
2. Else manifest top-level `voice`.

The `used_text` and `used_voice` are surfaced so Plan 04's manifest writer can compute `text_hash = sha256(used_text + ":" + used_voice)` for D-17 reviewed.yaml entries (this is what makes the review gate self-invalidating when a manifest text is changed without re-recording).

ffmpeg-normalize invocation skeleton (D-09 + D-12 + D-10):
```bash
ffmpeg-normalize "$RAW" \
  -t -19 \
  --tp -1 \
  --loudness-range-target 7 \
  --keep-loudness-range-target \
  -c:a aac \
  -b:a 96k \
  --sample-rate 48000 \
  --extension m4a \
  -ar 48000 \
  -o "$TARGET_TMP" \
  -f
# then pad:
ffmpeg -y -i "$TARGET_TMP" -af "adelay=30|30,aresample=48000" -ac 1 -c:a aac -b:a 96k -movflags +faststart "$TARGET"
# then measure with ebur128:
ffmpeg -i "$TARGET" -af ebur128=peak=true -f null - 2>&1 | tail -30
```
The exact ffmpeg-normalize flag set may vary by version — Plan 01 captured the installed version; tune if --loudness-range-target rejects with "unrecognized option".

ffmpeg/ffprobe must be on PATH (Plan 01's check_deps.py guarantees this).
</interfaces>
</context>

<tasks>

<task type="tdd" tdd="true">
  <name>Task 1: TiroClient — synthesize, rate limit, retry, override priority, caching (TDD)</name>
  <files>
    tools/tts/tiro_client.py
    tools/tts/tests/test_tiro_client.py
    tools/tts/requirements.txt
  </files>
  <behavior>
    Test 1 (RED): import fails — `from tools.tts.tiro_client import TiroClient`.
    Test 2: `TiroClient(base_url, voice_default).synthesize(entry, overrides={})` issues exactly one POST to `<base_url>/<synthesize_path>` with JSON body containing the verified Tiro field names (Text, VoiceId, OutputFormat). Mocked response = silent WAV bytes. Return value is a `SynthesisResult(raw_path, used_text, used_voice, content_type)`.
    Test 3: voice priority — `entry.voice = "Álfur_v2"` overrides the client's default voice; `used_voice == "Álfur_v2"`.
    Test 4: text priority A — overrides has `{entry.key: {"ssml": "<phoneme...>"}}`; the request body's Text is the SSML string; `used_text` is the SSML string.
    Test 5: text priority B — overrides has `{entry.key: {"text": "hund-ur"}}`; request body's Text is `hund-ur`; `used_text == "hund-ur"`.
    Test 6: text priority C — no override entry; request body's Text is `entry.text`; `used_text == entry.text`.
    Test 7: rate limit — patched `time.sleep`, two synthesize calls in a row → second call sleeps `1.0 - elapsed` seconds (the configured TIRO_RATE_LIMIT default).
    Test 8: 429 retry — first response is 429, second is 200; client retries with exponential backoff; final result is the 200's body. Sleep is patched and assertion checks backoff sequence ([1.0, 2.0, 4.0] truncated to retries).
    Test 9: 429 exhaustion — three 429s in a row → raises `TiroRateLimitError` with the last `Retry-After` header value if present.
    Test 10: 401 → raises `TiroAuthError` immediately (no retry); error message tells the user to set `TIRO_API_KEY` (per Plan 01 README escalation path).
    Test 11: 5xx → raises `TiroError` after one retry; not infinite-looped.
    Test 12: caching — `_raw/{key}.wav` already exists with a sidecar `.meta.json` matching the current (text, voice, override-fingerprint) tuple → no HTTP call made; SynthesisResult returned from cache.
    Test 13: cache invalidation — same `_raw/{key}.wav` exists but sidecar's `text_hash` differs from current → cache miss, HTTP call issued, file overwritten.
    Test 14: content-type passthrough — Tiro returns `audio/L16` (raw PCM) → client wraps the raw PCM in a WAV header before writing to `_raw/{key}.wav`. Tiro returns `audio/wav` → client writes bytes directly. Use `wave` stdlib module for the wrapping.
  </behavior>
  <action>
    **Step A — RED**: write `tools/tts/tests/test_tiro_client.py` covering Tests 1–14. Use `requests_mock` (or `responses` — pick one and add to requirements.txt). Patch `time.sleep` and `time.monotonic` for rate limit tests. Use a `tmp_path` fixture for the cache directory so tests don't write to real `_raw/`. Run pytest, confirm RED. Commit:
    `test(03-03): add failing TiroClient pytest harness (14 cases, mocked HTTP)`

    **Step B — GREEN**: implement `tools/tts/tiro_client.py`. Suggested structure (~200 lines):
    ```python
    import json, os, time, hashlib, wave, io, logging
    from dataclasses import dataclass
    from pathlib import Path
    import requests
    from .schema import ManifestEntry

    log = logging.getLogger(__name__)

    class TiroError(Exception): ...
    class TiroAuthError(TiroError): ...
    class TiroRateLimitError(TiroError): ...

    @dataclass(frozen=True)
    class SynthesisResult:
        raw_path: Path
        used_text: str
        used_voice: str
        content_type: str
        cached: bool

    class TiroClient:
        def __init__(self, *, base_url: str, synthesize_path: str,
                     voice_default: str, output_format: str = "pcm",
                     sample_rate: int = 16000, rate_limit_per_sec: float = 1.0,
                     max_retries: int = 3, timeout: float = 30.0,
                     cache_dir: Path = Path("tools/tts/_raw"),
                     api_key: str | None = None,
                     session: requests.Session | None = None,
                     sleep=time.sleep, monotonic=time.monotonic): ...

        def synthesize(self, entry: ManifestEntry, overrides: dict) -> SynthesisResult: ...

        # private helpers:
        def _resolve_text_voice(self, entry, overrides) -> tuple[str, str]: ...
        def _cache_lookup(self, key, fingerprint) -> SynthesisResult | None: ...
        def _post_with_retry(self, body) -> requests.Response: ...
        def _wrap_raw_pcm_as_wav(self, pcm_bytes: bytes, sample_rate: int, channels: int = 1) -> bytes: ...
    ```

    Implementation notes:
    - Read base_url, synthesize_path, voice_default from explicit __init__ args (no global env-var reads inside the class body — keeps unit tests deterministic). Plan 04 will read these from Plan 01's README.md / env vars and inject them.
    - Cache fingerprint = `sha256(f"{used_text}:{used_voice}:{output_format}:{sample_rate}".encode()).hexdigest()[:16]`. Sidecar JSON stores: `{key, used_text, used_voice, fingerprint, content_type, generated_at}`.
    - When Tiro returns raw PCM (`audio/L16` or `application/octet-stream` with `OutputFormat=pcm`), wrap it in a WAV container using the `wave` stdlib module before writing — downstream `normalize.py` is happier reading WAV than headerless PCM.
    - Honor `TIRO_API_KEY` via `Authorization: Bearer ...` IFF api_key is set. Plan 01's README will say whether this is needed.
    - Backoff schedule: `1.0, 2.0, 4.0` seconds capped at `max_retries`. Use `time.sleep` (patchable in tests).

    Run pytest, confirm GREEN. Commit:
    `feat(03-03): add tools/tts/tiro_client.py with rate limiting, 429 retry, override priority, caching`

    Atomic commit count for Task 1: 2 (RED + GREEN).
  </action>
  <verify>
    <automated>python3 -m pytest tools/tts/tests/test_tiro_client.py -x</automated>
  </verify>
  <done>
    `pytest tools/tts/tests/test_tiro_client.py` passes ≥14 tests. `tools/tts/tiro_client.py` exports `TiroClient`, `SynthesisResult`, `TiroError`, `TiroAuthError`, `TiroRateLimitError`. No real network is hit during pytest.
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 2: Normalizer — ffmpeg-normalize wrapper, silence pad, LUFS measurement, ±0.5 LU reject (TDD with REAL ffmpeg)</name>
  <files>
    tools/tts/normalize.py
    tools/tts/tests/test_normalize.py
    tools/tts/tests/fixtures/raw_silence_1s.wav
    tools/tts/tests/fixtures/raw_loud_1s.wav
  </files>
  <behavior>
    Test 1 (RED): import fails — `from tools.tts.normalize import Normalizer`.
    Test 2: fixture creation — first test in the file generates `raw_silence_1s.wav` (1-second mono 48 kHz silence, ~ -inf LUFS) AND `raw_loud_1s.wav` (1-second 1 kHz tone at ~ -3 LUFS) using ffmpeg's lavfi sources. These are written to `tests/fixtures/` if not already present, then committed. (Generation runs once per test session; subsequent runs read the existing files.)
    Test 3: `Normalizer().normalize_to_aac(raw_loud_1s, target)` produces `target` as an `.aac` file.
    Test 4: target file's integrated LUFS measured by ffprobe ebur128 is in `(-19.5, -18.5)` (within ±0.5 LU of -19; D-11 ENFORCED).
    Test 5: target file's true peak is < -0.5 dBTP (D-09 / -1 dBTP target with safety margin).
    Test 6: target file has 30 ms (±5 ms tolerance) of leading silence — assert by reading the first 1440 samples (30 ms × 48 kHz) and confirming their RMS is near-zero (D-10).
    Test 7: target file is AAC-LC mono 48 kHz — assert via ffprobe JSON output: codec_name == "aac", channels == 1, sample_rate == "48000" (D-12).
    Test 8: target bitrate is in [80k, 112k] (96k ±20%) — ffmpeg variable-rate AAC may not hit exactly 96k, so use a tolerance band.
    Test 9: `NormalizeResult.measured_lufs` is the actual LUFS the function read from ffprobe (used by Plan 04's reporting).
    Test 10: `NormalizeResult.duration_ms` is in `[1000, 1100]` (1 s input + 30 ms pad + ~negligible AAC encoder overhead).
    Test 11: ±0.5 LU REJECT — fabricate a degenerate input (e.g. 0.001 ms of audio, or just-silence) where ffmpeg-normalize cannot reach -19 LUFS. Confirm `NormalizeError` is raised; error message includes the measured LUFS and the target.
    Test 12: idempotent — calling `normalize_to_aac` twice on the same input + target produces byte-identical output (or at least metadata-identical via ffprobe). This validates that the pipeline's "rerun is safe" claim from D-02/D-03 is true at the normalize stage.
  </behavior>
  <action>
    **Step A — RED**: write `tools/tts/tests/test_normalize.py` covering Tests 1–12. The fixture-creation test (Test 2) MUST run first (use a pytest `session`-scoped fixture or a top-of-module helper). Run pytest, confirm RED.

    Generate fixtures (once, then commit):
    ```bash
    # 1 second mono 48 kHz silence
    ffmpeg -y -f lavfi -i 'anullsrc=channel_layout=mono:sample_rate=48000' -t 1 \
      -c:a pcm_s16le tools/tts/tests/fixtures/raw_silence_1s.wav

    # 1 second mono 48 kHz 1 kHz tone at -3 dBFS (~ -3 LUFS)
    ffmpeg -y -f lavfi -i 'sine=frequency=1000:sample_rate=48000:duration=1' \
      -af "volume=-3dB" -ac 1 -c:a pcm_s16le tools/tts/tests/fixtures/raw_loud_1s.wav
    ```

    Commit RED + fixtures:
    `test(03-03): add Normalizer pytest harness + ffmpeg-generated fixtures`

    **Step B — GREEN**: implement `tools/tts/normalize.py`. Suggested structure (~150 lines):
    ```python
    import json, re, subprocess
    from dataclasses import dataclass
    from pathlib import Path

    class NormalizeError(Exception): ...

    @dataclass(frozen=True)
    class NormalizeResult:
        target_path: Path
        measured_lufs: float
        true_peak: float
        duration_ms: int
        sample_rate: int
        channels: int
        codec: str
        bitrate_bps: int

    class Normalizer:
        def __init__(self, *,
                     target_lufs: float = -19.0,
                     true_peak_max: float = -1.0,
                     lufs_tolerance: float = 0.5,
                     bitrate: str = "96k",
                     sample_rate: int = 48000,
                     channels: int = 1,
                     leading_silence_ms: int = 30,
                     ffmpeg: str = "ffmpeg",
                     ffmpeg_normalize: str = "ffmpeg-normalize",
                     ffprobe: str = "ffprobe"): ...

        def normalize_to_aac(self, raw: Path, target: Path) -> NormalizeResult: ...

        # helpers:
        def _run_ffmpeg_normalize(self, raw: Path, intermediate: Path) -> None: ...
        def _pad_with_silence(self, intermediate: Path, target: Path) -> None: ...
        def _measure_lufs(self, target: Path) -> tuple[float, float]: ...  # (integrated_lufs, true_peak)
        def _probe_metadata(self, target: Path) -> dict: ...
    ```

    Implementation notes:
    - Use a `tempfile.TemporaryDirectory` for the intermediate (between ffmpeg-normalize and the silence-pad ffmpeg call). The final target is written atomically (write to `target.with_suffix('.tmp')` then rename).
    - Parse ebur128 output by regex: capture `Integrated loudness:\s+I:\s+(-?\d+\.?\d*) LUFS` and `Peak:\s+(-?\d+\.?\d*) dBFS` (or `True peak:`). Different ffmpeg versions emit slightly different formats — handle both.
    - On `subprocess.CalledProcessError` from any ffmpeg call: raise `NormalizeError` with the captured stderr in the message. Never swallow ffmpeg errors.
    - **±0.5 LU reject (D-11)**: after measurement, if `abs(measured_lufs - target_lufs) > lufs_tolerance`, raise `NormalizeError(f"LUFS {measured_lufs:.2f} outside [{target_lufs - tol}, {target_lufs + tol}]")`.
    - For Test 11 (degenerate input), the realistic trigger is a raw input that's too short or all-silence — ffmpeg-normalize can't measure LUFS on a sub-400ms clip and either errors or produces a wildly off-target output. Construct the test fixture deliberately to land outside the band.

    Run pytest, confirm GREEN. Commit:
    `feat(03-03): add tools/tts/normalize.py — ffmpeg-normalize wrapper with silence pad and ±0.5 LU reject`

    Atomic commit count for Task 2: 2 (RED + GREEN).

    Total Plan 03 atomic commits: 4.
  </action>
  <verify>
    <automated>python3 -m pytest tools/tts/tests/test_normalize.py tools/tts/tests/test_tiro_client.py -x</automated>
  </verify>
  <done>
    `pytest tools/tts/tests/test_normalize.py` passes ≥12 tests using REAL ffmpeg / ffmpeg-normalize / ffprobe (Plan 01 verified all three are installed). The fixture WAVs exist under `tools/tts/tests/fixtures/`. `tools/tts/normalize.py` exports `Normalizer`, `NormalizeResult`, `NormalizeError`. The ±0.5 LU reject path is exercised by a dedicated test, not just code-coverage.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| TiroClient → Tiro HTTPS API | Outbound HTTP. Response bytes (audio + headers) are server-controlled; client treats them as untrusted blobs (writes raw bytes to disk, validates content-type, never executes them). |
| Normalizer → ffmpeg / ffmpeg-normalize / ffprobe subprocesses | Local executables; standard supply chain. Inputs (raw WAV from Tiro) are server-controlled but treated as audio data only. |
| Cache directory `tools/tts/_raw/` | Local-only; never committed (see Plan 01's .gitignore). Sidecar JSON files contain text + voice + hash — no secrets. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-03-01 | Tampering | Tiro returns malformed audio (truncated, wrong codec) | mitigate | normalize.py runs ffprobe and asserts codec/channels/sample_rate; failures raise NormalizeError. tiro_client.py validates content-type matches the requested OutputFormat. |
| T-03-03-02 | Information disclosure | TIRO_API_KEY echoed into logs / error messages | mitigate | tiro_client logger never logs Authorization header. Error messages include status code + body snippet (truncated to 200 chars), not headers. |
| T-03-03-03 | Tampering | ffmpeg-normalize produces a clip with wrong loudness, silently passes downstream | mitigate | The ±0.5 LU reject (D-11) is the explicit defense. Plan 03 enforces this in code; Plan 04's bake_audio aggregates failures and aborts the run. |
| T-03-03-04 | Denial of service | Tiro rate-limits and pipeline runs forever retrying | mitigate | Max 3 retries → TiroRateLimitError surfaces to caller. Plan 04 stops the run on rate-limit exhaustion. |
| T-03-03-05 | Spoofing | Cached `_raw/{key}.wav` is a stale clip that no longer matches manifest text | mitigate | Sidecar JSON includes `(used_text, used_voice, fingerprint)`; cache_lookup re-derives the fingerprint and falls through to the network when it differs. The same hash is later embedded in reviewed.yaml `text_hash` so Plan 04's review gate also catches drift. |
| T-03-03-06 | Information disclosure | Raw Tiro outputs accidentally reach git history | mitigate | `tools/tts/.gitignore` from Plan 01 excludes `_raw/` (only `.gitkeep` is committed). |
| T-03-03-07 | Tampering | A rogue ffmpeg binary on PATH produces malicious output | accept | Standard local-machine trust. `check_deps.py` verifies ffmpeg is from a legitimate install; further mitigation (vendoring ffmpeg) is overkill for a dev pipeline. |
| T-03-03-08 | Repudiation | Cache fingerprints don't include override version → an override change doesn't bust the cache | mitigate | fingerprint = sha256(used_text + used_voice + output_format + sample_rate). Since `used_text` already encodes whatever the override produced, an override change → different used_text → different fingerprint → cache miss. |

</threat_model>

<verification>
- `python3 -m pytest tools/tts/tests/ -x` passes (cumulative ≥45 tests across Plans 01 + 02 + 03)
- `python3 tools/tts/check_deps.py` still exits 0 (Plan 03 added requests_mock to dev requirements; check_deps is dev-stack-aware)
- `flutter test`, `flutter analyze`, `tools/check-asset-paths.sh`, `tools/check-no-tracking.sh` all still pass (no Dart / pubspec / asset changes)
- `git status --ignored | grep tools/tts/_raw` shows _raw/ files as ignored
</verification>

<success_criteria>
1. `tools/tts/tiro_client.py` exists and passes ≥14 mocked-HTTP unit tests covering rate limit, retry, override priority, voice priority, caching, content-type handling, and error surfacing.
2. `tools/tts/normalize.py` exists and passes ≥12 real-ffmpeg unit tests covering target LUFS, true peak, leading silence pad, AAC-LC mono 48k 96k codec metadata, and ±0.5 LU reject.
3. AUDIO-02 (Tiro pipeline reads manifest + calls Diljá v2), AUDIO-03 (LUFS reject ±0.5), AUDIO-04 (AAC-LC mono 96k 48k M4A), AUDIO-05 (silence pad) are satisfied at the module level (Plan 04 wires them into the orchestrator).
4. No real Tiro network call during pytest; no flutter/pubspec/asset changes.
</success_criteria>

<output>
After completion, create `.planning/phases/03-tts-pipeline-audio-review-tooling/03-03-SUMMARY.md` covering:
- 4 atomic commits (2 RED + 2 GREEN)
- ffmpeg-normalize flag set actually used (some flags differ across versions — record what the local version accepted)
- Fixture WAV byte sizes (so Plan 04 can budget pipeline run time)
- Carry-over to Plan 04: TiroClient + Normalizer are the two heavy lifters; bake_audio.py wires `for entry in manifest: tiro_client.synthesize(entry, overrides) -> normalizer.normalize_to_aac(...)`
</output>
