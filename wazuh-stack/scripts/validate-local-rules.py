#!/usr/bin/env python3
"""Fail fast on NeoLabs Wazuh rule mistakes before container recovery begins."""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

STATIC_FIELDS = {
    "user", "srcip", "dstip", "srcport", "dstport", "protocol", "action",
    "id", "url", "data", "extra_data", "status", "system_name",
}


def fail(message: str) -> int:
    print(f"[FAILED] Wazuh rule validation: {message}", file=sys.stderr)
    return 1


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    path = root / "config" / "rules" / "neolabs_vcc_rules.xml"
    if not path.is_file():
        return fail(f"missing {path}")

    text = path.read_text(encoding="utf-8")
    try:
        document = ET.fromstring(text)
    except ET.ParseError as exc:
        return fail(f"invalid XML: {exc}")

    seen_ids: set[str] = set()
    for rule in document.findall(".//rule"):
        rule_id = (rule.attrib.get("id") or "").strip()
        if not rule_id.isdigit():
            return fail("every custom rule must have a numeric id")
        if rule_id in seen_ids:
            return fail(f"duplicate rule id {rule_id}")
        seen_ids.add(rule_id)

        level = (rule.attrib.get("level") or "").strip()
        if not level.isdigit():
            return fail(f"rule {rule_id} has an invalid level")

        for field in rule.findall("field"):
            name = (field.attrib.get("name") or "").strip()
            if name in STATIC_FIELDS:
                return fail(
                    f"rule {rule_id} treats Wazuh static field '{name}' as a dynamic <field>; "
                    f"use the dedicated <{name}> rule element instead"
                )

    if not seen_ids:
        return fail("no NeoLabs custom rules were found")

    print(f"[OK] NeoLabs Wazuh custom rules passed deterministic validation ({len(seen_ids)} rules).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
