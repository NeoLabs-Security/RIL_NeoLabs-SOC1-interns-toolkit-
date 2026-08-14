# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs × RIL SOC Level 1 Intern Toolkit** is the student-side **Learn + Connect + Operate** repository for authorised SOC training through the VCC Security Lab.

## 🚀 WEEK 1 — START HERE

**Scenario:** Operation Night Watch  
**Goal:** learn what normal VCC activity looks like before later incident scenarios begin.

### 1. Read the Week 1 pack

- Source: [`docs/week-01/operation-night-watch-launch-pack.md`](docs/week-01/operation-night-watch-launch-pack.md)
- Branded PDF: [`publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf`](publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf)

## Windows — recommended one-click start

Windows interns should normally use:

```text
START-NEOLABS-SOC.cmd
```

Double-click it from the cloned toolkit folder. It safely orchestrates the existing toolkit controls rather than bypassing them:

1. checks WSL2 and the toolkit path;
2. runs first-time Wazuh preparation only when `wazuh-stack/.env` is missing;
3. reuses a valid saved NeoLabs session or prompts for the assigned pod + private Access Code;
4. runs `neolabs connect` against the current server-authorised LIVE/REPLAY learning surface;
5. waits for the Wazuh manager, indexer, dashboard and telemetry collector to become healthy;
6. confirms the current server-issued pod/scenario state;
7. proves assigned-pod VCC telemetry is indexed and searchable in `wazuh-alerts-*`;
8. prints the age of the newest indexed VCC event so stale feeds are visible immediately;
9. applies the local 30-day Wazuh alert-retention policy and disk warnings;
10. provisions the pod-scoped **NeoLabs — Operation Night Watch** and **NeoLabs — Telemetry Health** saved dashboards/searches;
11. securely copies the local Wazuh `admin` password to the Windows clipboard without printing it; and
12. opens the preconfigured Night Watch dashboard when saved-object provisioning succeeds.

At the Wazuh login page use:

```text
Username: admin
Password: press Ctrl+V (the launcher copied it to your clipboard)
```

After signing in, copy any non-sensitive text to replace the password currently held in your clipboard. On a shared or screen-recorded workstation, advanced users can start the PowerShell launcher with `-NoClipboard`; the password remains private in the local `wazuh-stack/.env` and is never committed to GitHub.

The Night Watch saved view is automatically scoped to the **server-issued pod** and includes `pod_id`, `event_type`, user identity, `source_ip`, `outcome`, `correlation_id`, rule level and original `event_time`. On Wazuh 4.14.7, the original JSON `user` field is represented as `data.dstuser`, so the saved view uses that field for identity.

Existing local Wazuh secrets and configuration are preserved. The launcher does not let a student choose another telemetry target or bypass server-side pod/track scope.

> **Windows interns: use ` .\neolabs.cmd ` for individual commands — not bare `neolabs`.**  
> Run NeoLabs commands from inside this toolkit folder.

### First-time/manual setup fallback

If you need to prepare or troubleshoot the workstation separately, run:

```text
setup-windows.cmd
```

The setup checks WSL2, Bash, Docker, Python, OpenSSL, curl, available memory and required kernel settings. Ubuntu is **not** required; Kali, Debian and other current WSL2 Linux distributions are supported. It creates the private local Wazuh configuration/secrets when needed and prepares the stack without overwriting an existing `.env`.

Then you can use the manual flow:

```powershell
.\neolabs.cmd login
.\neolabs.cmd status
.\neolabs.cmd pod info
.\neolabs.cmd connect
.\neolabs.cmd doctor
```

`login` asks only for **your assigned pod** and **your private NeoLabs Access Code**. SOC telemetry scope is server-controlled; you do not choose another pod or telemetry target.

The gateway decides whether the current authorised SOC learning surface is LIVE or REPLAY. `connect` handles that mode and feeds the assigned pod's approved telemetry into the same local Wazuh workflow.

### If something looks wrong

Double-click:

```text
CHECK-NEOLABS-SOC.cmd
```

or run:

```powershell
.\neolabs.cmd doctor
```

The doctor prints each stage separately:

```text
VCC authentication
→ live/replay telemetry surface
→ raw VCC event file
→ Wazuh rule engine
→ Filebeat
→ Wazuh indexer
→ Wazuh dashboard
```

It also prints the latest indexed-event freshness, indexer disk usage/alert-index size and whether the local retention policy is present.

### Complete Operation Night Watch

