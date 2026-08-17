# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs × RIL SOC Level 1 Intern Toolkit** is the student-side Learn + Connect + Operate repository for authorised SOC training through the VCC Security Lab.

# Start here — use only the command for your platform

There are only **two normal SOC startup entry points** in this repository:

```text
Windows 10/11 physical PC:  START-NEOLABS-SOC.cmd
Ubuntu/Debian/Linux:        start-neolabs-soc.sh
```

Do **not** manually run files under `internal/` or individual files under `wazuh-stack/scripts/` for normal setup/startup.

For a fresh installation, clone the official toolkit repository, open a terminal in the clone's root directory and use the launcher for your platform. Do not copy another intern's `.env`, generated configuration, enrolment files or Docker volumes into the clone.

---

## Windows 10/11 — physical laptop or desktop

### 1. Update the toolkit

Open Command Prompt or PowerShell in the repository folder and run:

```text
git pull origin main
```

### 2. Optional: validate the launcher before installation/startup

```text
START-NEOLABS-SOC.cmd -ValidateOnly
```

Expected result includes:

```text
[OK] Root Windows SOC launcher contract is valid.
[OK] NeoLabs CLI is invoked as the tools.cli Python module to avoid script import-path failures.
```

### 3. Start NeoLabs SOC

Either double-click:

```text
START-NEOLABS-SOC.cmd
```

or run it from Command Prompt/PowerShell:

```text
START-NEOLABS-SOC.cmd
```

That same file is used on the **first run and every later run**.

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

Run:

```bash
bash ./start-neolabs-soc.sh --validate-only
```

Expected result:

```text
[OK] Linux one-click SOC launcher contract is valid.
```

The validation checks both supported Python entry paths and specifically catches the import-path failure that previously produced:

```text
ModuleNotFoundError: No module named 'tools'
```

### 3. Start NeoLabs SOC

Run:

```bash
bash ./start-neolabs-soc.sh
```

After executable permissions have been normalised, this also works:

```bash
./start-neolabs-soc.sh
```

Do **not** run the whole launcher with `sudo`:

```text
Do not use: sudo ./start-neolabs-soc.sh
```

The launcher itself uses `sudo` only for the small number of OS-level operations that actually require administrator privileges.

### What the Linux launcher does

On Ubuntu/Debian first run it can install required base packages, Docker Engine, Docker Compose v2, configure `vm.max_map_count`, generate the private local Wazuh configuration, prepare Wazuh 4.14.7, authenticate the intern, connect authorised VCC telemetry, start Wazuh and verify assigned-pod telemetry is searchable.

On later runs it detects the existing Wazuh installation/configuration and reuses it instead of reinstalling or deleting data.

The normal Linux launcher invokes the client as:

```bash
python3 -m tools.cli
```

