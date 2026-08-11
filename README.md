# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs SOC Level 1 Intern Toolkit** is the shared learning, practice and technical enablement repository for authorised SOC Level 1 internship training delivered through the VCC Security Lab.

It contains NeoLabs-branded educational materials, synthetic sample telemetry, guided defensive labs, analyst templates, Wazuh setup resources and a preconfigured containerised Wazuh environment. Official weekly assignments and student submissions belong in the separate central assignments repository.

## Start here

1. Read [`START_HERE.md`](START_HERE.md).
2. Follow [`LEARNING_PATH.md`](LEARNING_PATH.md).
3. Use the complete [`docs/README.md`](docs/README.md) index so every numbered module is easy to find.
4. Review the inventory in [`CONTENT_MANIFEST.md`](CONTENT_MANIFEST.md).
5. Use the dashboard tutorial, query reference and investigation templates during labs.
6. Run the workstation compatibility check before deploying [`wazuh-stack/`](wazuh-stack/).
7. Use only operator-issued VCC enrolment details; never invent or change a pod assignment locally.

## Important navigation note

The numbered SecOps documents **03 and 04 are present** under `docs/secops-foundations/` and are linked from `docs/README.md`:

- `docs/secops-foundations/03-siem-pipelines-and-log-quality.md`
- `docs/secops-foundations/04-incident-response-and-playbook-development.md`

The path `labs/local-access-control/` is **not a SOC lab**. It belongs to the separate Grey-Box Pentesting toolkit. If you are following instructions from that directory while you are assigned to SOC L1, you are in the wrong repository.

## Version 1 contents

- eight beginner-to-intermediate Security Operations modules covering foundations, triage, SIEM pipelines, incident response, Windows/Sysmon, Linux/web/cloud investigations, Wazuh investigation and safe tuning, case management and capstone reporting;
- Wazuh 4.14.7 architecture, dashboard, deployment, troubleshooting, compatibility and recovery guides;
- WQL, OpenSearch, `jq`, Linux and PowerShell query references;
- incident-report, evidence-register and query-journal templates;
- synthetic authentication data and guided defensive investigation labs;
- pinned containerised Wazuh manager, indexer, dashboard and pod-scoped telemetry collector;
- local secret generation, preflight checks, health checks, guarded reset, backup, verification and restore controls;
- operator-authoritative VCC enrolment using short-lived single-use tokens, locally generated private keys and client certificates;
- CI validation for code, shell scripts, XML, synthetic fixtures, Compose structure, secret boundaries, backup/restore and branded PDF generation.

## Student access boundary

SOC interns may use the assigned VCC learner application, approved student-facing dashboard, GitHub/Slack/email programme channels, their own approved Wazuh environment and only the telemetry feed issued for their assigned pod. Students do not receive direct EC2, AWS console, database, container-runtime, private-network, pod-host or mentor-dashboard access.

Never commit credentials, enrolment tokens, private keys, pod URLs or unredacted evidence. Editing a local label, URL or `POD_ID` is never authorization to access another pod.

## Release status

The student-facing Version 1 toolkit is on `main`. Repository content is ready for onboarding and supervised practice. Live VCC use still depends on operator-controlled deployment, real cohort credential issuance and successful pre-launch checks against the actual lab environment.