Use the Week 1 pack for the exact task and deliverables. Official submissions belong in the separate `RIL_NeoLabs-Intern-Assignments` repository, not this toolkit.

## Windows command reminder

```text
EASIEST:   double-click START-NEOLABS-SOC.cmd
CHECK:     double-click CHECK-NEOLABS-SOC.cmd

MANUAL:    .\neolabs.cmd login
MANUAL:    .\neolabs.cmd status
MANUAL:    .\neolabs.cmd connect
MANUAL:    .\neolabs.cmd doctor

DO NOT USE: python tools\neolabs.py login --base-url ...
```

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

- `START-NEOLABS-SOC.cmd` one-click Windows SOC startup;
- `CHECK-NEOLABS-SOC.cmd` / `neolabs doctor` staged telemetry health diagnosis;
- local Windows `neolabs.cmd` launcher that avoids pip/PATH failures;
- Windows/WSL2 readiness and first-run setup;
- containerised Wazuh manager/indexer/dashboard stack;
- NeoLabs pod-scoped telemetry collector and custom rules;
- automatic signed replay ingestion and live support for scheduled windows;
- end-to-end verification that assigned-pod VCC events are searchable in Wazuh before READY is displayed;
- last-event freshness reporting with a 90-minute warning threshold;
- pod-scoped Night Watch saved search/dashboard with Week 1 investigation fields;
- pod-scoped Telemetry Health saved search/dashboard around rule `100150`;
- local `wazuh-alerts-*` Index State Management retention, default 30 days;
- indexer filesystem and alert-index size warnings at 85%/92% thresholds;
- private local Wazuh admin credentials with clipboard-assisted Windows login;
- preflight, health, backup, restore and reset controls;
- SecOps/Wazuh educational material plus the Week 1 Log Literacy launch attachment;
- evidence, query-journal and incident-report templates;
- synthetic labs/sample telemetry;
- branded PDF publication and validation workflows.

The retention policy affects only the intern's **local Wazuh alert indices**. NeoLabs VCC telemetry archives, approved evidence and server-side records are unaffected. Existing non-NeoLabs ISM policies are not force-overridden.

## Useful Windows commands

```text
START-NEOLABS-SOC.cmd      setup + authenticate + connect + verify telemetry + freshness + open Night Watch
CHECK-NEOLABS-SOC.cmd      staged VCC-to-dashboard health diagnosis
.\neolabs.cmd login       authenticate with your assigned pod + private Access Code
.\neolabs.cmd connect     load the current authorised replay/live SOC surface into Wazuh
.\neolabs.cmd doctor      verify auth, telemetry, raw file, rules, Filebeat, indexer and dashboard
.\neolabs.cmd status      show current runtime, pod and scenario
.\neolabs.cmd evidence    download approved evidence for your pod/scenario
.\neolabs.cmd pod info    show the server-assigned pod
.\neolabs.cmd disconnect  remove the local gateway session
```

## Repository map

```text
README.md                   ← you are here
START-NEOLABS-SOC.cmd       ← recommended Windows one-click launcher
CHECK-NEOLABS-SOC.cmd       ← one-click staged SOC health check
Start-NeoLabsSOC.ps1        ← one-click orchestration implementation
setup-windows.cmd           ← Windows/WSL2 first-run preparation
neolabs.cmd                 ← use this for individual Windows NeoLabs commands
neolabs-local.cmd           ← gateway-aware Windows shim
neolabs.ps1                 ← PowerShell launcher implementation
START_HERE.md               ← workstation/orientation detail
docs/week-01/               ← current Week 1 instructions
publications/               ← branded student PDFs
wazuh-stack/                ← preconfigured SOC tooling + dashboards/retention/doctor
tools/cli.py                ← doctor-aware command entry point
tools/neolabs.py            ← underlying VCC access client
templates/                  ← evidence/report templates
sample-logs/ + labs/        ← safe practice material
research/ + references/     ← deeper reference material
```

## Security rules

Never share private access details, session files, certificates or keys. Never alter local pod identifiers in an attempt to access another pod. Use only synthetic data and authorised VCC resources. Stop and notify a mentor if another pod, real personal data, a credential or unexpected infrastructure access appears.

## Runtime design

**Toolkit:** Learn + Connect + Operate  
**Replay Gateway:** Stable Authentication + Runtime State + Replay  
**VCC Security Lab:** Scheduled Live Target/Telemetry + Scenario  
**Central Assignments:** Task submission + assessment
