import argparse
import contextlib
import gzip
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools.local_telemetry import analyze, load_events
from tools import neolabs


class LocalTelemetryTests(unittest.TestCase):
    def test_plain_and_gzip(self):
        with tempfile.TemporaryDirectory() as directory:
            for name, data in [('events.ndjson', b'{"event_id":"a"}\n'), ('events.ndjson.gz', gzip.compress(b'{"event_id":"a"}\n'))]:
                path = Path(directory) / name
                path.write_bytes(data)
                self.assertEqual(load_events(path), [{'event_id': 'a'}])

    def test_invalid_empty_and_non_object(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'events'
            for data in [b'', b'bad', b'[]', b'{}\nbad']:
                path.write_bytes(data)
                with self.assertRaises(ValueError):
                    load_events(path)

    def test_expanded_limit(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'events.gz'
            path.write_bytes(gzip.compress(b' ' * 100))
            with patch('tools.local_telemetry.MAX_BYTES', 10), self.assertRaises(ValueError):
                load_events(path)

    def test_analyze_never_authenticates_or_starts_wazuh(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'events'
            path.write_text('{"action":"failed","value":"\\u001b[31m"}\n{"action":"ok"}\n')
            args = neolabs.build_parser().parse_args(['offline', 'analyze', '--file', str(path), '--contains', 'FAILED'])
            output = io.StringIO()
            with patch.object(neolabs, 'read_session', side_effect=AssertionError), patch.object(neolabs, 'start_wazuh_stack', side_effect=AssertionError), contextlib.redirect_stdout(output):
                args.func(args)
            self.assertIn('1 matching', output.getvalue())
            self.assertNotIn('\x1b', output.getvalue())

    def test_download_is_validated_without_wazuh(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = {'runtime_mode': 'offline-fallback', 'pod_id': 'pod-01'}
            with patch.object(neolabs, 'read_session', return_value={'base_url': 'https://example.org', 'session_token': 'test'}), patch.object(neolabs, 'refresh', return_value=manifest), patch.object(neolabs, 'student_is_ready', return_value=True), patch.object(neolabs, 'request_json', return_value={'telemetry_packs': [{'key': 'events.gz', 'url': 'https://example.org/data'}]}), patch.object(neolabs, 'download_bytes', return_value=b'pack'), patch.object(neolabs, 'decode_replay_pack', return_value='{"event_id":"a"}\n') as decode, patch.object(neolabs, 'EVIDENCE_DIR', Path(directory)), patch.object(neolabs, 'start_wazuh_stack', side_effect=AssertionError), contextlib.redirect_stdout(io.StringIO()):
                neolabs.do_offline_download(argparse.Namespace())
                neolabs.do_offline_download(argparse.Namespace())
                self.assertEqual(len(list(Path(directory).glob('*.ndjson'))), 1)
                self.assertEqual(decode.call_count, 2)


if __name__ == '__main__':
    unittest.main()
