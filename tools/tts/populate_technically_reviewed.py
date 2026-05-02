"""tools/tts/populate_technically_reviewed.py — Phase 13 Workstream B step 2.

Merge `tools/tts/last-technical-review.json` into `reviewed.yaml`:

  - For every passing key, set `technically_reviewed: true` plus the
    audit fields (LUFS, duration, timestamp).
  - Existing `reviewed: true` entries (from native-speaker review)
    are preserved verbatim.
  - Failing keys are skipped (their absence in reviewed.yaml is the
    correct signal — `manifest_writer.py` will refuse to emit them).

Idempotent: running twice produces the same `reviewed.yaml`.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml


def merge(report: dict, reviewed: dict) -> dict:
    """Return a new reviewed-dict with technically_reviewed populated."""
    out = dict(reviewed) if reviewed else {}
    out.setdefault("version", 1)
    entries: dict = dict(out.get("entries") or {})
    timestamp = (
        datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    )

    for key, rec in (report.get("per_entry") or {}).items():
        if not rec.get("passed"):
            continue
        existing = dict(entries.get(key) or {})
        existing["technically_reviewed"] = True
        # Preserve a previous timestamp if present (idempotency).
        existing.setdefault("technically_reviewed_at", timestamp)
        if "measured_lufs" in rec:
            existing["technically_reviewed_lufs"] = round(
                float(rec["measured_lufs"]), 2
            )
        if "duration_ms" in rec:
            existing["technically_reviewed_duration_ms"] = int(
                rec["duration_ms"]
            )
        entries[key] = existing

    out["entries"] = entries
    return out


def _dump_yaml(data: dict) -> str:
    """Stable YAML output with a header comment."""
    body = yaml.safe_dump(
        data,
        default_flow_style=False,
        sort_keys=True,
        allow_unicode=True,
    )
    header = (
        "# reviewed.yaml — reviewer sign-off log (D-17).\n"
        "#\n"
        "# Two independent gates:\n"
        "#   - reviewed: true                  (native-speaker pronunciation)\n"
        "#   - technically_reviewed: true      (Phase 13 engineering pass)\n"
        "#\n"
        "# Phase 13 auto-populates technically_reviewed for clips that pass\n"
        "# tools/tts/technical_review.py (format / loudness / non-empty).\n"
        "# Native-speaker `reviewed: true` is added later via\n"
        "# tools/tts/review_server.py — it requires reviewer + timestamp +\n"
        "# voice + text_hash (audit trail). The Phase 13 manifest_writer.py\n"
        "# soft gate emits the Dart manifest with PRONUNCIATION REVIEW PENDING\n"
        "# warnings until that audit trail is filled in per entry.\n"
    )
    return header + body


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Phase 13 Workstream B: populate reviewed.yaml's "
                    "technically_reviewed field from the latest technical-"
                    "review report."
    )
    parser.add_argument(
        "--report",
        default="tools/tts/last-technical-review.json",
        help="Path to the technical_review.py JSON report.",
    )
    parser.add_argument(
        "--reviewed",
        default="reviewed.yaml",
        help="Path to reviewed.yaml (read + written in place).",
    )
    args = parser.parse_args(argv)

    report_path = Path(args.report)
    reviewed_path = Path(args.reviewed)

    if not report_path.is_file():
        print(f"FAIL: report not found: {report_path}", file=sys.stderr)
        return 2

    report = json.loads(report_path.read_text())
    reviewed = (
        yaml.safe_load(reviewed_path.read_text()) or {}
        if reviewed_path.is_file()
        else {"version": 1, "entries": {}}
    )

    merged = merge(report, reviewed)
    reviewed_path.write_text(_dump_yaml(merged))

    n_tech = sum(
        1 for e in (merged.get("entries") or {}).values()
        if e.get("technically_reviewed") is True
    )
    n_reviewed = sum(
        1 for e in (merged.get("entries") or {}).values()
        if e.get("reviewed") is True
    )
    print(
        f"reviewed.yaml updated: {n_tech} entries with "
        f"technically_reviewed=true, {n_reviewed} with reviewed=true"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
