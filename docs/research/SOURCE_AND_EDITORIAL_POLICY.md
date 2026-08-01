# Source and Editorial Policy

## Purpose

NeoLabs learning materials must be understandable to a new analyst without removing the professional terminology they will encounter in a real SOC.

## Preferred sources

Use primary or authoritative public literature wherever possible:

1. Wazuh official documentation and official release repositories.
2. NIST Cybersecurity Framework, incident-response and log-management publications.
3. CISA and recognised national cyber-security guidance.
4. MITRE ATT&CK official knowledge base.
5. OWASP official projects and standards.
6. Microsoft Learn and Sysinternals documentation for Windows and Sysmon.
7. AWS official documentation for CloudTrail, VPC Flow Logs, IAM and related telemetry.
8. OpenSearch official documentation.
9. SigmaHQ official specification and rule guidance.
10. Docker official documentation.

Community sources may be used to identify practical problems, but technical claims must be checked against an authoritative source before publication.

## Writing standard

Each technical term is introduced in three layers:

- **Definition:** the correct professional meaning;
- **Plain-language explanation:** what it means operationally;
- **Worked example:** how an analyst sees and uses it.

Do not replace terms such as *normalisation*, *correlation*, *decoder*, *index*, *false positive* or *confidence* with vague substitutes. Explain them and continue using the correct term.

## Evidence discipline

Learning material must distinguish:

- what an event directly proves;
- what it suggests when combined with context;
- what remains unknown;
- which additional telemetry would reduce uncertainty.

## Version-sensitive content

Dashboard labels, Wazuh configuration fields, ports, query behaviour and container images must state the tested version. Screenshots must be marked when navigation can differ between releases.

## Examples and datasets

All examples must be synthetic, documentation-reserved or sanitised. Use reserved example IP ranges and domains. Do not publish real student or VCC infrastructure details.

## Review record

Every completed module must include:

- document version;
- review date;
- tested software version where applicable;
- authoritative references;
- reviewer or review status;
- known limitations.
