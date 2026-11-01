"""Guard Wazuh doctor against misleading false negatives on fresh SOC installs.

The default JSON parent rule 86600 requires timestamp and event_type. Ensure the
doctor probe has both and that its indexer query includes runtime-health events,
without weakening the strict Week 4 authorization verifier.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCTOR = ROOT / "wazuh-stack/scripts/doctor.sh"
STRICT = ROOT / "wazuh-stack/scripts/verify-telemetry-pipeline.sh"


class DoctorRuleProbeTests(unittest.TestCase):
    def test_authentication_probe_matches_json_parent_prerequisites(self):
        text = DOCTOR.read_text(encoding="utf-8")
        probe = next(line for line in text.splitlines() if line.startswith('rule_output='))
        for key in ("schema_version", "timestamp", "event_type", "pod_id", "synthetic"):
            with self.subTest(key=key):
                self.assertIn(r'\"' + key + r'\"', probe)
        self.assertIn(r'authentication.login', probe)
        self.assertIn('100120', text)

    def test_doctor_counts_baseline_but_strict_verifier_keeps_week4_authorization(self):
        text = DOCTOR.read_text(encoding="utf-8")
        self.assertIn(r'\"100180\"', text)
        self.assertIn(r'\"100141\"', text)
        self.assertIn(r'\"100142\"', text)
        strict = STRICT.read_text(encoding="utf-8")
        self.assertIn("['100141','100142']", strict)
        self.assertIn("scenario=='w04-broken-gate'", strict)


if __name__ == "__main__":
    unittest.main()
