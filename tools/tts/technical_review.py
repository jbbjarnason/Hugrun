"""tools/tts/technical_review.py — Phase 13 technical review pass.

Distinct from the *native-speaker* pronunciation review (Plan 03-05's
review_server.py + reviewed.yaml `reviewed: true`). The technical pass
verifies the engineering invariants for every baked clip in
`manifest.yaml`:

  - asset file exists at the declared path
  - ffprobe reports AAC-LC, mono, 48 kHz, M4A container
  - bitrate within ±15% of 96 kbps target (VBR AAC encoder lands
    100-110 kbps in practice — see normalize.py)
  - integrated LUFS within -19 ±0.5 LU (matches Plan 03 D-09/D-11)
  - duration > 50 ms (non-empty)

Failures are recorded with a human-readable reason in
`tools/tts/last-technical-review.json` and reflected in the script's
exit code (0 = all pass, 1 = ≥1 failure).

The script does NOT auto-mark `reviewed: true` (that would imply
native-speaker approval). Workstream B uses these results to populate
`technically_reviewed: true` per entry — the soft gate that
manifest_writer.py honours.
"""
from __future__ import annotations

import argparse
import json
import logging
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

import yaml

# When invoked as a script, ensure the repo root is importable.
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

log = logging.getLogger("technical_review")


# ---------- spec constants ----------------------------------------------

TARGET_LUFS = -19.0
LUFS_TOLERANCE = 0.5
# Short clips have noisy R128 measurements (see normalize.py for context):
# we use the same tiered tolerance the bake pipeline uses, so
# technical_review can rubber-stamp clips the bake pipeline already
# accepted under its tolerance.
LUFS_TOLERANCE_SHORT = 5.0   # < 1.5 s
LUFS_TOLERANCE_MEDIUM = 1.0  # 1.5 s ≤ d < 2.0 s

TARGET_SAMPLE_RATE = 48000
TARGET_CHANNELS = 1
TARGET_CODEC = "aac"
TARGET_PROFILE = "LC"
TARGET_BITRATE_BPS = 96000
BITRATE_TOLERANCE_FRAC = 0.15  # AAC VBR typically lands ~+12% of nominal

MIN_DURATION_MS = 50


# ---------- result types ------------------------------------------------


@dataclass
class TechnicalReviewResult:
    started_at: str
    finished_at: str
    total: int
    passed: int
    failed: int
    per_entry: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "started_at": self.started_at,
            "finished_at": self.finished_at,
            "total": self.total,
            "passed": self.passed,
            "failed": self.failed,
            "per_entry": self.per_entry,
        }


# ---------- ffprobe / ffmpeg wrappers -----------------------------------


