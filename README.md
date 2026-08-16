# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs × RIL SOC Level 1 Intern Toolkit** is the student-side Learn + Connect + Operate repository for authorised SOC training through the VCC Security Lab.

# Start here — use only the command for your platform

Normal SOC startup always begins from the repository root.

```text
Windows 10/11 physical PC:  START-NEOLABS-SOC.cmd
Ubuntu/Debian/Linux:        start-neolabs-soc.sh
```

The repository also provides a root-level NeoLabs CLI on both platforms:

```text
Windows:  neolabs.cmd
Linux:    neolabs
```

Do **not** navigate into `tools/` to use the CLI, and do **not** manually run files under `internal/` or individual files under `wazuh-stack/scripts/` for normal setup/startup.

---

## Windows 10/11 — physical laptop or desktop

### 1. Update the toolkit

Open PowerShell in the repository folder and run:

```powershell
git pull origin main
```

### 2. Optional: validate the launcher

PowerShell:

```powershell
.\START-NEOLABS-SOC.cmd -ValidateOnly
```

Command Prompt users can run:

```text
START-NEOLABS-SOC.cmd -ValidateOnly
```

### 3. Start NeoLabs SOC

PowerShell:

```powershell
.\START-NEOLABS-SOC.cmd
```

Command Prompt:

```text
START-NEOLABS-SOC.cmd
```

You may also double-click `START-NEOLABS-SOC.cmd`. The same launcher is used on the **first run and every later run**.

### 4. Use the NeoLabs CLI from the repository root

PowerShell:

```powershell
.\neolabs.cmd --help
.\neolabs.cmd status
.\neolabs.cmd doctor
.\neolabs.cmd login
.\neolabs.cmd connect
```

Command Prompt:

```text
neolabs.cmd --help
neolabs.cmd status
neolabs.cmd doctor
neolabs.cmd login
neolabs.cmd connect
```

The Windows CLI wrapper uses the same WSL2 runtime and repository checkout as the main launcher.

### What the Windows launcher does

On the first run it checks the Windows host, prepares WSL2 and Docker Desktop where supported, installs missing Linux prerequisites inside WSL2, configures the Wazuh indexer kernel requirement, generates local Wazuh credentials, prepares the pinned Wazuh 4.14.7 stack, authenticates the assigned intern/pod, connects authorised VCC telemetry, starts Wazuh and verifies that assigned-pod telemetry is searchable.

On later runs it reuses the existing Wazuh configuration/data, starts or reconnects the required services, verifies telemetry again and opens the dashboard.

The Windows launcher invokes the NeoLabs Python client as:

```text
python3 -m tools.cli
```

inside WSL2. It does **not** use the old `python3 tools/cli.py` launcher path that caused the Ubuntu `ModuleNotFoundError: No module named 'tools'` failure.

### Windows platform rule

`START-NEOLABS-SOC.cmd` is for a **physical Windows 10/11 workstation**. It checks the host before WSL/Docker setup.

If it detects Windows Server or a Windows VM/VPS guest, it stops and tells the intern to use an Ubuntu/Debian VPS instead.

If a physical Windows PC has hardware virtualisation disabled, enable Intel VT-x / AMD-V / Virtualization in BIOS/UEFI, then rerun the same CMD file.

---

## Ubuntu / Debian / Linux

This is also the required path for **all SOC VPS/remote-server interns**.

### 1. Update the toolkit

From the repository root:

```bash
git pull origin main
```

### 2. Validate the Linux launcher

```bash
bash start-neolabs-soc.sh --validate-only
```

Expected result:

```text
[OK] Linux one-click SOC launcher contract is valid.
```

### 3. Start NeoLabs SOC

```bash
bash start-neolabs-soc.sh
```

The root launcher may also be executed directly after executable permissions are available, but `bash start-neolabs-soc.sh` is the portable documented form and does not depend on a Git execute bit.

Do **not** run the whole launcher with `sudo`:

```text
Do not use: sudo bash start-neolabs-soc.sh
```

The launcher itself uses `sudo` only for the small number of OS-level operations that actually require administrator privileges.

### 4. Use the NeoLabs CLI from the repository root

```bash
bash neolabs --help
bash neolabs status
bash neolabs doctor
bash neolabs login
bash neolabs connect
```

You do not need to enter `tools/`. The root wrapper runs `python3 -m tools.cli` from the correct repository root. `bash neolabs ...` is intentionally permission-safe even on checkouts where executable mode bits were not preserved.

### What the Linux launcher does

On Ubuntu/Debian first run it can install required base packages, Docker Engine, Docker Compose v2, configure `vm.max_map_count`, generate the private local Wazuh configuration, prepare Wazuh 4.14.7, authenticate the intern, connect authorised VCC telemetry, start Wazuh and verify assigned-pod telemetry is searchable.

On later runs it detects the existing Wazuh installation/configuration and reuses it instead of reinstalling or deleting data.

---

# VPS / remote server policy

SOC interns using a VPS or remote server must use **Ubuntu or Debian Linux**.

Recommended:

```text
Ubuntu 22.04 LTS
Ubuntu 24.04 LTS
Current supported Debian release
```

Do not use Windows Server or a Windows VPS/VM for the NeoLabs SOC workstation. Windows guests depend on nested virtualisation controlled by the VPS provider and are not the supported remote SOC path.

For an Ubuntu VPS, the complete normal startup is:

