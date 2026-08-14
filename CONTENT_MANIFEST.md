# Content Manifest

This file tracks the authoritative student-facing material and operational tooling included in the current NeoLabs SOC Level 1 toolkit.

| Material | Current scope | Repository/programme status |
|---|---|---|
| Log Literacy and SIEM Foundations | log purpose, event fields, SIEM pipelines, normalisation, data quality and investigation method | Current |
| SecOps Foundations | eight beginner-to-intermediate modules from SOC fundamentals through reporting/capstone | Current |
| Wazuh SOC L1 Handbook | Wazuh 4.14.7 architecture, NeoLabs deployment, setup, health, isolation, recovery and troubleshooting | Current |
| Wazuh Dashboard Tutorial | navigation, filters, alert-to-evidence pivots, timeline construction and reporting | Current; Night Watch/Telemetry Health saved objects are provisioned by the workstation tooling |
| Query and Command Reference | WQL/OpenSearch concepts plus approved CLI investigation references | Current |
| Practice Labs | guided synthetic authentication investigation plus staged scenario labs | Week 1 current; later labs are released only with their weekly assignment |
| Sample Logs | sanitised synthetic authentication dataset and schema requirements | Current baseline |
| Incident/Evidence Templates | facts, analysis, confidence, evidence register, timeline and query journal | Current |
| Wazuh Setup/Troubleshooting | one-click Windows launch, WSL2, health, doctor, retention, backup/restore and bounded repair | Current |
| VCC Access Integration | server-assigned pod, LIVE/replay selection, mTLS live path, signed replay ingestion and revocation | Deployed programme path; students do not select another pod |
| Telemetry-to-Dashboard Verification | real assigned-pod event must be searchable in `wazuh-alerts-*` before READY | Current and CI-contracted |
| Night Watch Saved View | pod-scoped Week 1 view with identity/source/outcome/correlation/rule/event-time fields | Runtime-provisioned on each local Wazuh workstation |
| Telemetry Health Saved View | rule `100150` collector/parser/visibility troubleshooting view | Runtime-provisioned on each local Wazuh workstation |
| Freshness/Retention | 90-minute default freshness warning; 30-day local alert-index retention; 85%/92% disk warnings | Current defaults; server-side VCC archives are unaffected |
| NeoLabs Publications | analyst handbook, Wazuh guide, template/lab packs and combined reference PDFs | Automated build on `main` |

## Current student startup

Windows students normally use `START-NEOLABS-SOC.cmd`. `CHECK-NEOLABS-SOC.cmd` / `.\neolabs.cmd doctor` is the standard diagnostic path. The normal local dashboard is `https://127.0.0.1:8443`; username is `admin`, with the locally generated password copied to the Windows clipboard without being printed.

Older instructions requiring a global `pip install`, a manually entered gateway URL or a separately provided always-on Wazuh server are superseded by the current local WSL2/Docker workstation model.

## Current programme state

- Production training topology is five isolated pods: `pod-01` through `pod-05`.
- Week 1 Operation Night Watch is the current assignment and is a HYBRID baseline week.
- The VCC Replay Gateway keeps authorised pod/scenario telemetry available when the main interactive VCC runtime is stopped.
- Normal NeoLabs VCC baseline events are indexed into `wazuh-alerts-*` so Threat Hunting can show Week 1 activity.
- The toolkit verifies the complete local ingestion/rule/index path before declaring the workstation ready.
- Later scenario content may be staged ahead of release but is not student authorisation by itself.

See [`PROGRAMME_CURRENT_STATE.md`](PROGRAMME_CURRENT_STATE.md) for the cross-week operational summary.

## Source handling

Original source files are preserved under `source-materials/` where licensing/confidentiality permit. Student-facing Markdown remains in documented repository directories. Superseded/duplicate editions are identified in `source-materials/SOURCE_REGISTER.md` rather than silently mixed.

## Publication/validation rule

Student material is considered current only after technical/safety review, terminology/reference review, exercise validation where applicable, Markdown/source checks, publication rendering where applicable and credential/private-information boundary checks.

Repository CI covers Python/shell/XML/NDJSON/Compose source checks, telemetry-to-dashboard contracts, Windows launcher contracts, backup/restore rehearsal, publication inputs and credential-file boundaries.

## Release state

The toolkit is on `main` and in active programme use. Remaining student-specific actions are local/operational: pull the latest toolkit, run the current launcher, authenticate with the assigned pod + private Access Code, and do not start analysis until the workstation verifies assigned-pod telemetry is searchable.
