# NeoLabs Wazuh Setup and Troubleshooting Guide

**Tested baseline:** Wazuh 4.14.7  
**Reconciled:** 2026-08-14  
**Scope:** learner-owned workstation + authorised synthetic VCC telemetry only

## 1. Start with the platform root launcher

Windows:

```text
START-NEOLABS-SOC.cmd doctor
```

Linux/Ubuntu:

```bash
./start-neolabs-soc.sh doctor
```

Do not start troubleshooting by running random files in `wazuh-stack/scripts/` or by adding `sudo` to a command that failed. The root launchers own supported prerequisite installation and privilege changes; the lower-level Wazuh scripts are intentionally runtime/validation components.

## 2. Golden path

```text
NeoLabs authentication / server assignment
→ current LIVE/REPLAY surface
→ raw assigned-pod VCC event file
→ Wazuh manager localfile input
→ NeoLabs Wazuh rules
→ Filebeat
→ Wazuh indexer (wazuh-alerts-*)
→ dashboard / saved views / time filters
```

`SOC WORKSTATION READY` is displayed only after assigned-pod telemetry is actually searchable in the indexer.

## 3. First-run prerequisite problems

### Windows

Rerun `START-NEOLABS-SOC.cmd` after resolving the exact state it reports. The launcher handles supported WSL2/Docker Desktop/bootstrap work. Legitimate one-time interruptions include a Windows restart after enabling WSL, launching a newly installed Linux distro once to create its Linux user, or resolving a Docker Desktop first-run/virtualisation/update prompt.

Do not run the Wazuh stack from Git Bash/MSYS/Cygwin.

### Linux / Ubuntu

Run the launcher as the normal user:

```bash
bash start-neolabs-soc.sh
```

Do **not** run `sudo ./start-neolabs-soc.sh`. The launcher invokes `sudo` itself only for package installation, Docker service/group setup and kernel configuration.

On Ubuntu/Debian the launcher can install Docker Engine + Compose v2 when missing. If it adds the user to the Docker group, it attempts to refresh that group context immediately; where the shell cannot do so, log out/in once and rerun the same root launcher.

## 4. Docker problems

Useful mentor/advanced checks:

```bash
docker --version
docker compose version
docker info
```

On Windows, Docker must be the Linux engine and reachable from the same WSL2 distro used by the toolkit. On native Linux, the normal user must be able to run `docker info` without prefixing every Wazuh command with `sudo`.

Never expose an unauthenticated Docker TCP socket to solve a permissions problem.

## 5. Memory, disk and indexer kernel requirement

Current workstation baseline:

- 7 GiB Linux/WSL-visible RAM hard floor;
- 8 GiB preferred;
- 12–16 GiB recommended;
- 25 GiB free disk hard floor; 50 GiB recommended;
- `vm.max_map_count >= 262144`.

The root launcher configures `vm.max_map_count` when it can. If an organisation/server policy blocks that administrator change, the host administrator must resolve the policy; do not edit Wazuh rules/Compose to bypass the indexer's requirement.

Local indexer filesystem warnings begin at 85% and become critical at 92%. Preserve required evidence before any mentor-approved cleanup; do not delete Wazuh volumes merely to clear a warning.

## 6. Local Wazuh configuration

The launchers generate `wazuh-stack/.env` only when it is absent and preserve an existing file. Do not regenerate local secrets because the repository was updated.

Human dashboard login:

```text
Username: admin
Password source: local WAZUH_INDEXER_PASSWORD
```

`WAZUH_API_PASSWORD` and `WAZUH_DASHBOARD_PASSWORD` are internal service credentials, not the human login.

## 7. NeoLabs authentication/runtime failures

Use the root launcher actions:

```text
Windows: START-NEOLABS-SOC.cmd status
         START-NEOLABS-SOC.cmd login

Linux:   ./start-neolabs-soc.sh status
         ./start-neolabs-soc.sh login
```

The pod entered during login is confirmation only; server assignment remains authoritative. Do not edit runtime state or a base URL to reach another pod.

## 8. Replay/live telemetry not arriving

Run Doctor, then verify the server state is an authorised SOC surface, raw telemetry contains synthetic assigned-pod records, replay validation did not reject pod/scenario fields, live enrolment is current when LIVE, and internet/TLS connectivity is available.

Replay preserves original `event_time`; replay time is not the incident sequence.

## 9. Raw events exist but Wazuh has no alerts

The manager must monitor `/var/ossec/logs/vcc/vcc-events.ndjson` as JSON and load `config/rules/neolabs_vcc_rules.xml`.

Normal startup restarts the manager after asserting the stack so current rules are loaded after `git pull`. The telemetry verifier uses `wazuh-logtest` as part of the rule-engine proof.

Do not broadly raise rule levels simply to make a dashboard busy.

## 10. Filebeat/indexer problems

If raw events/rule matching works but `wazuh-alerts-*` remains empty, Doctor separates Filebeat and indexer checks. Verify indexer health before changing mappings/policies. NeoLabs retention is deliberately scoped to local `wazuh-alerts-*` and does not force-overwrite unrelated policies.

## 11. Dashboard opens but looks empty

Before concluding “no events”:

1. confirm Doctor/indexer PASS;
2. check latest indexed VCC event freshness;
3. confirm assigned `pod_id` filter;
4. use `wazuh-alerts-*`, Threat Hunting or **NeoLabs — Operation Night Watch**;
5. set a correct absolute UTC range around original event times;
6. inspect **NeoLabs — Telemetry Health** / rule `100150`.

A zero-result query is useful evidence only after source health and time/filter assumptions are verified.

## 12. Saved Night Watch/Telemetry Health views missing

Saved-object provisioning is fail-soft. Healthy telemetry/indexing does not depend on the saved view import. Continue through Threat Hunting and report the view/import problem; do not reset Wazuh data merely because a saved object is absent.

## 13. Safe bounded repair

The root startup path permits one bounded local telemetry repair. It may reassert local services and, in replay mode, refetch the authorised replay state. It does not reset VCC server state, switch pods, delete Wazuh volumes or fetch another student's data.

If searchability still cannot be proven, stop relying on that workstation for assignment conclusions and send redacted Doctor output to the mentor.

## 14. Headless Linux dashboard access

The dashboard remains loopback-only. A headless server launcher prints an SSH local-forward example. Use that secure tunnel from the intern's own computer instead of changing the dashboard binding to a public address.

## 15. Advanced internal commands

Mentors may inspect `wazuh-stack/scripts/` directly for targeted diagnosis, backup/restore or CI rehearsal. These are not student setup steps. `reset.sh --confirm-destroy-local-data` is destructive local recovery and is never a normal startup fix.

## 16. Evidence to send a mentor

Useful redacted evidence includes Doctor PASS/WARN/FAIL lines, current assigned pod/scenario/runtime state without credentials, latest event freshness, `docker compose ps` status, small relevant logs and event/rule IDs/screenshots.

Never send `.env`, admin password, Access Code, session token, private key/certificate contents, signed private URLs or another pod's data.

## 17. Stop conditions

Stop/escalate on cross-pod events/access, real personal/production data, exposed credentials/private keys, unexpected infrastructure access, external-target traffic or service instability. Do not weaken isolation/security controls to make a troubleshooting check pass.
