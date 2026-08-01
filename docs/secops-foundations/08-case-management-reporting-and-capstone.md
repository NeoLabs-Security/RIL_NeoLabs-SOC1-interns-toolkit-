# Module 8 — Case Management, Reporting and SOC Capstone

## Learning objectives

By the end of this module, a SOC Level 1 analyst should be able to:

- maintain an investigation record that another analyst can reproduce;
- distinguish facts, assumptions, analysis and recommendations;
- communicate severity, confidence and business impact clearly;
- hand off a case without losing evidence or context;
- complete a defensive capstone using the NeoLabs templates.

## 1. The case record

A case is more than an alert screenshot. It is the organised record of what was reported, what was examined, what was found, what remains unknown and what should happen next.

A minimum case record includes:

- case or issue identifier;
- title and current status;
- owner and reviewers;
- alert source;
- affected accounts, hosts, applications or resources;
- detection, triage and escalation timestamps;
- evidence register;
- query journal;
- timeline;
- disposition and confidence;
- recommended actions;
- limitations and unanswered questions.

## 2. Facts, analysis and assumptions

Keep these categories separate.

### Fact

A directly observed and preserved item, such as:

```text
The authentication event records a successful remote-interactive logon for trainee-a at 09:13:20 UTC.
```

### Analysis

An interpretation supported by facts:

```text
The success occurred 77 seconds after repeated failures from the same synthetic source, increasing the likelihood that the events are related.
```

### Assumption

A statement not yet proven:

```text
The source may represent the same operator throughout the sequence.
```

### Recommendation

A proposed action:

```text
Escalate for review of the account's approved activity and preserve the related process telemetry.
```

Mixing these categories makes reports difficult to trust.

## 3. Severity and confidence

Severity describes the potential or observed effect. Confidence describes how strongly the evidence supports the conclusion.

Example:

```text
Severity: High
Confidence: Medium
Reason: The account obtained a privileged session and launched an unusual process, but endpoint network telemetry is incomplete.
```

Do not raise confidence merely because an alert has a high rule level. Do not lower severity solely because the dataset is synthetic; assess the scenario as instructed while clearly marking the evidence as synthetic.

## 4. Timeline construction

A useful timeline:

- uses one timezone;
- orders events chronologically;
- identifies the source of each entry;
- distinguishes event time from ingestion time when relevant;
- avoids duplicate entries;
- includes the analyst's key pivots;
- marks gaps or uncertain ordering.

| Time (UTC) | Source | Entity | Event | Significance |
|---|---|---|---|---|
| 09:12:03 | Windows Security | trainee-a | Failed logon | Start of repeated failures |
| 09:13:20 | Windows Security | trainee-a | Successful remote logon | First success in sequence |
| 09:13:42 | Sysmon | host-01 | Process creation | Follow-on execution |

## 5. Evidence handling

The evidence log should record:

- evidence ID;
- source and collection method;
- timestamp;
- file, event or screenshot reference;
- checksum when a file is submitted;
- analyst notes;
- redactions;
- storage location.

Do not alter original evidence to make a report look cleaner. Create a redacted copy and retain the original only in the approved private location.

The public toolkit and student submissions must not contain:

- passwords or tokens;
- private keys or certificates;
- private pod URLs;
- AWS account details;
- unredacted personal data;
- mentor ground truth;
- production evidence.

## 6. Query journal

A query journal makes the investigation reproducible. For each query, record:

- tool and data source;
- exact query or command;
- time range and timezone;
- purpose;
- result count;
- useful findings;
- limitations;
- next pivot.

A query that returns no results is still relevant when the source, time range and field assumptions are documented.

## 7. Handoff and escalation

A handoff should allow the next analyst to continue without repeating all work.

Include:

1. why the case matters;
2. current disposition and confidence;
3. affected entities;
4. key timeline events;
5. actions already taken;
6. evidence location;
7. unresolved questions;
8. recommended next steps;
9. deadlines or containment urgency.

Use Slack for approved collaboration and GitHub for official evidence, reports, feedback and submissions. Use WhatsApp only for urgent programme announcements or schedule changes, not as the authoritative case record.

## 8. Closure criteria

A case may be closed when:

- the alert has an evidence-supported disposition;
- required escalation or containment has been completed or accepted by the responsible operator;
- evidence and queries are documented;
- limitations are recorded;
- detection-quality feedback is submitted where needed;
- the final report is reviewed;
- credentials and sensitive data have been removed from the submission.

A lack of evidence is not automatically evidence of benign activity. Close as inconclusive or escalate when required information is unavailable.

## 9. Capstone scenario

The capstone combines authentication, endpoint, web and application telemetry from an authorised synthetic VCC scenario.

The learner must:

1. confirm the assigned pod scope shown by the toolkit;
2. capture the original Wazuh alert;
3. build a query journal;
4. correlate at least three telemetry sources;
5. construct a timeline;
6. identify affected entities;
7. state at least two competing explanations;
8. test those explanations against evidence;
9. assign disposition, severity and confidence;
10. recommend containment, escalation or tuning;
11. complete the incident report and evidence register;
12. submit through the approved GitHub assignment workflow.

## 10. Capstone assessment rubric

| Area | Weight | Evidence of success |
|---|---:|---|
| Scope and safety | 10% | Uses only assigned synthetic evidence and protects credentials |
| Evidence collection | 20% | Preserves relevant events and records sources accurately |
| Query method | 15% | Queries are reproducible and logically sequenced |
| Correlation and timeline | 20% | Links events across sources without unsupported claims |
| Disposition and confidence | 15% | Conclusion is supported and limitations are explicit |
| Communication | 10% | Report is clear, concise and suitable for handoff |
| Detection feedback | 10% | Tuning or quality recommendation is safe and testable |

## 11. Final analyst checklist

Before submission, confirm:

- every statement is labelled as fact, analysis, assumption or recommendation where needed;
- timestamps use a stated timezone;
- screenshots are readable and redacted;
- commands and queries can be reproduced;
- the assigned pod was not selected through a client-controlled parameter;
- no credential material is committed;
- limitations are honest;
- the report answers what happened, what was affected, how confident the analyst is and what should happen next.
