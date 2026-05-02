---
phase: 3
plan: 05
plan-name: review-ui
status: complete
date: 2026-05-02
duration: ~25 min
requirements_satisfied:
  - AUDIO-08
  - AUDIO-09
key-files:
  created:
    - tools/tts/review_server.py
    - tools/tts/templates/review.html.j2
    - tools/tts/static/review.css
    - tools/tts/static/review.js
    - tools/tts/tests/test_review_server.py
  modified: []
decisions:
  - "Stdlib http.server (no Flask/FastAPI dep) — keeps the dev tool footprint minimal."
  - "127.0.0.1 binding ENFORCED in build_server (D-19) — refuses non-loopback hosts at construction time."
  - "Path-traversal guard for /audio/{key}: resolved path must stay under assets/audio/ (commonpath check)."
  - "Concurrent-safe atomic_write_yaml: write-tmp + os.replace; threading.Lock around state read+write."
  - "Per-row state palette (4 colors): approved (green), stale (yellow), rerecord (gray), unreviewed (red). State encoded BOTH by color AND by an emoji/symbol in the badge — color-blind safe."
---

# Plan 03-05 Summary — Review UI

## What was built

| Artifact | Purpose |
|---|---|
| `tools/tts/review_server.py` | Stdlib http.server-based local review UI; binds 127.0.0.1 only. 7 routes (GET / /status /audio /static, POST /approve /rerecord /shutdown). text_hash imported from manifest_writer for review-gate consistency. |
| `tools/tts/templates/review.html.j2` | Server-side rendered HTML; one <article> per utterance. autoescape=True (XSS guard for reviewer notes). |
| `tools/tts/static/review.css` | ~80 lines minimal CSS; large tap targets (44 px min for web a11y); high-contrast text. |
| `tools/tts/static/review.js` | Vanilla JS, no framework. Approve / Re-record / bulk-approve handlers. Auto-advance on approval. |

## Atomic commits

| Hash | Type | Message |
|---|---|---|
| `4d4462a` | feat | feat(03-05): add review_server.py + HTML/CSS/JS for local review UI (Plan 05) |

(Single commit — Plan 05's surfaces are mutually dependent; the HTML
template references /static/* which the server serves, which depends on
the schema validators, etc.)

## Test counts

- 13 pytest cases: GET / renders, /status JSON, /audio/{key} (existing,
  unknown, not-yet-generated), /static (CSS, path-traversal rejected),
  POST /approve writes reviewed.yaml, POST /approve unknown→404, POST
  /rerecord marks unreviewed, concurrent approvals (3-way) without
  corruption, refuse non-loopback bind.

Cumulative: **110 pytest cases** after Plan 05.

## Final port + bind host

- Default port: 8765 (D-19)
- Bind host: 127.0.0.1 (refuses anything else at construction)
- Reviewer name default: env `HUGRUN_REVIEWER` or `Jon`

## HTML/CSS/JS line counts

- review.html.j2: ~40 lines
- review.css: ~80 lines
- review.js: ~80 lines

Total: ~200 lines (matches plan estimate).

## Carry-overs

- **Plan 07 review pass:** Jon runs `python tools/tts/review_server.py`
  while listening to all 65 clips. Each Approve POST atomically updates
  reviewed.yaml with reviewed=true + sha256 text_hash. Re-record POST sets
  reviewed=false + issue text; Jon manually edits
  pronunciation_overrides.yaml between bake re-runs.
- **Plan 06 CI guard:** can poll /status JSON for live-running review state,
  but the canonical CI check reads reviewed.yaml directly.
