# NeoLabs × RIL SOC Level 1 — Current Programme State

**Operational baseline:** 2026-08-14  
**Current assignment:** Week 01 — Operation Night Watch  
**Wazuh baseline:** 4.14.7  
**VCC topology:** five isolated pods (`pod-01` through `pod-05`)

This file is the current operational reference for the SOC toolkit. The supported student startup model is intentionally simple: **one root launcher per operating system**.

## Supported entry points

### Physical Windows 10/11 workstation

```text
START-NEOLABS-SOC.cmd
```

The Windows launcher is not the supported remote/VPS path. It performs a platform check before WSL/Docker work and refuses Windows Server and common Windows VM/VPS guests.

### Linux / Ubuntu

```bash
bash start-neolabs-soc.sh
```

After first-run permission normalisation:

```bash
./start-neolabs-soc.sh
```

### VPS / remote server

Programme policy requires an **Ubuntu or Debian Linux VPS**. Recommended images are Ubuntu 22.04/24.04 LTS or a current Debian release. Do not provision Windows Server or a Windows VM/VPS guest for the SOC workstation.

A Windows guest cannot make nested virtualisation appear from inside the VM when the host provider has not exposed it. NeoLabs therefore avoids WSL2 on VPS systems and runs Docker Engine/Wazuh directly on Linux.

All PowerShell, Docker, Wazuh and NeoLabs helper scripts are implementation details beneath the root entry points. Students should not assemble a manual setup sequence from files inside `internal/` or `wazuh-stack/scripts/`.

## First-run behaviour

Both launchers are designed to be idempotent orchestration layers. First run prepares missing prerequisites/configuration; subsequent runs reuse them.

### Windows first run

The root CMD delegates to `internal/windows/Start-NeoLabsSOC.ps1`, which:

1. rejects Windows Server and detected Windows VM/VPS guests before attempting WSL2;
2. prepares WSL2 and Docker Desktop through the internal Windows bootstrap on a supported physical workstation;
3. installs missing Linux prerequisites inside WSL2 with the WSL root account;
4. sets the required Wazuh indexer `vm.max_map_count` value when needed;
5. verifies workstation capacity;
6. generates private local Wazuh credentials if `.env` does not exist;
7. prepares the pinned Wazuh stack if generated configuration is absent;
8. authenticates the intern when no valid NeoLabs session exists;
9. connects the server-authorised LIVE/REPLAY telemetry surface and starts Wazuh;
10. waits for manager/indexer/dashboard/collector health;
11. verifies a real synthetic event from the server-assigned pod is searchable in `wazuh-alerts-*`;
12. reports freshness/retention/disk state;
13. provisions the Night Watch/Telemetry Health saved objects when supported;
14. copies the local `admin` password to the Windows clipboard without printing it; and
15. opens the local dashboard.

Windows may require a restart after first enabling WSL or one initial Linux-distribution user setup. When Windows cannot complete such an OS transition in the running process, the launcher stops clearly and the intern reruns the **same CMD** after the required restart/initialisation.

### Linux / Ubuntu first run

The root Bash launcher:

1. installs missing base packages;
2. on Ubuntu/Debian, installs Docker Engine + Compose v2 when Docker is absent;
3. starts/enables Docker and grants the normal user Docker access when required;
4. uses `sudo` only for OS-level package/kernel/group changes rather than requiring Wazuh runtime commands to be prefixed with `sudo`;
5. sets and persists `vm.max_map_count=262144` when required;
6. normalises executable permissions for internal shell scripts;
7. generates/prepares Wazuh only when the local installation is absent;
8. authenticates/reuses the NeoLabs session, connects telemetry, starts Wazuh and performs the same health/index verification as Windows.

Run the Linux launcher as the normal user, not as `sudo ./start-neolabs-soc.sh`.

## Subsequent-run behaviour

When `.env` and generated Wazuh configuration already exist, the launchers preserve/reuse them. Normal later startup does not regenerate Wazuh passwords, delete volumes or reset pod scope. It reconnects the current authorised surface, ensures Wazuh is running, checks current server state and verifies assigned-pod telemetry remains searchable.

## Diagnostics through the same entrypoint

Windows physical workstation:

```text
START-NEOLABS-SOC.cmd doctor
START-NEOLABS-SOC.cmd status
START-NEOLABS-SOC.cmd login
```

Linux / Ubuntu / VPS:

```bash
./start-neolabs-soc.sh doctor
./start-neolabs-soc.sh status
./start-neolabs-soc.sh login
```

Doctor checks NeoLabs authentication → current LIVE/REPLAY surface → raw VCC event file → Wazuh rule engine → Filebeat → indexer → dashboard, plus latest-event freshness and local index/disk state.

## Dashboard access

Normal local URL:

```text
https://127.0.0.1:8443
```

Username is `admin`. The password is generated locally and never belongs in GitHub/student submissions.

Windows copies it to the clipboard without printing it. A Linux desktop may copy it when a supported clipboard utility is already available. On headless Linux servers/VPS systems the launcher prints an SSH local-port-forward example because there is no GUI browser on the server; the dashboard remains loopback-only.

## READY meaning

`SOC WORKSTATION READY` means the assigned-pod telemetry-to-indexer path has been verified, not merely that Docker containers started.

## Week 1 Wazuh workflow

Use **NeoLabs — Operation Night Watch** when the saved dashboard is available; otherwise use Threat Hunting/Discover against `wazuh-alerts-*` and filter the server-assigned pod. Use **NeoLabs — Telemetry Health** / rule `100150` or launcher Doctor before interpreting zero results.

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
