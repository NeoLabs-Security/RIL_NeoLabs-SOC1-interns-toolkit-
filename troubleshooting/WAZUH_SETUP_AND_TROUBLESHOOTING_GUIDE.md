# NeoLabs Wazuh Setup and Troubleshooting Guide

**Tested baseline:** Wazuh 4.14.7  
**Guide version:** 0.2-draft  
**Review date:** 1 August 2026  
**Scope:** Learner-owned workstation and authorised VCC synthetic telemetry only

> Troubleshoot from the source toward the dashboard. Changing several settings at once can hide the real cause and create a second problem.

## 1. Golden troubleshooting sequence

```text
Host requirements
  → Docker daemon
  → local files and permissions
  → generated Wazuh configuration
  → container startup
  → component health
  → VCC enrolment and mTLS
  → collector output
  → manager file monitoring
  → decoding and rules
  → Filebeat/indexer
  → dashboard data view, time and filters
```

Record every command and result in the query journal. Remove credentials and private URLs before submitting evidence.

---

## 2. Safe commands first

Run from `wazuh-stack/`.

### Preflight

```bash
bash scripts/preflight.sh
```

### Service status

```bash
bash scripts/health-check.sh
```

### Compose process list

```bash
docker compose --env-file .env ps
```

### Recent service logs

```bash
docker compose --env-file .env logs --since=10m \
  wazuh.manager wazuh.indexer wazuh.dashboard vcc.telemetry.collector
```

Before sharing logs, review them for:

- private VCC endpoints;
- usernames or personal information;
- certificate details;
- environment values;
- raw application data outside the assignment.

Do not use `docker inspect` to publish complete environment blocks.

---

# Part I — Host and Docker problems

## 3. `docker: command not found`

### Meaning

Docker Engine or Docker Desktop is not installed, or the command is not on the current PATH.

### Checks

```bash
docker --version
docker compose version
```

### Resolution

Install Docker from the official Docker instructions for the learner’s operating system. Use the Compose plugin, not an unverified third-party package.

### Escalate when

- the learner does not have permission to install system software;
- the device is managed by an organisation;
- hardware virtualisation is disabled and requires administrator access.

## 4. Docker daemon not running

Typical message:

```text
Cannot connect to the Docker daemon
```

### Checks

```bash
docker info
```

On Docker Desktop, confirm the application is running. On Linux, an authorised administrator may check the Docker service.

### Caution

Do not solve this by exposing an unauthenticated Docker TCP socket. Docker daemon access provides extensive control over the local host.

## 5. Permission denied accessing Docker

Typical Linux message:

```text
permission denied while trying to connect to the Docker daemon socket
```

The user lacks access to the local Docker daemon.

Follow the approved system-administration procedure. Membership in the Docker group is effectively privileged on that workstation and should not be treated as a harmless application permission.

## 6. Insufficient memory or storage

Possible symptoms:

- indexer repeatedly restarts;
- dashboard remains unavailable;
- containers are killed with exit code 137;
- searches are extremely slow;
- disk watermark or read-only index errors appear.

### Checks

```bash
docker stats --no-stream
docker system df
df -h
```

The all-in-one training baseline should have approximately 4 CPU cores, 8 GiB RAM and 50 GB available storage.

### Resolution

- stop unrelated heavy applications;
- allocate enough resources to Docker Desktop;
- free approved local storage;
- do not delete Wazuh volumes unless the reset procedure is authorised;
- report repeated disk-watermark errors to the mentor.

## 7. `vm.max_map_count` too low

The indexer may fail with a message related to virtual memory areas.

### Check

```bash
cat /proc/sys/vm/max_map_count
```

Required baseline:

```text
262144 or higher
```

Use the operating-system-specific official OpenSearch/Wazuh guidance. A learner should not change shared or managed systems without permission.

---

# Part II — Local files and preparation

## 8. Missing `.env`

Typical preflight error:

```text
Missing wazuh-stack/.env
```

Run:

```bash
bash scripts/generate-local-secrets.sh
```

The script refuses to overwrite an existing `.env` because that could destroy valid local credentials or configuration.

## 9. Placeholder password remains

Preflight rejects values beginning with:

```text
CHANGE_ME
```

Use the secret-generation script. Do not replace placeholders with a short shared classroom password.

## 10. `.env` permissions are too broad

Expected mode:

```text
600
```

Check:

```bash
stat -c '%a %n' .env
```

Fix on a compatible Unix-like system:

```bash
chmod 600 .env
```

On platforms that do not expose Unix permissions in the same way, follow the tested platform-specific cohort guidance.

## 11. `prepare-stack.sh` cannot verify the Wazuh commit

The script checks that the official tag resolves to the exact reviewed commit.

Do not bypass the comparison. Possible causes include:

- the `.env` pin was edited;
- an incomplete or incorrect tag was configured;
- the local upstream checkout is damaged;
- the reviewed baseline has changed.

### Safe recovery

Remove only the ignored upstream state directory after confirming no local evidence is stored there, then rerun preparation. Do not change the expected commit to make the error disappear without technical review.

## 12. Certificate generation fails

Possible causes:

- Docker cannot pull the official generator image;
- the generated directory has incorrect ownership;
- stale generated files conflict;
- insufficient disk space;
- network access to the container registry is unavailable.

### Checks

```bash
docker pull wazuh/wazuh-certs-generator:0.0.2
ls -la generated
```

Use the exact image referenced by the reviewed official Wazuh release. Do not substitute an unknown certificate generator.

---

# Part III — Container startup

## 13. Compose configuration error

Validate without starting:

```bash
docker compose --env-file .env config --quiet
```

Common causes:

- missing environment variables;
- malformed YAML;
- missing generated bind-mount files;
- a host path created as a directory when a file was expected;
- unsupported Compose version.

## 14. Dashboard port already in use

Typical error:

```text
address already in use
```

Check which approved local process uses the port. Change `WAZUH_DASHBOARD_PORT` to another unused high port only if the cohort guidance permits it.

Keep:

```text
WAZUH_DASHBOARD_BIND=127.0.0.1
```

Do not change the bind address to `0.0.0.0` merely to fix a local browser problem.

## 15. Manager unhealthy

Check:

```bash
docker compose --env-file .env logs --since=10m wazuh.manager
```

Possible causes:

- invalid `ossec.conf` XML;
- unreadable mounted certificate;
- indexer connection failure;
- invalid local rules;
- volume permission issue;
- resource exhaustion.

### Rule/config validation

Inspect manager startup messages for the exact file and line. Do not delete the rule file blindly. Restore the reviewed file or test the specific change.

## 16. Indexer unhealthy

Check:

```bash
docker compose --env-file .env logs --since=10m wazuh.indexer
```

Common causes:

- `vm.max_map_count` too low;
- memory exhaustion;
- certificate mismatch;
- invalid internal-user password hashes;
- corrupted or incompatible data volume;
- disk watermark.

Do not delete `wazuh-indexer-data` as a first response. It contains the local searchable investigation data.

## 17. Dashboard unhealthy

Check:

```bash
docker compose --env-file .env logs --since=10m wazuh.dashboard
```

Common causes:

- indexer not healthy;
- wrong indexer password;
- wrong Wazuh API password;
- missing certificate mount;
- dashboard waiting for dependencies;
- insufficient memory.

Follow dependency order: indexer and manager must be healthy before expecting the dashboard to become ready.

---

# Part IV — Browser and login

## 18. Browser cannot open the dashboard

Confirm:

```bash
bash scripts/health-check.sh
```

Then use exactly the address printed by the script.

Checks:

- correct port;
- `https`, not `http`;
- loopback address;
- no corporate proxy rewriting local traffic;
- dashboard container healthy.

## 19. Certificate warning

The local Wazuh dashboard uses generated training certificates. Verify:

- the address is the local loopback address;
- the certificate belongs to the local generated stack;
- the programme-approved browser procedure allows proceeding.

Never generalise this behaviour to public or unknown websites.

## 20. Dashboard password rejected

Do not paste the password into screenshots or chat.

Possible causes:

- `.env` was regenerated after the indexer security configuration was prepared;
- preparation was run with one password and startup with another;
- browser password manager inserted an old value;
- local index data belongs to a previous configuration.

The local `.env`, generated `internal_users.yml` and running containers must belong to the same preparation cycle. Use the documented reset/rebuild procedure only after preserving required evidence.

---

# Part V — VCC enrolment

## 21. Enrolment base URL is empty

Set the operator-provided HTTPS base URL in `.env`:

```text
VCC_ENROLMENT_BASE_URL=https://<approved-host>:8443
```

Do not add a pod path or query parameter.

