# Module 3 — SIEM Pipelines, Data Quality and Detection Context

> **NeoLabs SOC Level 1 principle:** Before trusting a dashboard result, understand how the source activity became a searchable field and which failures could have altered or removed the evidence.

**Module version:** 0.2-draft  
**Review baseline:** 1 August 2026  
**Expected study time:** 4–6 hours

## Learning objectives

By the end of this module, a learner should be able to:

- define SIEM and explain its relationship to log management, detection and case handling;
- describe generation, collection, transport, parsing, normalisation, enrichment, indexing, detection and alerting;
- distinguish raw events, decoded fields, indexed documents and alerts;
- identify common data-quality failures and their investigative effect;
- explain why event time and ingest time can differ;
- recognise schema drift, duplicate ingestion, clock skew and retention gaps;
- validate a telemetry pipeline before concluding that an event did not occur;
- explain the Wazuh manager, indexer and dashboard roles at a beginner-to-intermediate level.

---

## 1. What a SIEM is

A **Security Information and Event Management (SIEM)** platform centralises security-relevant data, makes it searchable and applies rules or analytics to identify activity that deserves investigation.

A SIEM normally supports four broad capabilities:

1. **Collection:** receive records from endpoints, applications, network devices, identity systems and cloud services.
2. **Organisation:** parse, normalise, enrich, index and retain records.
3. **Detection:** evaluate records or sequences against rules, thresholds and analytics.
4. **Investigation:** provide searches, visualisations, alert queues and links to evidence.

A SIEM does not create visibility that the source never generated. If process auditing is disabled, the SIEM cannot reconstruct every process from nothing. If an application logs only “request failed” without user, route or request ID, later investigation will be limited.

### SIEM, XDR and log management

- **Log management** covers the generation, transmission, storage, access and disposal of log data.
- **SIEM** adds security-oriented correlation, detection, investigation and alerting.
- **XDR** generally combines detection and response across several security domains, such as endpoints, identities, cloud and email. Product definitions differ.

For SOC Level 1 work, the important skill is not memorising product categories. It is understanding which source produced the evidence, how it was transformed and what response authority exists.

---

## 2. The telemetry pipeline

```text
System activity
  → log generation
  → collection
  → transport
  → parsing / decoding
  → normalisation
  → enrichment
  → indexing and retention
  → rule or analytic
  → alert
  → investigation and case record
```

Each stage can succeed, fail or change the meaning available to an analyst.

### 2.1 System activity

Something occurs: a user signs in, a process starts, a file changes, a web request reaches an API or a cloud role performs an action.

The activity itself is not the log. The log is a system’s recorded representation of that activity.

### 2.2 Log generation

The source must be configured to record the event.

Examples:

- Windows Security auditing records selected authentication and account events.
- Sysmon records configured process, network, DNS, file and registry activity.
- NGINX records requests according to its log format.
- AWS CloudTrail records supported API activity according to trail and event-selector configuration.
- An application records business events only if developers implemented suitable logging.

**Generation failure:** Auditing is disabled, the event category is excluded or the application never logs the required action.

### 2.3 Collection

A collector reads the event from the source.

Collection mechanisms include:

- Wazuh agents;
- Windows Event Forwarding;
- syslog;
- API polling;
- cloud object storage;
- file readers;
- container stdout collectors;
- message queues.

**Collection failure:** The agent is stopped, lacks permission, watches the wrong path or starts after the event occurred.

### 2.4 Transport

Records move from the source or collector to the analysis platform.

Security considerations include:

- authentication of the sender and receiver;
- encryption in transit;
- buffering when the destination is unavailable;
- duplicate delivery after retries;
- network and proxy paths;
- size or rate limits.

**Transport failure:** Network interruption, expired certificate, rejected credentials, queue overflow or dropped oversized records.

### 2.5 Parsing or decoding

Parsing converts raw text or structured records into fields.

Raw example:

```text
Aug 01 09:14:21 web01 sshd[24109]: Failed password for invalid user admin from 203.0.113.44 port 44218 ssh2
```

Possible decoded fields:

