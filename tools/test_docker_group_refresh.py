"""Regression tests for refreshed Docker access on a stale native Linux SSH shell.

Uses a temporary UNIX socket and fake id/stat/sg commands. Never touches the
real Docker daemon, group membership, containers, or system security settings.
"""
from __future__ import annotations

import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "internal/linux/With-DockerAccess.sh"

ID_STUB = """#!/usr/bin/env python3
import os, sys
if sys.argv[1:] == ['-un']:
    print('neolabs-test')
elif sys.argv[1:] == ['-nG']:
    print(os.environ['TEST_ACTIVE_GROUPS'])
elif sys.argv[1:] == ['-nG', 'neolabs-test']:
    print(os.environ['TEST_ACCOUNT_GROUPS'])
else:
    raise SystemExit(3)
"""

SG_STUB = """#!/usr/bin/env python3
import os, pathlib, subprocess, sys
assert sys.argv[1:3] == ['docker', '-c'], sys.argv
pathlib.Path(os.environ['TEST_SG_CALLED']).write_text('yes')
raise SystemExit(subprocess.call(['/bin/sh', '-c', sys.argv[3]], env=os.environ))
"""

STAT_STUB = """#!/usr/bin/env python3
print('docker')
"""


class DockerGroupRefreshTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.sock = socket.socket(socket.AF_UNIX)
        self.addCleanup(self.sock.close)
        self.socket_path = root / "docker.sock"
        self.sock.bind(str(self.socket_path))
        stub_dir = root / "bin"
        stub_dir.mkdir()
        for name, source in (("id", ID_STUB), ("sg", SG_STUB), ("stat", STAT_STUB)):
            path = stub_dir / name
            path.write_text(source)
            path.chmod(0o700)
        self.sg_called = root / "sg.called"
        self.env = {
            **os.environ,
            "PATH": str(stub_dir) + os.pathsep + os.environ["PATH"],
            "NEOLABS_DOCKER_SOCKET": str(self.socket_path),
            "TEST_ACTIVE_GROUPS": "ubuntu adm sudo",
            "TEST_ACCOUNT_GROUPS": "ubuntu adm sudo docker",
            "TEST_SG_CALLED": str(self.sg_called),
        }
        self.env.pop("WSL_DISTRO_NAME", None)

    def run_helper(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(HELPER), *args],
            env=self.env,
            text=True,
            capture_output=True,
            timeout=10,
        )

    def test_stale_shell_refreshes_only_the_child_and_preserves_quoted_args(self) -> None:
        result = self.run_helper(
            "python3", "-c", "import sys; print(sys.argv[1])", "pod-01 has spaces",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("pod-01 has spaces", result.stdout)
        self.assertTrue(self.sg_called.exists())

    def test_active_docker_group_does_not_reenter_sg(self) -> None:
        self.env["TEST_ACTIVE_GROUPS"] = "ubuntu docker sudo"
        result = self.run_helper("python3", "-c", "print('OK')")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("OK", result.stdout)
        self.assertFalse(self.sg_called.exists())

    def test_account_without_docker_group_fails_safely(self) -> None:
        self.env["TEST_ACCOUNT_GROUPS"] = "ubuntu adm sudo"
        result = self.run_helper("python3", "-c", "print('NEVER RUN')")
        self.assertEqual(result.returncode, 2)
        self.assertIn("not authorized", result.stderr)
        self.assertNotIn("NEVER RUN", result.stdout)
        self.assertFalse(self.sg_called.exists())

    def test_missing_socket_does_not_manage_groups(self) -> None:
        self.env["NEOLABS_DOCKER_SOCKET"] = str(Path(self.temp.name) / "not-present.sock")
        result = self.run_helper("python3", "-c", "print('NO SOCKET')")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("NO SOCKET", result.stdout)
        self.assertFalse(self.sg_called.exists())

    def test_wsl_bypasses_native_docker_group(self) -> None:
        self.env["WSL_DISTRO_NAME"] = "Ubuntu"
        result = self.run_helper("python3", "-c", "print('WSL')")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("WSL", result.stdout)
        self.assertFalse(self.sg_called.exists())


if __name__ == "__main__":
    unittest.main()
