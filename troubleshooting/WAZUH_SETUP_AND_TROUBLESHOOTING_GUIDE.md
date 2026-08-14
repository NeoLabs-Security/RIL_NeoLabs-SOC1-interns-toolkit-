# NeoLabs Wazuh Setup and Troubleshooting Guide

**Tested baseline:** Wazuh 4.14.7  
**Reconciled:** 2026-08-14  
**Scope:** learner-owned workstation + authorised synthetic VCC telemetry only

> Current Windows first response is `CHECK-NEOLABS-SOC.cmd` / `.\neolabs.cmd doctor`. Troubleshoot from the VCC source toward the dashboard and change one layer at a time.

## 1. Current golden path

```text
NeoLabs authentication / server assignment
→ current LIVE/REPLAY surface
→ raw assigned-pod VCC event file
→ Wazuh manager localfile input
→ NeoLabs Wazuh rule engine
→ Filebeat
→ Wazuh indexer (wazuh-alerts-*)
→ dashboard / saved views / time filters
```

The one-click launcher will not display `SOC WORKSTATION READY` unless the assigned-pod telemetry is actually searchable in the indexer.

## 2. Run Doctor first

### Windows

Double-click:

```text
CHECK-NEOLABS-SOC.cmd
```

or:

```powershell
.\neolabs.cmd doctor
```

Doctor prints PASS/WARN/FAIL by stage and reports the latest indexed VCC event freshness, local index size/disk state and dashboard reachability.

### Manual Linux/WSL inspection

From the toolkit root:

```bash
bash wazuh-stack/scripts/health-check.sh
bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --wait 180
bash wazuh-stack/scripts/telemetry-freshness.sh
bash wazuh-stack/scripts/doctor.sh
```

Record useful non-secret output in your query journal. Never post complete `.env`, Docker environment dumps, Access Codes, passwords, private keys/certificates or private signed URLs.

## 3. Docker/WSL problems

### Docker command/daemon unavailable

Check:

```bash
docker --version
docker compose version
docker info
```

On Windows, start Docker Desktop and confirm WSL integration for the distro in use. Do not expose an unauthenticated Docker TCP socket.

### Git Bash/MSYS/Cygwin

Do not run the Wazuh stack directly there. Use `START-NEOLABS-SOC.cmd`, which hands Linux work into WSL2.

### Memory/disk

Current hard memory floor is 7 GiB visible to Linux/WSL2; 8 GiB preferred; 12–16 GiB recommended. Free disk hard floor is 25 GiB; 50 GiB recommended.

Check:

```bash
docker stats --no-stream
docker system df
df -h
```

The toolkit also warns at 85% local indexer filesystem use and treats 92% as critical. Do not delete Wazuh volumes just to silence a disk warning without preserving required assignment evidence/backup.

### `vm.max_map_count`

Check:

```bash
cat /proc/sys/vm/max_map_count
```

Expected at least `262144` where the platform exposes this setting.

## 4. First-run/local configuration problems

The Windows launcher calls the supported setup path when `wazuh-stack/.env` is absent and preserves an existing `.env`. Do not regenerate local secrets simply because the repo was updated.

Manual advanced preparation uses the scripts under `wazuh-stack/scripts/`; follow `wazuh-stack/README.md` rather than an old copied command sequence.

The human Wazuh login is:

```text
Username: admin
Password source: local WAZUH_INDEXER_PASSWORD
```

The Windows launcher copies this password to the clipboard without printing it. `WAZUH_API_PASSWORD` and `WAZUH_DASHBOARD_PASSWORD` are internal service credentials and are not the human login.

## 5. NeoLabs authentication/runtime failures

Check:

```powershell
.\neolabs.cmd status
.\neolabs.cmd pod info
```

If the saved session is expired/rejected, run `.\neolabs.cmd login` with the assigned pod + private Access Code. The pod supplied at login is only a confirmation value; server assignment remains authoritative.

Do not edit runtime files to reach another pod and do not manually replace the normal gateway URL using an old onboarding message.