```json
{
  "host": "web01",
  "program": "sshd",
  "process_id": 24109,
  "event_action": "authentication_failure",
  "user": "admin",
  "user_status": "invalid",
  "source_ip": "203.0.113.44",
  "source_port": 44218,
  "protocol": "ssh2"
}
```

Parsing makes searches more reliable, but the raw record should remain available where policy permits.

**Parsing failure:** The format changes, the decoder matches the wrong pattern or a field contains unexpected characters.

### 2.6 Normalisation

**Normalisation** maps similar meanings from different sources to consistent field names and values.

| Source-specific field | Normalised idea |
|---|---|
| `src`, `client_ip`, `sourceIPAddress` | source IP address |
| `username`, `TargetUserName`, `userIdentity.arn` | acting or targeted identity, with source-specific detail retained |
| `result`, `status`, HTTP status | outcome, interpreted according to source semantics |

Normalisation helps cross-source searches. It must not erase important differences. An AWS role ARN is not identical to a Windows username even if both represent identity.

### 2.7 Enrichment

Enrichment adds context not present in the original event.

Examples:

- asset owner and criticality;
- approved pod identifier;
- IP reputation or geographic context;
- vulnerability exposure;
- identity role;
- threat-intelligence tags;
- change-window information.

Enrichment can become stale. A system may have changed owner, a cloud address may be reassigned and a threat-intelligence match may be outdated.

### 2.8 Indexing and retention

An index stores fields in a form designed for search. Field mappings determine whether values behave as exact keywords, analysed text, numbers, dates or IP addresses.

Examples of mapping problems:

- a numeric status stored as text cannot be reliably compared with numeric ranges;
- an IP stored as ordinary text loses IP-aware queries;
- a timestamp stored in an unrecognised format may sort incorrectly;
- a username analysed into tokens may behave differently from an exact keyword field.

Retention determines how long evidence remains searchable or archived. Retention must consider operational need, incident-discovery delay, privacy, regulation, storage cost and evidence requirements.

### 2.9 Detection

A detection evaluates records or sequences.

Common detection types:

- exact or pattern match;
- threshold within a time window;
- sequence, such as failures followed by success;
- correlation across sources;
- baseline or anomaly comparison;
- threat-intelligence match;
- model or risk score.

A detection should state its data requirements. A rule that depends on command lines cannot work correctly when command-line auditing is disabled.

### 2.10 Alerting

The platform creates an alert with fields such as rule, severity, entities, evidence links and timestamps.

The alert may summarise several events. Analysts should determine whether the displayed count represents distinct source events, grouped documents or duplicated ingestion.

---

## 3. Wazuh components in this toolkit

### Wazuh manager

The **Wazuh manager** receives and analyses security data. It runs decoders and rules, manages agent-related functions and produces alert records.

In the NeoLabs student deployment, the manager also monitors a local NDJSON file written by the authorised VCC telemetry collector. The collector obtains only the feed issued to that learner’s assigned pod.

### Wazuh indexer

The **Wazuh indexer** stores and indexes alert and security data for search and visualisation. It is based on OpenSearch technology.

The indexer should not be exposed publicly in the student profile. The dashboard and internal components access it over the private Compose network.

### Wazuh dashboard

The **Wazuh dashboard** provides the analyst interface for alerts, agents, security modules, searches and visualisations.

A dashboard view is not the evidence itself. The analyst should be able to open event details and identify the supporting fields.

### Wazuh agent

The **Wazuh agent** is installed on monitored endpoints to collect local telemetry and perform supported security functions.

VCC interns do not install agents on pod infrastructure. Pod telemetry is exported through the VCC control plane and delivered to the learner’s local collector using a pod-scoped credential.

### Decoder and rule

- A **decoder** extracts fields or interprets structure.
- A **rule** evaluates decoded information and can create an alert.

For JSON records, Wazuh can use its JSON decoder and dynamic fields. Custom rules should use a documented local rule-ID range and be tested with `wazuh-logtest` before deployment.

---

## 4. Raw events, decoded events and alerts

Consider this synthetic VCC record:

