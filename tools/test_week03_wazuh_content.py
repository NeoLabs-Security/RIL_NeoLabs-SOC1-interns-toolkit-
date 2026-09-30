from __future__ import annotations

import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class Week03WazuhContentTests(unittest.TestCase):
    def test_week3_dashboard_contains_all_live_views(self) -> None:
        path = ROOT / "wazuh-stack" / "dashboard" / "neolabs-saved-objects.ndjson.template"
        objects = {
            item["id"]: item
            for item in (
                json.loads(line)
                for line in path.read_text(encoding="utf-8").splitlines()
                if line.strip()
            )
        }
        expected = {
            "neolabs-week3-network-search",
            "neolabs-week3-identity-search",
            "neolabs-week3-host-search",
            "neolabs-week3-watchlist-search",
            "neolabs-week3-arena",
        }
        self.assertTrue(expected.issubset(objects))
        identity = objects["neolabs-week3-identity-search"]["attributes"]
        self.assertIn("data.synthetic_username", identity["columns"])
        self.assertIn("data.source_ip", identity["columns"])
        watchlist = objects["neolabs-week3-watchlist-search"]["attributes"]
        self.assertIn("rule.id: 100160", watchlist["kibanaSavedObjectMeta"]["searchSourceJSON"])

    def test_week3_high_priority_rules_are_present(self) -> None:
        path = ROOT / "wazuh-stack" / "config" / "rules" / "neolabs_vcc_rules.xml"
        document = ET.fromstring(path.read_text(encoding="utf-8"))
        rules = {rule.attrib["id"]: rule for rule in document.findall(".//rule")}
        self.assertEqual(rules["100122"].attrib["level"], "12")
        self.assertEqual(rules["100160"].attrib["level"], "12")
        self.assertEqual(rules["100122"].findtext("field[@name='event_type']"), r"^identity\.account_hijacked$")
        self.assertEqual(rules["100160"].findtext("field[@name='event_type']"), r"^network\.ip_watchlist_match$")


if __name__ == "__main__":
    unittest.main()
