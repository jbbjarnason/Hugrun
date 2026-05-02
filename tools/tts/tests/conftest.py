"""Pytest config — augments sys.path so `tools.tts.X` imports work without packaging."""
import sys
from pathlib import Path

# Repo root = three parents up: tools/tts/tests/conftest.py -> tools/tts/tests -> tools/tts -> tools -> <repo>
REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
