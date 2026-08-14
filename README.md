# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs × RIL SOC Level 1 Intern Toolkit** is the student-side Learn + Connect + Operate repository for authorised SOC training through the VCC Security Lab.

## Start the SOC workstation

There are only **two normal student entry points**, one per operating system.

### Windows

Double-click:

```text
START-NEOLABS-SOC.cmd
```

### Linux / Ubuntu

From the repository root:

```bash
bash start-neolabs-soc.sh
```

After the first run has normalised executable permissions, you may also use:

```bash
./start-neolabs-soc.sh
```

Do not manually run the scripts under `internal/` or `wazuh-stack/scripts/` for normal cohort startup.

## What the launcher does on the first run

The platform launcher owns setup instead of expecting interns to guess which low-level command needs administrator privileges.

It checks/installs the supported platform prerequisites, prepares Docker, configures the Wazuh indexer kernel prerequisite, generates private local Wazuh credentials, prepares the pinned Wazuh 4.14.7 stack, authenticates the intern to the server-assigned NeoLabs pod, starts Wazuh, connects the authorised LIVE/REPLAY telemetry path, verifies Wazuh health, proves assigned-pod telemetry is searchable in `wazuh-alerts-*`, checks freshness/retention/disk state and opens or prints access to the Night Watch dashboard.

On Windows the launcher uses WSL2 + Docker Desktop. If Windows components require a reboot or a new WSL Linux distribution needs its one-time user creation, the launcher stops with a clear instruction and continues when the intern reruns the same root CMD afterward.

On Ubuntu/Debian Linux, the launcher can install the required base packages and Docker Engine/Compose v2, using `sudo` only for OS-level installation/kernel changes. Do **not** run the whole Linux launcher with `sudo`.

## Subsequent runs

Use the same entry point again:

```text
Windows: START-NEOLABS-SOC.cmd
Linux:   ./start-neolabs-soc.sh
```

If the local Wazuh installation/configuration already exists, it is reused. The launcher starts/reconnects the authorised SOC surface, verifies health and telemetry searchability, then opens the dashboard when a local GUI is available.

The launchers do not regenerate an existing `.env`, delete Wazuh volumes or change the student's server-assigned pod during ordinary startup.

## Diagnostics without extra root files

Windows:

```text
START-NEOLABS-SOC.cmd doctor
START-NEOLABS-SOC.cmd status
START-NEOLABS-SOC.cmd login
```

Linux:

```bash
./start-neolabs-soc.sh doctor
./start-neolabs-soc.sh status
./start-neolabs-soc.sh login
```

Doctor checks the path in order:

```text
NeoLabs authentication
→ current LIVE/REPLAY surface
→ raw VCC event file
→ Wazuh rule engine
→ Filebeat
→ Wazuh indexer
→ Wazuh dashboard
```

## Wazuh dashboard

Normal local URL:

```text
https://127.0.0.1:8443
```

Username:

```text
admin
```

On Windows, the locally generated password is copied to the clipboard without being printed. On Linux desktop systems the launcher uses an existing supported clipboard utility when available. Otherwise the password remains private in `wazuh-stack/.env` as `WAZUH_INDEXER_PASSWORD`.

On a headless Ubuntu/Linux server there is no browser to open on the server itself. The launcher prints the SSH local-port-forward command to use from the intern's own computer, then the intern opens the same loopback dashboard URL locally.

## READY means verified

Do not begin the practical merely because containers started. Wait for:

```text
SOC WORKSTATION READY
```

READY means a real synthetic event belonging to the **server-assigned pod** has been processed and is searchable in the local Wazuh indexer. The launcher makes at most one bounded local repair attempt if that path has not become searchable.

## Week 1 — Operation Night Watch

Read:

- [`docs/week-01/operation-night-watch-launch-pack.md`](docs/week-01/operation-night-watch-launch-pack.md)
- [`publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf`](publications/00_NeoLabs_SOC_L1_Week_01_Launch_Pack.pdf)

Use the preconfigured **NeoLabs — Operation Night Watch** view/dashboard when available. The separate **NeoLabs — Telemetry Health** view focuses on rule `100150` and collection/parser/visibility problems.

Official graded submissions belong in `RIL_NeoLabs-Intern-Assignments`, not this toolkit repository.

## Repository layout

```text
START-NEOLABS-SOC.cmd       ← Windows student entry point
start-neolabs-soc.sh        ← Linux/Ubuntu student entry point
README.md                    ← this page
START_HERE.md                ← onboarding/orientation
PROGRAMME_CURRENT_STATE.md   ← current programme/runtime reference
internal/windows/            ← hidden Windows implementation helpers
wazuh-stack/                 ← Wazuh Compose/config/rules/internal runtime scripts
tools/                       ← underlying NeoLabs client/Doctor implementation
docs/                        ← learning and operational documentation
publications/                ← branded student PDFs
templates/                   ← evidence/report templates
sample-logs/ + labs/         ← synthetic practice material
references/ + research/      ← deeper reference material
scripts/                     ← publication/build tooling
```

Students should not need to choose among setup scripts in the repository root. The root launchers are the supported orchestration layer; the implementation files beneath them are internal building blocks.

## Workstation expectations

Current Wazuh workstation baseline:

- 7 GiB Linux/WSL-visible RAM hard Week 1 floor;
- 8 GiB preferred minimum;
- 12–16 GiB recommended;
- 25 GiB free disk minimum, 50 GiB recommended;
- Docker with Compose v2;
- Wazuh indexer `vm.max_map_count >= 262144`.

The launcher attempts to satisfy installable/kernel prerequisites but cannot manufacture missing RAM/disk/CPU capacity.

## Security boundary

Never share the private NeoLabs Access Code, session files, local Wazuh password, certificates/private keys or signed private URLs. Never edit local pod identifiers to attempt another pod. Use only synthetic authorised VCC telemetry. Stop and notify a mentor if another pod, real personal/production data, a credential/private key or unexpected infrastructure access appears.

**Toolkit:** Learn + Connect + Operate  
**Replay Gateway:** stable authentication + runtime state + replay  
**VCC Security Lab:** scheduled live target/telemetry + scenario  
**Central Assignments:** submission + assessment
