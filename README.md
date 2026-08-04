# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs SOC Level 1 Intern Toolkit** is the shared learning, practice and technical enablement repository for authorised SOC Level 1 internship training delivered through the VCC Security Lab.

It contains NeoLabs-branded educational materials, synthetic sample telemetry, guided defensive labs, analyst templates, Wazuh setup resources and a preconfigured containerised Wazuh environment. Official weekly assignments and student submissions belong in the separate central SOC Assignments repository.

## Start here

1. Read [`START_HERE.md`](START_HERE.md).
2. Follow [`LEARNING_PATH.md`](LEARNING_PATH.md).
3. Review the publication inventory in [`CONTENT_MANIFEST.md`](CONTENT_MANIFEST.md).
4. Study the eight SecOps modules under [`docs/secops-foundations/`](docs/secops-foundations/).
5. Use the dashboard tutorial, query reference and investigation templates during labs.
6. Run the workstation compatibility check before deploying [`wazuh-stack/`](wazuh-stack/).
7. Use the generated NeoLabs PDF publication set for structured study and offline reference.

## Version 1 release-candidate contents

- eight beginner-to-intermediate Security Operations modules covering foundations, triage, SIEM pipelines, incident response, Windows/Sysmon, Linux/web/cloud investigations, Wazuh investigation and safe tuning, case management and capstone reporting;
- Wazuh 4.14.7 architecture, dashboard, deployment, troubleshooting, compatibility and recovery guides;
- comprehensive WQL, OpenSearch, `jq`, Linux and PowerShell query reference;
- incident-report, evidence-register and query-journal templates;
- synthetic authentication dataset and guided defensive investigation lab;
- pinned containerised Wazuh manager, indexer, dashboard and pod-scoped telemetry collector;
- local secret generation, preflight checks, health checks, guarded reset, backup, verification and restore controls;
- operator-authoritative VCC enrolment using short-lived single-use tokens, locally generated private keys and client certificates;
- CI validation for code, shell scripts, XML, synthetic fixtures, Compose structure, secret boundaries, backup/restore and branded PDF generation;
- NeoLabs visual system and automated generation of five reviewed PDF publications.

## Completed security rehearsals

The corresponding isolated VCC control-plane rehearsal passed the complete defensive access workflow:

- two separate intern-to-pod assignments;
- real certificate-signing request exchange;
- one-time bootstrap-token consumption;
- server-derived pod scope;
- denial of a client-supplied pod selector;
- verification that each certificate receives only its assigned pod's synthetic events;
- client-credential revocation;
- assignment revocation and certificate denial;
- automatic cleanup of disposable PKI, containers and test data.

The toolkit also passes a synthetic Docker-volume backup/restore rehearsal and an automated Linux workstation compatibility profile. WSL2 and macOS profiles are documented, but dedicated physical-machine testing on those platforms remains an operational rollout check rather than a repository implementation blocker.

## Safety and scope

- Use only in systems owned by the learner or explicitly authorised by NeoLabs/RIL.
- All included datasets and exercises must be synthetic or sanitised.
- Never commit credentials, enrolment tokens, private keys, pod URLs or unredacted student evidence.
- Students do not receive direct EC2, AWS console, database, container-runtime, private-network, pod-host or mentor-dashboard access.
- A student-facing Wazuh deployment may connect only to the telemetry feed issued for the intern's assigned pod.
- Editing a local label, URL or request parameter must never be sufficient to change the authorised pod.

## Release status

The feature branch is a **Version 1 release candidate** with green repository validation, green branded-publication generation and a green isolated VCC certificate/pod-isolation rehearsal. It has not been merged into `main` or deployed to the internship environment. Operator review, controlled rollout and real cohort credential issuance remain deliberate deployment steps.

The current branding uses a self-contained NeoLabs text wordmark and publication system. An approved official graphical logo can replace the wordmark later without changing the document structure or technical content.
