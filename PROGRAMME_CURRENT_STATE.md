# NeoLabs × RIL SOC Level 1 — Current Programme State

**Operational baseline:** 2026-08-14  
**Current assignment:** Week 01 — Operation Night Watch  
**Wazuh baseline:** 4.14.7  
**VCC topology:** five isolated pods (`pod-01` through `pod-05`)

This file is the current operational reference for the SOC toolkit. Technical learning chapters remain valid unless they conflict with this file, the root README, the current weekly assignment or the server-issued runtime state.

## Recommended Windows workflow

From the latest toolkit checkout, make sure Docker Desktop/WSL2 integration is available and double-click:

```text
START-NEOLABS-SOC.cmd
```

The launcher:

1. checks WSL2/toolkit prerequisites;
2. prepares the local Wazuh stack only when needed and preserves an existing `.env`;
3. reuses a valid NeoLabs session or prompts for the assigned pod + private Access Code;
4. connects to the current LIVE/REPLAY SOC surface;
5. waits for manager/indexer/dashboard/telemetry services;
6. reloads the current NeoLabs VCC rules;
7. proves a real synthetic event for the assigned pod is searchable in `wazuh-alerts-*`;
8. reports the latest indexed VCC event/freshness;
9. provisions the Night Watch and Telemetry Health dashboard/saved objects when supported;
10. checks local index retention/disk health;
11. copies the local Wazuh `admin` password to the Windows clipboard without printing it; and
12. opens the local Wazuh dashboard.

`SOC WORKSTATION READY` therefore means the assigned-pod telemetry-to-indexer path has been verified, not merely that containers started.

## Dashboard login

Normal local URL:

```text
https://127.0.0.1:8443
```

Username:

```text
admin
```

The password is generated locally during first setup. The Windows launcher copies it to the clipboard without printing it. Never put that password in a report, screenshot, Issue or Git commit.

## Diagnostics

Use either:

```text
CHECK-NEOLABS-SOC.cmd
```

or:

```powershell
.\neolabs.cmd doctor
```

Doctor checks each stage separately: NeoLabs authentication → current LIVE/REPLAY surface → raw VCC event file → Wazuh rule engine → Filebeat → Wazuh indexer → dashboard. It also reports the last indexed VCC event and local index/disk status.

## Week 1 Wazuh workflow

Use the preconfigured **NeoLabs — Operation Night Watch** view/dashboard when available. Otherwise use Threat Hunting/Discover against `wazuh-alerts-*` and filter the server-assigned pod.

Important Week 1 fields include pod ID, event type, synthetic user identity, source IP, outcome, correlation/session identifiers, Wazuh rule ID/level and original `event_time`. A separate **NeoLabs — Telemetry Health** view focuses on rule `100150` and collector/parser/visibility problems.

Week 1 is baseline analysis. Establish normal authentication and application/API behaviour, save reusable searches, build a short original-event-time timeline and document visibility gaps. Do not treat unusual activity as malicious merely because it differs from expectations.

## Telemetry/replay behaviour

The VCC uses a cost-aware hybrid runtime. During live windows SOC may receive the pod-scoped live telemetry path; during replay/cloud/endpoint states the same NeoLabs access flow loads only authorised archived telemetry for the assigned pod/scenario. Replay preserves original `event_time` and stores replay metadata separately.

Normal NeoLabs VCC events are indexed as searchable Wazuh alerts so Week 1 baseline activity is visible. The toolkit verifies actual index searchability before READY. The default local alert-index retention is 30 days; disk warnings begin at 85% and become critical at 92%. The default telemetry freshness warning is 90 minutes unless locally overridden.

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
