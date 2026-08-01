# Module 4 — Incident Response and Playbook Development

> **NeoLabs SOC Level 1 principle:** Incident response is not only what happens after an alert. Preparation, governance, logging, access control, communication and recovery readiness determine whether the organisation can respond effectively.

**Module version:** 0.2-draft  
**Review baseline:** 1 August 2026  
**Expected study time:** 5–7 hours

## Learning objectives

By the end of this module, a learner should be able to:

- explain the relationship between cybersecurity risk management and incident response;
- describe the current NIST SP 800-61 Rev. 3 approach using the six CSF 2.0 Functions;
- compare current NIST framing with older preparation/detection/containment/eradication/recovery/lessons models without confusing them;
- distinguish an alert, cybersecurity event, declared incident and crisis;
- explain the roles of Level 1 analysts, incident responders, incident commanders, system owners and business stakeholders;
- create a practical playbook with triggers, evidence requirements, decision points, escalation and recovery checks;
- distinguish containment, eradication and recovery actions;
- explain why response actions require authority and evidence preservation;
- use an incident report and evidence log during a synthetic VCC scenario.

---

## 1. What incident response means

**Cybersecurity incident response** is the coordinated capability used to prepare for, detect, analyse, contain, address, recover from and learn from cybersecurity incidents.

It includes more than technical commands. Effective response depends on:

- policy and authority;
- current asset and identity information;
- useful logging;
- trained people;
- communication paths;
- tested backups;
- legal, privacy and contractual awareness;
- technical containment and recovery procedures;
- improvement after the incident.

### Plain-language explanation

Incident response is how an organisation answers:

1. What happened?
2. Is it actually a cybersecurity incident?
3. What is affected?
4. What must be protected immediately?
5. Which evidence must be preserved?
6. Who is authorised to decide and act?
7. How do we remove or reduce the threat?
8. How do we restore safe operations?
9. What must change afterward?

---

## 2. Current NIST framing

NIST SP 800-61 Rev. 3, finalised in April 2025, aligns incident response with the six NIST Cybersecurity Framework 2.0 Functions:

```text
GOVERN
IDENTIFY
PROTECT
DETECT
RESPOND
RECOVER
```

The six Functions are not simply six chronological boxes. Govern, Identify and Protect help prepare the organisation and reduce incident likelihood or impact. Detect, Respond and Recover contain the core operational incident-response activity, while lessons and changes feed back into all Functions.

## 2.1 Govern

Govern establishes direction, accountability and risk decisions.

Incident-response examples:

- policy and incident definitions;
- executive sponsorship;
- roles and authorities;
- legal, regulatory and contractual requirements;
- third-party responsibilities;
- escalation thresholds;
- risk tolerance;
- reporting and communication governance.

### SOC Level 1 relevance

The Level 1 analyst follows approved definitions and escalation paths rather than inventing severity or response authority during an alert.

## 2.2 Identify

Identify develops understanding of assets, services, risks, dependencies and vulnerabilities.

Incident-response examples:

- asset inventory;
- data classification;
- identity and privilege inventory;
- dependency maps;
- vulnerability information;
- risk assessment;
- critical business-service identification.

### SOC Level 1 relevance

An unusual login to an ordinary test account and an unusual login to a critical administrator account may require different priority because the identity and business context differ.

## 2.3 Protect

Protect applies safeguards to reduce the likelihood and impact of adverse events.

Incident-response examples:

- access control and MFA;
- secure configuration;
- patching;
- awareness training;
- data protection;
- resilient architecture;
- backup protection;
- logging and monitoring preparation.

### SOC Level 1 relevance

Protection controls create the evidence and boundaries used during triage. Weak logging or shared credentials reduce the analyst’s ability to reach a defensible conclusion.

## 2.4 Detect

Detect identifies and analyses possible cybersecurity events.

Examples:

- event collection;
- SIEM rules and analytics;
- anomalous activity review;
- monitoring for control failure;
- alert validation;
- initial analysis and incident determination.

### SOC Level 1 relevance

This is where much L1 triage work occurs: validate the alert, review evidence, search related activity, classify and escalate.

## 2.5 Respond

Respond contains actions taken after an incident is detected and declared.

Examples:

- incident management;
- analysis and scope expansion;
- internal and external communication;
- containment;
- mitigation;
- evidence handling;
- coordinated decision-making.

### SOC Level 1 relevance

L1 analysts usually document and escalate. They may perform only the response actions explicitly authorised by a playbook.

## 2.6 Recover

