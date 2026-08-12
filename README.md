# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs × RIL SOC Level 1 Intern Toolkit** is the student-side **Learn + Connect + Operate** repository for authorised SOC training through the VCC Security Lab.

## 🚀 WEEK 1 — START HERE

**Scenario:** Operation Night Watch  
**Goal:** learn what normal VCC activity looks like before later incident scenarios begin.

### 1. Read the Week 1 pack

- Source: [`docs/week-01/operation-night-watch-launch-pack.md`](docs/week-01/operation-night-watch-launch-pack.md)
- Branded PDF: [`publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf`](publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf)

### 2. Install the NeoLabs access client

```bash
python -m pip install -e .
```

### 3. Prepare Wazuh

Follow [`wazuh-stack/README.md`](wazuh-stack/README.md), run its preflight/setup steps and confirm the local stack is healthy.

### 4. Authenticate with your private onboarding details

Set the NeoLabs lab gateway URL supplied by the programme, then run:

```bash
neolabs login
neolabs status
neolabs pod info
neolabs connect
```

Enter only **your assigned pod** and **your private NeoLabs Access Code**. SOC telemetry scope is server-controlled; you do not choose another pod or telemetry target.

### 5. Complete Operation Night Watch

Use the Week 1 pack for the exact task and deliverables. Official submissions belong in the separate `RIL_NeoLabs-Intern-Assignments` repository, not this toolkit.

## Week 1 study shelf

Use `publications/` in this order:

1. `00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf` — what to do this week.
2. `01_NeoLabs_Log_Literacy_for_Cybersecurity_Analysts.pdf` — how to read/correlate logs.
3. `02_NeoLabs_SOC_L1_SecOps_Field_Guide.pdf` — evidence-first SecOps workflow.
4. `NeoLabs_SOC_L1_Analyst_Handbook.pdf` — deeper analyst reference.
5. `NeoLabs_SOC_L1_Wazuh_Guide.pdf` — Wazuh setup/investigation reference.
6. `NeoLabs_SOC_L1_Complete_Toolkit.pdf` — long-form reference; do not try to read it all before starting Week 1.

The Markdown source modules under `docs/` remain available for search, notes and future weeks.

## What is preconfigured here

- installable `neolabs` pod-access/authentication client;
- containerised Wazuh manager/indexer/dashboard stack;
- NeoLabs pod-scoped telemetry collector and custom rules;
- live mTLS enrolment and automatic S3 replay support;
- preflight, health, backup, restore and reset controls;
- Log Literacy/SecOps/Wazuh educational material;
- evidence, query-journal and incident-report templates;
- synthetic labs/sample telemetry;
- branded PDF publication and validation workflows.

## Useful commands

```text
neolabs login       authenticate with your assigned pod + private Access Code
neolabs connect     use the current authorised LIVE/replay SOC surface
neolabs status      show current runtime, pod and scenario
neolabs evidence    download approved evidence for your pod/scenario
neolabs pod info    show the server-assigned pod
neolabs disconnect  remove the local gateway session
```

## Repository map

```text
README.md                 ← you are here
START_HERE.md             ← workstation/orientation detail
docs/week-01/             ← current Week 1 instructions
publications/             ← branded student PDFs
wazuh-stack/              ← preconfigured SOC tooling
tools/neolabs.py          ← pod access/authenticator client
templates/                ← evidence/report templates
sample-logs/ + labs/      ← safe practice material
research/ + references/   ← deeper reference material
```

## Security rules

- Never commit/share Access Codes, broker sessions, enrolment tokens, certificates or private keys.
- Never edit a pod label or target in an attempt to reach another pod.
- Use only synthetic data and authorised VCC resources.
- Keep `runtime/`, Wazuh state, replay state and certificate material local.
- Students never receive AWS credentials or bucket-wide S3 access.
- Stop and notify a mentor if another pod, real personal data, a credential or unexpected infrastructure access appears.

## Runtime design

**Toolkit:** Learn + Connect + Operate  
**Replay Gateway:** Stable Authentication + Runtime State + S3 Replay  
**VCC Security Lab:** Scheduled Live Target/Telemetry + Scenario  
**Central Assignments:** Task submission + assessment

Week 1 is intentionally hybrid: SOC can investigate the archived pod-scoped baseline even when the large VCC server is not continuously online.
