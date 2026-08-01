# NeoLabs Student Wazuh Stack

## Purpose

This directory provides a repeatable local Wazuh manager, indexer and dashboard for authorised NeoLabs SOC Level 1 training. A separate hardened collector can receive only the synthetic telemetry issued to the learner's assigned VCC pod.

The baseline follows the official Wazuh single-node container topology and pins:

- Wazuh release `4.14.7`;
- official Docker tag `v4.14.7`;
- verified upstream commit `adcc5b57d2f7edfcbe6c399272dc76fbdf12b623`.

Changing the version requires release-note review, regenerated configuration, rule tests, Compose validation and a new recorded review date.

## Current status

The stack is a reviewed **Version 1 release candidate** on the toolkit feature branch. The local manager, indexer, dashboard, collector, enrolment client, health checks, reset controls, backup/restore workflow, compatibility assessment, starter rules and CI tests are implemented.

The corresponding isolated VCC control-plane rehearsal passed:

- certificate-signing request exchange;
- single-use bootstrap-token enforcement;
- two separate intern-to-pod assignments;
- server-enforced pod isolation;
- rejection of client-selected pod scope;
- credential revocation;
- assignment revocation.

The repository also passes collector unit tests, Compose validation, secret-boundary checks and a synthetic Docker-volume backup/restore rehearsal. Automated workstation validation runs on Linux CI. WSL2 and macOS deployment profiles are documented in [`../docs/setup/WORKSTATION_COMPATIBILITY.md`](../docs/setup/WORKSTATION_COMPATIBILITY.md), but should still be checked on the actual cohort machines during controlled rollout.

This branch has not been merged or deployed. Students should use it only after NeoLabs operator approval and receipt of their individual enrolment details.

## Required workstation capacity

Run the automated assessment first:

```bash
bash scripts/compatibility-check.sh
```

For the all-in-one Wazuh topology, plan for approximately:

- 4 CPU cores;
- 8 GiB RAM minimum, with 12–16 GiB recommended;
- 25 GiB free storage minimum, with 50 GiB recommended;
- Docker Engine or Docker Desktop with Compose v2;
- Linux, WSL2 or a reviewed Docker Desktop environment;
- `vm.max_map_count` of at least `262144` where the host exposes that setting;
- Python 3, OpenSSL and curl.

Smaller systems may start but can become unstable or too slow for investigations.

## Security design

### Network exposure

- The Wazuh indexer is not published to the host.
- The Wazuh server API is not published to the host.
- The dashboard binds to `127.0.0.1:8443` by default.
- Wazuh components use an internal-only Compose network.
- Only the VCC telemetry collector receives an outbound network path.

### Pod isolation

The learner does not choose an authorised pod by editing `POD_LABEL`, a URL or a request parameter.

1. A programme operator records the intern-to-pod assignment in the VCC control plane.
2. The operator issues a short-lived, single-use bootstrap token.
3. The enrolment client creates a local private key and sends only a certificate signing request.
4. The control plane consumes the token and issues a client certificate bound to the recorded assignment.
5. Nginx verifies the client certificate for every telemetry request.
6. The control plane derives pod scope from the active certificate and assignment.
7. The collector rejects any event whose `pod_id` differs from the server-issued pod.
8. Reassignment requires server-side revocation and explicit local re-enrolment.

A shared pod password is intentionally not used.

## Files that must remain private

Never commit or send through a public channel:

- `.env`;
- bootstrap token files;
- `secrets/vcc/client.key`;
- issued client certificates when programme policy treats them as confidential;
- VCC private URLs;
- `state/enrolment.json`;
- raw evidence containing personal information or another pod's data;
- generated backups.

The operator-issued enrolment CA certificate is public-key material, but it must still be delivered through an approved channel so the learner can verify that it belongs to the real VCC lab.

## Setup workflow

Run commands from `wazuh-stack/`.

### 1. Check the workstation

```bash
bash scripts/compatibility-check.sh
```

Resolve every failure before continuing. Platform-specific guidance is available in [`../docs/setup/WORKSTATION_COMPATIBILITY.md`](../docs/setup/WORKSTATION_COMPATIBILITY.md).

### 2. Generate local secrets

```bash
bash scripts/generate-local-secrets.sh
```

This creates `.env`, an installation identifier and protected local directories. Password values are not printed.

### 3. Configure the enrolment endpoint

The operator supplies:

- the HTTPS enrolment base URL;
- the VCC enrolment CA certificate;
- a short-lived bootstrap token file when the intern is ready to enrol.

Place the CA at:

```text
secrets/vcc/enrolment-ca.crt
```

Set the operator-provided URL in `.env`:

```text
VCC_ENROLMENT_BASE_URL=https://soc.lab.example.invalid:8443
```

Do not add a pod ID to this URL.

