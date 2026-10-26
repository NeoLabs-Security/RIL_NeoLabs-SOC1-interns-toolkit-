"""Rule predicate regression checks; actual Wazuh engine/index validation is separate."""
import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class CourseAuthorizationRuleTests(unittest.TestCase):
    def setUp(self):
        document = ET.parse(ROOT / 'wazuh-stack/config/rules/neolabs_vcc_rules.xml')
        self.rules = {rule.attrib['id']: rule for rule in document.findall('.//rule')}

    def matches(self, rule_id, fields):
        rule = self.rules[rule_id]
        parent = rule.findtext('if_sid')
        if parent in {'100141'} and not self.matches(parent, fields):
            return False
        return all(re.search(field.text, str(fields.get(field.attrib['name'], '')))
                   for field in rule.findall('field'))

    def test_violation_requires_consistent_policy_and_result(self):
        fields = {'scenario_id': 'w04-broken-gate', 'event_type': 'authorization.check',
                  'metadata.actual_decision': 'allow', 'metadata.policy_expected_decision': 'deny',
                  'metadata.http_status': 200, 'outcome': 'policy_violation'}
        self.assertTrue(self.matches('100142', fields))
        for key, value in [('metadata.actual_decision', 'deny'), ('metadata.policy_expected_decision', 'allow'),
                           ('metadata.http_status', 403), ('outcome', 'success'),
                           ('scenario_id', 'w03-credential-storm'), ('event_type', 'authentication.login')]:
            with self.subTest(key=key):
                self.assertFalse(self.matches('100142', {**fields, key: value}))

    def test_normal_and_denied_checks_stay_searchable_without_escalation(self):
        for outcome in ('success', 'denied'):
            fields = {'scenario_id': 'w04-broken-gate', 'event_type': 'authorization.check', 'outcome': outcome}
            self.assertTrue(self.matches('100141', fields))
            self.assertFalse(self.matches('100142', fields))
        self.assertEqual(self.rules['100141'].attrib['level'], '3')


if __name__ == '__main__':
    unittest.main()
