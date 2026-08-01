# NeoLabs Student Wazuh Stack

## Goal

Provide each SOC Level 1 intern with a repeatable local Wazuh manager, indexer and dashboard deployment that can receive only the telemetry authorised for that learner's assigned VCC pod.

The implementation will follow the official Wazuh single-node container topology and pin the tested Wazuh release. NeoLabs wrapper files will replace example passwords, limit exposed services, add validation and integrate the VCC pod-enrolment workflow.

## Planned workflow

```text
Clone toolkit
  -> copy .env.example to .env
  -> run preflight validation
  -> generate local secrets and certificates
  -> start the Wazuh stack
  -> verify manager, indexer and dashboard health
  -> enrol with a short-lived VCC token
  -> receive a pod-scoped telemetry credential
  -> verify the assigned pod identity
  -> begin authorised monitoring
```

## Pod isolation rule

The learner will not select a trusted pod merely by editing a local variable. A local `POD_LABEL` may be shown for usability, but the VCC control plane determines the effective pod from the learner's enrolment record. The issued credential is bound to that pod and cannot request another pod's stream.

## Credential model

1. An operator assigns an intern to a pod.
2. The VCC enrolment service creates a random, short-lived, single-use bootstrap token.
3. The local enrolment client sends the token over HTTPS together with a generated public key and a client installation identifier.
4. The service consumes the token and returns a pod-scoped client certificate or equivalent narrow credential plus the approved telemetry endpoint and CA chain.
5. The credential is stored outside Git with restrictive permissions.
6. Reassignment requires operator revocation and a new enrolment.

Plain shared pod passwords are not acceptable because they are easy to copy, share and reuse.

## Student-facing commands planned

```text
./scripts/preflight.sh
./scripts/generate-local-secrets.sh
docker compose up -d
./scripts/health-check.sh
./scripts/enrol-vcc.sh --token-file <path>
./scripts/verify-pod-scope.sh
./scripts/backup.sh
./scripts/reset.sh
```

## Security requirements

- Pin container image versions.
- Never use example Wazuh passwords.
- Do not expose the indexer or Wazuh API publicly by default.
- Use TLS for dashboard, enrolment and telemetry connections.
- Do not print tokens, private keys or complete credentials in logs.
- Refuse startup when required secrets are missing or still use documented placeholders.
- Validate that credential files are not group- or world-readable.
- Provide revocation, reset and re-enrolment instructions.
- Keep VCC infrastructure details out of this public repository.

## Status

Foundation design only. The complete compose files, certificate workflow, enrolment client, health checks and integration tests will be added and tested in subsequent commits before the stack is marked student-ready.
