"""Regression tests for safe Week 4 synthetic telemetry startup recovery."""
from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RECONCILE = ROOT / "wazuh-stack/scripts/ensure-vcc-logcollection.py"
PREPARE = ROOT / "wazuh-stack/scripts/prepare-stack.sh"
VOLUME = ROOT / "wazuh-stack/scripts/repair-telemetry-volume.sh"
RUNTIME = ROOT / "wazuh-stack/scripts/recover-runtime.sh"

OLD = """<ossec_config>
  <localfile>
    <location>/var/log/unrelated.log</location>
    <log_format>syslog</log_format>
  </localfile>
</ossec_config>
<ossec_config>
  <localfile>
    <location>/var/ossec/logs/vcc/vcc-events.ndjson</location>
    <log_format>json</log_format>
    <label key="neolabs.source">vcc-pod-telemetry</label>
  </localfile>
</ossec_config>
"""


class SocVccStartupRecoveryTests(unittest.TestCase):
    def run_patch(self, text: str):
        with tempfile.TemporaryDirectory() as directory:
            conf = Path(directory) / "wazuh_manager.conf"
            conf.write_text(text)
            proc = subprocess.run(
                ["python3", str(RECONCILE), str(conf)],
                capture_output=True, text=True, timeout=10,
            )
            return proc, conf.read_text()

    def test_existing_config_is_reconciled_without_touching_unrelated_inputs(self):
        proc, result = self.run_patch(OLD)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("<only-future-events>no</only-future-events>", result)
        self.assertIn("<location>/var/log/unrelated.log</location>", result)
        self.assertIn("<log_format>syslog</log_format>", result)
        self.assertEqual(result.count("<only-future-events>no</only-future-events>"), 1)

    def test_config_migration_is_idempotent(self):
        first, updated = self.run_patch(OLD)
        second, unchanged = self.run_patch(updated)
        self.assertEqual(first.returncode, 0)
        self.assertEqual(second.returncode, 0)
        self.assertEqual(updated, unchanged)

    def test_duplicate_or_missing_vcc_input_fails_closed(self):
        input_block = OLD[OLD.rfind("<ossec_config>"):]
        for document in (OLD + input_block, OLD.replace(input_block, "")):
            with self.subTest(document=document[:20]):
                proc, _ = self.run_patch(document)
                self.assertNotEqual(proc.returncode, 0)

    def test_fresh_generated_config_and_prepared_config_both_support_backlog(self):
        prepare = PREPARE.read_text()
        ensure = (ROOT / "wazuh-stack/scripts/ensure-prepared.sh").read_text()
        self.assertIn("<only-future-events>no</only-future-events>", prepare)
        self.assertIn("ensure-vcc-logcollection.py", ensure)

    def test_prepares_shared_log_without_truncation_and_recreates_on_config_drift(self):
        volume = VOLUME.read_text()
        runtime = RUNTIME.read_text()
        self.assertIn("if [ ! -e /data/vcc-events.ndjson ]; then", volume)
        self.assertIn(": > /data/vcc-events.ndjson", volume)
        self.assertIn('"$fingerprint" != "$previous_fingerprint"', runtime)
        self.assertIn("! manager_vcc_input_current", runtime)
        self.assertIn('record_manager_fingerprint "$fingerprint"', runtime)
        self.assertIn("docker compose --env-file .env up -d --force-recreate --no-deps wazuh.manager", runtime)
        self.assertIn("Active Wazuh ossec.conf still lacks", runtime)
        self.assertNotIn("configuration changed; restarting only the manager", runtime)
        self.assertNotIn("docker volume rm", volume)

    def test_config_fingerprint_is_written_only_after_active_config_verification(self):
        runtime = RUNTIME.read_text()
        helper = runtime.split("record_manager_fingerprint() {", 1)[1].split("\\n}", 1)[0]
        self.assertIn("manager_vcc_input_current", helper)
        self.assertIn("return 1", helper)
        self.assertIn("state/wazuh-runtime-fingerprint", helper)
        # The recovery path must not mark desired host files as applied directly.
        outside_helper = runtime.replace(
            "record_manager_fingerprint() {" + helper + "\\n}", ""
        )
        self.assertNotIn('> state/wazuh-runtime-fingerprint', outside_helper)


if __name__ == "__main__":
    unittest.main()
