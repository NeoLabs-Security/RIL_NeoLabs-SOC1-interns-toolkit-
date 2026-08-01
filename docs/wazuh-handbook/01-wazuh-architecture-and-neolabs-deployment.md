# Wazuh SOC Level 1 Handbook — Module 1
# Architecture, Data Flow and the NeoLabs Student Deployment

**NeoLabs tested baseline:** Wazuh 4.14.7  
**Module version:** 0.2-draft  
**Research and review date:** 1 August 2026  
**Audience:** Beginner-to-intermediate SOC Level 1 interns

> Wazuh is not one program running in one window. It is a set of components that collect, analyse, store and display security data. Understanding which component performed each action is essential for troubleshooting and investigation.

## Learning objectives

By the end of this module, a learner should be able to:

- explain the roles of the Wazuh agent, server/manager, indexer and dashboard;
- describe how a source event becomes a decoded event, alert and searchable document;
- distinguish event collection, decoding, rule evaluation, indexing and visualisation;
- explain the difference between Wazuh alerts and archived events;
- identify the ports commonly used by the standard Wazuh components and explain the NeoLabs exposure restrictions;
- describe the local containerised student deployment;
- explain how VCC pod telemetry reaches the learner without installing an agent in the pod;
- identify which settings the learner controls and which pod-scope settings remain operator-controlled;
- perform a basic health and data-flow check without exposing secrets.

---

## 1. What Wazuh is

Wazuh is an open-source security platform that provides capabilities such as:

- log collection and analysis;
- security-event detection;
- file integrity monitoring;
- security configuration assessment;
- vulnerability-detection context;
- malware and rootkit-related monitoring;
- cloud and container monitoring;
- inventory and compliance-oriented views;
- agent management and dashboard investigation.

In practical SOC work, Wazuh acts as a security telemetry and detection platform. It can collect events from agents, files, Windows channels, syslog and supported integrations; decode and evaluate those events; forward alerts for indexing; and present them to analysts in the dashboard.

### Plain-language analogy

Think of a Wazuh deployment as a security newsroom:

- **Agent or collector:** gathers reports from the field.
- **Manager:** reads the reports, extracts important facts and applies editorial rules about what deserves attention.
- **Indexer:** organises the reports so they can be found quickly.
- **Dashboard:** gives analysts an interface for searching, reviewing and visualising the organised information.

The analogy is useful, but remember that a security event can be delayed, duplicated, incorrectly parsed or absent. The analyst must validate the pipeline.

---

## 2. Core Wazuh components

## 2.1 Wazuh agent

A **Wazuh agent** is software installed on a monitored endpoint. Depending on configuration, it can collect or produce information such as:

- operating-system and application logs;
- Windows Event channels;
- file-integrity changes;
- system inventory;
- security configuration assessment results;
- selected command or audit output;
- malware or rootkit-related observations;
- agent health and status information.

The agent normally communicates with the Wazuh server over an authenticated channel.

### Important analyst limitation

An agent can report only what its operating system, applications and Wazuh configuration make available. An active agent does not guarantee that every required event category is enabled or correctly parsed.

### VCC boundary

SOC interns do **not** install, enrol or administer Wazuh agents inside VCC pods. The pods remain operator-managed. The approved VCC log exporter creates a separate synthetic telemetry feed that is delivered to the learner’s local collector.

## 2.2 Wazuh server or manager

The **Wazuh server** includes the manager processes responsible for receiving, decoding, analysing and coordinating Wazuh data.

Important functions include:

- receiving agent or approved collector data;
- pre-decoding common message information;
- applying decoders to extract fields;
- applying rules and correlation conditions;
- writing alert and archive records;
- managing agent registration and grouping where used;
- exposing the Wazuh server API;
- coordinating supported integrations and active-response functions.

The container in the NeoLabs stack is named:

```text
wazuh.manager
```

### Manager is not the index

The manager analyses events, but analysts normally search indexed alert documents through the dashboard. When troubleshooting, distinguish “the manager generated the alert” from “the indexer stored and returned the alert.”

## 2.3 Filebeat in the Wazuh server container

The official single-node Wazuh container topology includes Filebeat configuration in the manager container. Filebeat forwards Wazuh alert data securely to the Wazuh indexer.

