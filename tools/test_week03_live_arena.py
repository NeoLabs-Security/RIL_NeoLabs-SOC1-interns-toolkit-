from __future__ import annotations

import argparse
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools import neolabs


class Week03LiveArenaTests(unittest.TestCase):
    def test_arena_url_requires_origin_only_https(self):
        self.assertEqual(neolabs.validate_arena_url("https://arena.example.org/"), "https://arena.example.org")
        self.assertEqual(neolabs.validate_arena_url("https://203.0.113.10/"), "https://203.0.113.10")
        with self.assertRaises(SystemExit):
            neolabs.validate_arena_url("http://arena.example.org")
        with self.assertRaises(SystemExit):
            neolabs.validate_arena_url("https://arena.example.org/admin")

    def test_ip_blacklist_accepts_exact_addresses_and_rejects_cidr(self):
        with tempfile.TemporaryDirectory() as directory:
            with (
                mock.patch.object(neolabs, "IP_WATCHLIST_FILE", Path(directory) / "watchlist.txt"),
                mock.patch.object(neolabs.shutil, "which", return_value=None),
            ):
                neolabs.do_ip_blacklist(argparse.Namespace(ip_action="add", ip="198.51.100.8"))
                self.assertEqual(neolabs.read_ip_watchlist(), {"198.51.100.8"})
                with self.assertRaises(SystemExit):
                    neolabs.do_ip_blacklist(argparse.Namespace(ip_action="add", ip="198.51.100.0/24"))
                neolabs.do_ip_blacklist(argparse.Namespace(ip_action="remove", ip="198.51.100.8"))
                self.assertEqual(neolabs.read_ip_watchlist(), set())

    def test_parser_exposes_arena_and_detection_only_blacklist(self):
        parser = neolabs.build_parser()
        arena = parser.parse_args(["arena", "status"])
        self.assertIs(arena.func, neolabs.do_arena_status)
        join = parser.parse_args(["arena", "join", "--url", "https://203.0.113.10", "--ca-file", "/tmp/arena-ca.crt"])
        self.assertEqual(join.ca_file, "/tmp/arena-ca.crt")
        watch = parser.parse_args(["ip-blacklist", "add", "203.0.113.9"])
        self.assertIs(watch.func, neolabs.do_ip_blacklist)

    def test_interactive_arena_join_prompts_for_direct_ip_ca(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stack = root / "wazuh-stack"
            stack.mkdir()
            (stack / ".env").write_text("VCC_TELEMETRY_ENDPOINT=\n", encoding="utf-8")
            ca = root / "arena-ca.crt"
            ca.write_text("synthetic test certificate\n", encoding="utf-8")
            with (
                mock.patch.object(neolabs, "ROOT", root),
                mock.patch.object(neolabs, "ARENA_SESSION_FILE", root / "arena-session.json"),
                mock.patch.object(neolabs, "INSTALLATION_FILE", root / "installation-id"),
                mock.patch("builtins.input", return_value=str(ca)),
                mock.patch.object(neolabs.getpass, "getpass", return_value="a" * 64),
                mock.patch.object(neolabs.ssl, "create_default_context"),
                mock.patch.object(neolabs, "verify_arena_telemetry") as verify,
                mock.patch.object(neolabs, "stage_collector_inputs"),
            ):
                neolabs.do_arena_join(argparse.Namespace(url="https://203.0.113.10", ca_file=None))
            verify.assert_called_once_with("https://203.0.113.10", "a" * 64, ca.resolve())
            self.assertTrue((stack / "secrets" / "vcc" / "arena-ca.crt").is_file())


if __name__ == "__main__":
    unittest.main()
