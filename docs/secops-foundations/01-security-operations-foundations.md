# Module 1 — Security Operations, SOC Models and Analyst Roles

> **NeoLabs SOC Level 1 principle:** A dashboard can display security information, but a Security Operations Center is the people, processes, evidence, technology and authority used to make and act on security decisions.

**Module version:** 0.2-draft  
**Review baseline:** 1 August 2026  
**Expected study time:** 3–4 hours

## Learning objectives

By the end of this module, a learner should be able to:

- define Security Operations and explain why a SOC is more than a room or SIEM dashboard;
- describe internal, outsourced, hybrid and virtual SOC models;
- distinguish the typical responsibilities of SOC Level 1, Level 2 and Level 3 personnel;
- use the terms log, event, alert, case, finding, incident, evidence, IOC and IOA correctly;
- distinguish severity, priority, confidence and business impact;
- explain the boundary between investigation, escalation and authorised response;
- describe a normal SOC shift from handover to closure.

---

## 1. What Security Operations means

### Professional definition

**Security Operations**, commonly shortened to **SecOps**, is the continuing organisational capability used to monitor technology environments, identify suspicious or harmful activity, investigate security-relevant events, coordinate response and improve defensive controls.

SecOps is continuous because organisational systems continue generating activity outside normal office hours. Even a small organisation that does not operate a 24-hour staffed SOC still needs processes for receiving alerts, deciding urgency and contacting someone who is authorised to act.

### Plain-language explanation

SecOps is the part of cybersecurity that asks:

1. What is happening in our systems right now?
2. Is any of it unsafe, unauthorised or unusual enough to investigate?
3. What evidence supports that conclusion?
4. Who needs to know or act?
5. What should change so the same problem is detected or prevented more effectively next time?

A SOC supports those questions with analysts, procedures, logging, SIEM or XDR platforms, endpoint tools, network data, cloud audit trails, ticketing systems, communication channels and management authority.

### People, process and technology

| Element | What it contains | Why it matters |
|---|---|---|
| People | Analysts, incident responders, threat hunters, engineers, IT staff, legal, management and system owners | Tools cannot decide business impact or authorise every response action |
| Process | Triage steps, severity definitions, escalation paths, playbooks, evidence handling and reporting | A repeatable process reduces inconsistent decisions during pressure |
| Technology | SIEM, Wazuh, endpoint protection, firewalls, cloud logs, threat intelligence and case systems | Technology collects and organises evidence at a scale people cannot review manually |

A mature SOC keeps these elements aligned. Buying a SIEM without staffing, useful logs or escalation procedures creates an expensive dashboard rather than an effective security operation.

---

## 2. What a Security Operations Center is

A **Security Operations Center (SOC)** is the team and operating structure that centralises security monitoring and incident-handling activities. “Center” does not require a physical room. A distributed team can operate a virtual SOC if it has defined responsibilities, secure tools, reliable communication and an established chain of authority.

### Core SOC functions

A SOC commonly performs some combination of the following:

- monitoring alert queues and important data sources;
- validating that required telemetry is arriving;
- triaging and classifying alerts;
- investigating activity across identities, hosts, applications, networks and cloud resources;
- documenting evidence and maintaining case records;
- escalating confirmed or unresolved risk;
- coordinating containment and recovery with authorised teams;
- tuning detections and reducing avoidable noise;
- measuring coverage, workload and response performance;
- preserving lessons from incidents and near misses.

### SOC is not the same as IT support

IT support and SecOps often cooperate, but their primary questions differ.

| IT support question | SecOps question |
|---|---|
| Why can the user not sign in? | Is the failed sign-in activity normal, accidental or hostile? |
| Why is the server slow? | Is the slowdown associated with scanning, resource abuse or unauthorised execution? |
| How do we restore the service? | What evidence must be preserved before restoration, and could recovery reintroduce the threat? |
| Which update fixes the error? | Does the missing update expose a vulnerability that changes incident priority? |

One event can require both teams. A locked account might be a normal support issue, a password attack or both.

---

## 3. Common SOC operating models

### 3.1 Internal SOC

An **internal SOC** is operated by the organisation’s own employees. It usually has deeper knowledge of the organisation’s systems, business processes and approved administrative behaviour.

