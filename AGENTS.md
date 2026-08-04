# AGENTS.md

## Repository purpose

This is the public, student-facing NeoLabs SOC Level 1 Intern Toolkit. It contains educational material, synthetic datasets, defensive practice labs, templates and a local Wazuh deployment wrapper.

## Non-negotiable boundaries

- Do not add mentor ground truth, hidden scenario answers or unreleased VCC vulnerabilities.
- Do not add real credentials, enrolment tokens, private certificates, private pod URLs, AWS identifiers or student personal information.
- Do not create functionality that grants students direct EC2, AWS console, database, host, private-network, container-runtime or mentor-dashboard access.
- Do not make a pod selectable by trusting a client-supplied `POD_ID` alone.
- Do not include offensive activity against public systems. Labs must use synthetic data or specifically authorised VCC targets.
- Do not silently change technical meaning when converting source documents. Record substantial editorial changes in the source manifest.

## Content standards

Every learning module should include:

1. learning objectives;
2. precise terminology with plain-language explanation;
3. worked examples;
4. analyst interpretation and limitations;
5. common mistakes;
6. a guided exercise or review questions;
7. references to authoritative sources;
8. a version and review date.

Prefer primary and authoritative sources: official Wazuh, NIST, CISA, MITRE ATT&CK, OWASP, Microsoft, AWS, OpenSearch, SigmaHQ and Docker documentation.

## Wazuh stack rules

- Pin image versions; do not use `latest`.
- Keep secrets outside version control.
- Expose only ports required by the approved deployment profile.
- Provide health checks, validation, backup and reset procedures.
- Pod enrolment must use a short-lived, single-use bootstrap token exchanged for a pod-scoped credential.
- The VCC Security Lab control plane, not the student, determines the final pod scope.
- Store issued credentials with restrictive filesystem permissions or Docker secrets.
- Never log raw tokens or private keys.

## Change workflow

- Work on a feature branch.
- Keep changes reviewable and document validation performed.
- Use pull requests; do not merge without maintainer review.
- Update `CONTENT_MANIFEST.md` when adding, replacing or superseding learning material.