```bash
cd ~/toolkit
git pull origin main
bash start-neolabs-soc.sh --validate-only
bash start-neolabs-soc.sh
```

If the repository was cloned somewhere else, replace `~/toolkit` with that directory.

---

# First run versus later runs

## First run

The platform launcher owns installation/preparation. Interns should not manually install individual Wazuh components or guess which internal scripts need `sudo`.

The launcher handles the supported prerequisites, prepares Docker, configures the Wazuh indexer requirement, creates private local credentials, prepares Wazuh, logs into NeoLabs, connects the server-assigned pod telemetry, verifies Manager/Filebeat/Indexer/Dashboard health and proves assigned-pod telemetry is searchable.

## Later runs

Use the same platform launcher again:

```text
Windows PowerShell: .\START-NEOLABS-SOC.cmd
Windows CMD:        START-NEOLABS-SOC.cmd
Linux:              bash start-neolabs-soc.sh
```

If `wazuh-stack/.env` and generated configuration already exist, they are reused. Ordinary startup does not regenerate the existing `.env`, delete Wazuh volumes, change pod assignment or reinstall the whole stack.

---

# Diagnostics

The launcher and root CLI both expose normal diagnostics.

### Windows PowerShell

```powershell
.\START-NEOLABS-SOC.cmd doctor
.\START-NEOLABS-SOC.cmd status
.\START-NEOLABS-SOC.cmd login

.\neolabs.cmd doctor
.\neolabs.cmd status
```

### Linux

```bash
bash start-neolabs-soc.sh doctor
bash start-neolabs-soc.sh status
bash start-neolabs-soc.sh login

bash neolabs doctor
bash neolabs status
```

Doctor checks NeoLabs authentication, the current LIVE/REPLAY surface, raw VCC telemetry, Wazuh rules, Filebeat, the indexer, dashboard and manager API connection.

If startup fails, send the mentor the exact terminal error/Doctor output after redacting credentials. Do not edit internal scripts or add `sudo` randomly.

---

# Wazuh dashboard

Normal local URL:

```text
https://127.0.0.1:8443
```

Username:

```text
admin
```

On Windows, the locally generated password is copied to the Windows clipboard without being printed. On Linux the launcher displays the local dashboard credential when appropriate so a headless/server intern can sign in; treat terminal screenshots as private if that password is visible.

## Headless Ubuntu/VPS

The launcher reports the dashboard address appropriate for the server profile. Cloud/host firewall policy still controls whether another device can reach TCP 8443.

---

# READY means verified

Do not begin the practical merely because Docker containers started. Wait for:

```text
SOC WORKSTATION READY
```

READY means a real synthetic event belonging to the **server-assigned pod** has been processed and is searchable in the local Wazuh indexer. The launcher makes bounded safe local repair attempts before failing closed.

---

# Week 1 — Operation Night Watch

Read:

- [`docs/week-01/operation-night-watch-launch-pack.md`](docs/week-01/operation-night-watch-launch-pack.md)
- [`publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf`](publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf)

Use the preconfigured **NeoLabs — Operation Night Watch** view/dashboard when available. The **NeoLabs — Telemetry Health** view focuses on collection/parser/visibility problems.

Official graded submissions belong in `RIL_NeoLabs-Intern-Assignments`, not this toolkit repository.

---

# Repository layout

```text
START-NEOLABS-SOC.cmd        ← Windows 10/11 physical-PC launcher
start-neolabs-soc.sh         ← Linux/Ubuntu/VPS launcher
neolabs.cmd                   ← Windows root NeoLabs CLI
neolabs                       ← Linux root NeoLabs CLI
README.md                     ← exact startup/CLI commands
START_HERE.md                 ← onboarding/orientation
PROGRAMME_CURRENT_STATE.md    ← current programme/runtime reference
internal/windows/             ← Windows implementation helpers; do not run directly
wazuh-stack/                  ← Wazuh Compose/config/rules/internal runtime scripts
tools/                        ← underlying Python CLI implementation
docs/                         ← learning/operational documentation
publications/                 ← branded student PDFs
templates/                    ← evidence/report templates
sample-logs/ + labs/          ← synthetic practice material
references/ + research/       ← deeper reference material
scripts/                      ← publication/build tooling
```

Students should not need to choose among setup scripts or navigate into `tools/`.

---

# Workstation expectations

Current Wazuh workstation baseline:

- 7 GiB Linux/WSL-visible RAM hard Week 1 floor;
- 8 GiB preferred minimum;
- 12–16 GiB recommended;
- 25 GiB free disk minimum, 50 GiB recommended;
- Docker with Compose v2;
- Wazuh indexer `vm.max_map_count >= 262144`.

The launcher attempts to satisfy installable/kernel prerequisites but cannot manufacture missing RAM/disk/CPU capacity or physical-host virtualisation capability.

---

# Security boundary

Never share the private NeoLabs Access Code, session files, local Wazuh password, certificates/private keys or signed private URLs. Never edit local pod identifiers to attempt another pod. Use only synthetic authorised VCC telemetry. Stop and notify a mentor if another pod, real personal/production data, a credential/private key or unexpected infrastructure access appears.

**Toolkit:** Learn + Connect + Operate  
**Replay Gateway:** stable authentication + runtime state + replay  
**VCC Security Lab:** scheduled live target/telemetry + scenario  
**Central Assignments:** submission + assessment
