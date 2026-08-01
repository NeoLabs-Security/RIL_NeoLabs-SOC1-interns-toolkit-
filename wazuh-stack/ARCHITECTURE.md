# Containerised Wazuh Architecture

## Purpose

Provide each SOC intern with a locally controlled Wazuh single-node learning environment that can be securely connected to only the telemetry feed for the intern's assigned VCC Security Lab pod.

## Local components

The supported stack will pin an approved Wazuh release and include:

- Wazuh manager;
- Wazuh indexer;
- Wazuh dashboard;
- certificate-generation workflow;
- enrolment client;
- health-check and diagnostics scripts;
- backup, reset and clean-uninstall scripts;
- NeoLabs dashboard branding where technically supported.

The local stack does not contain VCC pod credentials in the repository. Secrets are generated or issued at runtime and stored outside Git.

## Network exposure defaults

- Dashboard: bound to localhost by default.
- Wazuh API: internal Docker network only.
- Indexer: internal Docker network only.
- Agent-enrolment and event-ingestion ports: exposed only when required for a supervised local endpoint lab.
- VCC telemetry connection: outbound HTTPS or mutually authenticated TLS through the approved gateway.

## Pod-scoped enrolment

```text
Intern setup client
        |
        | one-time enrolment token over HTTPS
        v
VCC enrolment API on the Security Lab control plane
        |
        | validates intern, cohort and assigned pod
        v
Revocable pod-scoped credential and signed configuration
        |
        v
Local telemetry connector
        |
        | authenticated connection
        v
VCC telemetry gateway -> assigned pod feed only
```

## Trust rules

1. `POD_ID` supplied by an intern is descriptive, not authoritative.
2. The control plane derives the permitted pod from the server-side assignment record.
3. Enrolment tokens are short-lived, single-use and stored hashed at rest.
4. Issued credentials are revocable and contain or reference the assigned pod, intern and cohort.
5. The telemetry gateway validates the credential for every session.
6. Cross-pod requests are denied and written to an audit log.
7. Reassignment requires operator action and revocation of the prior credential.
8. No production environment, credentials or telemetry is reachable from this flow.

## Initial implementation stages

1. Import and harden the official Wazuh single-node Docker structure.
2. Replace published example passwords with generated secrets.
3. Restrict service exposure and add startup validation.
4. Implement a mock enrolment service for local integration tests.
5. Implement the real enrolment API and telemetry gateway changes in `NeoLabs-Security/VCC-Security-Lab`.
6. Test correct-pod enrolment, altered `POD_ID`, token replay, expired token, revoked credential and cross-pod access.
7. Publish only after mentor rehearsal in the isolated lab environment.

## Safety default

Active response is disabled for student deployments unless a supervised exercise explicitly enables a bounded, reversible action. The first release focuses on monitoring, investigation, evidence handling and escalation.
