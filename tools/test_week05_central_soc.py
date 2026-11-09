"""Week05 central SOC regression tests: no local stack or unscoped access."""
from __future__ import annotations

import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

from tools import neolabs, cli, week05_central


def manifest(**overrides):
    value = {
        "scenario_id": "w05-poisoned-upload",
        "track": "SOC",
        "pod_id": "pod-01",
        "student_ready": True,
        "lab_state": "STUDENT_READY",
        "runtime_mode": "INTERACTIVE_TEST",
        "resources": {
            "resource_type": "soc_enrolment.v1",
            "schema_version": 1,
            "scope_status": "WAZUH_LIVE",
            "central_wazuh_view": True,
            "pod_id": "pod-01",
            "soc_assignment_id": "trusted-assignment",
        },
    }
    value.update(overrides)
    return value


class Week05CentralSocTests(unittest.TestCase):
    def test_pod_scoped_week05_interactive_succeeds_without_local_wazuh(self):
        data = manifest()
        output = io.StringIO()
        with (mock.patch.object(neolabs, "read_arena_session", return_value=None),
              mock.patch.object(neolabs, "read_session", return_value={"session_token": "placeholder"}),
              mock.patch.object(neolabs, "refresh", return_value=data),
              mock.patch.object(neolabs, "start_wazuh_stack", side_effect=AssertionError("local Wazuh was started")),
              redirect_stdout(output)):
            neolabs.do_connect(None)
        self.assertIn("WEEK 05 CENTRAL SOC ACCESS READY", output.getvalue())
        self.assertIn("pod-01", output.getvalue())
        self.assertIn("central Wazuh dashboard", output.getvalue())
        self.assertIn("actual indexed events must still be checked", output.getvalue())

    def test_unpublished_and_wrong_pod_or_scope_fail_closed(self):
        base = manifest()
        bads = [
            {"resources": {**base["resources"], "scope_status": "PENDING_SSH"}},
            {"resources": {**base["resources"], "pod_id": "pod-02"}},
            {"resources": {**base["resources"], "central_wazuh_view": False}},
            {"resources": {**base["resources"], "soc_assignment_id": ""}},
            {"resources": {**base["resources"], "schema_version": 2}},
            {"student_ready": False},
            {"runtime_mode": "AUTH_TEST_ONLY"},
            {"track": "SUPPORT"},
        ]
        for patch in bads:
            with self.subTest(case=patch):
                self.assertFalse(neolabs.week05_central_soc_scope(manifest(**patch)))

    def test_w04_stays_on_legacy_live_path(self):
        data = manifest(scenario_id="w04-broken-gate", runtime_mode="LIVE")
        with (mock.patch.object(neolabs, "read_arena_session", return_value=None),
              mock.patch.object(neolabs, "read_session", return_value={}),
              mock.patch.object(neolabs, "refresh", return_value=data),
              mock.patch.object(neolabs, "connect_soc_live") as live):
            neolabs.do_connect(None)
            live.assert_called_once()

    def test_session_hint_not_authorization_and_never_follows_symlink(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "session.json"
            self.assertFalse(week05_central.session_requests_central_week05(path))
            path.write_text(json.dumps({"session_token": "x", "manifest": manifest()}))
            self.assertTrue(week05_central.session_requests_central_week05(path))
            path.write_text(json.dumps({"session_token": "x", "manifest": manifest(track="PENTEST")}))
            self.assertFalse(week05_central.session_requests_central_week05(path))
            path.write_text(json.dumps({"session_token": "x", "manifest": manifest()}))
            link = Path(d) / "symlink.json"
            link.symlink_to(path)
            self.assertFalse(week05_central.session_requests_central_week05(link))

    def test_doctor_skips_local_stack_with_current_broker_scope(self):
        output = io.StringIO()
        with (mock.patch.object(cli.core, "read_session", return_value={"session_token": "x"}),
              mock.patch.object(cli.core, "refresh", return_value=manifest()),
              mock.patch("subprocess.run", side_effect=AssertionError("local diagnostics used")),
              redirect_stdout(output)):
            self.assertEqual(cli.do_doctor(), 0)
        self.assertIn("WAZUH_LIVE", output.getvalue())
        self.assertIn("does not prove central Wazuh ingestion", output.getvalue())

    def test_launcher_routes_before_docker_and_local_staging(self):
        root = neolabs.ROOT
        linux = (root / "start-neolabs-soc.sh").read_text()
        common = (root / "internal/common/Start-NeoLabsSOC.sh").read_text()
        wrapper = (root / "neolabs").read_text()
        prep = (root / "wazuh-stack/scripts/ensure-prepared.sh").read_text()
        self.assertLess(linux.index("python3 -m tools.week05_central"), linux.index("Checking the native Ubuntu/Debian runtime"))
        self.assertLess(common.index("python3 -m tools.week05_central"), common.index("Ensuring the complete Wazuh installation"))
        self.assertLess(wrapper.index("python3 -m tools.week05_central"), wrapper.index("With-DockerAccess.sh"))
        self.assertIn("No SOC collector credential issued yet", prep)
        self.assertIn("bash ./scripts/stage-vcc-secrets.sh", prep)


if __name__ == "__main__":
    unittest.main()