from the repository root.

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
bash ./start-neolabs-soc.sh --validate-only
bash ./start-neolabs-soc.sh
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
Windows: START-NEOLABS-SOC.cmd
Linux:   ./start-neolabs-soc.sh
```

If `wazuh-stack/.env` and generated configuration already exist, they are reused. Ordinary startup does not regenerate the existing `.env`, delete Wazuh volumes, change pod assignment or reinstall the whole stack.

---

# After a shutdown, reboot or power loss

Do not reinstall Wazuh and do not reset the stack. Start Docker if your platform requires it, then run the same root launcher again:

```text
Windows: START-NEOLABS-SOC.cmd
Linux:   ./start-neolabs-soc.sh
```

On Windows, allow Docker Desktop and its WSL2 integration to finish starting. On Linux, the launcher checks Docker Engine and performs the supported service recovery. The launcher reuses local credentials, enrolment, generated configuration and indexed data; it starts the four services (indexer, manager, dashboard and telemetry collector), restores the telemetry path and waits for an assigned-pod event to become searchable before printing READY.

If recovery does not reach READY, run the matching `doctor` command from the Diagnostics section and send redacted output to a mentor.

---

# Destructive reset — testing or mentor-approved recovery only

A reset is not needed after an ordinary shutdown. It deletes the local Wazuh containers, volumes, indexed alerts, saved objects, generated Wazuh configuration/certificates, local telemetry and replay-fetch ledger so the next launch can build and fetch everything consistently from scratch.

From a Linux or WSL terminal in the repository root:

```bash
cd wazuh-stack
bash ./scripts/reset.sh --confirm-destroy-local-data
cd ..
```

Then rebuild through the supported root launcher:

```text
Windows: START-NEOLABS-SOC.cmd
Linux:   ./start-neolabs-soc.sh
```

By default, reset preserves the ignored `.env`, repository source and VCC enrolment/assigned-pod state. The next startup regenerates local Wazuh assets, reapplies restrictive telemetry-volume permissions, refetches authorised replay data where applicable and must verify end-to-end searchability before READY.

Do not add `--include-enrolment` for routine testing. That option also removes the local VCC client credential, certificates, assigned-pod record and enrolment state. It does not revoke the server-side credential; use it only when a VCC operator has revoked the old enrolment and supplied a fresh authorised handoff.

---

# Diagnostics

You do not need separate Doctor/setup files in the repository root.

### Windows

```text
START-NEOLABS-SOC.cmd doctor
START-NEOLABS-SOC.cmd status
START-NEOLABS-SOC.cmd login
```

### Linux

```bash
./start-neolabs-soc.sh doctor
./start-neolabs-soc.sh status
./start-neolabs-soc.sh login
```

Doctor checks:

```text
NeoLabs authentication
→ current LIVE/REPLAY surface
→ raw VCC event file
→ Wazuh rule engine
→ Filebeat
→ Wazuh indexer
→ Wazuh dashboard
```

If startup fails, send the mentor the exact terminal error/Doctor output after redacting credentials. Do not edit internal scripts or add `sudo` randomly.

---

# Wazuh dashboard

After successful NeoLabs authentication and a verified start, the launcher prints the dashboard username and password.

Username:

```text
admin
```

Password: the locally generated `WAZUH_INDEXER_PASSWORD`. The launcher prints it on the `SOC WORKSTATION READY` screen. Windows also copies it to the clipboard.

On this machine:

```text
https://127.0.0.1:8443
```

## Other devices / VPS

The dashboard is published on every host interface (`0.0.0.0:8443`). After READY, the launcher prints `https://<host-ip>:8443` URLs you can open from another laptop, phone or browser that can reach this host.

The certificate is self-signed, so continue past the browser warning. If the page does not load, allow inbound TCP `8443` on the host or cloud security group. Indexer and manager ports stay unpublished.

---

# READY means verified

Do not begin the practical merely because Docker containers started. Wait for:

```text
SOC WORKSTATION READY
```

READY means a real synthetic event belonging to the **server-assigned pod** has been processed and is searchable in the local Wazuh indexer. The launcher makes at most one bounded local repair attempt before failing closed.

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
START-NEOLABS-SOC.cmd        ← Windows 10/11 physical-PC entry point
start-neolabs-soc.sh         ← Linux/Ubuntu/VPS entry point
README.md                     ← exact startup commands
START_HERE.md                 ← onboarding/orientation
PROGRAMME_CURRENT_STATE.md    ← current programme/runtime reference
internal/windows/             ← Windows implementation helpers; do not run directly
wazuh-stack/                  ← Wazuh Compose/config/rules/internal runtime scripts
tools/                        ← underlying NeoLabs client/Doctor implementation
docs/                         ← learning/operational documentation
publications/                 ← branded student PDFs
templates/                    ← evidence/report templates
sample-logs/ + labs/          ← synthetic practice material
references/ + research/       ← deeper reference material
scripts/                      ← publication/build tooling
```

Students should not need to choose among setup scripts. The two root launchers are the supported orchestration layer.

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
