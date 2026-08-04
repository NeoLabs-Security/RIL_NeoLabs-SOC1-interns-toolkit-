# NeoLabs SOC Level 1 Learning Path

The toolkit is organised as a progressive beginner-to-intermediate pathway. Technical terminology is preserved, but each concept is explained before learners are expected to use it.

## Phase 1 — Security Operations foundations

- What a SOC is and how Security Operations works
- SOC Level 1 responsibilities and boundaries
- Alert, event, finding, incident, evidence and indicator terminology
- Escalation, severity, priority and confidence
- Analyst documentation and professional communication

Primary material:

- `docs/secops-foundations/01-security-operations-foundations.md`
- `docs/secops-foundations/02-alert-triage-evidence-and-escalation.md`

## Phase 2 — Log and SIEM literacy

- How telemetry is generated, collected, parsed, normalised, indexed and searched
- Time zones, event time, ingestion time and clock drift
- Windows, Sysmon, Linux, web, application, database and cloud evidence
- Correlation, baselines, visibility gaps and defensible conclusions
- Data-quality failures that can create misleading alerts

Primary material:

- `docs/secops-foundations/03-siem-pipelines-and-log-quality.md`
- `references/query-command-reference/README.md`

## Phase 3 — Incident response and evidence handling

- Triage and investigation workflow
- Containment, eradication, recovery and lessons learned
- Playbook structure and escalation points
- Evidence preservation and reproducible query journals
- Facts, analysis, assumptions and recommendations

Primary material:

- `docs/secops-foundations/04-incident-response-and-playbook-development.md`
- `templates/evidence-log-template.md`
- `templates/query-journal-template.md`
- `templates/incident-report-template.md`

## Phase 4 — Endpoint and identity investigation

- Windows authentication and logon types
- Process trees, parent-child relationships and command lines
- Sysmon process, network, file and registry relationships
- PowerShell review
- Linux authentication, privilege changes, process activity and persistence

Primary material:

- `docs/secops-foundations/05-windows-and-sysmon-investigation.md`
- `docs/secops-foundations/06-linux-web-and-cloud-log-investigation.md`

## Phase 5 — Wazuh fundamentals and workstation deployment

- Manager, indexer, dashboard and collector roles
- Alert and archive data
- Decoders, rules, groups and centralised configuration
- Safe local deployment, compatibility, health checking, backup and recovery
- Operator-approved connection to a VCC pod-scoped telemetry feed

Primary material:

- `docs/wazuh-handbook/01-wazuh-architecture-and-neolabs-deployment.md`
- `docs/setup/WORKSTATION_COMPATIBILITY.md`
- `docs/setup/BACKUP_AND_RECOVERY.md`
- `wazuh-stack/README.md`
- `troubleshooting/WAZUH_SETUP_AND_TROUBLESHOOTING_GUIDE.md`

## Phase 6 — Dashboard and query literacy

- Dashboard navigation and saved views
- Alert filtering and investigation pivots
- Wazuh Query Language and OpenSearch concepts
- Linux, Windows and JSON command-line searches
- Timeline construction and alert-to-evidence movement

Primary material:

- `docs/dashboard-tutorials/01-orientation-and-alert-investigation.md`
- `references/query-command-reference/README.md`

## Phase 7 — Guided investigations and safe detection feedback

- Authentication triage
- Suspicious process activity
- Web and API evidence
- Cloud identity and configuration activity
- Missing telemetry and parser failures
- Wazuh alert interpretation
- Safe, narrow and reversible tuning proposals

Primary material:

- `labs/01-authentication-triage/README.md`
- `sample-logs/`
- `docs/secops-foundations/07-wazuh-alert-investigation-and-tuning.md`

## Phase 8 — Case management and capstone

- Case ownership and status
- Evidence registers and timelines
- Severity and confidence
- Handoff and escalation
- Detection-quality feedback
- Final synthetic multi-source investigation

Primary material:

- `docs/secops-foundations/08-case-management-reporting-and-capstone.md`
- `templates/`

## Completion standard

A learner completes the Version 1 pathway when they can:

1. receive and preserve an alert;
2. verify the underlying evidence;
3. search for related authentication, endpoint, web, application or cloud events;
4. maintain a reproducible query journal;
5. build a timezone-consistent timeline;
6. distinguish fact from interpretation and assumption;
7. assign an evidence-supported disposition, severity and confidence;
8. identify visibility limitations;
9. recommend containment, escalation or safe tuning;
10. submit a clear handoff-ready report without credentials, private URLs or another pod's evidence.

The capstone is completed only within the learner's operator-assigned synthetic VCC pod scope.
