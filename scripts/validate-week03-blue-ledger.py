#!/usr/bin/env python3
"""Validate a Week 3 Blue evidence ledger without sending its contents anywhere."""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

HEADERS = ["case_id", "account_id", "event_time_utc", "event_type", "outcome", "source_ip", "alert_or_event_id", "query_time_window_utc", "evidence_reference", "analyst", "notes"]
ACCOUNT = re.compile(r"^syn-credential-storm-pod-01-(?:0[1-9]|1[0-5])$")
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?Z$")


def validate(path: Path) -> list[str]:
    errors: list[str] = []
    with path.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != HEADERS:
            return ["header does not match the Week 3 Blue ledger template"]
        for line, row in enumerate(reader, 2):
            if not ACCOUNT.fullmatch(row["account_id"]):
                errors.append(f"line {line}: invalid account_id")
            if not UTC.fullmatch(row["event_time_utc"]):
                errors.append(f"line {line}: event_time_utc must be ISO 8601 UTC ending in Z")
            if not row["alert_or_event_id"].strip():
                errors.append(f"line {line}: alert_or_event_id is required")
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate-week03-blue-ledger.py LEDGER.csv", file=sys.stderr)
        return 2
    errors = validate(Path(sys.argv[1]))
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Week 3 Blue ledger structure is valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
