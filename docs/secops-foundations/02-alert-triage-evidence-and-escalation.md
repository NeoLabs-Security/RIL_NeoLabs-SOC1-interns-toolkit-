# Module 2 — Alert Triage, Evidence and Escalation

> **NeoLabs SOC Level 1 principle:** Triage is a disciplined decision process. It is not a race to close alerts and it is not a requirement to solve every incident alone.

**Module version:** 0.2-draft  
**Review baseline:** 1 August 2026  
**Expected study time:** 4–5 hours

## Learning objectives

By the end of this module, a learner should be able to:

- explain the purpose and limits of SOC Level 1 triage;
- apply a repeatable alert-review workflow;
- verify the evidence behind an alert before accepting its title;
- identify affected entities, scope, time window and data-source health;
- distinguish true positive, benign positive, false positive and insufficient evidence;
- record queries, negative results, assumptions and confidence;
- prepare a useful escalation package;
- recognise stop conditions that require immediate escalation.

---

## 1. What triage means

In medicine, triage determines who needs attention first. In a SOC, **alert triage** is the initial process used to decide what an alert represents, how urgent it is, whether more investigation is needed and who should handle the next action.

Triage answers four practical questions:

1. **Is the alert based on valid and trustworthy data?**
2. **What entity and activity are involved?**
3. **How concerning is the activity in context?**
4. **Should the alert be closed, monitored, investigated further or escalated?**

A Level 1 analyst should reach the best supported decision possible within the allotted time and authority. Spending hours on a case that clearly requires a higher tier can delay response.

---

## 2. The NeoLabs L1 triage workflow

Use the following sequence unless a playbook requires a different order.

```text
Receive alert
  → verify source and raw event
  → establish time, identity, asset and action
  → validate telemetry health
  → gather immediate context
  → search related activity
  → consider benign explanations
  → classify and assign confidence
  → document and close or escalate
```

### Step 1 — Read the alert without trusting the conclusion

Record:

- alert name and identifier;
- creation time;
- detection or rule identifier;
- severity assigned by the tool;
- data source;
- affected user, host, application, IP, file or cloud resource;
- the raw event or events that triggered it.

The alert severity is input to the investigation, not the final decision.

### Step 2 — Verify the raw evidence

Ask:

- does the raw record exist?
- did the expected parser or decoder extract the fields correctly?
- is the timestamp event time or ingest time?
- is the source field the original client, a proxy or a collector?
- is the alert based on one record, a threshold or a sequence?
- could duplicate ingestion have inflated the count?

Example:

An alert says “20 failed SSH logins.” Inspection reveals the same event was ingested twice by two collectors, meaning there were 10 attempts, not 20. The activity may still be suspicious, but the analyst must correct the scope.

### Step 3 — Identify the entities

An **entity** is something involved in the activity and useful for correlation.

Common entities include:

- user account or service account;
- source and destination IP address;
- hostname, device ID, agent ID or cloud resource;
- process image, PID, Process GUID or command line;
- file path and hash;
- URL, domain, request ID or session ID;
- role, API key identifier or cloud account;
- pod identifier in the VCC lab.

Record stable identifiers where available. A display name may change; a SID, ARN, agent ID or request ID can be more reliable.

### Step 4 — Establish the investigation window

Start with a narrow window around the alert, then expand only when evidence requires it.

Example approach:

- 5 minutes before and after for a single process or web request;
- 15–30 minutes for an authentication sequence;
- several hours for account takeover or cloud configuration changes;
- days for low-frequency persistence or slow credential abuse.

Do not assume records are perfectly ordered. Clock drift, delayed forwarding and different time zones can move events outside the expected sequence.

### Step 5 — Validate telemetry health

Before interpreting missing evidence, determine whether the source could have produced and delivered it.

Check:

- agent or feed connection state;
- last event time;
- normal event volume;
- audit policy or log configuration;
- parser/decoder success;
- index availability and retention;
- system clock and time zone.

**Important distinction:**

