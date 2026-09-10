import argparse
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools import neolabs as core
from tools.local_import import run, normalize_event


class ImportTests(unittest.TestCase):
    def test_legacy_normalization_preserves_source(self):
        source = {'event_type': 'authentication', 'result': 'failure', 'user': 'fixture', 'source_ip': '192.0.2.1'}
        original = dict(source)
        event = normalize_event(source)
        self.assertEqual(source, original)
        self.assertEqual(event['schema_version'], '1.0')
        self.assertEqual(event['outcome'], 'failure')
        self.assertEqual(event['result'], 'failure')

    def test_conflicting_legacy_fields_rejected(self):
        with self.assertRaises(ValueError):
            normalize_event({'event_type': 'authentication', 'result': 'failure', 'outcome': 'success', 'user': 'fixture', 'source_ip': '192.0.2.1'})

    def test_unknown_format_rejected(self):
        with self.assertRaises(ValueError):
            normalize_event({'event_type': 'unknown'})

    def test_versioned_event_not_reinterpreted(self):
        source = {'schema_version': '2.0', 'result': 'failure'}
        self.assertEqual(normalize_event(source), source)

    def exercise(self, wrong=False, indexed=True):
        with tempfile.TemporaryDirectory() as directory, contextlib.ExitStack() as context:
            root = Path(directory)
            path = root / 'events.ndjson'
            event = {'schema_version': '1.0', 'synthetic': True, 'pod_id': 'pod-02' if wrong else 'pod-01', 'scenario_id': 'fixture', 'event_id': 'fixture-event', 'event_time': '2026-09-10T00:00:00Z'}
            path.write_text(json.dumps(event) + '\n' + json.dumps(dict(event, event_id='second-event')) + '\n')
            manifest = {'runtime_mode': 'offline-fallback', 'pod_id': 'pod-01', 'scenario_id': 'fixture'}
            for name, value in [('HOME_STATE', root), ('REPLAY_STATE_FILE', root/'seen.json'), ('REPLAY_PENDING_FILE', root/'pending.json')]:
                context.enter_context(patch.object(core, name, value))
            context.enter_context(patch.object(core, 'read_session', return_value={}))
            context.enter_context(patch.object(core, 'refresh', return_value=manifest))
            context.enter_context(patch.object(core, 'student_is_ready', return_value=True))
            start = context.enter_context(patch.object(core, 'start_wazuh_stack', return_value=root))
            append = context.enter_context(patch.object(core, 'append_to_wazuh'))
            context.enter_context(patch.object(core, 'verify_replay_indexed', return_value=indexed))
            context.enter_context(contextlib.redirect_stdout(io.StringIO()))
            for _ in range(2):
                if wrong or not indexed:
                    with self.assertRaises(SystemExit):
                        run(argparse.Namespace(file=str(path)))
                else:
                    run(argparse.Namespace(file=str(path)))
            self.assertEqual(append.call_count, 0 if wrong else 1)
            if wrong:
                start.assert_not_called()
            self.assertFalse((root/'local-import.lock').exists())

    def test_repeat_does_not_append(self):
        self.exercise()

    def test_pending_retry_verifies_without_append(self):
        self.exercise(indexed=False)

    def test_wrong_pod_rejected_before_runtime(self):
        self.exercise(wrong=True)