A problem between manager and indexer can produce this situation:

```text
Manager alert file contains the alert
        but
Dashboard search does not show it
```

That difference is a useful troubleshooting clue.

## 2.4 Wazuh indexer

The **Wazuh indexer** is the search and storage component based on OpenSearch technology. It stores documents in indices and makes them searchable.

The indexer handles:

- index creation and storage;
- field mappings;
- distributed search functions;
- security and access-control configuration;
- queries and aggregations;
- data retention through index-management policies where configured.

The NeoLabs Compose service is:

```text
wazuh.indexer
```

### Field mapping matters

An indexed value can be mapped as a date, number, IP address, keyword or analysed text. Mapping affects equality, range, sorting and aggregation behaviour. A field being visible in JSON does not guarantee that every query type will work correctly.

## 2.5 Wazuh dashboard

The **Wazuh dashboard** is the browser interface for:

- security-event and alert investigation;
- agent and server management views;
- security modules and compliance-oriented dashboards;
- Wazuh Query Language filters in supported areas;
- OpenSearch-backed Discover and visualisation functions;
- saved searches and dashboards;
- component configuration available to the logged-in role.

The NeoLabs service is:

```text
wazuh.dashboard
```

The standard student profile publishes only the dashboard to the host and binds it to loopback:

```text
127.0.0.1:8443
```

This means another device cannot normally reach the dashboard over the network unless the learner or operator deliberately changes the profile. Such a change is not authorised by default.

---

## 3. How Wazuh analyses an event

A simplified Wazuh analysis flow is:

```text
Raw event
  → pre-decoding
  → decoder matching and field extraction
  → rule evaluation
  → alert or no alert
  → alert file
  → Filebeat forwarding
  → indexer document
  → dashboard search and visualisation
```

## 3.1 Raw event

A raw event is the source record received by Wazuh.

Synthetic VCC example:

```json
{
  "schema_version": "1.0",
  "event_id": "evt-auth-0009",
  "event_time": "2026-08-01T09:18:07Z",
  "pod_id": "pod-03",
  "event_type": "authentication",
  "action": "login",
  "outcome": "success",
  "user": "svc-backup",
  "source_ip": "203.0.113.44",
  "session_id": "sess-suspect-902",
  "synthetic": true
}
```

## 3.2 Pre-decoding

Pre-decoding identifies common header information in supported text formats, such as timestamps, hostnames and program names. Structured JSON may already carry these values as fields.

## 3.3 Decoding

A **decoder** identifies the event format and extracts named fields.

The VCC collector writes NDJSON. The Wazuh manager reads each JSON line using `log_format=json`, and Wazuh’s JSON decoder can expose dynamic fields such as:

```text
pod_id
event_type
outcome
user
source_ip
session_id
```

### Decoder success does not equal detection

A record can be decoded correctly and still generate no alert because no rule condition was satisfied or because the matching rule’s level is below the alert threshold.

## 3.4 Rule evaluation

A **rule** evaluates decoded information. A rule can match:

- one field or message pattern;
- several fields together;
- an event that follows an earlier rule match;
- a repeated event count within a time window;
- the same user, source, destination or another correlation value;
- child rules that inherit context from a parent rule.

The NeoLabs rules use custom IDs in the documented Wazuh custom range and currently cover synthetic authentication, access-control and telemetry-health events.

### Rule result is a detection decision

When a rule matches, it tells the analyst that the configured condition was observed. It does not automatically prove malicious intent or successful impact.

## 3.5 Alert creation

Rules at or above the configured alert threshold create alert records. The alert includes Wazuh metadata such as:

- rule ID;
- rule level;
- rule description;
- rule groups;
- decoded fields;
- source location;
- manager or agent context;
- timestamp.

## 3.6 Indexing

Filebeat forwards alerts to the indexer. The indexer creates searchable documents, usually under an index pattern such as:

```text
wazuh-alerts-*
```

## 3.7 Dashboard display

The dashboard queries indexed documents. Filters, selected time field, browser time zone and data view affect what is displayed.

---

## 4. Alerts and archives

## 4.1 Alert data

Alert data contains events that matched Wazuh rules at or above the configured alerting level.

Useful for:

- alert triage;
- rule and severity review;
- dashboards and common investigations;
- tracking detection volume.

Limitation: events that did not become alerts are absent.

## 4.2 Archive data

Wazuh archives can contain all received events when archive logging and indexing are enabled.

Useful for:

- finding context that did not trigger a rule;
- validating rule coverage;
- searching benign or low-level activity;
- investigating parser and detection gaps.

Costs and risks:

- much higher storage volume;
- more sensitive raw content;
- additional privacy and retention requirements;
- increased indexer workload.

NeoLabs will enable indexed archives only after resource, privacy and retention testing. The handbook must not instruct interns to assume archive data is always present.

---

## 5. Common ports and the NeoLabs restrictions

Official Wazuh deployments commonly use ports such as:

| Port | Common purpose | NeoLabs student profile |
|---|---|---|
| `1514/TCP` | Wazuh agent event communication | Not published to the host by default |
| `1515/TCP` | Agent enrolment service | Not published to the host by default |
| `514/UDP` or TCP | Syslog, where configured | Not published in the initial student profile |
| `55000/TCP` | Wazuh server API | Internal only; not host-published |
| `9200/TCP` | Wazuh indexer/OpenSearch API | Internal only; not host-published |
| `5601/TCP` inside container | Dashboard service | Mapped to loopback `8443` on the host |

### Why the restrictions exist

Publishing a service means making it reachable from the host network. Unnecessary exposure increases the attack surface and can reveal administrative APIs or indexed data.

The initial student stack uses a private Compose network for Wazuh components. Only the VCC collector has outbound egress to the approved telemetry endpoint.

---

## 6. NeoLabs container topology

```text
Host workstation
│
├─ 127.0.0.1:8443
│    └─ wazuh.dashboard
│          ├─ internal TLS → wazuh.indexer
│          └─ internal TLS → wazuh.manager API
│
├─ wazuh.manager
│    ├─ reads /var/ossec/logs/vcc/vcc-events.ndjson
│    ├─ JSON decoding
│    ├─ NeoLabs custom rules
│    └─ Filebeat → wazuh.indexer
│
├─ wazuh.indexer
│    └─ internal-only indexed alert storage
│
└─ vcc.telemetry.collector
     ├─ outbound HTTPS/mTLS only
     ├─ server-issued pod scope
     ├─ synthetic-event validation
     └─ shared volume → manager input file
```

### Persistence

Docker named volumes retain Wazuh configuration, index data, queues and dashboard state across ordinary stops. The guarded reset script removes volumes only after explicit destructive confirmation.

### Generated files

Official Wazuh configuration and certificates are generated into ignored local directories. They are not committed because they include environment-specific cryptographic material and generated configuration.

---

## 7. VCC pod telemetry without pod access

The VCC model separates **telemetry access** from **infrastructure access**.

The intern receives:

- a local Wazuh environment;
- a short-lived enrolment token;
- a client certificate issued for the operator-recorded pod;
- synthetic events exported from that pod’s scenario.

The intern does not receive:

- pod SSH access;
- an AWS role;
- database credentials;
- container access;
- private pod routes;
- a pod log-file mount;
- the ability to select another pod.

### End-to-end scope enforcement

```text
Operator assignment
  → one-time token
  → locally generated private key
  → certificate bound to assignment
  → Nginx mTLS verification
  → API lookup of active assignment
  → database query restricted to assigned pod
  → collector verifies response pod and every event pod
```

This is stronger than a shared password because each credential is unique, revocable and tied to an installation and assignment.

---

## 8. Local setup sequence

Run from `wazuh-stack/` after reading its README.

### Step 1 — Generate local secrets

```bash
bash scripts/generate-local-secrets.sh
```

Creates `.env`, the local installation identifier and protected directories.

### Step 2 — Receive operator material

The operator provides:

- the VCC HTTPS base URL;
- the public enrolment CA certificate;
- a short-lived token file.

The operator does not provide a pod password.

### Step 3 — Prepare official Wazuh files

```bash
bash scripts/prepare-stack.sh
```

This checks out the exact official Wazuh Docker tag and commit, copies the single-node configuration, generates local indexer password hashes and creates Wazuh TLS certificates.

### Step 4 — Run preflight

