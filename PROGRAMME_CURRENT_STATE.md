# NeoLabs × RIL SOC Level 1 — Current Programme State

**Operational baseline:** 2026-08-16  
**Current assignment:** Week 01 — Operation Night Watch  
**Wazuh baseline:** 4.14.7  
**VCC topology:** five isolated pods (`pod-01` through `pod-05`)

This file is the current operational reference for the SOC toolkit. The supported student model is intentionally simple: **one startup/repair launcher and one root NeoLabs CLI wrapper per operating system**.

## Supported entry points

### Physical Windows 10/11 workstation

PowerShell startup:

```powershell
.\START-NEOLABS-SOC.cmd
```

PowerShell CLI:

```powershell
.\neolabs.cmd --help
.\neolabs.cmd status
.\neolabs.cmd doctor
```

Command Prompt may run the same `.cmd` files without the PowerShell `.\` current-directory prefix.

The Windows launcher is not the supported remote/VPS path. It performs a platform check before WSL/Docker work and refuses Windows Server and common Windows VM/VPS guests.

### Linux / Ubuntu

Startup:

```bash
bash start-neolabs-soc.sh
```

Root CLI:

```bash
bash neolabs --help
bash neolabs status
bash neolabs doctor
```

Students do not need to navigate into `tools/`.

### VPS / remote server

Programme policy requires an **Ubuntu or Debian Linux VPS**. Recommended images are Ubuntu 22.04/24.04 LTS or a current Debian release. Do not provision Windows Server or a Windows VM/VPS guest for the SOC workstation.

A Windows guest cannot make nested virtualisation appear from inside the VM when the host provider has not exposed it. NeoLabs therefore avoids WSL2 on VPS systems and runs Docker Engine/Wazuh directly on Linux.

PowerShell, Docker, Wazuh and low-level Python helper scripts are implementation details beneath the root entry points. Students should not assemble a manual setup sequence from files inside `internal/`, `tools/` or `wazuh-stack/scripts/`.

## First-run behaviour

Both platform launchers are idempotent orchestration layers. First run prepares missing prerequisites/configuration; subsequent runs reuse them.

### Windows first run

The root CMD routes through the Windows runtime authority and shared SOC orchestrator, which:

1. rejects Windows Server and detected Windows VM/VPS guests before attempting WSL2;
2. prepares WSL2 and Docker Desktop on a supported physical workstation;
3. installs missing Linux prerequisites inside WSL2;
4. sets the required Wazuh indexer `vm.max_map_count` value when needed;
5. verifies workstation capacity;
6. generates/reuses private local Wazuh credentials;
7. prepares the pinned Wazuh stack and required certificates/images;
8. authenticates/reuses the intern NeoLabs session;
9. connects the server-authorised LIVE/REPLAY telemetry surface;
10. starts/reuses Wazuh manager, indexer, dashboard and collector;
11. verifies the dashboard-to-manager API connection;
12. verifies a real synthetic event from the server-assigned pod is searchable in `wazuh-alerts-*`;
13. reports freshness/retention/disk state; and
14. opens the local dashboard and securely provides the local login credential.

Windows may require a restart after first enabling WSL or one initial Linux-distribution user setup. Rerun the **same CMD** afterward.

### Linux / Ubuntu first run

The root Bash launcher:

1. checks the actual native Docker runtime before repairing anything;
2. on Ubuntu/Debian, installs/repairs Docker Engine + Compose v2 when genuinely required;
3. handles normal-user Docker access when required;
4. uses `sudo` only for OS-level package/kernel/group changes;
5. sets/persists `vm.max_map_count=262144` when required;
6. normalises internal helper permissions;
7. prepares/reuses the Wazuh configuration, credentials, images and certificates;
8. authenticates/reuses the NeoLabs session;
9. connects authorised pod telemetry;
10. starts/reuses Wazuh and verifies dashboard/API health; and
11. refuses final READY until assigned-pod Night Watch telemetry is indexed/searchable.

Run the Linux launcher as the normal user:

```bash
bash start-neolabs-soc.sh
```

Do not run the whole launcher with `sudo`.

## Subsequent-run behaviour

When `.env` and generated Wazuh configuration already exist, the launchers preserve/reuse them. Normal later startup does not regenerate Wazuh passwords, delete indexer/telemetry volumes or reset pod scope. It reconnects the current authorised surface, ensures Wazuh is running and verifies assigned-pod telemetry remains searchable.

## Root NeoLabs CLI

The CLI wrappers are intentionally separate from the startup launchers so interns can perform status/login/connect/Doctor operations without changing directory.

Windows PowerShell:

```powershell
.\neolabs.cmd status
.\neolabs.cmd doctor
.\neolabs.cmd login
.\neolabs.cmd connect
```

Linux / Ubuntu / VPS:

```bash
bash neolabs status
bash neolabs doctor
bash neolabs login
bash neolabs connect
```

Both wrappers ultimately invoke `python3 -m tools.cli` from the repository root. The `tools/` directory is an implementation package, not a directory students should enter for normal CLI use.

Doctor checks NeoLabs authentication → current LIVE/REPLAY surface → raw VCC event file → Wazuh rule engine → Filebeat → indexer → dashboard/manager API, plus latest-event freshness and local index/disk state.

## Dashboard access

Normal local URL:

```text
https://127.0.0.1:8443
```

Username is `admin`. The password is generated locally and never belongs in GitHub/student submissions.

Windows copies it to the clipboard without printing it. On supported headless native Linux servers the dashboard is published on host TCP `8443`; the launcher reports usable local/private/public URLs when available. Cloud/host firewall policy must restrict access to the intern's approved source IP.

## READY meaning

`SOC WORKSTATION READY` means the assigned-pod telemetry-to-indexer path has been verified, not merely that Docker containers started.

## Week 1 Wazuh workflow

Use **NeoLabs — Operation Night Watch** when the saved dashboard is available; otherwise use Threat Hunting/Discover against `wazuh-alerts-*` and filter the server-assigned pod. Use **NeoLabs — Telemetry Health** / rule `100150` or the root CLI Doctor before interpreting zero results.

Week 1 remains baseline analysis: establish normal authentication and application/API behaviour, save reusable searches, build an original-event-time timeline and document visibility gaps.

## Telemetry/replay defaults

The VCC uses a cost-aware hybrid runtime. LIVE and replay/cloud/endpoint states remain server-controlled and pod-scoped. Replay preserves original `event_time` with replay metadata separate.

Normal NeoLabs VCC events are searchable in `wazuh-alerts-*`. Default local alert retention is 30 days, disk warnings begin at 85% and are critical at 92%, and the default telemetry freshness warning is 90 minutes.

## Twelve-week SOC arc

| Week | Scenario | SOC emphasis |
|---|---|---|
| 01 | Operation Night Watch | baseline/log literacy |
| 02 | Ghost Login | authentication/session investigation |
| 03 | Credential Storm | credential-attack detection/correlation |
| 04 | Broken Gate | authorisation/access anomalies |
| 05 | Poisoned Upload | upload/file telemetry |
| 06 | Web Breach | web attack-chain correlation |
| 07 | Cloud Locker | IAM/S3/CloudTrail monitoring |
| 08 | S3 Insider Trail | behavioural/privileged-access analysis |
| 09 | Data Escape | exfiltration correlation |
| 10 | Hidden Endpoint | API anomaly investigation |
| 11 | Developer Ransomware Drill | endpoint timeline/recovery evidence |
| 12 | Blackout at VCC | capstone incident investigation |

Later-week material can be staged before release. Only the current assignment and server state authorise student activity.

## Safety

Never alter pod identifiers to reach another pod. Do not share Access Codes, sessions, Wazuh credentials/certificates or private signed URLs. Stop and contact a mentor if another pod, real data, credentials/private keys, unexpected infrastructure access or service instability appears.