## 22. Enrolment CA certificate missing

Expected path:

```text
secrets/vcc/enrolment-ca.crt
```

The CA must come from the NeoLabs operator through the approved channel. Do not download or replace it from an unverified message or website.

## 23. TLS verification failed during enrolment

Possible causes:

- incorrect CA certificate;
- hostname does not match the server certificate;
- connecting to the wrong port or host;
- system clock incorrect;
- intercepting proxy;
- expired server certificate.

Do not disable TLS verification. Escalate the hostname and certificate error to the operator.

## 24. Bootstrap token rejected

The client intentionally returns a general message for invalid, expired, consumed or mismatched tokens.

Possible causes:

- token expired;
- token was already used;
- a replacement token invalidated it;
- assignment was revoked;
- whitespace or line wrapping altered the token;
- the token belongs to another installation workflow.

Request a new token through the approved channel. Do not ask another intern for theirs.

## 25. Existing local enrolment detected

The client refuses to overwrite active material.

Correct procedure:

1. contact the operator;
2. identify the existing credential ID from local enrolment metadata without publishing it;
3. obtain server-side revocation;
4. confirm whether the assignment changes;
5. rerun enrolment with explicit replacement only after approval.

Deleting the certificate locally does not revoke it on the server.

## 26. Enrolment succeeds but collector shows authentication error

Possible causes:

- credential revoked after issuance;
- certificate expired;
- telemetry URL changed;
- installation ID file changed;
- mTLS Nginx route not configured correctly;
- client and server clocks differ significantly.

Do not regenerate the installation ID. Preserve the local health record and ask the operator to check the credential and audit events.

---

# Part VI — Collector problems

## 27. Collector status `unenrolled`

This is expected before valid endpoint and certificate files exist.

Check:

```bash
ls -l secrets/vcc
cat state/collector-health.json
```

Do not print private key contents.

## 28. Collector status `connection_error`

Possible causes:

- endpoint unavailable;
- DNS failure;
- firewall or proxy block;
- server certificate verification failure;
- timeout.

Use only non-secret connectivity checks approved by the operator. Do not use insecure curl flags against the VCC endpoint in submitted work.

## 29. Collector status `authentication_error`

The API returned HTTP 401 or 403.

Likely causes:

- missing or invalid client certificate;
- revocation;
- installation ID mismatch;
- assignment revoked;
- certificate expired.

This requires operator-side audit review. Editing `POD_LABEL` cannot fix authentication.

## 30. Collector status `validation_error`

The collector rejected the response.

Possible causes:

- missing required field;
- `synthetic` is not exactly `true`;
- event `pod_id` differs from the server-issued pod;
- response omitted `X-VCC-Pod-ID`;
- invalid NDJSON;
- oversized response;
- server-issued pod changed without credential reset.

Treat a wrong-pod event as a security stop condition. Preserve the private evidence and notify the programme operator immediately.

## 31. Cursor not moving

A cursor can remain unchanged when no new events exist. Check:

- collector health says the poll succeeded;
- event count returned was zero;
- assignment scenario is active;
- cursor file modification time;
- operator exporter health.

Do not delete the cursor to force replay unless the operator approves. Replaying a large range can duplicate local analysis work.

---

# Part VII — Manager ingestion and detection

## 32. Collector writes events but Wazuh shows none

Validate the shared data path inside containers without exposing event content unnecessarily.

Questions:

1. Is the collector output file present?
2. Does the manager mount the same named volume?
3. Does the manager configuration monitor the exact path?
4. Is `log_format=json` set?
5. Did the manager reload the configuration?
6. Are events valid one-object-per-line NDJSON?

## 33. JSON decoder does not expose fields

Use `wazuh-logtest` in the local manager with one approved synthetic record.

Check:

- valid JSON;
- no extra prefix before `{`;
- field types are expected;
- schema version is supported;
- nested fields match the rule paths;
- the event fits within size limits.

A JSON record being syntactically valid does not guarantee its schema matches the rules.

## 34. Rule does not match

Check:

- parent rule matched;
- field name and case;
- regex anchors;
- expected string versus Boolean representation;
- custom rule file loaded;
- rule ID does not collide;
- level and grouping;
- correlation timeframe and frequency;
- correct static/dynamic correlation field.

Test one simple event first, then the sequence.

## 35. Repeated-event rule does not trigger