- **No evidence found** means the search did not return the event.
- **Evidence that no activity occurred** requires a source that reliably records the activity and was functioning during the relevant period.

### Step 6 — Gather context

Useful context can include:

- asset criticality and owner;
- account role and normal function;
- normal source locations or peer group;
- maintenance and deployment windows;
- approved vulnerability scanning;
- known automation or scheduled tasks;
- threat-intelligence matches;
- recent password resets or configuration changes;
- prior alerts involving the same entity.

Context should explain behaviour, not automatically excuse it. “It is an administrator account” can increase risk rather than make unusual activity harmless.

### Step 7 — Search for related activity

Good pivots include:

- same user across other hosts;
- same source IP against other users;
- same host before and after the alert;
- process parent and child relationships;
- file hash or path across endpoints;
- request ID across proxy, application and database logs;
- cloud access-key or role session across API events;
- same pod and correlation ID across VCC telemetry.

Record both the query and time range. “Checked logs” is not reproducible.

### Step 8 — Consider alternative explanations

A strong analyst actively tests benign and malicious explanations.

For repeated login failures, alternatives may include:

- password guessing;
- a user typing an old password;
- a service using an expired secret;
- a vulnerability scanner;
- a disconnected system repeatedly retrying;
- an attacker testing leaked credentials.

The goal is not to invent excuses. It is to avoid closing on the first plausible story.

### Step 9 — Classify and assign confidence

Use the programme’s approved categories. A practical training model is:

| Classification | Meaning |
|---|---|
| False positive | Detection logic or parsing produced an incorrect match |
| Benign positive | Detection correctly identified the behaviour, but the activity was authorised or expected |
| Suspicious | Evidence justifies concern, but malicious activity is not confirmed |
| Confirmed incident | Evidence supports unauthorised or harmful activity requiring coordinated response |
| Insufficient evidence | Available telemetry or context cannot support a reliable classification |
| Data-quality issue | The primary problem is missing, duplicated, delayed or incorrectly parsed telemetry |

Add a confidence statement and explain why.

### Step 10 — Document and act

A case record should allow another analyst to continue without repeating all work.

At minimum include:

- alert and affected entities;
- event and ingest times;
- observed facts;
- queries and time ranges;
- correlated evidence;
- relevant negative findings;
- alternative explanations considered;
- current classification and confidence;
- recommended next action;
- reason for closure or escalation.

---

## 3. What evidence proves, suggests and cannot prove

### Example 1 — Firewall allow record

```json
{
  "event_time": "2026-08-01T10:02:44Z",
  "action": "ACCEPT",
  "src_ip": "203.0.113.9",
  "src_port": 53120,
  "dst_ip": "10.20.3.15",
  "dst_port": 443,
  "protocol": "TCP"
}
```

**Proves:** The firewall recorded an allowed flow with those observed network fields.

**Suggests:** A connection may have been established between the source and destination.

**Does not prove:** Which human initiated it, what application data was exchanged, whether authentication succeeded or whether exploitation occurred.

### Example 2 — HTTP 200 response

```text
203.0.113.44 - - [01/Aug/2026:10:06:22 +0000] "GET /api/profile/204 HTTP/1.1" 200 894
```

**Proves:** The web server returned HTTP status 200 for the logged request.

**Suggests:** The route processed successfully from the server’s perspective.

**Does not prove:** The requester was authorised to access profile 204, that the response contained sensitive data or that the client received the full response.

### Example 3 — Antivirus detection

An antivirus alert proves that the product identified content or behaviour matching its detection logic. It does not automatically prove successful execution, persistence or impact. Quarantine status, process telemetry, file origin and surrounding activity are still required.

---

## 4. Alert dispositions in detail

### False positive

Use this when the detection itself is wrong or misleading.

Examples:

- a parser placed the destination IP in the source field;
- a rule matched a harmless string because it lacked boundaries;
- duplicate records caused a threshold to trigger incorrectly;
- a test record was accidentally classified as production activity.

