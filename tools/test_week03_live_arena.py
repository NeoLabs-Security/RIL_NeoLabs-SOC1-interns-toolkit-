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
        watch = parser.parse_args(["ip-blacklist", "add", "203.0.113.9"])
        self.assertIs(watch.func, neolabs.do_ip_blacklist)


if __name__ == "__main__":
    unittest.main()
