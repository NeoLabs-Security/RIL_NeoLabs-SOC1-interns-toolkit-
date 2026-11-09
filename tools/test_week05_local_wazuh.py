"""Week05 SOC regression: Wazuh still installs/starts on the intern's own host."""
from __future__ import annotations

import io
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

from tools import neolabs


def manifest(**kwargs):
    base={
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
        "soc_assignment_id": "w05-soc-pod01",
      },
    }
    base.update(kwargs)
    return base


class Week05LocalWazuhTests(unittest.TestCase):
    def test_connect_uses_real_live_soc_enrollment(self):
        m=manifest()
        with mock.patch.object(neolabs,"read_arena_session",return_value=None), \
             mock.patch.object(neolabs,"read_session",return_value={"session_token":"redacted"}), \
             mock.patch.object(neolabs,"refresh",return_value=m), \
             mock.patch.object(neolabs,"connect_soc_live") as live:
            neolabs.do_connect(None)
            live.assert_called_once()
            self.assertEqual(live.call_args.args[1],m)

    def test_missing_or_mismatched_resources_fail_closed(self):
        original=manifest()
        cases=[
            {"resources":{**original["resources"],"scope_status":"PENDING_SSH"}},
            {"resources":{**original["resources"],"soc_assignment_id":""}},
            {"resources":{**original["resources"],"pod_id":"pod-02"}},
            {"resources":{**original["resources"],"schema_version":2}},
            {"track":"SUPPORT"},
            {"runtime_mode":"AUTH_TEST_ONLY"},
        ]
        for case in cases:
            with self.subTest(case=case):
                m=manifest(**case)
                with mock.patch.object(neolabs,"read_arena_session",return_value=None), \
                     mock.patch.object(neolabs,"read_session",return_value={}), \
                     mock.patch.object(neolabs,"refresh",return_value=m), \
                     mock.patch.object(neolabs,"connect_soc_live") as live:
                    with self.assertRaises(SystemExit):
                        neolabs.do_connect(None)
                    live.assert_not_called()

    def test_no_change_to_w04_live_flow(self):
        m=manifest(scenario_id="w04-broken-gate",runtime_mode="LIVE")
        with mock.patch.object(neolabs,"read_arena_session",return_value=None), \
             mock.patch.object(neolabs,"read_session",return_value={}), \
             mock.patch.object(neolabs,"refresh",return_value=m), \
             mock.patch.object(neolabs,"connect_soc_live") as live:
            neolabs.do_connect(None)
            live.assert_called_once()

    def test_startup_provisions_local_runtime_before_login(self):
        root=neolabs.ROOT
        launcher=(root/"start-neolabs-soc.sh").read_text()
        common=(root/"internal/common/Start-NeoLabsSOC.sh").read_text()
        wrapper=(root/"neolabs").read_text()
        ensure=(root/"wazuh-stack/scripts/ensure-prepared.sh").read_text()
        self.assertIn("Repair-NeoLabsRuntime.sh",launcher)
        self.assertNotIn("tools.week05_central",launcher)
        self.assertNotIn("tools.week05_central",common)
        self.assertNotIn("tools.week05_central",wrapper)
        self.assertLess(common.index("ensure-prepared.sh"),common.index("python3 -m tools.cli login"))
        self.assertLess(common.index("python3 -m tools.cli login"),common.index("python3 -m tools.cli connect"))
        self.assertIn("No SOC collector credential issued yet",ensure)
        self.assertIn("bash ./scripts/stage-vcc-secrets.sh",ensure)
        self.assertIn("python3 -m tools.cli connect",common)


if __name__ == "__main__":
    unittest.main()