**Advantages**

- strong access to internal context and system owners;
- direct control over tooling and procedures;
- easier alignment with organisational priorities.

**Challenges**

- staffing a 24-hour operation can be expensive;
- specialist expertise may be difficult to recruit;
- small teams can experience alert fatigue and coverage gaps.

### 3.2 Managed Security Service Provider or Managed SOC

A **Managed Security Service Provider (MSSP)** or managed SOC monitors systems for multiple customer organisations under a service agreement.

**Advantages**

- broader staffing coverage;
- access to established platforms and specialist personnel;
- useful for organisations that cannot build a complete internal SOC.

**Challenges**

- analysts may initially lack business context;
- customer and provider responsibilities must be clearly divided;
- escalation and evidence-sharing delays can affect response.

### 3.3 Hybrid SOC

A **hybrid SOC** combines internal capability with an external provider. For example, a provider may monitor overnight alerts while internal staff handle daytime investigations and response decisions.

This model works only when ownership is explicit. An alert should never remain unresolved because both parties assumed the other was responsible.

### 3.4 Virtual or distributed SOC

A **virtual SOC** operates across different locations without requiring one physical room. It still needs controlled access, shift handover, case tracking, secure communications and an on-call structure.

### 3.5 Follow-the-sun model

Large organisations may hand monitoring between teams in different time zones. This provides continuous coverage but makes clear case notes and handover quality essential.

---

## 4. SOC roles and tier boundaries

Role names differ between organisations. “Level 1” does not always describe exactly the same permissions or responsibilities. The VCC programme uses the following learning model.

### 4.1 SOC Level 1 — monitoring and triage

A Level 1 analyst is commonly the first human reviewer of an alert. The analyst’s job is not to prove every incident alone. It is to perform a reliable first investigation and make the next decision defensible.

Typical responsibilities include:

- review the alert and underlying raw event;
- verify the source, time and affected entity;
- determine whether expected telemetry is present;
- collect basic context about the account, host, application or resource;
- search a reasonable time window for related activity;
- distinguish obvious benign causes from unresolved or suspicious activity;
- classify the alert using the organisation’s definitions;
- document facts, interpretation, uncertainty and queries performed;
- escalate when scope, impact, permissions or complexity exceed Level 1 authority.

In the VCC programme, interns may recommend an action but do not perform unauthorised containment against lab infrastructure.

### 4.2 SOC Level 2 — deeper investigation and coordinated response

Level 2 analysts usually handle escalated cases requiring broader correlation or response coordination. Activities may include:

- reconstructing a detailed timeline across several data sources;
- scoping affected identities and assets;
- validating whether an attack succeeded;
- coordinating approved containment with IT, cloud or application teams;
- collecting additional forensic evidence;
- determining root cause and likely entry path;
- updating stakeholders and case severity;
- identifying detection gaps.

### 4.3 SOC Level 3 — threat hunting, advanced analysis and detection engineering

Level 3 titles can include threat hunter, senior analyst, malware analyst or detection engineer. Typical work may include:

- hypothesis-driven hunting beyond existing alerts;
- advanced endpoint, network or malware analysis;
- researching adversary behaviour;
- creating and validating new detections;
- leading complex incidents;
- improving playbooks and architecture;
- mentoring junior analysts.

### 4.4 Supporting roles

A SOC depends on people outside the tier structure:

- **SOC manager:** staffing, process ownership, metrics and escalation authority;
- **SIEM/platform engineer:** ingestion pipelines, parsers, storage, upgrades and platform health;
- **detection engineer:** threat hypotheses, analytics, validation and tuning;
- **incident commander:** coordinates a major incident and keeps decision-making organised;
- **forensic examiner:** acquires and analyses evidence using controlled methods;
- **threat intelligence analyst:** provides adversary, campaign and indicator context;
- **system or application owner:** explains expected behaviour and business impact;
- **legal/privacy/communications:** advises on obligations and external communication.

---

## 5. Core terminology

### 5.1 Log

A **log** is a stored record produced by a system, application, service, device or security tool.

Example:

```text
2026-08-01T09:14:21Z web01 sshd[24109]: Failed password for invalid user admin from 203.0.113.44 port 44218 ssh2
```

The record states that an SSH authentication attempt failed. It does not identify the human behind the source address and does not prove compromise.

### 5.2 Event

An **event** is a specific occurrence represented by one or more log records. A successful sign-in, file change, process start or cloud API request can be an event.

### 5.3 Alert

An **alert** is a notification produced when a rule, analytic, threshold or model decides that an event or sequence deserves analyst attention.

An alert is a lead, not a verdict. A rule can match correctly while the underlying activity remains authorised.

### 5.4 Case or ticket

A **case** or **ticket** is the organised record of analyst work. It normally stores the alert, affected entities, evidence, timeline, queries, decisions, communications and next actions.

### 5.5 Finding

A **finding** is a statement supported by analysed evidence.

Weak finding:

> The user was hacked.

Better finding:

> Authentication logs recorded 47 failed sign-ins for `learner-17` from `203.0.113.44`, followed by one successful sign-in from the same source. The account’s normal source range is not available, so unauthorised access is suspected but not yet confirmed. Confidence: medium.

### 5.6 Incident

A **cybersecurity incident** is an occurrence that actually or imminently jeopardises information or systems, violates security policy, or requires coordinated response according to the organisation’s definition.

Not every alert becomes an incident. Organisations should document their own declaration criteria.

### 5.7 Evidence

**Evidence** is information preserved and interpreted to support or challenge a conclusion. Good evidence records include source, time, collection method, relevant fields and integrity considerations.

A screenshot can support a report, but the underlying event or export is usually stronger because it is searchable and contains more fields.

### 5.8 Indicator of Compromise and Indicator of Attack

An **Indicator of Compromise (IOC)** is an observable value associated with known or suspected malicious activity, such as a file hash, domain, IP address or registry path.

An **Indicator of Attack (IOA)** focuses on behaviour that may show an attack in progress, such as repeated credential guessing followed by unusual access.

IOC caution: addresses, domains and hashes can be shared, reassigned, spoofed or used in benign contexts. An IOC match requires validation.

---

## 6. Severity, priority, impact and confidence

These terms are related but not interchangeable.

### Severity

**Severity** describes the potential or confirmed seriousness of the security condition. An organisation may calculate severity from technical impact, affected asset criticality, data sensitivity and scope.

### Priority

**Priority** determines the order and urgency of work. A technically severe event may receive lower immediate priority if it is fully contained, while a medium-severity alert affecting an executive account may require immediate review.

### Business impact

**Business impact** describes consequences to operations, finances, safety, legal obligations, reputation or customers.

### Confidence

**Confidence** describes how strongly available evidence supports the current conclusion.

| Confidence | Appropriate use |
|---|---|
| Low | Limited evidence, major visibility gaps or several plausible explanations |
| Medium | Multiple supporting observations but missing confirmation or context |
| High | Strong corroborated evidence with few reasonable alternatives |

Confidence is not the same as severity. A potentially critical incident can begin with low-confidence evidence and still require urgent escalation.

### Worked example

An alert reports a new administrator account on a test server.

- **Potential severity:** High, because unauthorised administrator creation can enable control of the host.
- **Current confidence:** Medium, because the creation event is confirmed but change approval has not been checked.
- **Priority:** High until the system owner confirms whether the account was expected.
- **Impact:** Unknown; no activity by the new account has yet been identified.

---

## 7. A normal SOC shift

### 7.1 Handover

The incoming analyst reviews:

- open high-priority cases;
- pending owner responses;
- known maintenance windows;
- platform or data-source outages;
- threat advisories relevant to monitored systems;
- actions that require follow-up.

A good handover states what is known, what remains uncertain and the next action. “Still investigating” is not enough.

### 7.2 Platform and queue health

Before trusting the alert queue, the analyst checks that the monitoring system is healthy:

- are agents or feeds connected?
- are event volumes within an expected range?
- are timestamps current?
- are parsing fields populated?
- are index or storage errors present?

No alerts can mean no threats, a quiet environment or a broken telemetry pipeline.

### 7.3 Alert triage

