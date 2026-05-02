"""tools/tts/review_server.py — Plan 05 local-only review UI (D-16, D-19).

Stdlib-only HTTP server (no Flask/FastAPI). Binds 127.0.0.1 ONLY.
Routes:
  GET  /                — render review.html.j2
  GET  /audio/{key}     — serve the AAC asset (path-traversal guard)
  GET  /static/{file}   — serve review.css / review.js
  GET  /status          — JSON: {total, reviewed, blocked, last_reviewed_at}
  POST /approve/{key}   — atomically write reviewed.yaml entry (D-17)
  POST /rerecord/{key}  — mark reviewed:false + queue override
  POST /shutdown        — graceful stop (only if --allow-shutdown)
"""
from __future__ import annotations

import argparse
import http.server
import json
import os
import socketserver
import sys
import threading
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader, select_autoescape

# Repo-root path import shim.
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from tools.tts.schema import (  # noqa: E402
    validate_manifest,
    validate_overrides,
    validate_reviewed,
)
from tools.tts.manifest_writer import text_hash  # noqa: E402

DEFAULT_PORT = 8765
REVIEWER_DEFAULT = os.environ.get("HUGRUN_REVIEWER", "Jon")
TEMPLATES_DIR = Path(__file__).resolve().parent / "templates"
STATIC_DIR = Path(__file__).resolve().parent / "static"


def _resolve_used(entry: dict, overrides: dict, manifest_voice: str) -> tuple[str, str]:
    """Same priority as PiperClient._resolve_text_voice (text + voice)."""
    key = entry["key"]
    override = (overrides or {}).get(key, {}) or {}
    if "text" in override and override["text"]:
        used_text = override["text"]
    elif "phonemes" in override and override["phonemes"]:
        used_text = override["phonemes"]
    else:
        used_text = entry["text"]
    used_voice = entry.get("voice") or manifest_voice
    return used_text, used_voice


def _atomic_write_yaml(path: Path, data: dict) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(yaml.safe_dump(data, sort_keys=True, allow_unicode=True))
    with tmp.open("rb") as f:
        os.fsync(f.fileno())
    tmp.replace(path)


def _row_state(
    key: str,
    reviewed_entry: dict | None,
    used_text: str,
    used_voice: str,
    overrides: dict,
) -> tuple[str, str]:
    """Determine (state, state_label) for the per-row badge."""
    if key in (overrides or {}) and reviewed_entry is None:
        return "rerecord", "re-record queued"
    if reviewed_entry is None:
        return "unreviewed", "unreviewed"
    if reviewed_entry.get("reviewed") is False:
        return "rerecord", "re-record queued"
    expected_hash = text_hash(used_text, used_voice)
    if reviewed_entry.get("text_hash") != expected_hash:
        return "stale", "stale (text changed)"
    return "approved", "approved"


