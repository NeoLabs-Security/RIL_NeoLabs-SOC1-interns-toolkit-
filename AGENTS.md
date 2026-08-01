# AGENTS.md — NeoLabs SOC Level 1 Intern Toolkit

## Mission

Build a beginner-to-intermediate SOC Level 1 toolkit that is technically accurate, evidence-led, accessible and safe for authorised defensive training.

## Repository boundaries

- This repository is student-facing and public. Never add private lab URLs, credentials, tokens, certificates, student personal information, mentor ground truth or unreleased scenario details.
- Official assignments and submissions belong in the separate central SOC Assignments repository.
- The VCC Security Lab repository owns the lab control plane, pod runtime and enrolment API.
- Students never receive direct host, EC2, AWS console, database, container-runtime or private-network access.

## Content rules

- Prefer official and primary sources.
- Preserve core terminology; explain it rather than replacing it with oversimplified language.
- Clearly distinguish observation, interpretation and conclusion.
- Use synthetic, sanitised or programme-generated examples only.
- Include limitations, alternative explanations and visibility gaps.
- Do not copy large copyrighted passages. Paraphrase and cite.
- Mark outdated or superseded material rather than silently merging conflicting editions.

## Wazuh rules

- Pin tested versions rather than using `latest`.
- Do not expose the indexer or Wazuh API publicly by default.
- Do not ship default passwords.
- Generate secrets locally and keep them outside Git.
- Treat pod enrolment tokens as short-lived, single-use credentials.
- A local configuration change to `POD_ID` must never be sufficient to access another pod.
- Pod authorisation must be enforced server-side by the VCC Security Lab enrolment and telemetry services.
- Active response is disabled by default for students unless a specific supervised lab enables a safe action.

## Development workflow

1. Work on a dedicated branch.
2. Add or update tests and validation scripts.
3. Run Markdown, secret, schema and shell checks.
4. Document assumptions and unresolved dependencies.
5. Open a reviewable pull request; do not self-merge.