Correlation rules require events to arrive within the configured timeframe and satisfy grouping conditions.

Check:

- event ingestion order;
- Wazuh analysis timestamp behaviour;
- same-user or same-field values are populated consistently;
- frequency count includes the intended parent rule;
- the test session is not affected by prior cached events;
- malformed or rejected events did not break the sequence.

## 36. Alert exists in manager but not dashboard

Check:

1. manager alert file;
2. Filebeat logs;
3. certificate and indexer connectivity;
4. indexer health;
5. index existence;
6. dashboard data view;
7. absolute time range;
8. hidden filters.

This indicates the detection stage worked and the problem is later in the pipeline.

---

# Part VIII — Indexer and dashboard investigation problems

## 37. Indexer cluster red or read-only

Possible causes:

- disk pressure;
- unavailable shard;
- corrupted volume;
- memory instability;
- incompatible restored data.

Do not run destructive index commands as a learner. Preserve logs and escalate.

## 38. Query returns zero results unexpectedly

Check:

- correct index pattern;
- absolute UTC range;
- event versus ingest timestamp;
- exact field path;
- keyword versus analysed mapping;
- active dashboard filters;
- pod and synthetic values;
- alert level and archive availability.

Record the zero-result query and the source-health checks before calling it evidence.

## 39. Fields appear under a different path

Wazuh and index mappings may nest source fields under `data` or another source-specific object.

Open a real event, inspect the field list and use the actual indexed path. Update the query journal. Do not silently change the training rule without confirming the decoder and mapping.

## 40. Times appear shifted

Check:

- browser time-zone setting;
- dashboard advanced settings;
- source `event_time`;
- indexed `timestamp`;
- collector `ingest_time`;
- host clock.

Build the report timeline in UTC and document conversions.

---

# Part IX — Reset and recovery

## 41. Stop without deleting data

```bash
bash scripts/stop.sh
```

## 42. Destructive reset

First run without confirmation to display the warning:

```bash
bash scripts/reset.sh
```

Then, only after preserving required work:

```bash
bash scripts/reset.sh --confirm-destroy-local-data
```

This removes Wazuh volumes, generated configuration and local telemetry state. It retains enrolment material unless the additional approved flag is used.

## 43. Removing enrolment material

Server-side revocation must happen first. Then:

```bash
bash scripts/reset.sh \
  --confirm-destroy-local-data \
  --include-enrolment
```

Confirm revocation with the operator. Local deletion alone is not a security control.

---

# Part X — Escalation package

When troubleshooting cannot be completed safely, provide:

```text
Workstation OS and version:
Docker and Compose versions:
Wazuh version:
Exact failing step:
First error time in UTC:
Service health summary:
Relevant redacted error lines:
Commands already run:
Whether the system ever worked:
Recent approved changes:
Assigned pod as shown by local state:
Credential ID reference, not private certificate/key:
Impact on investigation:
```

Do not include:

- `.env` contents;
- tokens;
- private keys;
- complete certificate dumps;
- private VCC URLs in public issues;
- unrelated student or pod evidence.

---

## Quick decision tree

```text
Dashboard unavailable?
  ├─ Compose invalid → fix local configuration
  ├─ Indexer unhealthy → host/kernel/memory/cert/storage checks
  ├─ Manager unhealthy → XML/rule/cert/indexer checks
  └─ Dashboard only unhealthy → API/indexer/password/cert checks

Dashboard available but no VCC events?
  ├─ Collector unenrolled → complete approved enrolment
  ├─ Authentication error → operator credential/audit review
  ├─ Validation error → security stop; check wrong-pod/schema response
  ├─ No collector output → exporter/feed/connectivity review
  ├─ Output exists, no decoded event → manager localfile/JSON review
  ├─ Decoded event, no alert → rule/level/correlation review
  ├─ Manager alert exists, no index → Filebeat/indexer review
  └─ Indexed alert exists, not visible → data view/time/filter review
```

## Authoritative references

- Wazuh official documentation: Docker deployment, component requirements, server logs, JSON decoder, custom rules, `wazuh-logtest`, indexer and dashboard troubleshooting.
- OpenSearch documentation: bootstrap checks, disk watermarks, cluster health and mappings.
- Docker documentation: daemon, Compose, resource controls, volumes and security.
- `wazuh-stack/README.md`.
- `research/AUTHORITATIVE_SOURCE_REGISTER.md`.