```bash
bash scripts/preflight.sh
```

This checks required tools, exact version pins, file permissions, placeholder secrets, dashboard binding, memory guidance and indexer kernel settings.

### Step 5 — Enrol

```bash
bash scripts/enrol-vcc.sh --token-file /protected/path/bootstrap-token.txt
```

The private key remains on the workstation. The client sends no pod selector.

### Step 6 — Start

```bash
bash scripts/start.sh
```

The script validates the Compose model, builds the collector, starts services and waits for health checks.

---

## 9. Health checks

Run:

```bash
bash scripts/health-check.sh
```

Expected output lists:

```text
wazuh.manager
wazuh.indexer
wazuh.dashboard
vcc.telemetry.collector
```

### Healthy but unenrolled

The collector can report a healthy waiting state before credentials are installed. This means the collector process is functioning; it does not mean VCC telemetry is arriving.

### Manager healthy but no alerts

Possible reasons include:

- collector unenrolled or disconnected;
- no new telemetry;
- manager input file absent or unchanged;
- JSON decoding failure;
- rules not loaded;
- events matched only level-zero parent rules;
- Filebeat/indexer problem;
- dashboard time/filter problem.

Health is component-specific. One green component does not guarantee the complete pipeline works.

---

## 10. Basic data-flow validation

Use this order:

1. **Collector health:** Is it enrolled and polling successfully?
2. **Collector cursor:** Is the stored cursor advancing?
3. **Shared NDJSON file:** Are new valid lines present in the telemetry volume?
4. **Manager configuration:** Is the VCC localfile input loaded?
5. **Decoder test:** Does `wazuh-logtest` expose expected fields?
6. **Rule test:** Does the synthetic record match the intended rule?
7. **Manager alert file:** Was an alert written?
8. **Filebeat:** Is forwarding healthy?
9. **Indexer:** Is the cluster healthy and index writable?
10. **Dashboard:** Is the correct data view and absolute time range selected?

Do not skip directly to changing rules when the collector is not delivering data.

---

## 11. Common beginner misunderstandings

### “The dashboard created the alert”

The manager’s rule engine created the alert. The dashboard displayed an indexed representation.

### “The agent is active, so every log is collected”

Agent connectivity and source coverage are different questions.

### “No alert means no event”

The event may have failed to generate, collect, decode, match, forward, index or appear under the selected filters.

### “HTTP 200 proves the action was authorised”

A 200 response records a server outcome, not the legitimacy of the requester.

### “Changing `POD_LABEL` changes my pod”

`POD_LABEL` is local display information. Authorised scope comes from the server-side assignment and certificate.

### “A high rule level proves an incident”

Rule level expresses detection importance configured by the rule author. The analyst must still validate context and impact.

---

## 12. Guided exercise

Using the synthetic authentication dataset:

1. identify the raw JSON fields;
2. identify which fields the JSON decoder should expose;
3. identify the NeoLabs parent rule and relevant child rules;
4. predict which records should create alerts;
5. explain why a level-zero parent rule may not appear as an alert;
6. run the approved local rule test after the stack is prepared;
7. find the indexed alert in the dashboard;
8. record manager, indexer and dashboard evidence separately;
9. state one failure that could occur at each pipeline stage.

## 13. Review questions

1. What is the practical difference between the manager and indexer?
2. What does a decoder do?
3. What does a rule match prove?
4. Why can manager alerts exist without appearing in the dashboard?
5. What is the difference between alert and archive data?
6. Why are ports 55000 and 9200 not published in the student profile?
7. How does VCC provide pod telemetry without giving pod access?
8. Why is a unique client certificate stronger than one shared pod password?
9. What does a healthy but unenrolled collector mean?
10. List the ten data-flow validation stages in order.

---

## Authoritative references

- Wazuh official documentation: architecture, Wazuh components, log data analysis and event logging.
- Wazuh official Docker repository, release `v4.14.7`.
- Wazuh official documentation: JSON decoder, custom rules, rule testing, Wazuh indices and API security.
- OpenSearch documentation: indices, mappings and Query DSL.
- Docker documentation: Compose networks, volumes, health checks and container security.
- `research/AUTHORITATIVE_SOURCE_REGISTER.md`.