```json
{
  "schema_version": "1.0",
  "event_time": "2026-08-01T09:18:07Z",
  "ingest_time": "2026-08-01T09:18:10Z",
  "pod_id": "pod-03",
  "event_type": "authentication",
  "action": "login",
  "outcome": "success",
  "user": "svc-backup",
  "source_ip": "203.0.113.44",
  "destination_service": "learner-api",
  "correlation_id": "corr-7d9f0a",
  "synthetic": true
}
```

### Raw event

The complete JSON line written by the collector.

### Decoded event

Wazuh identifies fields such as `pod_id`, `action`, `outcome`, `user` and `source_ip`.

### Alert

A custom rule might alert when a successful login from a source follows repeated failures for the same account. The alert includes rule metadata and selected event fields.

The analyst should retain the distinction:

- the raw record came from the VCC feed;
- the decoder exposed fields;
- the rule made a detection decision;
- the analyst adds context and reaches a case conclusion.

---

## 5. Time in security investigations

### Event time

When the source says the activity occurred.

### Ingest time

When the platform received or indexed the record.

### Processing or alert time

When a rule evaluated the record and created an alert.

These times can differ because of buffering, network delay, batch delivery or processing load.

### Clock skew

**Clock skew** is a difference between system clocks. A host running three minutes fast can make a later action appear earlier than a preceding event on another system.

### Time-zone handling

Prefer UTC for correlation. Preserve the source time zone when available and document any conversion.

### Example

```text
Application event time: 09:14:21Z
Collector received:      09:15:05Z
Indexed:                 09:15:09Z
Alert created:           09:15:10Z
```

The 44-second delivery delay is not automatically suspicious. It becomes important when building a precise sequence.

---

## 6. Data-quality failures

| Failure | What the analyst may see | Risk to conclusion | First checks |
|---|---|---|---|
| Auditing disabled | Expected event never exists | “No evidence” mistaken for “no activity” | Source policy and test event |
| Agent or collector disconnected | Events stop suddenly | Blind period around incident | Last heartbeat, queue and service status |
| Parser failure | Raw data exists but fields are empty | Searches and rules miss records | Raw message, decoder logs and schema version |
| Schema drift | Old fields disappear or change type | Rules silently stop matching | Compare recent and older samples |
| Clock skew | Events appear out of order | False timeline | Source time, NTP status and ingest time |
| Duplicate ingestion | Counts double or thresholds fire | Inflated scope and false alerts | Event IDs, hashes and collector paths |
| Dropped events | Missing records during high volume | Incomplete scope | Queue, rate limits and volume metrics |
| Retention expiry | Older events unavailable | Root cause cannot be reconstructed | Index age and archive policy |
| Wrong field type | Exact/range searches behave oddly | False negatives or misleading results | Index mapping |
| Truncation | Command, URI or payload is incomplete | Important context missing | Source limits and raw record |
| Redaction error | Sensitive data remains or useful context removed | Privacy exposure or lost evidence | Logging policy and sanitisation tests |

---

## 7. Schema drift

**Schema drift** occurs when field names, nesting, formats or data types change.

Version 1:

```json
{"source_ip":"203.0.113.44","user":"student03"}
```

Version 2:

```json
{"source":{"ip":"203.0.113.44"},"identity":{"name":"student03"}}
```

A rule expecting `source_ip` may stop working even though records still arrive.

### Controls

- include a `schema_version` field;
- validate required fields in the exporter;
- maintain sample fixtures for each supported version;
- test decoders and rules in CI;
- monitor field-population rates;
- reject or quarantine unsupported versions rather than silently misparse them.

---

## 8. Validating a telemetry pipeline

When an expected event is missing, work from source to destination.

### Source

- Is the activity configured to generate a log?
- Can a safe test event be produced?
- Is the local record present?

### Collector

- Is the service running?
- Does it have permission to read the source?
- Is its cursor or checkpoint advancing?

### Transport

- Is authentication valid?
- Are TLS and network connections successful?
- Are queues full or retries increasing?

### Parsing

- Is the raw event received?
- Are required fields extracted?
- Did the schema change?

### Indexing

