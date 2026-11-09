#!/usr/bin/env python3
"""Wazuh XML basic structural checks for Week 05 rule additions."""
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RULES = ROOT / "wazuh-stack/config/rules/neolabs_vcc_rules.xml"

class TestWeek05Rules(unittest.TestCase):
    def test_w05_central_verifier_requires_rule_and_exact_event(self):
        script = (ROOT / "wazuh-stack/scripts/verify-week05-rule-engine.sh").read_text()
        self.assertIn("wazuh-logtest", script)
        self.assertIn("wazuh-alerts-*/_search", script)
        self.assertIn("data.event_id", script)
        self.assertIn("data.pod_id", script)
        self.assertIn("data.scenario_id", script)
        self.assertIn("data.payload.scenario_id", script)
        self.assertIn("--index", script)
        self.assertIn("--logtest", script)
        for rule in ("100190", "100191", "100192", "100193"):
            self.assertIn(rule, script)

    def test_all_local_wazuh_visibility_checks_include_week5_rule_ids(self):
        strict = (ROOT / "wazuh-stack/scripts/verify-telemetry-pipeline.sh").read_text()
        doctor = (ROOT / "wazuh-stack/scripts/doctor.sh").read_text()
        freshness = (ROOT / "wazuh-stack/scripts/telemetry-freshness.sh").read_text()
        self.assertIn("scenario=='w05-poisoned-upload'", strict)
        for rule in ("100190", "100191", "100192", "100193"):
            self.assertIn("'" + rule + "'", strict)
            self.assertIn(rule, doctor)
            self.assertIn(rule, freshness)
        # Week 04's stricter authorization gate must remain unchanged.
        self.assertIn("['100141','100142']", strict)

    def test_w05_rule_parsing_and_scope(self):
        root = ET.parse(RULES).getroot()
        rules = {r.attrib.get("id"): r for r in root.iter("rule")}
        for number in ("100190", "100191", "100192", "100193"):
            self.assertIn(number, rules)
            self.assertEqual(rules[number].findtext("if_sid"), "100190" if number == "100191" else "100100")
        self.assertIn("w05-poisoned-upload", ET.tostring(rules["100190"], encoding="unicode"))
        self.assertIn("w05-poisoned-upload", ET.tostring(rules["100192"], encoding="unicode"))
        self.assertIn("w05-poisoned-upload", ET.tostring(rules["100193"], encoding="unicode"))
        self.assertIn("extension_only_validation", ET.tostring(rules["100191"], encoding="unicode"))
        self.assertEqual(len([r for r in root.iter("rule") if r.attrib.get("id") == "100142"]), 1)

if __name__ == "__main__":
    unittest.main()
