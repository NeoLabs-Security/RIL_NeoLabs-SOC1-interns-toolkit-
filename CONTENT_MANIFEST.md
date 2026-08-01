# Content Manifest

This file tracks the authoritative student-facing materials planned for the NeoLabs SOC Level 1 Toolkit.

| Material | Current source | Planned action | Repository status |
|---|---|---|---|
| Log Literacy Manual | Existing July 2026 manual | NeoLabs branding, editorial QA, source refresh and GitHub navigation | Source located; import pending |
| SecOps Foundations Notes | Uploaded research draft | Expand explanations, correct examples, add Wazuh-specific workflows, labs and references | Source located; rewrite in progress |
| Wazuh SOC L1 Handbook | Existing cloud-native handbook editions | Consolidate latest approved edition, update for current pinned release and VCC access model | Audit pending |
| Wazuh Dashboard Tutorials | Existing dashboard assignment plus new research | Build screenshot-led, task-oriented tutorials with version notes | Research pending |
| Query and Command Reference | New material | Create WQL, OpenSearch, jq, grep, journalctl, ausearch and PowerShell references | Research pending |
| Practice Labs | Existing concepts plus new material | Build progressive synthetic defensive investigations with instructor-separated answers | Design pending |
| Sample Logs | New material | Generate sanitised Windows, Sysmon, Linux, web, application, database and cloud datasets | Design pending |
| Incident Report Templates | Existing concepts plus new material | Create beginner and professional report variants | Draft pending |
| Evidence Log Templates | New material | Create evidence register, timeline and query-journal templates | Draft pending |
| Wazuh Setup and Troubleshooting | Existing handbook plus new code | Build tested local container deployment, health checks and troubleshooting decision trees | Scaffold in progress |

## Source handling

Original source files will be preserved under `source-materials/` where licensing and confidentiality permit. Student-facing Markdown and PDFs will be placed under `docs/`. Superseded or duplicate editions will be identified in `source-materials/SOURCE_REGISTER.md` rather than silently mixed.

## Publication rule

A material is marked **approved** only after technical review, branding review, reference verification, exercise validation and PDF/Markdown quality assurance.
