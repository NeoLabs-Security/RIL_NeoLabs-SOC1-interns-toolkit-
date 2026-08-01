# NeoLabs SOC Level 1 Learning Path

The toolkit is organised as a progressive beginner-to-intermediate pathway. Technical terminology is preserved, but each concept must be explained before learners are expected to use it.

## Phase 1 — Security operations foundations

- What a SOC is and how Security Operations works
- SOC Level 1 responsibilities and boundaries
- Alert, event, finding, incident, evidence and indicator terminology
- Escalation, severity, priority and confidence
- Analyst documentation and professional communication

Primary material: `docs/secops-foundations/`

## Phase 2 — Log literacy

- How telemetry is generated, collected, parsed, indexed and searched
- Time zones, event time, ingest time and clock drift
- Windows, Sysmon, Linux, network, web, database and AWS logs
- Correlation, baselines, visibility gaps and defensible conclusions

Primary material: `docs/log-literacy/`

## Phase 3 — Wazuh fundamentals

- Manager, indexer, dashboard and agent roles
- Alert and archive data
- Decoders, rules, groups and centralised configuration
- Safe local deployment, health checking and backup
- Connection to a VCC pod-scoped telemetry feed

Primary material: `docs/wazuh-handbook/` and `wazuh-stack/`

## Phase 4 — Dashboard and query literacy

- Dashboard navigation and saved views
- Agent and data-source health
- Alert filtering and investigation pivots
- Wazuh Query Language and OpenSearch concepts
- Linux, Windows and JSON command-line searches

Primary material: `docs/dashboard-tutorials/` and `references/query-command-reference/`

## Phase 5 — Guided investigations

- Authentication triage
- Suspicious process activity
- File-integrity changes
- Web and API abuse
- Cloud identity and configuration activity
- Missing telemetry and parser failures

Primary material: `labs/` and `sample-logs/`

## Phase 6 — Reporting and escalation

- Evidence logs
- Query journals
- Investigation timelines
- Incident and escalation reports
- Confidence statements and unresolved questions

Primary material: `templates/`

## Completion standard

A learner should be able to receive an alert, verify the underlying evidence, search for related events, build a timeline, distinguish fact from interpretation, assign a justified classification, document uncertainty and escalate using the approved process.
