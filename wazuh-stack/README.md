# NeoLabs Student Wazuh Stack

## Purpose

This directory provides the local Wazuh manager, indexer and dashboard used by authorised NeoLabs SOC Level 1 interns. The stack is pinned to Wazuh `4.14.7` / Docker tag `v4.14.7` and receives only synthetic telemetry authorised for the learner's server-assigned VCC pod.

For current programme/startup behaviour read [`../PROGRAMME_CURRENT_STATE.md`](../PROGRAMME_CURRENT_STATE.md). The old release-candidate/manual-enrolment workflow is no longer the normal student path.

## Recommended Windows path

Students normally do **not** enter this directory and manually perform every setup/enrolment step. From the toolkit root:

```text
START-NEOLABS-SOC.cmd
```

The launcher prepares/reuses the stack, authenticates to NeoLabs, connects the assigned LIVE/REPLAY surface, waits for service health, reloads current NeoLabs rules, proves assigned-pod telemetry is searchable in `wazuh-alerts-*`, reports freshness/retention/disk state, provisions Night Watch/Telemetry Health saved objects where supported, copies the local `admin` password to the Windows clipboard without printing it and opens the dashboard.

If anything is wrong:

```text
CHECK-NEOLABS-SOC.cmd
```

or:

```powershell
.\neolabs.cmd doctor
```

## Current readiness meaning

`SOC WORKSTATION READY` means more than containers are running. A real synthetic event for the current server-assigned pod must be present in the local telemetry path and searchable through the Wazuh indexer. If that proof fails, the launcher makes at most one bounded local repair attempt and does not falsely report READY.

## Dashboard login

Normal local URL:

```text
https://127.0.0.1:8443
```

Username is `admin`. The human dashboard password is the locally generated `WAZUH_INDEXER_PASSWORD` in the private `.env`; the Windows launcher copies it to the clipboard without printing it. The internal `wazuh-wui` and `kibanaserver` service passwords are separate and are not student login credentials.

## Current telemetry path

```text
VCC live/archive
→ NeoLabs authorised LIVE/REPLAY access
→ local vcc-events.ndjson
→ Wazuh manager JSON localfile input
→ NeoLabs VCC rules
→ Filebeat
→ Wazuh indexer wazuh-alerts-*
→ dashboard / Threat Hunting / saved views
```

Replay validates `synthetic=true`, assigned `pod_id`, required event fields and scenario scope before append. Original `event_time` is preserved; replay metadata is separate.

## Current NeoLabs rules

`config/rules/neolabs_vcc_rules.xml` includes training rules for:

- normal VCC baseline events (searchable in `wazuh-alerts-*`);
- authentication failures;
- repeated failures by account/source;
- successful authentication and success after failures;
- sensitive account changes;
- protected authorisation denials;
- telemetry quality/availability problems (`100150`).

Starter alerts are pivots, not automatic proof of compromise.

Startup explicitly restarts the Wazuh manager after asserting the stack so an existing installation loads the current rule file after `git pull`.

## Night Watch / Telemetry Health views

The current local provisioning script attempts to create:

- **NeoLabs — Operation Night Watch** — server-assigned pod baseline view with event type, identity, source, outcome, correlation/rule/original event-time fields;
- **NeoLabs — Telemetry Health** — rule `100150` / collection-parser-visibility troubleshooting view.

Saved-object provisioning is fail-soft. If a dashboard version/API rejects the import, Threat Hunting remains available and the Doctor reports the issue.

## Freshness and local retention

- Default telemetry freshness warning: **90 minutes**.
- Default local `wazuh-alerts-*` retention: **30 days**.
- Disk warning: **85%**; critical: **92%**.

Retention applies only to the intern's local alert indices. It does not delete VCC telemetry archives, approved evidence or server-side records and does not force-overwrite unrelated existing ISM policies.

## Workstation capacity

Run:

```bash
bash wazuh-stack/scripts/compatibility-check.sh
```

Current baseline:

| Requirement | Hard floor | Preferred | Recommended |
|---|---:|---:|---:|
| Linux/WSL2 visible memory | 7 GiB | 8 GiB | 12–16 GiB |
| CPU | 4 logical cores | 4 | 6+ |
| Free disk | 25 GiB | 25 GiB | 50 GiB |
| Compose | v2 | v2 | current supported v2 |
| `vm.max_map_count` | 262144 | 262144 | >=262144 |

Windows uses WSL2; Ubuntu specifically is **not** required. Kali, Debian and other current WSL2 distros are acceptable when Docker/Python/OpenSSL/curl are available. Git Bash/MSYS/Cygwin are not supported as the Wazuh runtime.

## Manual/advanced stack operations

These remain useful for troubleshooting/advanced non-Windows operation:

```bash
bash scripts/compatibility-check.sh
bash scripts/generate-local-secrets.sh
bash scripts/prepare-stack.sh
bash scripts/preflight.sh
bash scripts/start.sh
bash scripts/health-check.sh
bash scripts/verify-telemetry-pipeline.sh --wait 180
bash scripts/telemetry-freshness.sh
bash scripts/doctor.sh
```

Use `scripts/backup.sh`, `verify-backup.sh`, `restore.sh`, `stop.sh` and `reset.sh` only according to their warnings. Destructive reset is local-only and must not be used as a substitute for diagnosing a normal Week 1 telemetry issue.

## Private files

Never commit/share publicly:

- `.env`;
- NeoLabs Access Codes/session files;
- VCC private keys/certificates/private signed URLs;
- local Wazuh passwords;
- enrolment/runtime state;
- raw evidence containing real/private information or another pod's data;
- generated backups.

## Network/security design

- Dashboard binds to loopback by default.
- Indexer and Wazuh API are not published to the host for student use.
- Internal Wazuh components remain on the Compose internal network.
- Pod scope is server-managed, not selected through `POD_LABEL`/URL/query parameters.
- The collector/replay path rejects cross-pod/non-synthetic data.

## Troubleshooting order

Prefer `CHECK-NEOLABS-SOC.cmd` / `.\neolabs.cmd doctor`. For manual review, check: NeoLabs auth/runtime → raw VCC event file → manager localfile/rules (`wazuh-logtest`) → Filebeat → indexer → dashboard/time filter → freshness/telemetry-health events.

Full decision tree: [`../troubleshooting/WAZUH_SETUP_AND_TROUBLESHOOTING_GUIDE.md`](../troubleshooting/WAZUH_SETUP_AND_TROUBLESHOOTING_GUIDE.md).