Recover restores affected assets, services and operations and communicates recovery status.

Examples:

- restoration from trusted backups;
- rebuilding systems;
- credential reset;
- verification of safe service operation;
- monitoring after restoration;
- stakeholder communication;
- recovery improvement.

### SOC Level 1 relevance

Analysts may monitor restored systems and confirm that alert patterns, telemetry and expected behaviour return to normal.

---

## 3. Older incident-handling phase models

Many textbooks and older procedures describe a sequence such as:

```text
Preparation
  → Detection and Analysis
  → Containment
  → Eradication
  → Recovery
  → Lessons Learned
```

NIST SP 800-61 Rev. 2 used a four-phase life cycle that grouped containment, eradication and recovery together and included post-incident activity. That publication was superseded by Rev. 3 in April 2025.

The older terms remain operationally useful. Do not say they are “wrong,” but do not present them as the current NIST Rev. 3 structure.

### Practical mapping

| Traditional term | Current CSF-aligned location |
|---|---|
| Preparation | Govern, Identify and Protect, with preparation across all Functions |
| Detection and analysis | Detect and parts of Respond |
| Containment and eradication | Respond |
| Recovery | Recover |
| Lessons learned | Feedback into Govern, Identify, Protect, Detect, Respond and Recover |

---

## 4. Alert, event, incident and crisis

### Security event

A security-relevant occurrence recorded by a system or reported by a person.

### Alert

A detection-generated notification that an event or sequence deserves review.

### Cybersecurity incident

An occurrence that meets the organisation’s declared incident criteria because it actually or imminently threatens systems, information, policy or operations and requires coordinated response.

### Major incident or crisis

An incident with significant operational, financial, safety, legal, customer or reputational impact that requires executive coordination beyond the normal SOC process.

### Important distinction

The SIEM can generate an alert. An authorised organisational process declares an incident. A Level 1 analyst may recommend declaration or escalate evidence, but the exact authority depends on policy.

---

## 5. Incident-response roles

## 5.1 SOC Level 1 analyst

- validates alert evidence;
- gathers initial context;
- identifies affected entities;
- records queries and a preliminary timeline;
- follows the relevant playbook;
- escalates on defined triggers;
- avoids unauthorised containment.

## 5.2 SOC Level 2 or incident responder

- expands scope;
- correlates additional sources;
- validates compromise and impact;
- coordinates authorised containment;
- preserves and requests deeper evidence;
- develops eradication and recovery recommendations.

## 5.3 Incident commander

The **incident commander** coordinates the response, maintains priorities, assigns owners, manages decisions and ensures communication. The commander does not need to perform every technical investigation personally.

## 5.4 System and service owners

They explain expected operation, approve or perform service-impacting actions and assess business consequences.

## 5.5 IT, cloud and application teams

They may isolate hosts, revoke credentials, change firewall or IAM policies, deploy fixes, restore services and validate normal operation.

## 5.6 Legal, privacy, communications and management

These stakeholders assess obligations, sensitive-data exposure, notification, public communication and business risk.

### VCC training boundary

Mentors and operators retain containment authority over VCC infrastructure. Interns investigate the approved student-facing evidence and make recommendations.

---

## 6. Incident classification and declaration

An organisation should define incident categories and thresholds before an event occurs.

Possible factors:

- affected asset criticality;
- privilege of affected identities;
- confidentiality, integrity or availability impact;
- number of affected users or systems;
- persistence or lateral movement;
- data access or exfiltration evidence;
- legal or contractual significance;
- operational disruption;
- confidence in the evidence;
- whether the condition remains active.

### Severity and confidence remain separate

A suspected compromise of a privileged cloud account may be potentially critical even when initial confidence is medium. Urgent escalation can be justified by risk while investigation continues.

---

## 7. Containment, eradication and recovery

## 7.1 Containment

**Containment** limits the spread, activity or impact of the incident.

Examples:

- revoke a compromised session;
- disable or restrict an account;
- isolate an endpoint;
- block a known malicious destination;
- remove an exposed service from public access;
- temporarily disable a vulnerable function;
- preserve a system before rebuilding.

### Containment caution

Containment can disrupt business, alert an adversary or destroy volatile evidence. It must be proportionate and authorised.

## 7.2 Eradication

**Eradication** removes the cause or remaining threat.

Examples:

- remove malicious persistence;
- patch the exploited vulnerability;
- delete unauthorised accounts after evidence preservation;
- rotate exposed secrets;
- remove a malicious application or configuration;
- close the exploited access path.

