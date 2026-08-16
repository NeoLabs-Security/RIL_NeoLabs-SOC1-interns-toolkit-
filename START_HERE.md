# Start Here — SOC Analyst Level 1

Welcome to the **NeoLabs × RIL SOC Level 1 Intern Toolkit**. Official graded submissions belong in `RIL_NeoLabs-Intern-Assignments`.

For the current architecture/runtime summary, read [`PROGRAMME_CURRENT_STATE.md`](PROGRAMME_CURRENT_STATE.md).

## Choose your platform

### Physical Windows 10/11 workstation

Pull the latest toolkit, then either double-click `START-NEOLABS-SOC.cmd` or run from PowerShell:

```powershell
.\START-NEOLABS-SOC.cmd
```

From Command Prompt, run:

```text
START-NEOLABS-SOC.cmd
```

This is the normal Windows startup/repair entry point. It first checks that the intern is on a supported physical Windows workstation. If it detects Windows Server or a Windows virtual machine/VPS guest, it stops before WSL/Docker setup and directs the intern to use an Ubuntu/Debian VPS instead.

On supported Windows it owns WSL2/Docker Desktop setup, first-run Linux prerequisites, the required Wazuh indexer kernel setting, first-run Wazuh preparation, NeoLabs authentication, LIVE/REPLAY connection, Wazuh health, telemetry-to-index verification, freshness/retention checks, saved Night Watch views and dashboard startup.

If Windows has just enabled WSL or installed a Linux distribution, Windows may require a restart and/or one first launch of the Linux distro to create its Linux user. Rerun the same CMD afterward; do not start picking individual setup scripts.

Use the root NeoLabs CLI wrapper for status/login/Doctor and other CLI commands:

```powershell
.\neolabs.cmd --help
.\neolabs.cmd status
.\neolabs.cmd doctor
.\neolabs.cmd login
.\neolabs.cmd connect
```

Do not navigate into `tools/` to run the Python files manually.

### Linux / Ubuntu workstation

From the repository root, use the canonical Linux launcher syntax:

```bash
bash start-neolabs-soc.sh
```

On Ubuntu/Debian it can install missing base packages and Docker Engine + Compose v2, configure the required Wazuh indexer kernel setting, prepare Wazuh and complete the same NeoLabs/telemetry verification path. Run the launcher as your **normal Linux user**; it invokes `sudo` itself only for the OS-level actions that require administrator privileges.

Use the root Linux NeoLabs CLI wrapper instead of changing into `tools/`:

```bash
bash neolabs --help
bash neolabs status
bash neolabs doctor
bash neolabs login
bash neolabs connect
```

### VPS / remote server

If you are using a VPS or remote server for the SOC workstation, the programme requires **Ubuntu or Debian Linux**. Do not choose Windows Server and do not use a Windows VM/VPS guest for the SOC workstation.

Recommended VPS operating systems:

```text
Ubuntu 24.04 LTS
Ubuntu 22.04 LTS
Current Debian release
```

Then use:

```bash
bash start-neolabs-soc.sh
```

This uses Docker Engine directly and avoids the WSL2/nested-virtualisation dependency. On a headless server the dashboard is published on TCP 8443 by the supported Linux profile; cloud/host firewall rules must restrict access to the intern's approved source IP.

## Do not begin until READY

```text
SOC WORKSTATION READY
```

READY means an actual synthetic event for the **server-assigned pod** is indexed and searchable in local Wazuh, not merely that Docker containers are running.

## Wazuh login

Normal local dashboard:

```text
https://127.0.0.1:8443
```

Username is `admin`. Windows copies the locally generated password to the clipboard without printing it. Linux reports the protected local credential when appropriate; do not share terminal screenshots containing it.

## Repository structure

Students should not execute implementation files under `internal/`, `tools/` or `wazuh-stack/scripts/` during normal startup/CLI use.

```text
START-NEOLABS-SOC.cmd       Windows physical-PC startup/repair
start-neolabs-soc.sh        Linux/Ubuntu/VPS startup/repair
neolabs.cmd                 Windows root NeoLabs CLI
neolabs                     Linux root NeoLabs CLI
internal/windows/           Windows implementation helpers
wazuh-stack/                Wazuh configuration/runtime internals
tools/                      underlying Python CLI implementation
docs/ + publications/       learning material
templates/                  evidence/report templates
```

Low-level scripts remain because the launchers/CLI and CI need them; they are not competing student entry points.

## Continue with Week 1

Read [`docs/week-01/operation-night-watch-launch-pack.md`](docs/week-01/operation-night-watch-launch-pack.md). Use the **NeoLabs — Operation Night Watch** view/dashboard when available and use **NeoLabs — Telemetry Health** or `bash neolabs doctor` / `.\neolabs.cmd doctor` before interpreting missing/zero-result data.

## Security boundary

Never commit/share the NeoLabs Access Code, session token, Wazuh password, certificates/private keys or signed private URLs. Scope is server-controlled. Stop and contact a mentor if another pod, real personal/production data, credentials/private keys, unexpected infrastructure access or service instability appears.
