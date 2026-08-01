# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs SOC Level 1 Intern Toolkit** is the shared learning, practice and technical enablement repository for authorised SOC Level 1 internship training delivered through the VCC Security Lab.

It contains NeoLabs-branded educational materials, synthetic sample telemetry, guided defensive labs, analyst templates, Wazuh setup resources and a preconfigured containerised Wazuh environment. Official weekly assignments and student submissions belong in the separate central SOC Assignments repository.

## Start here

1. Read [`START_HERE.md`](START_HERE.md).
2. Follow [`LEARNING_PATH.md`](LEARNING_PATH.md).
3. Review the current publication status in [`CONTENT_MANIFEST.md`](CONTENT_MANIFEST.md).
4. Study the expanded SecOps modules under [`docs/secops-foundations/`](docs/secops-foundations/).
5. Use the dashboard tutorials and query reference during labs.
6. Deploy the Wazuh stack only after reading [`wazuh-stack/README.md`](wazuh-stack/README.md).

## Current contents

- expanded Security Operations foundations, alert triage and SIEM pipeline modules;
- authoritative public-source register;
- Wazuh dashboard orientation and first-alert tutorial;
- comprehensive query and command reference;
- incident report, evidence log and query journal templates;
- synthetic authentication investigation dataset and guided practice lab;
- Wazuh 4.14.7 container scaffold with local secret generation, preflight checks, health checks and guarded reset;
- pod-scoped VCC enrolment client and defence-in-depth telemetry collector;
- CI validation for code, fixtures, Compose structure and credential boundaries.

## Safety and scope

- Use only in systems owned by the learner or explicitly authorised by NeoLabs/RIL.
- All included datasets and exercises must be synthetic or sanitised.
- Never commit credentials, enrolment tokens, private keys, pod URLs or unredacted student evidence.
- Students do not receive direct EC2, AWS console, database, container-runtime, private-network, pod-host or mentor-dashboard access.
- A student-facing Wazuh deployment may connect only to the telemetry feed issued for the intern's assigned pod.
- Editing a local label or URL must never be sufficient to change the authorised pod.

## Release status

This repository is still under technical and editorial review. Static CI is active, but the Wazuh stack is not labelled student-ready until isolated end-to-end certificate exchange, pod-isolation, backup/restore and workstation compatibility rehearsals are complete.
