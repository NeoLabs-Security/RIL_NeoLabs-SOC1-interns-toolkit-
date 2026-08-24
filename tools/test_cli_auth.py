from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

if __package__ in {None, ""}:
    repository_root = str(Path(__file__).resolve().parents[1])
    if repository_root not in sys.path:
        sys.path.insert(0, repository_root)

from tools import cli


class SocCliAuthTests(unittest.TestCase):
    def test_missed_hidden_paste_reprompts_without_recursion(self) -> None:
        with mock.patch.object(cli, "_SYSTEM_GETPASS", side_effect=["", "NL-AbCdEf0123456789"]):
            self.assertEqual(cli._prompt_access_code(), "NL-AbCdEf0123456789")

    def test_login_wrapper_restores_original_getpass(self) -> None:
        original = cli.core.getpass.getpass
        observed: list[str] = []

        def fake_main() -> int:
            observed.append(cli.core.getpass.getpass("NeoLabs Access Code: "))
            return 0

        with (
            mock.patch.object(cli, "_SYSTEM_GETPASS", return_value="NL-AbCdEf0123456789"),
            mock.patch.object(cli.core, "main", side_effect=fake_main),
        ):
            self.assertEqual(cli._run_core(["login"]), 0)

        self.assertEqual(observed, ["NL-AbCdEf0123456789"])
        self.assertIs(cli.core.getpass.getpass, original)

    def test_rejected_saved_session_is_removed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            session = Path(temp) / "session.json"
            runtime = Path(temp) / "access-manifest.json"
            session.write_text("{}", encoding="utf-8")
            runtime.write_text("{}", encoding="utf-8")
            with (
                mock.patch.object(cli.core, "SESSION_FILE", session),
                mock.patch.object(cli.core, "RUNTIME_MANIFEST", runtime),
                mock.patch.object(
                    cli.core,
                    "main",
                    side_effect=SystemExit("ERROR: authentication or pod/track authorization was rejected; verify your access code and assigned pod"),
                ),
            ):
                self.assertEqual(cli._run_core(["status"]), 2)
            self.assertFalse(session.exists())
            self.assertFalse(runtime.exists())


if __name__ == "__main__":
    unittest.main()
