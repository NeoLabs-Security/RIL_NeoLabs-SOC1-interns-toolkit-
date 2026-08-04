# Content Manifest

This file tracks the authoritative student-facing materials included in the NeoLabs SOC Level 1 Toolkit Version 1 release candidate.

| Material | Version 1 scope | Repository status |
|---|---|---|
| Log Literacy and SIEM Foundations | Log purpose, event fields, SIEM pipelines, normalisation, data quality and investigation method | Integrated into the analyst handbook and query reference |
| SecOps Foundations | Eight beginner-to-intermediate modules from SOC fundamentals through capstone reporting | Complete for Version 1 |
| Wazuh SOC L1 Handbook | Wazuh 4.14.7 architecture, NeoLabs deployment model, setup, health, isolation, recovery and troubleshooting | Complete for Version 1 |
| Wazuh Dashboard Tutorial | Orientation, filters, alert-to-evidence pivots, timeline construction and reporting workflow | Complete for Version 1; additional screenshot-led exercises may be added after rollout feedback |
| Query and Command Reference | WQL, OpenSearch, `jq`, `grep`, `journalctl`, `ausearch` and PowerShell investigation references | Complete for Version 1 |
| Practice Labs | Guided synthetic authentication investigation plus capstone method and assessment rubric | Complete for Version 1; later scenario packs are planned as post-release expansion |
| Sample Logs | Sanitised synthetic authentication dataset and schema requirements | Complete for Version 1 baseline; later endpoint, web and cloud datasets are planned as expansion |
| Incident Report Template | Professional investigation report structure with facts, analysis, confidence and recommendations | Complete |
| Evidence and Query Templates | Evidence register, timeline and reproducible query journal | Complete |
| Wazuh Setup and Troubleshooting | Pinned container topology, local-secret workflow, compatibility check, health checks, collector, reset, backup, verify and restore | Complete for Version 1 |
| VCC Enrolment Integration | Single-use token exchange, local key generation, client certificate, server-derived pod scope and revocation | Isolated end-to-end rehearsal passed |
| NeoLabs Publications | Analyst handbook, Wazuh guide, template pack, lab pack and complete toolkit PDF | Automated build passed and artifacts reviewed |

## Source handling

Original source files are preserved under `source-materials/` where licensing and confidentiality permit. Student-facing Markdown remains in the documented repository directories. Superseded or duplicate editions are identified in `source-materials/SOURCE_REGISTER.md` rather than silently mixed.

The current publication system uses a self-contained NeoLabs text wordmark. No external font or unofficial graphical-logo file is committed. An approved official logo may replace the wordmark during a later visual-brand update without changing the technical content.

## Publication rule

A material is marked **Version 1 complete** only after:

- technical and safety review;
- reference and terminology review;
- exercise or fixture validation;
- Markdown structure validation;
- branded PDF rendering;
- representative-page visual inspection;
- credential and private-information boundary checks.

Generated PDFs are workflow artifacts. They should be released to interns only from a reviewed commit or tagged version.

## Completed validation

- Repository CI validates Python, shell syntax, XML, NDJSON, Docker Compose structure, required publication inputs and credential-file boundaries.
- Collector unit tests cover synthetic-event enforcement, required fields, cross-pod rejection, server-issued pod stability and absence of a client pod selector.
- The local Wazuh stack is pinned to Wazuh 4.14.7 and a verified official Docker repository commit.
- A synthetic Docker-volume rehearsal verifies backup creation, checksums, deletion, recreation and restoration.
- Automated Linux compatibility validation exercises the workstation checker; WSL2 and macOS requirements are documented for controlled cohort-machine checks.
- The private VCC Security Lab CI completed real CSR exchange, two-pod separation, single-use token denial, client pod-selector denial, credential revocation and assignment revocation.
- The branded publication workflow generated five non-empty PDFs and uploaded them as CI artifacts.

## Release state

The feature branch is a Version 1 release candidate. It is not yet merged into `main`, deployed to the internship environment or used to issue real cohort credentials. Those remain operator-controlled release steps rather than unfinished repository implementation.