Document the detection problem so it can be tuned.

### Benign positive

The rule correctly detected the behaviour, but context shows it was authorised.

Example:

A rule detects a new scheduled task. Change records confirm an approved backup agent installed it, the binary is signed, the path is expected and the timing matches the deployment window.

The event is not a false positive because the scheduled task genuinely existed.

### Suspicious activity

The evidence is concerning but incomplete.

Example:

A service account logged in interactively from a new source and launched a shell, but account ownership and maintenance context have not been confirmed.

### Confirmed incident

The available evidence satisfies the organisation’s incident criteria.

Example:

An unauthorised account successfully accessed a protected resource, changed configuration and attempted to remove audit records. Multiple sources corroborate the sequence.

### Insufficient evidence

Use this when visibility gaps prevent a defensible result. Do not disguise uncertainty as a benign closure.

Example:

A suspected process-execution alert cannot be validated because process auditing was disabled and the endpoint was rebuilt before evidence collection.

### Data-quality issue

Sometimes the incident is the monitoring failure itself.

Examples:

- a critical application stopped sending authentication logs;
- event times are shifted by two hours;
- a new schema caused decoder fields to become empty;
- records are being ingested twice.

---

## 5. Escalation

### 5.1 Why escalation exists

Escalation transfers a case to someone with additional authority, expertise, tooling or time. It should reduce delay, not merely move responsibility.

### 5.2 Common escalation triggers

Escalate when:

- activity may affect a critical asset or privileged identity;
- a successful compromise is possible or confirmed;
- scope appears larger than one user or host;
- containment may be required;
- malware, persistence or lateral movement is suspected;
- sensitive or regulated data may be involved;
- evidence collection requires tools or permissions the analyst lacks;
- the alert matches a mandatory playbook trigger;
- the investigation exceeds the approved Level 1 time limit;
- telemetry gaps prevent a safe closure;
- the analyst is uncertain whether an action is authorised.

### 5.3 Immediate stop conditions

In the VCC environment, stop and escalate immediately if:

- a task appears to require access outside the assigned student-facing interfaces;
- credentials, private keys or production-looking data appear in evidence;
- telemetry appears to come from another pod;
- a student can change configuration and view another pod’s events;
- a requested action could disrupt the lab host or other students;
- the scenario no longer matches the written scope.

### 5.4 Escalation package

A useful escalation contains:

```text
Case title:
Alert ID and detection:
Current severity / priority:
Affected entities:
Earliest and latest relevant event time:
Observed facts:
Queries and sources reviewed:
Timeline summary:
Current classification:
Confidence and reason:
Alternative explanations considered:
Business or lab impact:
Actions already taken:
Recommended next action:
Unresolved questions:
```

### Weak escalation

> Suspicious login. Please check.

### Stronger escalation

> Wazuh alert `AUTH-SEQ-0142` identified 19 failed logins and one success for `svc-backup` on `pod-03-app` from `203.0.113.44` between 09:14:21Z and 09:18:07Z. The account is labelled as a service identity, and interactive use is not documented in the available profile. I searched the same source across all assigned pod authentication records for ±30 minutes and found failures against two additional accounts. No approved maintenance note is attached. Post-login process telemetry is unavailable because that source stopped reporting at 09:16Z. Classification: suspicious; confidence medium. Escalation requested for account-owner validation and telemetry-gap review.

---

## 6. Query and evidence journal

Every meaningful search should be reproducible.

| Time run | Data source | Query or filter | Time range | Result summary | Next pivot |
|---|---|---|---|---|---|
| 10:20Z | Wazuh alerts | `data.user: "svc-backup"` | 09:00–10:00Z | 20 authentication records | Search same source IP |
| 10:23Z | Wazuh alerts | `data.srcip: "203.0.113.44"` | 08:45–10:15Z | Three accounts targeted | Check success and post-login events |
| 10:27Z | Endpoint events | host `pod-03-app` | 09:15–09:30Z | No records after 09:16Z | Validate source health |

