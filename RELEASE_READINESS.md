# NeoLabs SOC Level 1 Toolkit — Release / Operational Readiness

**Status date:** 2026-08-14  
**Release state:** active programme baseline on `main`  
**Current scenario:** Week 01 — Operation Night Watch

This document records the current readiness state. It supersedes earlier release-candidate notes that described the VCC/SOC integration as unmerged or undeployed.

## Current readiness

| Area | Status | Current evidence/behaviour |
|---|---|---|
| SOC curriculum | Ready | foundational modules, Week 1 launch pack, labs, templates and references on `main` |
| Wazuh architecture | Ready | pinned Wazuh 4.14.7 manager/indexer/dashboard + telemetry collector |
| Windows startup | Ready | `START-NEOLABS-SOC.cmd` validated on `windows-latest` |
| WSL2 support | Ready | Kali/Ubuntu/Debian and other current WSL2 distros supported; Ubuntu is not required |
| VCC access | Ready | server-assigned pod/track; LIVE/replay mode selected by the gateway |
| Telemetry ingestion | Ready | live mTLS/replay ingestion feeds the same local telemetry file |
| Rule loading | Ready | startup explicitly reloads the Wazuh manager after current NeoLabs rules are asserted |
| Index/search verification | Ready | workstation does not report READY until assigned-pod synthetic telemetry is searchable in `wazuh-alerts-*` |
| Week 1 baseline visibility | Ready | base NeoLabs VCC rule is searchable, so normal baseline events can appear in Threat Hunting |
| Saved investigation views | Ready with fail-soft provisioning | Night Watch + Telemetry Health objects are provisioned locally when the dashboard API supports import |
| Doctor diagnostics | Ready | staged auth → telemetry → raw file → rules → Filebeat → indexer → dashboard checks |
| Freshness monitoring | Ready | latest indexed event age reported; 90-minute warning default |
| Local retention/disk safety | Ready | 30-day `wazuh-alerts-*` retention; warnings at 85%/92%; server archive unaffected |
| Credential handling | Ready | local random Wazuh secrets; admin password never printed and may be copied to Windows clipboard |
| Pod isolation | Ready | server-derived assignment and cross-pod rejection; no client pod-target selector |
| Synthetic-only boundary | Ready | replay/live ingestion validates synthetic pod-scoped records |
| Backup/recovery | Ready | CI rehearsal and local controls retained |
| Publications | Ready | automated branded publication workflow passes on `main` |

## Student release path

On Windows, the normal release path is:

```text
git pull
START-NEOLABS-SOC.cmd
```

The launcher reuses existing local Wazuh secrets/configuration and does not require students to delete their `.env`, regenerate credentials or reinstall a global CLI after ordinary toolkit updates.

If the workstation cannot prove telemetry/searchability, use:

```text
CHECK-NEOLABS-SOC.cmd
```

or `.\neolabs.cmd doctor`. The launcher must not be considered successful merely because the browser/dashboard opens.

## Operational limitations that remain by design

- A student's own laptop/Docker/Internet/disk can fail; the toolkit detects and reports these rather than claiming universal availability.
- Saved dashboard provisioning is a convenience layer and is fail-soft; Threat Hunting remains the fallback investigation surface.
- Student runtime scope remains server-controlled. A local edit does not authorise another pod/target.
- Later-week content can be staged on `main` before release; only the current assignment and server scenario authorise its use.

## Stop conditions

Do not use a workstation for cohort evidence collection when the toolkit cannot verify assigned-pod telemetry in the indexer, another pod appears, private credentials are exposed, the local indexer/dashboard is externally published, real/production data appears or service instability is observed.

## Approval record

```text
Toolkit main commit:
VCC main commit:
Technical reviewer:
Security reviewer:
Programme owner:
Deployment/rollout date:
Rollback owner:
Approved exceptions:
```
