from __future__ import annotations

import unittest
from unittest import mock

from tools import neolabs


class OfflineFallbackTests(unittest.TestCase):
    def test_explicit_offline_runtime_replays_without_live_enrolment(self) -> None:
        manifest = {
            "student_ready": True,
            "lab_state": "STUDENT_READY",
            "runtime_mode": "offline-fallback",
            "pod_id": "pod-01",
        }
        session = {"session_token": "masked"}
        with (
            mock.patch.object(neolabs, "read_session", return_value=session),
            mock.patch.object(neolabs, "refresh", return_value=manifest),
            mock.patch.object(neolabs, "replay_soc") as replay,
            mock.patch.object(neolabs, "connect_soc_live") as live,
        ):
            neolabs.do_connect(mock.Mock())
        replay.assert_called_once_with(session, manifest)
        live.assert_not_called()


if __name__ == "__main__":
    unittest.main()