The analyst opens an alert, reviews raw evidence, enriches context, searches related events and decides whether to close, continue or escalate.

### 7.4 Case documentation

Work is recorded during the investigation, not reconstructed from memory at the end. Queries, time ranges and important negative results should be documented.

### 7.5 Escalation and communication

The analyst follows the defined escalation route, supplies relevant evidence and avoids overstating conclusions.

### 7.6 Shift closure

Before handover, the analyst updates open cases, identifies deadlines and records platform issues. Unwritten knowledge is easily lost between shifts.

---

## 8. Worked scenario — failed sign-ins followed by success

### Alert summary

```text
Detection: Repeated authentication failures followed by success
Account: svc-backup
Destination: app-pod-03
First failure: 2026-08-01T09:14:21Z
Success: 2026-08-01T09:18:07Z
Source: 203.0.113.44
```

### Initial questions

1. Is `svc-backup` expected to sign in interactively?
2. Is the source address expected for the service?
3. What authentication method was used?
4. What happened after the success?
5. Did the same source target other accounts?
6. Was there a maintenance or deployment window?
7. Are the timestamps and source fields trustworthy?

### Observation, interpretation and conclusion

**Observation:** The monitored authentication source recorded 19 failures for `svc-backup` from `203.0.113.44`, followed by one successful authentication from the same source.

**Interpretation:** A failure-to-success sequence can occur during password guessing, but it can also result from a stored credential being corrected or an automation retrying after a secret rotation.

**Current conclusion:** Suspicious authentication requiring escalation unless approved maintenance explains the sequence. Confidence: medium.

**Next evidence:** Post-authentication activity, deployment records, service owner confirmation and other accounts targeted by the source.

---

## 9. Common beginner mistakes

### Mistake 1 — treating the alert title as evidence

The title is a summary produced by detection logic. Always inspect the records that caused it.

### Mistake 2 — assuming unusual means malicious

An anomaly differs from the baseline. It becomes suspicious or malicious only when context and evidence support that judgment.

### Mistake 3 — using “false positive” for every benign alert

A rule may correctly detect behaviour that is real but authorised. Some teams call this a **benign positive** rather than a false positive. Use the organisation’s definitions consistently.

### Mistake 4 — escalating without a useful handoff

“Please investigate” transfers work but not understanding. Include the trigger, affected entities, timeline, searches, evidence, classification and unresolved questions.

### Mistake 5 — taking response actions outside authority

Disabling accounts, blocking addresses or isolating systems can affect operations and evidence. Follow the authorised process.

### Mistake 6 — ignoring telemetry health

Missing data is not evidence that nothing happened.

---

## 10. Guided exercise

For each statement, identify whether it is an observation, interpretation or conclusion.

1. `Event ID 4625 recorded a failed network logon for account student03 from 203.0.113.80.`
2. `The source address is outside the account's documented normal range.`
3. `The activity is suspicious and should be escalated for possible password guessing.`
4. `No process-creation events were found in the available five-minute window.`
5. `Endpoint process auditing may be disabled, so the absence of process events does not rule out execution.`

Suggested discussion:

- Statements 1 and 4 are observations.
- Statements 2 and 5 are interpretations based on context or visibility.
- Statement 3 is a conclusion and action decision.

---

## 11. Review questions

1. Why is a SOC more than a SIEM dashboard?
2. What is the practical difference between an event and an alert?
3. What should a Level 1 analyst normally include in an escalation?
4. Why can severity be high while confidence remains low?
5. Give one example of an IOC and one limitation of IOC-based decisions.
6. What does a quiet alert queue fail to prove?
7. Explain the difference between observation, interpretation and conclusion.
8. When should a Level 1 analyst stop investigating and escalate?

---

## References

- NIST SP 800-61 Rev. 3, *Incident Response Recommendations and Considerations for Cybersecurity Risk Management*.
- NIST SP 800-92, *Guide to Computer Security Log Management*.
- NIST SP 800-92 Rev. 1 Initial Public Draft, *Cybersecurity Log Management Planning Guide*.
- MITRE ATT&CK v19.1.
- Wazuh official documentation, architecture and data-analysis sections.
- `research/AUTHORITATIVE_SOURCE_REGISTER.md`.
