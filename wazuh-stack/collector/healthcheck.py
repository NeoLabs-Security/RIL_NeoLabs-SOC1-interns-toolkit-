#!/usr/bin/env python3
"""Container health check for the VCC telemetry collector."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

HEALTH_PATH = Path(os.getenv("VCC_HEALTH_PATH", "/state/collector-health.json"))
POLL_INTERVAL = int(os.getenv("VCC_POLL_INTERVAL_SECONDS", "15"))
MAX_AGE_SECONDS = max(POLL_INTERVAL * 6, 90)
HEALTHY_STATES = {"healthy", "unenrolled"}


def parse_timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def main() -> int:
    try:
        payload = json.loads(HEALTH_PATH.read_text(encoding="utf-8"))
        status = str(payload["status"])
        updated_at = parse_timestamp(str(payload["updated_at"]))
    except (FileNotFoundError, KeyError, ValueError, TypeError, json.JSONDecodeError):
        return 1

    if updated_at.tzinfo is None:
        return 1

    age = (datetime.now(timezone.utc) - updated_at.astimezone(timezone.utc)).total_seconds()
    if age < 0 or age > MAX_AGE_SECONDS:
        return 1

    if status not in HEALTHY_STATES:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