Eradication is not only deleting a suspicious file. The root cause and all affected scope must be addressed.

## 7.3 Recovery

**Recovery** restores trustworthy operation.

Examples:

- rebuild from a trusted image;
- restore clean data from backup;
- verify patched configuration;
- re-enable services gradually;
- monitor closely for recurrence;
- confirm logging and detection are working;
- communicate service status.

### Recovery validation

A service being reachable does not prove recovery is complete. Validate identity, integrity, security controls, telemetry and expected business functions.

---

## 8. Evidence preservation during response

Response and evidence collection can conflict. For example, restarting a system may restore service but remove volatile evidence.

Level 1 analysts should:

- record important event IDs and timestamps;
- preserve approved exports before filters or retention change;
- document who performed each action and when;
- distinguish source evidence from screenshots;
- avoid modifying the affected system without authority;
- record visibility gaps created by containment;
- protect credentials and personal information.

The NeoLabs evidence log is a training record, not a substitute for formal forensic chain-of-custody procedures where those are required.

---

## 9. What a playbook is

A **playbook** is a documented, repeatable response guide for a particular incident type or trigger.

A playbook supports consistent action under pressure. It does not remove analyst judgment. It should define decision points, authority and stop conditions rather than list commands without context.

### Playbook versus runbook

Terminology differs, but a useful distinction is:

- **Playbook:** broader incident strategy, decisions, roles and coordinated actions.
- **Runbook:** detailed procedure for a specific repeatable technical task.

Example:

- Account-takeover playbook: triage, declaration, communication, containment and recovery decisions.
- Session-revocation runbook: exact approved steps to revoke sessions in one identity platform.

---

## 10. Required playbook sections

## 10.1 Purpose and scope

State:

- incident type;
- systems and environments covered;
- authorised users;
- exclusions;
- linked policies.

## 10.2 Trigger

Define what starts the playbook:

- SIEM alert;
- user report;
- threat-intelligence notification;
- monitoring outage;
- cloud-provider alert;
- confirmed vulnerability exposure.

A trigger starts investigation. It does not necessarily confirm an incident.

## 10.3 Required evidence

List the minimum sources and fields needed.

Example for account takeover:

- failed and successful authentication;
- MFA result;
- session creation and revocation;
- source and device context;
- password or email changes;
- sensitive actions after login;
- account owner confirmation;
- telemetry-health status.

## 10.4 Initial L1 actions

Keep them bounded and reproducible:

1. validate the underlying event;
2. establish absolute UTC range;
3. identify account, source, asset and session;
4. search preceding and following activity;
5. check known maintenance and account role;
6. document observations and queries;
7. classify and escalate on defined conditions.

## 10.5 Escalation criteria

Examples:

- privileged account affected;
- successful access after suspicious failures;
- sensitive account or data change;
- multiple accounts targeted;
- active session remains valid;
- missing telemetry after the success;
- possible cross-pod data exposure;
- response action needed;
- uncertainty cannot be resolved within L1 authority.

## 10.6 Containment options

Each option should state:

- authorising role;
- operational impact;
- evidence consideration;
- verification step;
- rollback or recovery dependency.

## 10.7 Eradication and recovery

Define how root cause is addressed and how trustworthy operation is confirmed.

## 10.8 Communication

State:

- who receives initial escalation;
- who owns stakeholder updates;
- approved communication channels;
- required update frequency;
- what information must not be placed in public channels.

## 10.9 Closure and improvement

Require:

- final classification;
- timeline;
- affected scope;
- actions and owners;
- evidence references;
- unresolved risks;
- detection and logging improvements;
- playbook revision if needed.

---

## 11. Worked playbook — suspected account takeover

### Purpose

Investigate authentication failures followed by a successful login and sensitive account activity in an authorised synthetic VCC scenario.

### Trigger

A Wazuh rule reports success after repeated failures for the same account.

### L1 evidence requirements

- raw failure and success records;
- user and source address;
- authentication method;
- session ID;
- post-login actions;
- other accounts targeted by the source;
- telemetry-health events;
- approved maintenance or account-owner context.

### L1 workflow

1. Set an absolute UTC range beginning 15 minutes before the first failure.
2. Validate distinct event IDs and exclude duplicate ingestion.
3. Count failures for the account and source.
4. Confirm whether the success came from the same source.
5. Pivot to the created session.
6. Identify account, authorisation and application events.
7. Search for other targeted users.
8. Identify telemetry gaps.
9. write observation, interpretation and conclusion.
10. Escalate if success, sensitive action, privileged identity, multi-account targeting or visibility gap is present.

