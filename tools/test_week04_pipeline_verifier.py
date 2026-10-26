"""Execute the pipeline verifier with fake Docker; no live SIEM is claimed."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DOCKER = r'''#!/usr/bin/env python3
import json,os,sys
a=sys.argv[1:]
if a[0]=='inspect':
    print('healthy' if 'Health' in a[2] else 'running')
elif 'ps' in a:
    print('fake-container')
elif '/var/ossec/bin/wazuh-logtest' in a:
    e=json.load(sys.stdin)
    rule='100120'
    if e.get('scenario_id')=='w04-broken-gate':
        rule='100142' if e['outcome']=='policy_violation' else '100141'
    if os.environ.get('FAKE_MISSING_RULE')==rule: rule='100100'
    print("id: '%s'" % rule)
elif 'wazuh.indexer' in a:
    query=json.load(sys.stdin)
    filters=query['query']['bool']['filter']
    ids=next(f['terms']['rule.id'] for f in filters if 'terms' in f)
    if os.environ.get('EXPECT_WEEK4')=='yes':
        assert ids==['100141','100142'],ids
    else:
        assert '100120' in ids
    if os.environ.get('EXPECT_EVENT'):
        assert {'match_phrase':{'data.event_id':os.environ['EXPECT_EVENT']}} in filters
    print(json.dumps({'hits':{'total':{'value':0 if os.environ.get('FAKE_NO_HITS') else 1}}}))
elif 'vcc.telemetry.collector' in a:
    sys.stdin.read()
else:
    raise SystemExit('Unexpected Docker invocation')
'''


class Week04PipelineVerifierTests(unittest.TestCase):
    def run_verifier(self, scenario='w04-broken-gate', event=None, **settings):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            scripts = root / 'wazuh-stack/scripts'
            scripts.mkdir(parents=True)
            script = scripts / 'verify-telemetry-pipeline.sh'
            shutil.copyfile(ROOT / 'wazuh-stack/scripts' / script.name, script)
            (scripts.parent / '.env').write_text('WAZUH_INDEXER_PASSWORD=synthetic-test-only\n')
            (scripts.parent / 'state').mkdir()
            (scripts.parent / 'state/assigned-pod').write_text('pod-01\n')
            binary = root / 'docker'
            binary.write_text(DOCKER)
            binary.chmod(0o700)
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'], **settings)
            if scenario == 'w04-broken-gate':
                env['EXPECT_WEEK4'] = 'yes'
            command = ['bash', str(script), '--scenario-id', scenario]
            if event:
                command += ['--event-id', event]
                env['EXPECT_EVENT'] = event
            return subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)

    def test_week4_uses_both_rules_and_exact_event_query(self):
        result = self.run_verifier(event='synthetic-request-event')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('VCC_TELEMETRY_SEARCHABLE', result.stdout)

    def test_missing_week4_rules_fail_engine_gate(self):
        for rule in ['100141', '100142']:
            with self.subTest(rule=rule):
                result = self.run_verifier(FAKE_MISSING_RULE=rule)
                self.assertEqual(result.returncode, 2, result.stderr)

    def test_no_indexed_week4_event_fails_readiness(self):
        result = self.run_verifier(FAKE_NO_HITS='yes')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertNotIn('VCC_TELEMETRY_SEARCHABLE', result.stdout)

    def test_earlier_week_still_uses_existing_rules(self):
        result = self.run_verifier(scenario='w01-operation-night-watch', FAKE_MISSING_RULE='100142')
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
