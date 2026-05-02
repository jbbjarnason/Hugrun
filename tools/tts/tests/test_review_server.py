"""Tests for tools/tts/review_server.py — Plan 05 local review UI."""
from __future__ import annotations

import json
import shutil
import threading
import time
import urllib.request
import urllib.error
from pathlib import Path

import pytest
import yaml


REPO_ROOT = Path(__file__).resolve().parents[3]


def _setup_minimal_repo(tmp_path: Path) -> Path:
    """Build a minimal repo layout the review server can read against."""
    (tmp_path / "assets" / "audio" / "letters" / "names").mkdir(parents=True)
    (tmp_path / "assets" / "audio" / "narration").mkdir(parents=True)
    # 5-entry manifest (matches the schema fixtures).
    manifest = {
        "version": 1,
        "voice": "is_IS-steinn-medium",
        "language": "is-IS",
        "utterances": [
            {
                "key": "letterA",
                "text": "a",
                "asset": "assets/audio/letters/names/a.aac",
                "kind": "letter_name",
            },
            {
                "key": "letterEth",
                "text": "eð",
                "asset": "assets/audio/letters/names/eth.aac",
                "kind": "letter_name",
            },
            {
                "key": "narrationWelcome",
                "text": "Halló",
                "asset": "assets/audio/narration/welcome_hugrun.aac",
                "kind": "narration",
            },
        ],
    }
    (tmp_path / "manifest.yaml").write_text(yaml.safe_dump(manifest))
    (tmp_path / "pronunciation_overrides.yaml").write_text("version: 1\noverrides: {}\n")
    (tmp_path / "reviewed.yaml").write_text("version: 1\nentries: {}\n")
    # Fake AAC for letterA only.
    (tmp_path / "assets" / "audio" / "letters" / "names" / "a.aac").write_bytes(b"AAC\x00\x00")
    return tmp_path


def _start_server(tmp_path: Path):
    """Start the review server on a kernel-assigned port; return (server, port, thread)."""
    from tools.tts.review_server import build_server

    server = build_server(
        host="127.0.0.1",
        port=0,
        repo_root=tmp_path,
        allow_shutdown=True,
    )
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    # Allow the server a moment to bind.
    time.sleep(0.05)
    return server, port, thread


def _http_get(port: int, path: str) -> tuple[int, bytes]:
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}", timeout=5) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def _http_post(port: int, path: str, body: dict | None = None) -> tuple[int, bytes]:
    data = json.dumps(body or {}).encode("utf-8")
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}{path}",
        data=data,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def test_module_imports():
    from tools.tts.review_server import (  # noqa: F401
        build_server,
        main,
        ReviewServer,
        make_handler,
        text_hash,
    )


def test_get_root_renders(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        status, body = _http_get(port, "/")
        assert status == 200
        text = body.decode("utf-8")
        assert "letterA" in text
        assert "letterEth" in text
        assert "narrationWelcome" in text
        assert "Hugrún audio review" in text
    finally:
        server.shutdown()


def test_get_status_returns_json(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        status, body = _http_get(port, "/status")
        assert status == 200
        payload = json.loads(body)
        assert payload["total"] == 3
        assert payload["reviewed"] == 0
    finally:
        server.shutdown()


def test_get_audio_existing(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        status, body = _http_get(port, "/audio/letterA")
        assert status == 200
        assert body == b"AAC\x00\x00"
    finally:
        server.shutdown()


def test_get_audio_unknown_key_404(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        status, _ = _http_get(port, "/audio/notARealKey")
        assert status == 404
    finally:
        server.shutdown()


def test_get_audio_not_yet_generated_404(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        # letterEth's AAC file does not exist on disk.
        status, body = _http_get(port, "/audio/letterEth")
        assert status == 404
        assert b"not yet generated" in body or b"audio not yet" in body
    finally:
        server.shutdown()


def test_get_static_css(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        status, body = _http_get(port, "/static/review.css")
        assert status == 200
        text = body.decode("utf-8")
        assert "article.row" in text
    finally:
        server.shutdown()


def test_static_path_traversal_rejected(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        status, _ = _http_get(port, "/static/..%2F..%2Fmanifest.yaml")
        assert status == 404
    finally:
        server.shutdown()


def test_post_approve_writes_reviewed_yaml(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        status, body = _http_post(port, "/approve/letterA", {"notes": "OK"})
        assert status == 200
        payload = json.loads(body)
        assert payload["ok"] is True
        assert payload["key"] == "letterA"
        # Verify reviewed.yaml updated on disk.
        reviewed = yaml.safe_load((repo / "reviewed.yaml").read_text())
        assert reviewed["entries"]["letterA"]["reviewed"] is True
        assert reviewed["entries"]["letterA"]["text_hash"].startswith("sha256:")
    finally:
        server.shutdown()


def test_post_approve_unknown_key_404(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        status, _ = _http_post(port, "/approve/notRealKey", {})
        assert status == 404
    finally:
        server.shutdown()


def test_post_rerecord_marks_unreviewed(tmp_path):
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        status, body = _http_post(
            port, "/rerecord/letterEth", {"issue": "ð sounds like d"}
        )
        assert status == 200
        reviewed = yaml.safe_load((repo / "reviewed.yaml").read_text())
        entry = reviewed["entries"]["letterEth"]
        assert entry["reviewed"] is False
        assert "ð sounds like d" in entry["issue"]
    finally:
        server.shutdown()


def test_concurrent_approvals_no_corruption(tmp_path):
    """Concurrent POST /approve calls don't corrupt reviewed.yaml."""
    repo = _setup_minimal_repo(tmp_path)
    server, port, _ = _start_server(repo)
    try:
        keys = ["letterA", "letterEth", "narrationWelcome"]
        threads = []
        results: list = []

        def doit(key):
            results.append(_http_post(port, f"/approve/{key}", {"notes": ""}))

        for k in keys:
            t = threading.Thread(target=doit, args=(k,))
            threads.append(t)
            t.start()
        for t in threads:
            t.join()

        # All 3 should have succeeded.
        assert all(r[0] == 200 for r in results), results
        reviewed = yaml.safe_load((repo / "reviewed.yaml").read_text())
        assert len(reviewed["entries"]) == 3
        for k in keys:
            assert reviewed["entries"][k]["reviewed"] is True
    finally:
        server.shutdown()


def test_refuse_non_loopback_bind():
    """build_server refuses to bind anything other than 127.0.0.1 (D-19)."""
    from tools.tts.review_server import build_server

    with pytest.raises(ValueError) as exc_info:
        build_server(host="0.0.0.0", port=0)
    assert "127.0.0.1" in str(exc_info.value) or "local-only" in str(exc_info.value).lower()
