# Start Here — SOC Analyst Level 1

Welcome to the **NeoLabs × RIL SOC Level 1 Intern Toolkit**. This repository contains SOC learning material, the local Wazuh workstation, investigation templates and the student-side NeoLabs access client. Official graded submissions belong in `RIL_NeoLabs-Intern-Assignments`.

For the current architecture/runtime summary, read [`PROGRAMME_CURRENT_STATE.md`](PROGRAMME_CURRENT_STATE.md).

## Windows — recommended start

1. Pull the latest toolkit.
2. Make sure Docker Desktop is running with WSL2 integration.
3. Double-click:

```text
START-NEOLABS-SOC.cmd
```

The launcher handles first-run preparation, authentication, LIVE/REPLAY connection, Wazuh health, current rule reload, assigned-pod telemetry indexing verification, freshness/retention checks, Night Watch saved-object provisioning and local dashboard login assistance.

Do not begin investigation until the launcher reaches:

```text
SOC WORKSTATION READY
```

READY means an actual synthetic VCC event for your server-assigned pod is searchable in Wazuh.

## Wazuh login

Normal local dashboard:

```text
https://127.0.0.1:8443
```

Use username `admin`. The locally generated password is copied to the Windows clipboard by the launcher without being printed. Press `Ctrl+V` on the Wazuh login page, then replace the clipboard contents with non-sensitive text after signing in.

## If anything looks wrong

Double-click:

```text
CHECK-NEOLABS-SOC.cmd
```

or run from PowerShell in this toolkit folder:

```powershell
.\neolabs.cmd doctor
```

Doctor checks NeoLabs authentication, LIVE/REPLAY availability, raw VCC telemetry, the Wazuh rule engine, Filebeat, indexer and dashboard. It also reports the age of the newest indexed VCC event and local index/disk status.

## Manual commands

Windows interns use the toolkit-local launcher, not bare `neolabs`:

```powershell
.\neolabs.cmd login
.\neolabs.cmd status
.\neolabs.cmd pod info
.\neolabs.cmd connect
.\neolabs.cmd doctor
.\neolabs.cmd evidence
```

Windows interns do **not** need a global `pip install`, Python Scripts PATH changes or a manually entered gateway URL for the normal programme flow.

## Continue with Week 1

Read [`README.md`](README.md) and [`docs/week-01/operation-night-watch-launch-pack.md`](docs/week-01/operation-night-watch-launch-pack.md). Use the **NeoLabs — Operation Night Watch** saved view/dashboard when available; use the **NeoLabs — Telemetry Health** view or Doctor before interpreting missing/zero-result data.

## Learning order

Use `LEARNING_PATH.md` for the broader SOC curriculum and the material under `publications/`, `docs/`, `wazuh-stack/`, `sample-logs/`, `labs/` and `templates/` as directed by the current weekly task.

## Repository boundary

Keep private onboarding details, local Wazuh credentials, runtime state and internship evidence out of this public toolkit. Stop and contact a mentor if another pod, real data, credentials/private keys, unexpected infrastructure access or service instability appears.
