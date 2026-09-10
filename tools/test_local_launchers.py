"""Exercise actual platform launchers, including spaced relative file paths."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LauncherTests(unittest.TestCase):
    def launch(self, *args):
        with tempfile.TemporaryDirectory(prefix='neolabs evidence ') as directory:
            (Path(directory) / 'test events.ndjson').write_text('{"event_id":"fixture-local","action":"failed"}\n')
            if os.name == 'nt':
                command = ['cmd.exe', '/d', '/c', str(ROOT / 'neolabs.cmd')]
            else:
                command = ['bash', str(ROOT / 'neolabs')]
            return subprocess.run(command + ['offline', 'analyze', '--file', 'test events.ndjson', *args], cwd=directory, text=True, capture_output=True, timeout=30)

    def test_relative_path_and_filter(self):
        result = self.launch('--contains', 'FAILED')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('fixture-local', result.stdout)

    def test_error_code_propagates(self):
        result = self.launch('--limit', '0')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('--limit must be positive', result.stdout + result.stderr)
