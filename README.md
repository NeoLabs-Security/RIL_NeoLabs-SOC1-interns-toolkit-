# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs × RIL SOC Level 1 Intern Toolkit** is the student-side **Learn + Connect + Operate** repository for authorised SOC training through the VCC Security Lab.

## 🚀 WEEK 1 — START HERE

**Scenario:** Operation Night Watch  
**Goal:** learn what normal VCC activity looks like before later incident scenarios begin.

### 1. Read the Week 1 pack

- Source: [`docs/week-01/operation-night-watch-launch-pack.md`](docs/week-01/operation-night-watch-launch-pack.md)
- Branded PDF: [`publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf`](publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf)

### 2. Windows setup — no pip/PATH work required

From the cloned toolkit folder, double-click:

```text
setup-windows.cmd
```

It checks that Windows can find Python. You do **not** need to run `pip install -e .`, edit PATH, or manually type the NeoLabs gateway URL.

Then open PowerShell in this toolkit folder and test the local launcher:

```powershell
.\neolabs.cmd --help
```

The Windows launcher routes the client through the official NeoLabs gateway while keeping the underlying SOC client in this repository.

### 3. Prepare Wazuh

Follow [`wazuh-stack/README.md`](wazuh-stack/README.md), run its preflight/setup steps and confirm the local stack is healthy.

### 4. Authenticate with your private onboarding details

Run:

```powershell
.\neolabs.cmd login
.\neolabs.cmd status
.\neolabs.cmd pod info
.\neolabs.cmd connect
```

`login` asks only for **your assigned pod** and **your private NeoLabs Access Code**. SOC telemetry scope is server-controlled; you do not choose another pod or telemetry target.

For Week 1, the gateway deliberately returns **REPLAY** to SOC interns. `connect` downloads only your assigned pod's signed archived telemetry and feeds it into the same local Wazuh workflow. You do not need the live VCC SOC port to be publicly exposed.

### 5. Complete Operation Night Watch

Use the Week 1 pack for the exact task and deliverables. Official submissions belong in the separate `RIL_NeoLabs-Intern-Assignments` repository, not this toolkit.

## Week 1 study shelf

Use these materials in this order:

1. [`publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf`](publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf) — what to do this week.
2. **NeoLabs Log Literacy for Cybersecurity Analysts** — the branded 36-page manual supplied with your private Week 1 launch email.
3. [`publications/02_NeoLabs_SOC_L1_SecOps_Field_Guide.pdf`](publications/02_NeoLabs_SOC_L1_SecOps_Field_Guide.pdf) — evidence-first SecOps workflow.
4. [`publications/NeoLabs_SOC_L1_Wazuh_Guide.pdf`](publications/NeoLabs_SOC_L1_Wazuh_Guide.pdf) — Wazuh setup/investigation reference.
5. [`publications/NeoLabs_SOC_L1_Analyst_Handbook.pdf`](publications/NeoLabs_SOC_L1_Analyst_Handbook.pdf) — deeper analyst reference.
6. [`publications/NeoLabs_SOC_L1_Complete_Toolkit.pdf`](publications/NeoLabs_SOC_L1_Complete_Toolkit.pdf) — long-form reference; do not try to read it all before starting Week 1.

The Markdown source modules under `docs/` remain available for search, notes and future weeks.

## What is preconfigured here

- local Windows `neolabs.cmd` launcher that avoids pip/PATH failures;
- Windows readiness check;
- installable Python pod-access/authentication client for non-Windows/manual use;
- containerised Wazuh manager/indexer/dashboard stack;
- NeoLabs pod-scoped telemetry collector and custom rules;
- automatic signed S3 replay ingestion and live mTLS support for later windows;
- preflight, health, backup, restore and reset controls;
- SecOps/Wazuh educational material plus the Week 1 Log Literacy launch attachment;
- evidence, query-journal and incident-report templates;
- synthetic labs/sample telemetry;
- branded PDF publication and validation workflows.

## Useful commands

```text
.\neolabs.cmd login       authenticate with your assigned pod + private Access Code
.\neolabs.cmd connect     load the current authorised replay/live SOC surface into Wazuh
.\neolabs.cmd status      show current runtime, pod and scenario
.\neolabs.cmd evidence    download approved evidence for your pod/scenario
.\neolabs.cmd pod info    show the server-assigned pod
.\neolabs.cmd disconnect  remove the local gateway session
```

## Repository map

```text
README.md                 ← you are here
setup-windows.cmd         ← one-click Windows readiness check
neolabs.cmd               ← Windows launcher; avoids pip/PATH problems
neolabs-local.cmd         ← gateway-aware Windows shim
neolabs.ps1               ← PowerShell launcher implementation
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

Week 1 is intentionally hybrid: SOC works from pod-scoped replay while Pentest and Support use scheduled isolated live access.