## 6. Replay/live telemetry not arriving

Run Doctor. Then verify:

- server state is a valid SOC surface (`LIVE`, `REPLAY`, applicable cloud/endpoint state);
- raw telemetry contains synthetic records for the assigned pod;
- replay pack validation did not reject pod/scenario/event fields;
- in LIVE mode, the protected collector/enrolment state is current;
- internet/TLS connectivity is available.

Replay preserves original `event_time`. Do not treat replay time as the incident timeline.

## 7. Raw events exist but Wazuh has no alerts

The manager must monitor `/var/ossec/logs/vcc/vcc-events.ndjson` as JSON and load `config/rules/neolabs_vcc_rules.xml`.

The normal startup path restarts the manager after asserting the stack so the current NeoLabs rules are loaded after `git pull`.

Use `wazuh-logtest` through the verifier/Doctor before editing decoders/rules. The NeoLabs base VCC rule is intentionally searchable so normal Week 1 baseline events can reach `wazuh-alerts-*`.

Do not change rule levels broadly merely to make a dashboard look busy.

## 8. Filebeat/indexer problems

Symptoms include raw events/rule matches but no `wazuh-alerts-*` documents, dashboard index errors or indexer health failures.

Check Doctor and service logs. Verify the indexer is healthy before changing mappings/policies. Local retention is deliberately scoped to `wazuh-alerts-*`; unrelated ISM policies are not force-overridden.

If the disk is near watermarks, preserve/submit required evidence first, then follow mentor-approved local cleanup/retention guidance rather than deleting volumes blindly.

## 9. Dashboard opens but data looks empty

Before concluding “no events”:

1. confirm Doctor/indexer PASS;
2. check `Last VCC event indexed` freshness;
3. confirm the assigned `pod_id` filter;
4. use `wazuh-alerts-*` / Threat Hunting or the **NeoLabs — Operation Night Watch** view;
5. set an appropriate/absolute UTC time range around the source event times;
6. inspect the **NeoLabs — Telemetry Health** view/rule `100150` for collection/parser/visibility issues.

A zero-result query is evidence only after source health and time/filter assumptions are verified.

## 10. Saved Night Watch/Telemetry Health views missing

Saved-object provisioning is fail-soft. The telemetry/indexer can be healthy even if the dashboard API rejects an import on a particular local version/state.

Run Doctor and continue through Threat Hunting if needed. Do not reset the Wazuh data/indexer merely because a saved view is absent.

## 11. Safe bounded repair

The one-click launcher/repair tooling may reassert local services and, in replay mode, refetch authorised replay state once. It does **not** reset the VCC server, switch pods, delete Wazuh volumes or fetch another student's data.

If one bounded repair still cannot prove assigned-pod telemetry is searchable, stop relying on that workstation for assignment conclusions and send the Doctor output (redacted) to the mentor.

## 12. Dashboard certificate/browser warning

The local dashboard uses local TLS. Verify you are opening the expected loopback URL (`https://127.0.0.1:8443` by default) from your own workstation. Never work around a certificate warning by exposing the dashboard on a public interface.

## 13. Backups/resets

Use the documented backup/verify/restore scripts before destructive local changes. `reset.sh --confirm-destroy-local-data` destroys local Wazuh state; it is not normal troubleshooting. Removing local VCC credential files does not by itself revoke server-side assignment/credentials.

## 14. Evidence to send a mentor

Useful redacted evidence:

- Doctor PASS/WARN/FAIL lines;
- current assigned pod/scenario/runtime state without Access Code/token;
- latest event freshness;
- `docker compose ps` status;
- small relevant service-log excerpts;
- event/rule IDs or a screenshot showing the failing dashboard stage.

Never send `.env`, copied admin password, Access Code, session token, private key/certificate contents or another pod's data.

## 15. Stop conditions

Stop and escalate on cross-pod events/access, real personal/production data, exposed credentials/private keys, unexpected infrastructure access, external-target traffic or service instability. Do not weaken isolation/security controls to make a troubleshooting check pass.