### Potential containment recommendations

An authorised responder may:

- revoke the suspicious session;
- reset or rotate credentials;
- require fresh MFA enrolment when appropriate;
- temporarily restrict the account;
- block the source when justified and operationally safe;
- preserve relevant identity and application logs.

The intern documents recommendations and observed scenario-controller actions but does not directly administer VCC identity systems.

### Eradication questions

- How were credentials obtained or guessed?
- Are other credentials or sessions affected?
- Was a weak authentication or recovery flow involved?
- Was the account used to create persistence?
- Which control or vulnerability enabled access?

### Recovery checks

- suspicious sessions revoked;
- credentials rotated;
- expected owner access restored;
- sensitive account values verified;
- monitoring and logging healthy;
- no repeat activity during the defined observation period;
- detection and rate-limit controls reviewed.

---

## 12. Playbook anti-patterns

### A list of destructive commands

A playbook should not assume every alert deserves isolation, deletion or blocking.

### No authority information

Analysts need to know who can approve each action.

### No evidence requirements

Without evidence criteria, the team may act on an alert title alone.

### One path with no decision points

Real incidents differ. Include conditions for close, continue, escalate and declare.

### No recovery validation

“Service restored” is incomplete without trust and monitoring checks.

### Secrets inside the playbook

Use secret references, never actual passwords, tokens or private endpoints.

### No owner or review date

Outdated playbooks can be worse than no playbook when tools and systems change.

---

## 13. Incident communication

Good incident communication is:

- factual;
- time-stamped;
- clear about uncertainty;
- appropriate for the audience;
- limited to approved recipients;
- consistent with the case record.

### Technical update example

> At 09:18:07Z, synthetic authentication telemetry recorded a successful login for `svc-backup` from the source that produced five earlier failures. The resulting session later accessed a profile and attempted cross-pod evidence access, which the application denied. A process-telemetry gap began before the success, so endpoint activity cannot currently be confirmed or excluded. Classification: suspicious synthetic incident; confidence medium-high. Session revocation is recorded. Further owner and telemetry review is requested.

### Poor update

> Hacker entered the system and tried to steal everything.

The poor update overstates identity, intent and impact.

---

## 14. Post-incident improvement

Improvement should consider:

- logging fields and source coverage;
- detection logic and false-positive patterns;
- playbook clarity;
- escalation delay;
- authority and communication gaps;
- backup and recovery performance;
- identity and access controls;
- asset and dependency records;
- training needs;
- third-party coordination.

A lessons-learned review should not become a blame session. Focus on system and process improvement while preserving accountability.

---

## 15. Guided exercise

Using Practice Lab 01:

1. decide whether the evidence meets the training definition of an incident;
2. map observed actions to Detect, Respond and Recover;
3. identify which Govern, Identify and Protect activities should have existed before the alert;
4. draft an account-takeover playbook using the template below;
5. identify three actions outside L1 authority;
6. write one technical update and one management-friendly summary;
7. list five lessons or control improvements.

### Playbook draft template

```text
Title:
Owner:
Version/review date:
Purpose and scope:
Trigger:
Required evidence:
Initial L1 actions:
Decision points:
Escalation criteria:
Incident declaration authority:
Containment options and authorisers:
Eradication requirements:
Recovery checks:
Communication plan:
Evidence and reporting requirements:
Closure criteria:
Post-incident review:
References:
```

---

## 16. Review questions

1. How does NIST SP 800-61 Rev. 3 organise incident-response recommendations?
2. Why is the older six-step model still useful but not the current NIST structure?
3. Who normally declares an incident?
4. What is the difference between containment and eradication?
5. Why can containment damage evidence?
6. What makes a playbook different from a simple command list?
7. Name five required playbook sections.
8. Why should recovery include logging and monitoring validation?
9. What information belongs in an incident update?
10. How do lessons feed back into all six CSF Functions?

---

## Authoritative references

- NIST SP 800-61 Rev. 3, *Incident Response Recommendations and Considerations for Cybersecurity Risk Management: A CSF 2.0 Community Profile*.
- NIST Cybersecurity Framework 2.0.
- NIST SP 800-61 Rev. 2, withdrawn and superseded, for historical incident-handling phase terminology.
- CISA, *Federal Government Cybersecurity Incident and Vulnerability Response Playbooks*, used as public playbook structure context rather than as VCC policy.
- NeoLabs evidence, incident-report and query-journal templates.
- `research/AUTHORITATIVE_SOURCE_REGISTER.md`.