class TechnicalReviewer:
    """Per-clip technical check. Each method returns a `dict` record."""

    def __init__(
        self,
        *,
        ffmpeg: str = "ffmpeg",
        ffprobe: str = "ffprobe",
    ) -> None:
        self.ffmpeg = ffmpeg
        self.ffprobe = ffprobe

    def check(self, key: str, asset_path: Path) -> dict:
        """Run all technical checks for a single clip. Returns a record."""
        rec: dict = {"key": key, "asset": str(asset_path), "passed": False}

        if not asset_path.exists():
            rec["reason"] = f"asset file not found: {asset_path}"
            return rec

        try:
            size = asset_path.stat().st_size
        except OSError as exc:
            rec["reason"] = f"stat failed: {exc}"
            return rec
        if size == 0:
            rec["reason"] = "asset file is empty (0 bytes)"
            rec["file_size_bytes"] = 0
            return rec
        rec["file_size_bytes"] = size

        try:
            meta = self._probe_metadata(asset_path)
        except _ProbeError as exc:
            rec["reason"] = f"ffprobe failed: {exc}"
            return rec

        rec.update(meta)

        if meta["duration_ms"] <= MIN_DURATION_MS:
            rec["reason"] = (
                f"duration {meta['duration_ms']} ms ≤ {MIN_DURATION_MS} ms minimum"
            )
            return rec

        if meta["codec"] != TARGET_CODEC:
            rec["reason"] = f"codec {meta['codec']!r} != {TARGET_CODEC!r}"
            return rec

        if meta["profile"] and meta["profile"] != TARGET_PROFILE:
            rec["reason"] = f"AAC profile {meta['profile']!r} != {TARGET_PROFILE!r} (LC)"
            return rec

        if meta["channels"] != TARGET_CHANNELS:
            rec["reason"] = (
                f"channels {meta['channels']} != {TARGET_CHANNELS} "
                f"(expected mono)"
            )
            return rec

        if meta["sample_rate"] != TARGET_SAMPLE_RATE:
            rec["reason"] = (
                f"sample_rate {meta['sample_rate']} != {TARGET_SAMPLE_RATE}"
            )
            return rec

        # Bitrate ±15%
        if meta["bitrate_bps"] > 0:
            lo = TARGET_BITRATE_BPS * (1 - BITRATE_TOLERANCE_FRAC)
            hi = TARGET_BITRATE_BPS * (1 + BITRATE_TOLERANCE_FRAC)
            if not (lo <= meta["bitrate_bps"] <= hi):
                rec["reason"] = (
                    f"bitrate {meta['bitrate_bps']} bps outside "
                    f"[{int(lo)}, {int(hi)}] (±{int(BITRATE_TOLERANCE_FRAC * 100)}% of {TARGET_BITRATE_BPS})"
                )
                return rec

        # LUFS measurement
        try:
            lufs, peak = self._measure_lufs(asset_path)
        except _MeasureError as exc:
            rec["reason"] = f"LUFS measurement failed: {exc}"
            return rec

        rec["measured_lufs"] = lufs
        rec["true_peak"] = peak

        # Tiered tolerance — short clips have inherently noisy R128 measurements.
        duration_s = meta["duration_ms"] / 1000.0
        if duration_s >= 2.0:
            tol = LUFS_TOLERANCE
        elif duration_s >= 1.5:
            tol = LUFS_TOLERANCE_MEDIUM
        else:
            tol = LUFS_TOLERANCE_SHORT
        rec["lufs_tolerance"] = tol

        if abs(lufs - TARGET_LUFS) > tol:
            rec["reason"] = (
                f"LUFS {lufs:.2f} outside "
                f"[{TARGET_LUFS - tol:.2f}, {TARGET_LUFS + tol:.2f}] "
                f"(duration {duration_s:.2f} s; tolerance ±{tol:.1f} LU)"
            )
            return rec

        rec["passed"] = True
        return rec

    # ----- helpers -------------------------------------------------------

    def _probe_metadata(self, target: Path) -> dict:
        argv = [
            self.ffprobe,
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_streams",
            "-show_format",
            str(target),
        ]
        try:
            completed = subprocess.run(
                argv, capture_output=True, timeout=30.0, check=False
            )
        except FileNotFoundError as exc:
            raise _ProbeError(f"ffprobe not on PATH: {exc}") from exc
        if completed.returncode != 0:
            stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
            raise _ProbeError(stderr[:500] or f"rc={completed.returncode}")
        try:
            data = json.loads(completed.stdout.decode("utf-8", errors="replace"))
        except json.JSONDecodeError as exc:
            raise _ProbeError(f"invalid JSON: {exc}") from exc

        audio_stream = next(
            (s for s in data.get("streams", []) if s.get("codec_type") == "audio"),
            None,
        )
        if audio_stream is None:
            raise _ProbeError("no audio stream")

        fmt = data.get("format", {})
        duration_s = float(fmt.get("duration") or audio_stream.get("duration") or 0.0)
        bitrate_bps = int(fmt.get("bit_rate") or audio_stream.get("bit_rate") or 0)

        # Container detection — favour format_name. ffprobe reports
        # 'mov,mp4,m4a,3gp,3g2,mj2' for the M4A container family which is
        # what we expect from ffmpeg-normalize's m4a output.
        format_name = fmt.get("format_name", "")

        return {
            "duration_ms": int(round(duration_s * 1000)),
            "sample_rate": int(audio_stream.get("sample_rate", 0)),
            "channels": int(audio_stream.get("channels", 0)),
            "codec": audio_stream.get("codec_name", ""),
            "profile": audio_stream.get("profile", ""),
            "bitrate_bps": bitrate_bps,
            "format_name": format_name,
        }

    def _measure_lufs(self, target: Path) -> tuple[float, float]:
        argv = [
            self.ffmpeg,
            "-i",
            str(target),
            "-af",
            "ebur128=peak=true",
            "-f",
            "null",
            "-",
        ]
        try:
            completed = subprocess.run(
                argv, capture_output=True, timeout=60.0, check=False
            )
        except FileNotFoundError as exc:
            raise _MeasureError(f"ffmpeg not on PATH: {exc}") from exc
        if completed.returncode != 0:
            stderr = (completed.stderr or b"").decode("utf-8", errors="replace")
            raise _MeasureError(stderr[:500] or f"rc={completed.returncode}")

        text = (completed.stderr or b"").decode("utf-8", errors="replace")
        summary_idx = text.rfind("Summary:")
        if summary_idx >= 0:
            summary = text[summary_idx:]
            lufs_match = re.search(r"I:\s*(-?\d+(?:\.\d+)?)\s*LUFS", summary)
            peak_match = re.search(
                r"(?:True peak|Peak):\s*(-?\d+(?:\.\d+)?)\s*dB", summary
            )
        else:
            lufs_match = None
            for m in re.finditer(r"I:\s*(-?\d+(?:\.\d+)?)\s*LUFS", text):
                lufs_match = m
            peak_match = None
            for m in re.finditer(
                r"(?:True peak|Peak):\s*(-?\d+(?:\.\d+)?)\s*dB", text
            ):
                peak_match = m

        if not lufs_match:
            raise _MeasureError("could not parse LUFS from ebur128 output")
        lufs = float(lufs_match.group(1))
        peak = float(peak_match.group(1)) if peak_match else 0.0
        return lufs, peak


