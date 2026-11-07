#!/usr/bin/env python3
"""Wazuh XML basic structural checks for Week 05 rule additions."""
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RULES = ROOT / "wazuh-stack/config/rules/neolabs_vcc_rules.xml"

class TestWeek05Rules(unittest.TestCase):
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
