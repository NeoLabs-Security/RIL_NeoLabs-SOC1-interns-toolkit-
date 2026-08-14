# Start Here — SOC Analyst Level 1

Welcome to the **NeoLabs × RIL SOC Level 1 Intern Toolkit**. This repository contains SOC learning material, the local Wazuh workstation, investigation templates and the student-side NeoLabs access client. Official graded submissions belong in `RIL_NeoLabs-Intern-Assignments`.

For the current architecture/runtime summary, read [`PROGRAMME_CURRENT_STATE.md`](PROGRAMME_CURRENT_STATE.md).

## Windows — recommended start

1. Pull the latest toolkit.
2. Double-click:

```text
START-NEOLABS-SOC.cmd
```

That is now the normal **single starting point**. The launcher first runs the NeoLabs Docker/WSL2 bootstrap, then handles first-run Wazuh preparation, authentication, LIVE/REPLAY connection, Wazuh health, current rule reload, assigned-pod telemetry indexing verification, freshness/retention checks, Night Watch saved-object provisioning and local dashboard login assistance.

The Docker bootstrap automatically:

- verifies WSL is available and the default Linux distro is actually WSL2;
- sets WSL2 as the default for future distro installs;
- starts Docker Desktop when it is installed but stopped;
- requires Docker Desktop's Linux container engine;
- waits for the Docker daemon to become ready; and
- proves `docker` is available inside the same default WSL2 distro used by the SOC toolkit.

If Docker Desktop is not installed, the launcher opens the official Docker Desktop for Windows installation page and stops cleanly. First-time Windows WSL enablement, a required Windows restart, or enabling a specific Docker Desktop WSL distro integration can require a one-time Windows/Docker Desktop action and is not silently forced by the toolkit.

### Optional Docker-only check

If you want to prepare/test Docker before starting Wazuh, double-click:

```text
START-NEOLABS-DOCKER.cmd
```

When it reports `NEOLABS DOCKER READY`, the Docker/WSL2 layer is ready for the SOC launcher.

Do not begin investigation until the SOC launcher reaches:

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

If the failure occurs before Wazuh starts and mentions Docker/WSL2, run `START-NEOLABS-DOCKER.cmd` to isolate that layer.

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
