"""Read-only early routing hint for the Week 05 centrally hosted SOC dashboard.

This deliberately NEVER asserts authorization: session metadata is only used
to avoid installing a local Wazuh stack. The actual connect command refreshes
and verifies the current signed broker session/manifest before reporting scope.
"""
from __future__ import annotations

import json
from pathlib import Path


def session_requests_central_week05(path: Path | None = None) -> bool:
    if path is None:
        path = Path.home() / ".neolabs" / "soc" / "session.json"
    try:
        if path.is_symlink() or not path.is_file():
            return False
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError, UnicodeError):
        return False
    if not isinstance(data, dict) or not isinstance(data.get("session_token"), str):
        return False
    manifest = data.get("manifest")
    return (isinstance(manifest, dict)
            and manifest.get("scenario_id") == "w05-poisoned-upload"
            and manifest.get("track") == "SOC")


if __name__ == "__main__":
    raise SystemExit(0 if session_requests_central_week05() else 1)
