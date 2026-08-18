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

Command Prompt users can omit the `./`-style current-directory prefix and run:

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
```

`neolabs.cmd` runs the same `python3 -m tools.cli` client inside the supported WSL2 environment. Students no longer need to `cd tools` or run `python3 neolabs.py` manually.

### What the Windows launcher does

On the first run it checks the Windows host, prepares WSL2 and Docker Desktop where supported, installs missing Linux prerequisites inside WSL2, configures the Wazuh indexer kernel requirement, generates local Wazuh credentials, prepares the pinned Wazuh 4.14.7 stack, authenticates the assigned intern/pod, connects authorised VCC telemetry, starts Wazuh and verifies that assigned-pod telemetry is searchable.

On later runs it reuses the existing Wazuh configuration/data, starts or reconnects the required services, verifies telemetry again and opens the dashboard.

### Windows platform rule

`START-NEOLABS-SOC.cmd` is for a **physical Windows 10/11 workstation**. If it detects Windows Server or a Windows VM/VPS guest, it stops and directs the intern to use an Ubuntu/Debian VPS instead.

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

Canonical Linux syntax:

```bash
bash start-neolabs-soc.sh --validate-only
```

Expected result includes:

```text
[OK] Linux one-click SOC launcher contract is valid.
```

### 3. Start NeoLabs SOC

Run:

```bash
bash start-neolabs-soc.sh
```

Do **not** run the whole launcher with `sudo`:

```text
Do not use: sudo bash start-neolabs-soc.sh
```

The launcher itself uses `sudo` only for the small number of OS-level operations that require administrator privileges.

### 4. Use the NeoLabs CLI from the repository root

Use the root wrapper instead of navigating into `tools/`:

```bash
bash neolabs --help
bash neolabs status
bash neolabs doctor
bash neolabs login
bash neolabs connect
```

The wrapper runs:

```text
python3 -m tools.cli
```

from the correct repository root, preventing the import-path errors caused by launching the low-level Python files from inside `tools/`.

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

Do not use Windows Server or a Windows VPS/VM for the NeoLabs SOC workstation.

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

Use the **same platform launcher again**:

```text
Windows PowerShell: .\START-NEOLABS-SOC.cmd
Linux/Ubuntu:       bash start-neolabs-soc.sh
```

If `wazuh-stack/.env` and generated configuration already exist, they are reused. Ordinary startup does not regenerate the existing `.env`, delete Wazuh volumes, change pod assignment or reinstall the whole stack.

---

# NeoLabs CLI and diagnostics

The launcher is for starting/repairing the SOC workstation. The root `neolabs` wrappers are for CLI operations.

### Windows PowerShell

```powershell
.\neolabs.cmd status
.\neolabs.cmd doctor
.\neolabs.cmd login
.\neolabs.cmd connect
```

### Linux / Ubuntu

```bash
bash neolabs status
bash neolabs doctor
bash neolabs login
bash neolabs connect
```

Doctor checks:

```text
NeoLabs authentication
→ current LIVE/REPLAY surface
→ raw VCC event file
→ Wazuh rule engine
→ Filebeat
→ Wazuh indexer
→ Wazuh dashboard + manager API connection
```

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

On Windows, the locally generated password is copied to the Windows clipboard without being printed. On Linux the launcher reports the local dashboard credential from the protected local configuration when appropriate; do not post screenshots containing it.

## Headless Ubuntu/VPS

The supported headless Linux profile publishes dashboard TCP `8443` on the server so an intern can reach the dashboard using the server address. The launcher prints the local/private/public URL that it can determine.

Cloud or host firewall access remains an administrator-controlled boundary. Allow TCP `8443` only from the intern's approved source IP; do not open Wazuh administrative access broadly to the Internet.

---

# READY means verified

Do not begin the practical merely because Docker containers started. Wait for:

```text
SOC WORKSTATION READY
```

READY means a real synthetic event belonging to the **server-assigned pod** has been processed and is searchable in the local Wazuh indexer. Operation Night Watch is configured across the authorised Week 1 pods, so persistent missing assigned-pod telemetry is treated as a delivery/pipeline fault rather than an acceptable final state.

---

# Week 1 — Operation Night Watch

Read:

- [`docs/week-01/operation-night-watch-launch-pack.md`](docs/week-01/operation-night-watch-launch-pack.md)
- [`publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf`](publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf)

Use the preconfigured **NeoLabs — Operation Night Watch** view/dashboard when available. The **NeoLabs — Telemetry Health** view focuses on rule `100150` and collection/parser/visibility problems.

Official graded submissions belong in `RIL_NeoLabs-Intern-Assignments`, not this toolkit repository.

---

# Repository layout

```text
START-NEOLABS-SOC.cmd        ← Windows 10/11 physical-PC startup/repair entry point
start-neolabs-soc.sh         ← Linux/Ubuntu/VPS startup/repair entry point
neolabs.cmd                  ← Windows root NeoLabs CLI wrapper
neolabs                      ← Linux root NeoLabs CLI wrapper
README.md                    ← exact platform command syntax
START_HERE.md                ← onboarding/orientation
PROGRAMME_CURRENT_STATE.md   ← current programme/runtime reference
internal/windows/            ← Windows implementation helpers; do not run directly
wazuh-stack/                 ← Wazuh Compose/config/rules/internal runtime scripts
tools/                       ← underlying NeoLabs Python implementation; do not cd here for normal CLI use
docs/                        ← learning/operational documentation
publications/                ← branded student PDFs
templates/                   ← evidence/report templates
sample-logs/ + labs/         ← synthetic practice material
references/ + research/      ← deeper reference material
scripts/                     ← publication/build tooling
```

Students have one startup launcher and one root CLI wrapper for their operating system; the files under `internal/`, `tools/` and `wazuh-stack/scripts/` are implementation details.

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
