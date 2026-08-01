# Content Manifest

This file tracks the authoritative student-facing materials planned for the NeoLabs SOC Level 1 Toolkit.

| Material | Current source | Planned action | Repository status |
|---|---|---|---|
| Log Literacy Manual | Existing July 2026 manual | NeoLabs branding, editorial QA, source refresh and GitHub navigation | Source located; branded publication pending |
| SecOps Foundations Notes | Uploaded research draft | Expand explanations, correct examples, add Wazuh-specific workflows, labs and references | Modules 1–3 drafted; remaining modules pending |
| Wazuh SOC L1 Handbook | Existing cloud-native handbook editions | Consolidate latest approved edition, update for Wazuh 4.14.7 and VCC access model | Audit complete; rewrite in progress |
| Wazuh Dashboard Tutorials | Existing dashboard assignment plus new research | Build screenshot-led, task-oriented tutorials with version notes | Tutorial 1 drafted; screenshot QA and later tutorials pending |
| Query and Command Reference | New material | Create WQL, OpenSearch, jq, grep, journalctl, ausearch and PowerShell references | First comprehensive draft complete |
| Practice Labs | Existing concepts plus new material | Build progressive synthetic defensive investigations with instructor-separated answers | Lab 1 complete; later labs pending |
| Sample Logs | New material | Generate sanitised Windows, Sysmon, Linux, web, application, database and cloud datasets | Authentication dataset complete; later datasets pending |
| Incident Report Templates | Existing concepts plus new material | Create beginner and professional report variants | Initial professional template complete |
| Evidence Log Templates | New material | Create evidence register, timeline and query-journal templates | Evidence log and query journal complete |
| Wazuh Setup and Troubleshooting | Existing handbook plus new code | Build tested local container deployment, health checks and troubleshooting decision trees | Functional scaffold complete; isolated end-to-end rehearsal pending |

## Source handling

Original source files will be preserved under `source-materials/` where licensing and confidentiality permit. Student-facing Markdown and PDFs will be placed under `docs/`. Superseded or duplicate editions will be identified in `source-materials/SOURCE_REGISTER.md` rather than silently mixed.

## Publication rule

A material is marked **approved** only after technical review, branding review, reference verification, exercise validation and PDF/Markdown quality assurance.

## Current validation status

- Repository CI validates Python, shell syntax, XML, NDJSON, Docker Compose structure and credential-file boundaries.
- The VCC collector unit tests cover synthetic-event enforcement, required fields, cross-pod rejection, server-issued pod stability and the absence of a client pod selector.
- The local Wazuh stack is pinned to Wazuh 4.14.7 and a verified official Docker repository commit.
- Live certificate exchange, pod-isolation rehearsal, backup/restore testing and workstation compatibility remain required before the stack is labelled student-ready.