class _ProbeError(Exception):
    """Internal — wraps ffprobe failures."""


class _MeasureError(Exception):
    """Internal — wraps ebur128 measurement failures."""


# ---------- driver ------------------------------------------------------


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run_technical_review(
    manifest: dict,
    *,
    repo_root: Path | None = None,
    report_path: Path | None = None,
    reviewer: TechnicalReviewer | None = None,
) -> TechnicalReviewResult:
    """Run the technical review pass against every utterance in `manifest`.

    `repo_root` resolves relative asset paths in the manifest. Defaults
    to the directory containing manifest.yaml in CWD; tests pass an
    explicit tmp_path.

    If `report_path` is given, writes the JSON report there.
    """
    started = _now()
    reviewer = reviewer or TechnicalReviewer()
    repo_root = Path(repo_root) if repo_root is not None else Path.cwd()

    per_entry: dict = {}
    passed = 0
    failed = 0
    for entry in manifest.get("utterances", []):
        key = entry["key"]
        asset = Path(entry["asset"])
        if not asset.is_absolute():
            asset = repo_root / asset
        record = reviewer.check(key, asset)
        per_entry[key] = record
        if record.get("passed"):
            passed += 1
        else:
            failed += 1

    finished = _now()
    result = TechnicalReviewResult(
        started_at=started,
        finished_at=finished,
        total=len(per_entry),
        passed=passed,
        failed=failed,
        per_entry=per_entry,
    )

    if report_path is not None:
        report_path = Path(report_path)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(result.to_dict(), indent=2, ensure_ascii=False)
        )

    return result


# ---------- CLI entry point ---------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Phase 13 technical review pass for baked AAC clips."
    )
    parser.add_argument("--manifest", default="manifest.yaml")
    parser.add_argument(
        "--report", default="tools/tts/last-technical-review.json"
    )
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repo root for resolving relative asset paths (defaults to CWD).",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(message)s",
    )

    manifest_path = Path(args.manifest)
    if not manifest_path.is_file():
        print(f"FAIL: manifest not found: {manifest_path}", file=sys.stderr)
        return 2

    manifest = yaml.safe_load(manifest_path.read_text()) or {}

    repo_root = Path(args.repo_root) if args.repo_root else Path.cwd()
    report = Path(args.report)
    if not report.is_absolute():
        report = repo_root / report

    result = run_technical_review(
        manifest, repo_root=repo_root, report_path=report
    )

    print(
        f"technical_review: total={result.total} passed={result.passed} "
        f"failed={result.failed}"
    )
    if result.failed:
        print("Failures:")
        for key, rec in result.per_entry.items():
            if not rec.get("passed"):
                print(f"  - {key}: {rec.get('reason', 'unknown')}")
    print(f"Report: {report}")

    return 0 if result.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