def make_handler(
    manifest_path: Path,
    overrides_path: Path,
    reviewed_path: Path,
    repo_root: Path,
    *,
    allow_shutdown: bool = False,
):
    """Factory returns a BaseHTTPRequestHandler subclass with all paths bound."""
    lock = threading.Lock()
    # Late-init so test code can swap files between requests.
    env = Environment(
        loader=FileSystemLoader(str(TEMPLATES_DIR)),
        autoescape=select_autoescape(["html", "html.j2"]),
        keep_trailing_newline=True,
    )

    class ReviewHandler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.0"

        def log_message(self, format, *args):
            pass  # quiet

        def do_GET(self):  # noqa: N802
            parsed = urllib.parse.urlsplit(self.path)
            path = parsed.path
            if path == "/":
                return self._serve_root()
            if path == "/status":
                return self._serve_status()
            if path.startswith("/audio/"):
                key = urllib.parse.unquote(path[len("/audio/"):])
                return self._serve_audio(key)
            if path.startswith("/static/"):
                name = urllib.parse.unquote(path[len("/static/"):])
                return self._serve_static(name)
            self.send_error(404, "Not Found")

        def do_POST(self):  # noqa: N802
            parsed = urllib.parse.urlsplit(self.path)
            parts = parsed.path.strip("/").split("/")
            if parts[0] == "approve" and len(parts) == 2:
                return self._approve(urllib.parse.unquote(parts[1]))
            if parts[0] == "rerecord" and len(parts) == 2:
                return self._rerecord(urllib.parse.unquote(parts[1]))
            if parts[0] == "shutdown" and allow_shutdown:
                return self._shutdown()
            self.send_error(404, "Not Found")

        # ---------------- handlers ---------------- #

        def _read_state(self) -> tuple[dict, dict, dict]:
            manifest = yaml.safe_load(manifest_path.read_text())
            overrides_data = yaml.safe_load(overrides_path.read_text()) or {"version": 1, "overrides": {}}
            reviewed_data = yaml.safe_load(reviewed_path.read_text()) or {"version": 1, "entries": {}}
            return manifest, overrides_data, reviewed_data

        def _serve_root(self):
            manifest, overrides_data, reviewed_data = self._read_state()
            entries = (reviewed_data.get("entries") or {})
            overrides = (overrides_data.get("overrides") or {})

            rows = []
            reviewed_count = 0
            for u in manifest["utterances"]:
                used_text, used_voice = _resolve_used(u, overrides, manifest["voice"])
                rev_entry = entries.get(u["key"])
                state, state_label = _row_state(u["key"], rev_entry, used_text, used_voice, overrides)
                if state == "approved":
                    reviewed_count += 1
                rows.append(
                    {
                        "key": u["key"],
                        "kind": u["kind"],
                        "starts_with": u.get("starts_with", ""),
                        "notes_for_reviewer": u.get("notes_for_reviewer", ""),
                        "used_text": used_text,
                        "used_voice": used_voice,
                        "state": state,
                        "state_label": state_label,
                        "audio_exists": (repo_root / u["asset"]).is_file(),
                        "notes": (rev_entry or {}).get("notes", "") if rev_entry else "",
                    }
                )

            html = env.get_template("review.html.j2").render(
                utterances=rows, total=len(rows), reviewed_count=reviewed_count
            )
            body = html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _serve_status(self):
            manifest, overrides_data, reviewed_data = self._read_state()
            entries = reviewed_data.get("entries") or {}
            total = len(manifest["utterances"])
            reviewed_ok = sum(1 for v in entries.values() if v.get("reviewed") is True)
            blocked = sum(1 for v in entries.values() if v.get("reviewed") is False)
            last_ts = ""
            for v in entries.values():
                ts = v.get("timestamp", "")
                if ts > last_ts:
                    last_ts = ts
            payload = {
                "total": total,
                "reviewed": reviewed_ok,
                "blocked": blocked,
                "last_reviewed_at": last_ts,
            }
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _serve_audio(self, key: str):
            manifest, _, _ = self._read_state()
            by_key = {u["key"]: u for u in manifest["utterances"]}
            if key not in by_key:
                self.send_error(404, f"unknown utterance key: {key}")
                return
            asset = by_key[key]["asset"]
            full = (repo_root / asset).resolve()
            audio_root = (repo_root / "assets" / "audio").resolve()
            try:
                full.relative_to(audio_root)
            except ValueError:
                self.send_error(400, "asset path outside assets/audio/")
                return
            if not full.is_file():
                self.send_error(404, f"audio not yet generated: {asset}")
                return
            data = full.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "audio/mp4")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
            self.wfile.write(data)

        def _serve_static(self, name: str):
            allowed = {".css": "text/css", ".js": "application/javascript"}
            ext = Path(name).suffix
            if ext not in allowed:
                self.send_error(404)
                return
            full = (STATIC_DIR / name).resolve()
            if not full.is_file() or STATIC_DIR.resolve() != full.parent:
                self.send_error(404)
                return
            data = full.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", allowed[ext] + "; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _read_post_json(self) -> dict:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0:
                return {}
            raw = self.rfile.read(length)
            try:
                return json.loads(raw.decode("utf-8"))
            except json.JSONDecodeError:
                return {}

        def _approve(self, key: str):
            body = self._read_post_json()
            with lock:
                manifest, overrides_data, reviewed_data = self._read_state()
                by_key = {u["key"]: u for u in manifest["utterances"]}
                if key not in by_key:
                    self.send_error(404, f"unknown key: {key}")
                    return
                used_text, used_voice = _resolve_used(
                    by_key[key], overrides_data.get("overrides") or {}, manifest["voice"]
                )
                entry = {
                    "reviewed": True,
                    "reviewer": body.get("reviewer", REVIEWER_DEFAULT),
                    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "voice": used_voice,
                    "text_hash": text_hash(used_text, used_voice),
                    "notes": body.get("notes", ""),
                }
                reviewed_data.setdefault("version", 1)
                reviewed_data.setdefault("entries", {})
                reviewed_data["entries"][key] = entry

                # Validate before write.
                vr = validate_reviewed(reviewed_data)
                if not vr.ok:
                    self.send_error(400, f"validation failed: {vr.errors}")
                    return

                _atomic_write_yaml(reviewed_path, reviewed_data)

            payload = {"ok": True, "key": key, "text_hash": entry["text_hash"]}
            data = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _rerecord(self, key: str):
            body = self._read_post_json()
            with lock:
                manifest, overrides_data, reviewed_data = self._read_state()
                by_key = {u["key"]: u for u in manifest["utterances"]}
                if key not in by_key:
                    self.send_error(404, f"unknown key: {key}")
                    return
                used_text, used_voice = _resolve_used(
                    by_key[key], overrides_data.get("overrides") or {}, manifest["voice"]
                )
                reviewed_data.setdefault("version", 1)
                reviewed_data.setdefault("entries", {})
                reviewed_data["entries"][key] = {
                    "reviewed": False,
                    "reviewer": body.get("reviewer", REVIEWER_DEFAULT),
                    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "voice": used_voice,
                    "text_hash": text_hash(used_text, used_voice),
                    "issue": body.get("issue", "needs re-record"),
                }
                _atomic_write_yaml(reviewed_path, reviewed_data)

            payload = {"ok": True, "key": key}
            data = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _shutdown(self):
            self.send_response(200)
            self.end_headers()
            threading.Thread(target=self.server.shutdown, daemon=True).start()

    return ReviewHandler


class ReviewServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True


def build_server(
    *,
    host: str = "127.0.0.1",
    port: int = DEFAULT_PORT,
    repo_root: Path = Path("."),
    allow_shutdown: bool = False,
) -> ReviewServer:
    if host != "127.0.0.1" and host != "localhost":
        raise ValueError(
            f"refusing to bind {host}: review server is local-only (D-19). "
            f"Use 127.0.0.1 only."
        )
    handler_cls = make_handler(
        manifest_path=repo_root / "manifest.yaml",
        overrides_path=repo_root / "pronunciation_overrides.yaml",
        reviewed_path=repo_root / "reviewed.yaml",
        repo_root=repo_root,
        allow_shutdown=allow_shutdown,
    )
    return ReviewServer((host, port), handler_cls)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Hugrún audio review server (Plan 05).")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--allow-shutdown", action="store_true",
                        help="enable POST /shutdown (used by tests; off by default in production)")
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args(argv)

    server = build_server(
        host=args.host,
        port=args.port,
        repo_root=Path(args.repo_root).resolve(),
        allow_shutdown=args.allow_shutdown,
    )
    print(f"review server: http://{args.host}:{args.port}/")
    print("(Ctrl-C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
