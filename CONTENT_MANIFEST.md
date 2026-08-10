# Content Manifest

This file tracks the authoritative student-facing materials included in the NeoLabs SOC Level 1 Toolkit Version 1.

| Material | Version 1 scope | Repository status |
|---|---|---|
| Log Literacy and SIEM Foundations | Log purpose, event fields, SIEM pipelines, normalisation, data quality and investigation method | Integrated into the analyst handbook and query reference |
| SecOps Foundations | Eight beginner-to-intermediate modules from SOC fundamentals through capstone reporting | Complete for Version 1 |
| Wazuh SOC L1 Handbook | Wazuh 4.14.7 architecture, NeoLabs deployment model, setup, health, isolation, recovery and troubleshooting | Complete for Version 1 |
| Wazuh Dashboard Tutorial | Orientation, filters, alert-to-evidence pivots, timeline construction and reporting workflow | Complete for Version 1; screenshot-led exercises may be refreshed after rollout feedback |
| Query and Command Reference | WQL, OpenSearch, `jq`, `grep`, `journalctl`, `ausearch` and PowerShell investigation references | Complete for Version 1 |
| Practice Labs | Guided synthetic authentication investigation plus capstone method and assessment rubric | Complete for Version 1 baseline; later scenario packs are delivered through assignments |
| Sample Logs | Sanitised synthetic authentication dataset and schema requirements | Complete for Version 1 baseline |
| Incident Report Template | Professional investigation report structure with facts, analysis, confidence and recommendations | Complete |
| Evidence and Query Templates | Evidence register, timeline and reproducible query journal | Complete |
| Wazuh Setup and Troubleshooting | Pinned container topology, local-secret workflow, compatibility check, health checks, collector, reset, backup, verify and restore | Complete for Version 1 |
| VCC Enrolment Integration | Single-use token exchange, local key generation, client certificate, server-derived pod scope and revocation | End-to-end rehearsal passed; server control plane merged into VCC Security Lab `main` |
| NeoLabs Publications | Analyst handbook, Wazuh guide, template pack, lab pack and complete toolkit PDF | Automated build passed and artifacts reviewed |

## Source handling

Original source files are preserved under `source-materials/` where licensing and confidentiality permit. Student-facing Markdown remains in the documented repository directories. Superseded or duplicate editions are identified in `source-materials/SOURCE_REGISTER.md` rather than silently mixed.

## Publication rule

A material is marked **Version 1 complete** only after technical and safety review, reference/terminology review, exercise validation, Markdown validation, publication rendering where applicable, representative-page inspection, and credential/private-information boundary checks.

## Completed validation

- Repository CI validates Python, shell syntax, XML, NDJSON, Docker Compose structure, required publication inputs and credential-file boundaries.
- Collector unit tests cover synthetic-event enforcement, required fields, cross-pod rejection, server-issued pod stability and absence of a client pod selector.
- The local Wazuh stack is pinned to the approved Wazuh release rather than `latest`.
- Synthetic backup/restore rehearsal validates archive creation, checksums and restoration.
- Linux compatibility checks are automated; WSL2 and macOS requirements are documented.
- The private VCC Security Lab completed real CSR exchange, two-pod separation, single-use token denial, client pod-selector denial, credential revocation and assignment revocation.
- The branded publication workflow generated and validated the student PDF set.

## Release state

Version 1 is merged into `main` and is the student-facing SOC toolkit. The remaining cohort-launch actions are operational rather than missing repository implementation: each student must provide/run a suitable server, the operator must deploy the VCC control plane with real DNS/TLS/secrets, assign pods, issue short-lived enrolment tokens securely and verify the student's first synthetic telemetry event before scenario work begins.
