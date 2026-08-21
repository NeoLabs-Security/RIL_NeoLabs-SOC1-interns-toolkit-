from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools import neolabs
from tools import toolkit_update


class ReleaseContractTests(unittest.TestCase):
    def manifest(self, **extra):
        value = {"track": "SOC", "pod_id": "pod-01", "resources": {}, "scenario_id": "w02-ghost-login", "release_generation": 2}
        value.update(extra)
        return value

    def test_release_change_and_same_generation_preserve_other_state(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "current-release.json"
            evidence = Path(directory) / "evidence.txt"
            evidence.write_text("historical", encoding="utf-8")
            with mock.patch.object(neolabs, "CURRENT_RELEASE_FILE", state):
                self.assertTrue(neolabs.record_current_release(self.manifest()))
                self.assertFalse(neolabs.record_current_release(self.manifest()))
                self.assertTrue(neolabs.record_current_release(self.manifest(release_generation=3)))
            self.assertEqual(evidence.read_text(encoding="utf-8"), "historical")
            saved = json.loads(state.read_text(encoding="utf-8"))
            self.assertEqual(saved["scenario_id"], "w02-ghost-login")

    def test_readiness_defaults_compatible_and_honours_false(self):
        self.assertTrue(neolabs.student_is_ready(self.manifest()))
        self.assertTrue(neolabs.student_is_ready(self.manifest(student_ready=True)))
        self.assertFalse(neolabs.student_is_ready(self.manifest(student_ready=False)))

    def test_minimum_version_is_enforced(self):
        with mock.patch.object(neolabs, "client_version", return_value="1.2.0"):
            neolabs.ensure_compatible(self.manifest(minimum_client_version="1.2.0"))
            with self.assertRaises(SystemExit) as raised:
                neolabs.ensure_compatible(self.manifest(minimum_client_version="2.0.0"))
        self.assertIn("too old", str(raised.exception))

    def test_manifest_pod_is_server_controlled(self):
        self.assertEqual(neolabs.manifest_from({"manifest": self.manifest()})["pod_id"], "pod-01")
        parser = neolabs.build_parser()
        self.assertNotIn("--pod", parser.parse_args(["connect"]).__dict__)

    def test_replay_ack_waits_for_index(self):
        manifest = self.manifest()
        with mock.patch("subprocess.run", return_value=subprocess.CompletedProcess([], 1)):
            self.assertFalse(neolabs.verify_replay_indexed(Path("/tmp"), manifest, "event-2", wait=0))


class RuntimeTextTests(unittest.TestCase):
    def test_generic_launcher_is_dynamic_and_no_night_watch(self):
        text = (neolabs.ROOT / "internal/common/Start-NeoLabsSOC.sh").read_text(encoding="utf-8")
        self.assertNotIn("Night Watch", text)
        self.assertIn('--scenario-id "$current_scenario"', text)
        self.assertIn("data.scenario_id", text)

    def test_verifier_requires_scenario_in_index_query(self):
        text = (neolabs.ROOT / "wazuh-stack/scripts/verify-telemetry-pipeline.sh").read_text(encoding="utf-8")
        self.assertIn("data.scenario_id", text)
        self.assertIn("--scenario-id", text)

    def test_no_browser_and_no_secret_material(self):
        launcher = (neolabs.ROOT / "internal/common/Start-NeoLabsSOC.sh").read_text(encoding="utf-8")
        self.assertIn("--no-browser", launcher)
        self.assertNotIn("bootstrap_token", launcher)
        self.assertNotIn("private_key", launcher)


class ToolkitUpdateTests(unittest.TestCase):
    @staticmethod
    def completed(code=0, output=""):
        return subprocess.CompletedProcess([], code, stdout=output, stderr="")

    def test_no_remote_is_compatible(self):
        with mock.patch.object(toolkit_update, "ROOT", Path("/missing")), mock.patch.object(toolkit_update, "git", return_value=self.completed(2)):
            self.assertEqual(toolkit_update.main(), 0)

    def test_dirty_clone_is_not_updated(self):
        def fake_git(*args, **_):
            if args[:3] == ("remote", "get-url", "origin"):
                return self.completed()
            if args[0] == "status":
                return self.completed(output="?? student-notes.txt\n")
            self.fail(f"unexpected destructive/update command: {args}")
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(toolkit_update, "ROOT", Path(directory)), mock.patch.object(toolkit_update, "git", side_effect=fake_git):
            (Path(directory) / ".git").mkdir()
            self.assertEqual(toolkit_update.main(), 0)

    def test_clean_clone_fast_forwards_only(self):
        calls = []
        def fake_git(*args, **_):
            calls.append(args)
            if args[0] == "diff":
                return self.completed(1)
            return self.completed()
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(toolkit_update, "ROOT", Path(directory)), mock.patch.object(toolkit_update, "git", side_effect=fake_git):
            (Path(directory) / ".git").mkdir()
            self.assertEqual(toolkit_update.main(), 10)
        self.assertIn(("merge", "--ff-only", "origin/main"), calls)
        self.assertFalse(any("reset" in call for call in calls))

    def test_network_failure_is_non_destructive(self):
        def fake_git(*args, **_):
            if args[0] == "fetch":
                return self.completed(1)
            return self.completed()
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(toolkit_update, "ROOT", Path(directory)), mock.patch.object(toolkit_update, "git", side_effect=fake_git):
            (Path(directory) / ".git").mkdir()
            self.assertEqual(toolkit_update.main(), 0)


if __name__ == "__main__":
    unittest.main()