- Is the target index writable and searchable?
- Are mappings correct?
- Is the selected time range based on the correct timestamp?

### Detection

- Does the rule load successfully?
- Do the exact fields and values satisfy the condition?
- Is the threshold window correct?
- Was the event excluded or suppressed?

### Dashboard

- Are filters hiding the record?
- Is the correct index pattern or data view selected?
- Is the browser displaying the intended time zone?

---

## 9. Worked example — alert disappeared after application update

### Symptom

A rule that detects failed logins stops generating alerts after an application release.

### Incorrect conclusion

> Failed login attempts have stopped.

### Investigation

1. The application still writes JSON records.
2. The collector continues receiving current events.
3. Raw records now use `authentication.result` instead of `outcome`.
4. The Wazuh rule expects `outcome` equal to `failure`.
5. Indexed documents contain the new nested field, but the old field is empty.

### Finding

The monitoring gap was caused by schema drift. Failed logins continued, but the existing rule no longer matched them.

### Remediation

- update and test the decoder/rule;
- version the schema;
- add a CI fixture for both transition formats;
- monitor the population rate of required authentication fields;
- document the blind period.

---

## 10. Detection context and ATT&CK

MITRE ATT&CK helps describe adversary behaviour, but an ATT&CK technique label does not replace detection logic.

A useful detection design states:

1. **Threat hypothesis:** What behaviour are we concerned about?
2. **Required telemetry:** Which sources and fields can show it?
3. **Analytic:** What sequence, relationship or threshold should be evaluated?
4. **Expected benign causes:** Which authorised behaviours may look similar?
5. **Validation:** How will synthetic tests show that the detection works?
6. **Tuning record:** What changes were made and what coverage might be lost?

Current ATT&CK teaching should use Detection Strategies, Analytics and Data Components rather than treating a technique ID as a complete detection.

---

## 11. Common mistakes

### Believing structured JSON is automatically correct

JSON can contain wrong timestamps, empty fields, unexpected types or attacker-controlled values.

### Searching only the friendly message

Use structured fields and inspect the raw record. Friendly descriptions may omit important context.

### Treating source IP as unquestionable

Proxies, NAT, forwarded headers and collection architecture affect which address is recorded.

### Ignoring ingest delay

A delayed event can appear after an analyst has already closed a case.

### Tuning by deleting noisy data

Noise can expose misconfiguration, stale credentials or operational problems. Understand the cause before excluding evidence.

### Exposing internal services

The Wazuh indexer and server API should not be publicly exposed merely for convenience. Use the local dashboard and approved internal connections.

---

## 12. Guided exercise — pipeline failure classification

For each situation, identify the pipeline stage and likely investigative effect.

1. A Windows host never generated Event 4688 because process-creation auditing was disabled.
2. The VCC collector certificate expired and polling returned HTTP 401/403.
3. JSON records arrive, but `pod_id` is missing after a release.
4. The same file is read by two collectors.
5. A query searches the last hour using ingest time while the incident occurred two hours earlier and arrived late.
6. The index retained only seven days, but the suspected access occurred ten days ago.

Then write one validation step for each situation.

---

## 13. Review questions

1. What is the difference between log generation and collection?
2. Why should raw records remain available where policy permits?
3. Explain normalisation and one risk of over-normalising.
4. What is schema drift?
5. Why can event time and ingest time differ?
6. What does a decoder do in Wazuh?
7. What does the Wazuh indexer do?
8. Why should the indexer not be exposed publicly in the student profile?
9. Give three reasons why “no alert” does not prove “no attack.”
10. What six elements belong in a detection design?

---

## References

- NIST SP 800-92 and SP 800-92 Rev. 1 Initial Public Draft.
- Wazuh official documentation: architecture, log collection, JSON decoder, custom rules, WQL and Docker deployment.
- OpenSearch official Query DSL and field-mapping documentation.
- MITRE ATT&CK v19.1 Detection Strategies, Analytics and Data Components.
- Microsoft Sysmon and Windows auditing documentation.
- AWS CloudTrail documentation.
- `research/AUTHORITATIVE_SOURCE_REGISTER.md`.
