# NeoLabs SOC Level 1 Toolkit — Release / Operational Readiness

**Status date:** 2026-08-16  
**Current scenario:** Week 01 — Operation Night Watch

## Current readiness

| Area | Status | Current evidence/behaviour |
|---|---|---|
| SOC curriculum | Ready | foundational modules, Week 1 launch pack, labs, templates and references |
| Wazuh architecture | Ready | pinned Wazuh 4.14.7 manager/indexer/dashboard + telemetry collector |
| Windows root startup | Ready | `START-NEOLABS-SOC.cmd` is the normal Windows startup/repair entry point |
| Linux/Ubuntu root startup | Ready by source/contract; runtime depends on host | `start-neolabs-soc.sh` owns Ubuntu/Debian runtime preparation and subsequent startup |
| Windows root CLI | Ready | `neolabs.cmd` provides CLI access from repository root through WSL2 |
| Linux root CLI | Ready | `neolabs` provides CLI access from repository root without navigating into `tools/` |
| Root repository UX | Ready | one startup launcher + one CLI wrapper per platform; low-level implementation remains under `internal/`, `tools/` and runtime folders |
| WSL2 support | Ready | existing current WSL2 distros supported; missing Windows WSL/distro bootstrap handled by the Windows launcher |
| Docker setup | Ready | Windows Docker Desktop bootstrap; Ubuntu/Debian Docker Engine + Compose v2 bootstrap |
| Privilege handling | Ready | low-level Wazuh scripts run unprivileged; root launchers perform only required OS-level elevation |
| VCC access | Ready | server-assigned pod/track; LIVE/replay mode selected by the gateway |
| Telemetry ingestion | Ready | live mTLS/replay ingestion feeds the same local telemetry file |
| Rule loading | Ready | startup validates and reloads current NeoLabs Wazuh rules |
| Index/search verification | Ready | no READY until assigned-pod synthetic telemetry is searchable in `wazuh-alerts-*` |
| Week 1 baseline visibility | Ready | normal baseline VCC events are searchable |
| Saved investigation views | Ready with fail-soft provisioning | Night Watch + Telemetry Health objects are provisioned locally when supported |
| Doctor diagnostics | Ready | root `neolabs` wrappers check auth → telemetry → raw file → rules → Filebeat → indexer → dashboard/API |
| Freshness monitoring | Ready | latest indexed event age reported; 90-minute warning default |
| Local retention/disk safety | Ready | 30-day `wazuh-alerts-*` retention; 85%/92% warnings |
| Credential handling | Ready | local random Wazuh secrets; password never printed by normal Windows startup |
| Pod isolation | Ready | server-derived assignment and cross-pod rejection |
| Synthetic-only boundary | Ready | replay/live ingestion validates synthetic pod-scoped records |
| Backup/recovery | Ready | CI rehearsal and local controls retained |
| Publications | Ready | automated branded publication workflow |

## Student release paths

### Windows PowerShell

```powershell
git pull origin main
.\START-NEOLABS-SOC.cmd
```

CLI/diagnostics:

```powershell
.\neolabs.cmd status
.\neolabs.cmd doctor
```

Command Prompt can run the same `.cmd` filenames without PowerShell's `.\` prefix.

### Linux / Ubuntu

```bash
git pull origin main
bash start-neolabs-soc.sh
```

CLI/diagnostics:

```bash
bash neolabs status
bash neolabs doctor
```

The launchers reuse existing local Wazuh secrets/configuration on later runs. Students should not delete `.env`, delete volumes or reconstruct setup from low-level scripts during ordinary troubleshooting.

## Verification boundary

CI can verify Bash syntax, root CLI syntax/contracts, Linux launcher contract/source behaviour, Wazuh/Compose configuration and Windows PowerShell/CMD contracts. A GitHub-hosted runner is not a substitute for every intern's actual Windows/WSL/Docker Desktop or fresh Ubuntu Server host. The first real machine in each platform profile should still be used as a smoke-test workstation before broad rollout.

## Operational limitations

- WSL feature installation or a new Windows Linux-distro install can legitimately require a Windows restart/one-time distro user initialisation.
- Docker Desktop can present first-run/licence/update/virtualisation prompts that a safe automation must not fake past.
- Linux automatic Docker installation is intentionally bounded to Ubuntu/Debian; other Linux distributions may use the same root launcher after Docker Engine + Compose v2 are installed by their supported method.
- A headless Linux server has no GUI browser; the supported profile can publish dashboard TCP 8443, but cloud/host firewall rules must restrict that port to the intern's approved source IP.
- A student's hardware, internet, disk or host administration policy can still prevent startup; the launcher reports the failing layer rather than declaring READY.

## Stop conditions

Do not use a workstation for cohort evidence when the toolkit cannot verify assigned-pod telemetry in the indexer, another pod appears, credentials/private keys are exposed, Wazuh administrative services are broadly exposed, real/production data appears or service instability is observed.
