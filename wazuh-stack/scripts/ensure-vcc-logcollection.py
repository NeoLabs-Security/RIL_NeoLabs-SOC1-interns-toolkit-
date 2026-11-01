#!/usr/bin/env python3
"""Reconcile only the generated, synthetic VCC Wazuh log input.

Never regenerate certificates, credentials or the full Wazuh config just to
enable startup log replay. Preserve every unrelated <localfile> and setting.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path


LOCATION = "<location>/var/ossec/logs/vcc/vcc-events.ndjson</location>"
SETTING = "<only-future-events>no</only-future-events>"


def reconcile(text: str) -> str:
    blocks = list(re.finditer(r"<localfile>.*?</localfile>", text, re.DOTALL))
    selected = [match for match in blocks if LOCATION in match.group(0)]
    if len(selected) != 1:
        raise ValueError("expected exactly one generated VCC telemetry <localfile> block")

    match = selected[0]
    block = match.group(0)
    if "<log_format>json</log_format>" not in block:
        raise ValueError("VCC telemetry localfile no longer has JSON log format")

    future = re.findall(r"<only-future-events>.*?</only-future-events>", block)
    if len(future) > 1:
        raise ValueError("VCC telemetry localfile has duplicate only-future-events settings")

    if future:
        if future[0] not in (
            "<only-future-events>yes</only-future-events>",
            SETTING,
        ):
            raise ValueError("unexpected VCC only-future-events setting")
        updated = block.replace(future[0], SETTING, 1)
    else:
        updated = block.replace(
            "<log_format>json</log_format>",
            "<log_format>json</log_format>\n"
            "    <!-- Read synthetic training events delivered before manager startup. -->\n"
            f"    {SETTING}",
            1,
        )

    return text[: match.start()] + updated + text[match.end() :]


def main(path: Path) -> int:
    if not path.is_file() or path.is_symlink():
        print(f"[FAILED] Missing or invalid generated manager configuration: {path}", file=sys.stderr)
        return 2
    old = path.read_text(encoding="utf-8")
    try:
        new = reconcile(old)
    except ValueError as exc:
        print(f"[FAILED] VCC log input reconciliation: {exc}", file=sys.stderr)
        return 2
    if new == old:
        print("[OK] Generated VCC telemetry input is already startup-replay capable.")
        return 0
    # Keep the existing inode, owner and mode on the private generated file.
    # A healthy running manager is restarted separately on fingerprint changes.
    with path.open("w", encoding="utf-8") as stream:
        stream.write(new)
    print("[OK] Updated only VCC synthetic logcollector input to include earlier events.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: ensure-vcc-logcollection.py <generated-wazuh-manager.conf>")
    raise SystemExit(main(Path(sys.argv[1])))
