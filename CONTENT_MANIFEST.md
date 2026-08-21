# Content Manifest

This file tracks the authoritative student-facing material and operational tooling included in the current NeoLabs SOC Level 1 toolkit.

| Material | Current scope | Repository/programme status |
|---|---|---|
| Log Literacy and SIEM Foundations | log purpose, event fields, SIEM pipelines, normalisation, data quality and investigation method | Current |
| SecOps Foundations | eight beginner-to-intermediate modules from SOC fundamentals through reporting/capstone | Current |
| Wazuh SOC L1 Handbook | Wazuh 4.14.7 architecture, NeoLabs deployment, health, isolation, recovery and troubleshooting | Current |
| Wazuh Dashboard Tutorial | navigation, filters, alert-to-evidence pivots, timeline construction and reporting | Current |
| Query and Command Reference | WQL/OpenSearch concepts plus approved investigation references | Current |
| Practice Labs | guided synthetic authentication investigation plus staged scenario labs | Week 1 current; later labs assignment-controlled |
| Sample Logs | sanitised synthetic authentication dataset and schema requirements | Current baseline |
| Incident/Evidence Templates | facts, analysis, confidence, evidence register, timeline and query journal | Current |
| Windows SOC startup entry point | `START-NEOLABS-SOC.cmd` | Current root student startup/repair launcher |
| Linux/Ubuntu SOC startup entry point | `start-neolabs-soc.sh` | Current root student startup/repair launcher |
| Windows NeoLabs CLI entry point | `neolabs.cmd` | Current root CLI wrapper; delegates into WSL2 `python3 -m tools.cli` |
| Linux NeoLabs CLI entry point | `neolabs` | Current root CLI wrapper; runs `python3 -m tools.cli` from repository root |
| Windows implementation | WSL2/Docker Desktop/bootstrap/orchestration | Internal under `internal/windows/`; not a competing student setup path |
| Linux implementation | package/Docker/kernel/bootstrap/orchestration | Integrated into root Bash launcher; uses sudo only for OS-level work |
| VCC Access Integration | server-assigned pod, LIVE/replay selection, mTLS live path, signed replay ingestion and revocation | Active programme path |
| Telemetry-to-Dashboard Verification | real assigned-pod event must be searchable in `wazuh-alerts-*` before READY | Current and CI-contracted |
| Current-release client contract | bounded safe fast-forward, broker compatibility, release-generation state, readiness and pod+scenario verification | Current; version 1.2.0, reviewed 2026-08-21 |
| Night Watch Saved View | pod-scoped Week 1 view with identity/source/outcome/correlation/rule/event-time fields | Runtime-provisioned |
| Telemetry Health Saved View | rule `100150` collection/parser/visibility troubleshooting view | Runtime-provisioned |
| Freshness/Retention | 90-minute default freshness warning; 30-day local alert-index retention; 85%/92% disk warnings | Current defaults |
| NeoLabs Publications | analyst handbook, Wazuh guide, template/lab packs and combined reference PDFs | Automated build on `main` |

## Current student startup

Windows PowerShell:

```powershell
.\START-NEOLABS-SOC.cmd
```

Linux/Ubuntu:

```bash
bash start-neolabs-soc.sh
```

## Current student CLI

Windows PowerShell:

```powershell
.\neolabs.cmd status
.\neolabs.cmd doctor
```

Linux/Ubuntu:

```bash
bash neolabs status
bash neolabs doctor
```

Students no longer need to navigate into `tools/` for normal CLI use. The root wrappers preserve the supported `python3 -m tools.cli` module entrypoint.

The first run prepares missing prerequisites and Wazuh configuration. Subsequent runs safely check for toolkit updates and preserve/reuse the existing local Wazuh installation, history and credentials while refreshing and verifying the current server-authorised SOC release.

## Current programme state

- Production training topology is five isolated pods: `pod-01` through `pod-05`.
- Week 1 Operation Night Watch is the current HYBRID baseline week.
- Replay keeps authorised pod/scenario telemetry available when the main interactive VCC runtime is stopped.
- Normal VCC baseline events are searchable in `wazuh-alerts-*`.
- The toolkit verifies the complete local ingestion/rule/index path before READY.
- Later scenario content may be staged ahead of release but is not student authorisation.

See [`PROGRAMME_CURRENT_STATE.md`](PROGRAMME_CURRENT_STATE.md).

## Validation rule

CI covers Python/shell/XML/NDJSON/Compose checks, both startup launcher contracts, both root CLI wrapper contracts, internal Windows PowerShell syntax, root-layout hygiene, telemetry-to-dashboard contracts, backup/restore rehearsal, publication inputs and credential/private-file boundaries.

## Release state

The toolkit is active programme tooling. After initial setup, students run the platform root launcher; its safe update/version check removes the normal need for a manual weekly pull. Students do not start analysis until `SOC WORKSTATION READY` proves current assigned-pod/scenario telemetry is searchable.