### 4. Prepare the pinned Wazuh configuration

```bash
bash scripts/prepare-stack.sh
```

The script:

- clones the official `wazuh/wazuh-docker` repository into ignored local state;
- checks out the exact pinned tag;
- verifies the full expected commit SHA;
- copies the official single-node configuration;
- generates local indexer password hashes;
- generates the Wazuh TLS certificate set;
- adds the NeoLabs VCC NDJSON input configuration.

No Wazuh service is started by this step.

### 5. Run preflight validation

```bash
bash scripts/preflight.sh
```

Preflight checks Docker, Compose, local file permissions, placeholder passwords, pinned versions, dashboard binding, memory guidance and `vm.max_map_count` where available.

### 6. Enrol to the assigned VCC pod

Protect the operator-issued token file:

```bash
chmod 600 /path/to/bootstrap-token.txt
```

Then run:

```bash
bash scripts/enrol-vcc.sh --token-file /path/to/bootstrap-token.txt
```

The client does not send a learner-selected pod. It stores the server-issued pod and credential metadata locally without printing private key or certificate contents.

### 7. Start and validate the stack

```bash
bash scripts/start.sh
```

The startup script validates the generated files, checks the Compose model, builds the collector, starts services and waits for health checks.

View current health later with:

```bash
bash scripts/health-check.sh
```

The collector is considered healthy while waiting for enrolment, but Wazuh will not receive VCC telemetry until valid credentials and an endpoint exist.

### 8. Back up local Wazuh data

```bash
bash scripts/backup.sh
```

The stack is stopped briefly for a consistent archive and restarted afterward. Backups exclude `.env`, VCC tokens, private keys, certificates and private endpoints. Verify a backup with:

```bash
bash scripts/verify-backup.sh /path/to/backup
```

The complete recovery procedure is documented in [`../docs/setup/BACKUP_AND_RECOVERY.md`](../docs/setup/BACKUP_AND_RECOVERY.md).

### 9. Stop without deleting data

```bash
bash scripts/stop.sh
```

This retains Wazuh volumes, local telemetry and enrolment credentials.

### 10. Restore local Wazuh data

Stop the stack, verify the selected backup and restore only after confirming the destructive replacement:

```bash
bash scripts/restore.sh /path/to/backup --force
```

Credential material is intentionally not restored. Complete a new operator-approved enrolment after recovery.

### 11. Destructive local reset

Review the warning first:

```bash
bash scripts/reset.sh
```

To delete local Wazuh data and generated configuration:

```bash
bash scripts/reset.sh --confirm-destroy-local-data
```

Removing enrolment material additionally requires confirmed server-side revocation:

```bash
bash scripts/reset.sh --confirm-destroy-local-data --include-enrolment
```

Deleting local certificate files alone does not revoke the server credential.

## VCC telemetry format

The collector accepts newline-delimited JSON and requires at least:

```json
{
  "schema_version": "1.0",
  "event_id": "evt-example-001",
  "event_time": "2026-08-01T09:14:21Z",
  "pod_id": "pod-03",
  "event_type": "authentication",
  "synthetic": true
}
```

The collector fails closed when:

- the event is not marked synthetic;
- required fields are missing;
- an event carries a different pod from the server-issued response header;
- the server-issued pod changes without credential reset;
- TLS verification fails;
- the response exceeds the configured size or event-count limit.

## Initial NeoLabs rules

`config/rules/neolabs_vcc_rules.xml` contains training detections for:

- authentication failure;
- repeated failures by account;
- repeated failures by source;
- successful authentication;
- success following earlier failures;
- sensitive account changes;
- protected access-control denials;
- telemetry quality and availability problems.

These are starter rules, not proof of compromise. Analysts must inspect the underlying records, context and visibility limitations.

## Troubleshooting order

When events are missing, check in this order:

1. local Compose and container health;
2. enrolment state and certificate expiry;
3. collector health JSON and cursor movement;
4. HTTPS/mTLS connectivity without printing secrets;
5. presence of records in the shared `vcc_telemetry` volume;
6. Wazuh manager file monitoring;
7. JSON decoding and required fields;
8. rule loading and `wazuh-logtest` validation;
9. indexer health and dashboard time filters.

Use [`../troubleshooting/WAZUH_SETUP_AND_TROUBLESHOOTING_GUIDE.md`](../troubleshooting/WAZUH_SETUP_AND_TROUBLESHOOTING_GUIDE.md) for the full decision tree.

## References

- Official Wazuh documentation and `wazuh/wazuh-docker` release repository.
- Docker Compose and Docker Engine security documentation.
- [`../research/AUTHORITATIVE_SOURCE_REGISTER.md`](../research/AUTHORITATIVE_SOURCE_REGISTER.md).
- VCC control-plane architecture and implementation in the private VCC Security Lab repository.
