"""tools/tts/schema.py — Phase 3 Plan 02 YAML schema validators.

Pure-stdlib + dataclasses + re. No pydantic / no jsonschema (kept light).

Three validators:
  - validate_manifest(data)  — manifest.yaml (D-04)
  - validate_overrides(data) — pronunciation_overrides.yaml (D-13, Piper-flavored)
  - validate_reviewed(data)  — reviewed.yaml (D-17)

Each returns a ValidationResult(ok: bool, errors: list[str]). Callers can
inspect errors[] for human-readable messages.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime


ALLOWED_KINDS = frozenset(
    {
        "letter_name",
        "example_word",
        "phoneme",
        "numeral_masculine",
        "numeral_feminine",
        "numeral_neuter",
        "narration",
        "celebration",
    }
)

ASSET_PATH_REGEX = re.compile(r"^assets/audio/[a-z0-9._/-]+\.aac$")
KEY_REGEX = re.compile(r"^[a-z][A-Za-z0-9]*$")  # camelCase, matches Dart enum
ALLOWED_OVERRIDE_FIELDS = frozenset({"text", "phonemes", "length_scale", "noise_scale", "ssml"})

MAX_TEXT_LEN = 500
PHASE2_STUB_KEYS = frozenset(
    {"letterA", "letterEth", "letterThorn", "wordHundur", "narrationWelcome"}
)


@dataclass
class ManifestEntry:
    """Validated manifest.yaml entry. Mirrors the YAML schema verbatim."""
    key: str
    text: str
    asset: str
    kind: str
    starts_with: str | None = None
    voice: str | None = None
    length_scale: float | None = None
    noise_scale: float | None = None
    notes_for_reviewer: str | None = None


@dataclass
class ValidationResult:
    ok: bool
    errors: list[str] = field(default_factory=list)


class ManifestError(Exception):
    """Raised when programmatic callers want to handle validation failure as exception."""


def _check(cond: bool, errors: list[str], msg: str) -> None:
    if not cond:
        errors.append(msg)


def validate_manifest(data: object) -> ValidationResult:
    """Validate the structure of a parsed manifest.yaml document."""
    errors: list[str] = []
    if not isinstance(data, dict):
        return ValidationResult(False, ["manifest: top-level must be a mapping"])

    _check(data.get("version") == 1, errors, "manifest: version must be 1")
    voice = data.get("voice")
    _check(
        isinstance(voice, str) and voice.strip() != "",
        errors,
        "manifest: 'voice' must be a non-empty string",
    )
    _check(data.get("language") == "is-IS", errors, "manifest: 'language' must be 'is-IS'")

    utterances = data.get("utterances")
    if not isinstance(utterances, list) or not utterances:
        errors.append("manifest: 'utterances' must be a non-empty list")
        return ValidationResult(False, errors)

    seen_keys: set[str] = set()
    for i, u in enumerate(utterances):
        if not isinstance(u, dict):
            errors.append(f"manifest: utterances[{i}] must be a mapping")
            continue

        key = u.get("key")
        if not isinstance(key, str):
            errors.append(f"manifest: utterances[{i}]: missing required field 'key'")
            continue

        if key in seen_keys:
            errors.append(
                f"manifest: duplicate key '{key}' (appears more than once)"
            )
        seen_keys.add(key)

        if not KEY_REGEX.match(key):
            errors.append(
                f"manifest: '{key}': key must match camelCase pattern [a-z][A-Za-z0-9]*"
            )

        for required in ("text", "asset", "kind"):
            if required not in u or u[required] in (None, ""):
                errors.append(f"manifest: '{key}': missing required field '{required}'")

        text = u.get("text")
        if isinstance(text, str) and len(text) > MAX_TEXT_LEN:
            errors.append(
                f"manifest: '{key}': text too long ({len(text)} chars > {MAX_TEXT_LEN} max)"
            )

        asset = u.get("asset")
        if isinstance(asset, str) and not ASSET_PATH_REGEX.match(asset):
            errors.append(
                f"manifest: '{key}': asset path '{asset}' violates D-06 "
                f"(must match {ASSET_PATH_REGEX.pattern})"
            )

        kind = u.get("kind")
        if isinstance(kind, str) and kind not in ALLOWED_KINDS:
            errors.append(
                f"manifest: '{key}': kind '{kind}' not in allowed set "
                f"{sorted(ALLOWED_KINDS)}"
            )

        if kind == "example_word":
            sw = u.get("starts_with")
            if not isinstance(sw, str) or sw == "":
                errors.append(
                    f"manifest: '{key}': example_word entries require non-empty 'starts_with'"
                )

    return ValidationResult(not errors, errors)


def validate_overrides(data: object) -> ValidationResult:
    """Validate the structure of pronunciation_overrides.yaml (Piper-flavored, D-13)."""
    errors: list[str] = []
    if not isinstance(data, dict):
        return ValidationResult(False, ["overrides: top-level must be a mapping"])

    _check(data.get("version") == 1, errors, "overrides: version must be 1")

    overrides = data.get("overrides", {})
    if overrides is None:
        overrides = {}
    if not isinstance(overrides, dict):
        errors.append("overrides: 'overrides' must be a mapping (or empty)")
        return ValidationResult(False, errors)

    for key, override in overrides.items():
        if not isinstance(override, dict):
            errors.append(f"overrides: '{key}': override entry must be a mapping")
            continue
        unknown = set(override.keys()) - ALLOWED_OVERRIDE_FIELDS
        if unknown:
            errors.append(
                f"overrides: '{key}': unknown field(s) {sorted(unknown)} "
                f"(allowed: {sorted(ALLOWED_OVERRIDE_FIELDS)})"
            )
        # Optional: text and phonemes are mutually exclusive.
        if "text" in override and "phonemes" in override:
            errors.append(
                f"overrides: '{key}': cannot set both 'text' and 'phonemes' (use one)"
            )
        if "length_scale" in override:
            ls = override["length_scale"]
            if not isinstance(ls, (int, float)) or ls <= 0:
                errors.append(
                    f"overrides: '{key}': length_scale must be a positive number"
                )

    return ValidationResult(not errors, errors)


def validate_reviewed(data: object) -> ValidationResult:
    """Validate the structure of reviewed.yaml (D-17)."""
    errors: list[str] = []
    if not isinstance(data, dict):
        return ValidationResult(False, ["reviewed: top-level must be a mapping"])

    _check(data.get("version") == 1, errors, "reviewed: version must be 1")

    entries = data.get("entries", {})
    if entries is None:
        entries = {}
    if not isinstance(entries, dict):
        errors.append("reviewed: 'entries' must be a mapping (or empty)")
        return ValidationResult(False, errors)

    for key, entry in entries.items():
        if not isinstance(entry, dict):
            errors.append(f"reviewed: '{key}': entry must be a mapping")
            continue

        if "reviewed" not in entry:
            errors.append(f"reviewed: '{key}': missing 'reviewed' field")
            continue
        if not isinstance(entry["reviewed"], bool):
            errors.append(f"reviewed: '{key}': 'reviewed' must be a boolean")

        if entry.get("reviewed") is True:
            # Approved entries require the full audit trail.
            for required in ("reviewer", "timestamp", "voice", "text_hash"):
                if required not in entry or entry[required] in (None, ""):
                    errors.append(
                        f"reviewed: '{key}': missing required field '{required}' "
                        f"(approved entries need reviewer + timestamp + voice + text_hash)"
                    )

            ts = entry.get("timestamp")
            if isinstance(ts, str):
                try:
                    # Python 3.11+ accepts the trailing "Z" via fromisoformat.
                    datetime.fromisoformat(ts.replace("Z", "+00:00"))
                except ValueError:
                    errors.append(
                        f"reviewed: '{key}': timestamp '{ts}' is not ISO-8601"
                    )

            text_hash = entry.get("text_hash")
            if isinstance(text_hash, str) and not text_hash.startswith("sha256:"):
                errors.append(
                    f"reviewed: '{key}': text_hash must start with 'sha256:'"
                )

    return ValidationResult(not errors, errors)
