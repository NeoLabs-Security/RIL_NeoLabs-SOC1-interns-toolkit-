#!/usr/bin/env python3
"""Offline evidence triage for authorized, synthetic Week 05 Wazuh/VCC NDJSON."""
from __future__ import annotations
import argparse
import json
from pathlib import Path

SCENARIO = "w05-poisoned-upload"
TYPES = {"file.upload_accepted", "file.upload_rejected", "file.upload_quarantined"}


def triage(path: Path, pod: str) -> dict:
    if pod not in {f"pod-{n:02d}" for n in range(1, 6)}:
        raise ValueError("Pod must be one of pod-01..pod-05")
    if not path.is_file() or path.is_symlink() or path.stat().st_size > 8_000_000:
        raise ValueError("Refusing missing/symlinked/oversized event evidence")
    timeline, seen = [], set()
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Invalid JSON at line {line_number}") from exc
        if ev.get("scenario_id") != SCENARIO:
            continue
        if ev.get("pod_id") != pod:
            raise ValueError("Found Week 05 event outside assigned pod: stop and notify mentor")
        if ev.get("synthetic") is not True:
            raise ValueError("Found non-synthetic event: stop")
        if ev.get("event_type") not in TYPES:
            continue
        eid = ev.get("event_id")
        if not isinstance(eid, str) or not eid:
            raise ValueError("Missing event_id")
        if eid in seen:
            continue
        seen.add(eid)
        meta = ev.get("metadata") if isinstance(ev.get("metadata"), dict) else {}
        timeline.append({
            "time_utc": ev.get("event_time"), "event_id": eid,
            "request_id": ev.get("request_id"), "event_type": ev.get("event_type"),
            "outcome": ev.get("outcome"), "reason_code": meta.get("reason_code"),
            "upload_id": meta.get("upload_id"), "sha256": meta.get("sha256"),
        })
    timeline.sort(key=lambda x: str(x["time_utc"]))
    return {"scenario_id": SCENARIO, "pod_id": pod, "total_events": len(timeline),
            "accepted_mismatch": sum(t["reason_code"] == "extension_only_validation" for t in timeline),
            "rejected": sum(t["event_type"] == "file.upload_rejected" for t in timeline),
            "quarantined": sum(t["event_type"] == "file.upload_quarantined" for t in timeline),
            "timeline": timeline}


def report(result: dict) -> str:
    lines = [f"# Week 05 SOC evidence - {result['pod_id']}", "",
             f"Scenario: {result['scenario_id']}",
             f"Events: {result['total_events']}; accepted mismatch: {result['accepted_mismatch']}; rejected: {result['rejected']}; quarantined: {result['quarantined']}",
             "", "| UTC event time | Type | Reason | Request ID | Event ID |",
             "|---|---|---|---|---|"]
    for t in result["timeline"]:
        fields = [t["time_utc"], t["event_type"], t["reason_code"], t["request_id"], t["event_id"]]
        lines.append("| " + " | ".join(str(f or "-").replace("|", "") for f in fields) + " |")
    lines += ["", "## Analyst notes", "",
              "Validate these IDs against actual indexed Wazuh alerts; this offline report does not prove ingestion.",
              "Use the original event time, not collector or indexer arrival time."]
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", required=True, type=Path, help="Mentor-approved local NDJSON export")
    parser.add_argument("--assigned-pod", required=True)
    parser.add_argument("--out", type=Path, help="Optional new sanitized Markdown report")
    args = parser.parse_args()
    try:
        result = triage(args.file, args.assigned_pod)
    except (OSError, ValueError) as exc:
        raise SystemExit(f"STOP: {exc}") from None
    output = report(result)
    print(output)
    if args.out:
        if args.out.exists():
            raise SystemExit("Refusing to replace prior evidence")
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(output, encoding="utf-8")
