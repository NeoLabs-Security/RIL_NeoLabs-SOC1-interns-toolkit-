# Start Here — SOC Analyst Level 1

Welcome to the **NeoLabs × RIL SOC Level 1 Intern Toolkit**. Official graded submissions belong in `RIL_NeoLabs-Intern-Assignments`.

For the current architecture/runtime summary, read [`PROGRAMME_CURRENT_STATE.md`](PROGRAMME_CURRENT_STATE.md).

## Choose your platform

### Physical Windows 10/11 workstation

Pull the latest toolkit, then double-click:

```text
START-NEOLABS-SOC.cmd
```

This is the only normal Windows entry point. It first checks that the intern is on a supported physical Windows workstation. If it detects Windows Server or a Windows virtual machine/VPS guest, it stops before WSL/Docker setup and directs the intern to use an Ubuntu/Debian VPS instead.

On supported Windows it owns WSL2/Docker Desktop setup, first-run Linux prerequisites, the required Wazuh indexer kernel setting, first-run Wazuh preparation, NeoLabs authentication, LIVE/REPLAY connection, Wazuh health, telemetry-to-index verification, freshness/retention checks, saved Night Watch views and dashboard startup.

If Windows has just enabled WSL or installed a Linux distribution, Windows may require a restart and/or one first launch of the Linux distro to create its Linux user. Rerun the same CMD afterward; do not start picking individual setup scripts.

Diagnostics/status/login are subcommands of the same root file:

```text
START-NEOLABS-SOC.cmd doctor
START-NEOLABS-SOC.cmd status
START-NEOLABS-SOC.cmd login
```

### Linux / Ubuntu workstation

From the repository root, use:

```bash
bash start-neolabs-soc.sh
```

The launcher fixes its executable permission during setup, so subsequent runs may use:

```bash
./start-neolabs-soc.sh
```

On Ubuntu/Debian it can install missing base packages and Docker Engine + Compose v2, configure the required Wazuh indexer kernel setting, prepare Wazuh and complete the same NeoLabs/telemetry verification path. Run the launcher as your **normal Linux user**; it invokes `sudo` itself only for the OS-level actions that require administrator privileges.

Linux diagnostics/status/login:

```bash
./start-neolabs-soc.sh doctor
./start-neolabs-soc.sh status
./start-neolabs-soc.sh login
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

This uses Docker Engine directly and avoids the WSL2/nested-virtualisation dependency. On a headless server, the launcher prints an SSH local-port-forward command so the intern can securely open the loopback-only Wazuh dashboard from their own computer.

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

Username is `admin`. Windows copies the locally generated password to the clipboard without printing it. Linux desktop systems use an available supported clipboard utility when present; otherwise the password stays private in `wazuh-stack/.env` as `WAZUH_INDEXER_PASSWORD`.

## Repository structure

Students should not execute the implementation files under `internal/` or `wazuh-stack/scripts/` during normal startup.

```text
START-NEOLABS-SOC.cmd       physical Windows 10/11 entry point
start-neolabs-soc.sh        Linux/Ubuntu/VPS entry point
internal/windows/            Windows implementation helpers
wazuh-stack/                 Wazuh configuration/runtime internals
tools/                       NeoLabs client/Doctor internals
docs/ + publications/       learning material
templates/                   evidence/report templates
```

Low-level scripts remain in the repository because the launchers need them and mentors/CI may inspect them, but they are not competing student setup choices.

## Continue with Week 1

Read [`docs/week-01/operation-night-watch-launch-pack.md`](docs/week-01/operation-night-watch-launch-pack.md). Use the **NeoLabs — Operation Night Watch** view/dashboard when available and use **NeoLabs — Telemetry Health** or the launcher `doctor` action before interpreting missing/zero-result data.

## Security boundary

Never commit/share the NeoLabs Access Code, session token, Wazuh password, certificates/private keys or signed private URLs. Scope is server-controlled. Stop and contact a mentor if another pod, real personal/production data, credentials/private keys, unexpected infrastructure access or service instability appears.
