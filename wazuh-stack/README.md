# NeoLabs Student Wazuh Stack

## Purpose

This directory contains the local Wazuh 4.14.7 manager, indexer, dashboard, telemetry collector, rules and maintenance scripts used by authorised NeoLabs SOC Level 1 interns.

**This directory is an implementation/runtime directory, not the normal student start location.**

## Student entry points

From the repository root:

### Windows

```text
START-NEOLABS-SOC.cmd
```

### Linux / Ubuntu

```bash
bash start-neolabs-soc.sh
```

The platform launcher owns prerequisite installation, kernel configuration, first-run secret/config generation, Wazuh startup, NeoLabs authentication, telemetry connection, index verification and dashboard access. Students should not assemble a startup process by directly invoking scripts in this directory.

Diagnostics are also routed through the root launcher:

```text
Windows: START-NEOLABS-SOC.cmd doctor
Linux:   ./start-neolabs-soc.sh doctor
```

## Internal telemetry path

```text
VCC live/archive
→ authorised NeoLabs LIVE/REPLAY access
→ local vcc-events.ndjson
→ Wazuh manager JSON localfile input
→ NeoLabs VCC rules
→ Filebeat
→ Wazuh indexer wazuh-alerts-*
→ dashboard / Threat Hunting / saved views
```

Replay validates `synthetic=true`, assigned `pod_id`, required fields and scenario scope before append. Original `event_time` is preserved and replay metadata remains separate.

## READY contract

`SOC WORKSTATION READY` means a real synthetic event for the server-assigned pod has been processed and is searchable through the local Wazuh indexer. Container health alone is insufficient. If searchability initially fails, the root launcher permits only one bounded local repair attempt before refusing READY.

## Dashboard

After a successful start the launcher prints:

```text
Username:  admin
Password:  <locally generated WAZUH_INDEXER_PASSWORD>
```

On this machine:

```text
https://127.0.0.1:8443
```

From another device that can reach this host, use the `https://<host-ip>:8443` URL printed by the launcher. Internal `wazuh-wui`/`kibanaserver` credentials are separate service credentials, not the human login.

## Current NeoLabs rules

`config/rules/neolabs_vcc_rules.xml` includes training rules for normal VCC baseline events, authentication failures/repetition, successful authentication, success after failures, sensitive account changes, protected authorisation denials and telemetry-health problems (`100150`).

The base NeoLabs VCC rule produces searchable baseline documents, which is required for Operation Night Watch. Rule matches are investigation pivots, not automatic proof of malicious activity.

`start.sh` explicitly restarts the Wazuh manager after Compose assertion so updated bind-mounted NeoLabs rules are loaded after a toolkit update.

## Saved investigation views

Runtime provisioning attempts to create:

- **NeoLabs — Operation Night Watch** — assigned-pod baseline investigation view;
- **NeoLabs — Telemetry Health** — rule `100150` collection/parser/visibility troubleshooting view.

Saved-object provisioning is fail-soft; Threat Hunting remains available if local saved-object import fails.

## Freshness and local retention

- telemetry freshness warning default: **90 minutes**;
- local `wazuh-alerts-*` retention default: **30 days**;
- filesystem warning: **85%**;
- critical: **92%**.

These controls affect the student's local Wazuh data only; they do not delete VCC server-side telemetry/evidence.

## Workstation baseline

| Requirement | Hard floor | Preferred | Recommended |
|---|---:|---:|---:|
| Linux/WSL2-visible memory | 7 GiB | 8 GiB | 12–16 GiB |
| CPU | 4 logical cores | 4 | 6+ |
| Free disk | 25 GiB | 25 GiB | 50 GiB |
| Compose | v2 | v2 | current v2 |
| `vm.max_map_count` | 262144 | 262144 | >=262144 |

The root launchers now own the supported privilege changes required to reach these software/kernel prerequisites. `compatibility-check.sh` and `preflight.sh` deliberately remain read-only validation scripts and should not contain scattered `sudo` commands.

## Internal/mentor operations

The scripts below remain available for CI, recovery and advanced mentor troubleshooting, but are not student-facing setup choices:

```text
scripts/compatibility-check.sh
scripts/generate-local-secrets.sh
scripts/prepare-stack.sh
scripts/preflight.sh
scripts/start.sh
scripts/health-check.sh
scripts/prepare-telemetry-volume.sh
scripts/verify-telemetry-pipeline.sh
scripts/repair-telemetry-pipeline.sh
scripts/telemetry-freshness.sh
scripts/doctor.sh
scripts/backup.sh / verify-backup.sh / restore.sh
scripts/stop.sh / reset.sh
```

Do not add `sudo` to those runtime commands simply because Docker/kernel setup failed. Correct the platform setup through the root launcher. `reset.sh` is destructive local recovery and is not normal Week 1 troubleshooting.

## Shutdown recovery and reset behavior

After a host shutdown or power loss, rerun the repository-root platform launcher. It recovers the four-service stack and verifies the complete telemetry path; a manual `docker compose up` is not the supported readiness check.

For an intentional clean-install rehearsal, run this from a Linux or WSL terminal in the repository root:

```bash
cd wazuh-stack
bash ./scripts/reset.sh --confirm-destroy-local-data
cd ..
```

The reset removes local containers, named volumes/indexed data, saved objects, generated Wazuh configuration/certificates, collector state/telemetry and the local replay-fetch ledger. Removing the replay ledger with the telemetry volume ensures the next launch refetches authorised packs. It preserves `.env`, source and VCC enrolment by default.

The next root-launcher run recreates the stack. `prepare-telemetry-volume.sh` reapplies restrictive collector-write/manager-read permissions before collection begins, and READY remains fail-closed until an assigned-pod event is searchable.

Do not add `--include-enrolment` unless the VCC operator has revoked the old server-side credential and provided a fresh handoff. That option deletes local VCC credentials, certificates, assignment and enrolment state; it does not perform server-side revocation.

## Private files

Never commit/share `.env`, NeoLabs Access Codes/session files, VCC private keys/certificates/private signed URLs, local Wazuh passwords, enrolment/runtime state, generated backups or another pod's evidence.

## Network/security design

- Dashboard is published on every host interface (`WAZUH_DASHBOARD_BIND=0.0.0.0`) so another device can open it.
- Indexer and Wazuh API are not published for student network access.
- Internal components remain on the Compose internal network.
- Pod scope is server-managed.
- Collector/replay validation rejects wrong-pod/non-synthetic data.

Full troubleshooting guide: [`../troubleshooting/WAZUH_SETUP_AND_TROUBLESHOOTING_GUIDE.md`](../troubleshooting/WAZUH_SETUP_AND_TROUBLESHOOTING_GUIDE.md).