A negative result matters only when the data source and query were capable of finding the activity.

---

## 7. Worked investigation — possible web-account takeover

### Alert

```json
{
  "rule": "Successful login after repeated failures",
  "user": "student17",
  "src_ip": "198.51.100.73",
  "destination": "vcc-pod-02",
  "failure_count": 12,
  "success_time": "2026-08-01T11:42:08Z",
  "risk": "high"
}
```

### Step 1 — Validate

The analyst confirms 12 distinct failed events and one success. No duplicates are present. The source IP field came from the application after trusted-proxy processing.

### Step 2 — Context

The user normally signs in from a different example source range. No scheduled test or password-reset activity is documented.

### Step 3 — Correlation

The analyst searches the session ID created by the success and finds:

- profile viewed;
- email-change page opened;
- password reset requested;
- no confirmed profile change;
- session revoked five minutes later by the scenario controller.

### Step 4 — Interpretation

The sequence is consistent with attempted account takeover, but the lab record does not identify the actor or prove credentials were obtained through any specific method.

### Step 5 — Disposition

**Classification:** Confirmed synthetic security incident within the assigned VCC scenario.  
**Confidence:** High.  
**Reason:** Successful access from the failure source followed by sensitive account actions, corroborated by session and application records.  
**Escalation:** Provide timeline and affected session to mentor; recommend credential reset and review of other accounts targeted by the source within the scenario.

---

## 8. Time management in L1 triage

A fixed time limit is organisation-specific. The purpose is to prevent one difficult case from blocking the queue.

A practical approach:

- first 2 minutes: verify alert, source and affected entity;
- next 5–10 minutes: gather immediate context and perform core pivots;
- decision point: close with evidence, continue under a playbook or escalate;
- document throughout.

Do not use a time limit to force a benign answer. If the result remains uncertain, state the uncertainty and escalate appropriately.

---

## 9. Common mistakes

### Searching only alerts

Relevant events may exist in raw or archive data without triggering a rule.

### Ignoring time zones

Comparing local application time with UTC cloud time can create a false sequence.

### Copying raw logs without analysis

Evidence must be connected to the question. A large dump is not a clear escalation.

### Closing because an IOC is not on a threat list

Absence from a list does not make an address or file safe.

### Overstating identity

An account name or source IP does not automatically identify the human responsible.

### Failing to record negative results

A later analyst needs to know what was searched, where and for what time range.

### Recommending destructive action too early

Containment should be proportionate and authorised. Preserve evidence and consider business impact.

---

## 10. Guided practice

Use the synthetic records in `sample-logs/authentication/` when available.

Prepare:

1. a one-paragraph alert summary;
2. a table of affected entities;
3. three queries and their results;
4. an observation–interpretation–conclusion statement;
5. a classification and confidence level;
6. an escalation package or closure justification.

Do not assume the alert is malicious. Test at least two alternative explanations.

---

## 11. Review questions

1. Why must an analyst inspect the raw event behind an alert?
2. What is the difference between a false positive and a benign positive?
3. When can a negative search result be treated as meaningful evidence?
4. Name five useful correlation entities.
5. Why should the analyst record time ranges with queries?
6. Give three examples of immediate VCC stop conditions.
7. What information makes an escalation useful to Level 2?
8. Why can a telemetry outage require escalation even when no compromise is confirmed?
9. Classify this statement: “The host stopped reporting after the successful login, so the attacker disabled logging.” What is wrong with it?
10. How should an analyst communicate uncertainty?

---

## References

- NIST SP 800-61 Rev. 3.
- NIST SP 800-92 and SP 800-92 Rev. 1 Initial Public Draft.
- Wazuh official documentation: alert management, event logging, WQL and dashboard navigation.
- MITRE ATT&CK v19.1 Detection Strategies, Analytics and Data Components.
- NeoLabs Log Literacy Manual.
- `research/AUTHORITATIVE_SOURCE_REGISTER.md`.
