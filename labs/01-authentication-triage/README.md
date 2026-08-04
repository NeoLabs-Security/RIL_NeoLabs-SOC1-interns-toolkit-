# Practice Lab 01 — Authentication Failure Chain

**Track:** SOC Level 1  
**Difficulty:** Beginner → intermediate  
**Estimated time:** 60–90 minutes  
**Dataset:** `sample-logs/authentication/failed-login-chain.ndjson`  
**Scope:** Synthetic `pod-03` training records only

## Scenario

A Wazuh alert reports repeated authentication failures involving a service account. A successful login appears later in the same period, but one telemetry source also reports a collection gap.

Your task is to perform a defensible Level 1 triage. Do not assume that the alert proves compromise, and do not ignore the visibility gap.

## Learning objectives

You should be able to:

- distinguish normal and suspicious authentication sequences;
- pivot by account, source address, session and correlation identifiers;
- build an event-time timeline;
- identify what the available records prove and what remains uncertain;
- recognise a cross-pod access-control denial without attempting to reproduce it;
- document a telemetry gap and explain its effect on confidence;
- prepare an incident report, evidence log and escalation package.

## Safety boundary

- Use only the supplied synthetic dataset or the approved local Wazuh stack.
- Do not send requests to any VCC pod, endpoint or public address as part of this practice lab.
- Reserved example IP addresses in the dataset are documentation values, not targets.
- Do not attempt to change pod scope or access another pod.

## Preparation

Study:

1. `docs/secops-foundations/01-security-operations-foundations.md`
2. `docs/secops-foundations/02-alert-triage-evidence-and-escalation.md`
3. `docs/secops-foundations/03-siem-pipelines-and-log-quality.md`
4. The Log Literacy manual sections on time, correlation and evidence statements

Copy these templates into your working folder:

- `templates/incident-report-template.md`
- `templates/evidence-log-template.md`
- `templates/query-journal-template.md`

## Part A — Validate the dataset

Before analysing the security activity:

1. Confirm that every non-empty line is valid JSON.
2. Count the records.
3. Identify the schema version and pod identifier.
4. Confirm that each event is marked `synthetic: true`.
5. Compare `event_time` with `ingest_time` for delayed records.
6. Note any event type that represents telemetry health rather than user activity.

Example local validation command:

```bash
python3 - <<'PY'
import json
from pathlib import Path

path = Path("sample-logs/authentication/failed-login-chain.ndjson")
records = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
print(f"records={len(records)}")
print(f"pods={sorted({record['pod_id'] for record in records})}")
print(f"schemas={sorted({record['schema_version'] for record in records})}")
print(f"all_synthetic={all(record.get('synthetic') is True for record in records)}")
PY
```

Record this command and result in your query journal.

## Part B — Authentication pivots

Answer the following with evidence IDs and exact queries:

1. Which accounts experienced authentication failures?
2. Which source addresses generated failures?
3. How many failures involved `svc-backup`?
4. Did any successful authentication follow those failures?
5. Which session was created by the relevant success?
6. Did the same source target additional accounts?
7. Which later events reference the suspicious session?
8. Is there a normal failure-followed-by-success sequence elsewhere in the dataset? How does its context differ?

You may use Python, `jq`, Wazuh dashboard filters or another approved local tool. Record the exact method.

## Part C — Timeline

Build a timeline beginning five minutes before the first relevant failure and ending five minutes after the session revocation.

Your timeline should include:

- authentication failures;
- successful authentication;
- application activity;
- authorization decisions;
- account changes;
- session action;
- telemetry-health events.

Use **event time** for the primary order and note meaningful ingest delay separately.

## Part D — Evidence reasoning

Write an evidence statement for each of the following:

1. Repeated failures for the service account.
2. Successful login from the same source.
3. Activity performed through the new session.
4. The denied cross-pod request.
5. The sensitive account change.
6. The process-telemetry gap.

For each statement, include:

- what the record directly proves;
- what it suggests in context;
- what it does not prove;
- the next source that would reduce uncertainty.

## Part E — Classification

Choose one current classification:

- false positive;
- benign positive;
- suspicious;
- confirmed synthetic incident;
- insufficient evidence;
- data-quality issue.

Then provide:

- confidence: low, medium or high;
- potential severity;
- the strongest supporting facts;
- alternative explanations considered;
- the effect of the telemetry gap;
- whether the case should be escalated.

The quality of your reasoning matters more than selecting a label without explanation.

## Part F — Deliverables

Submit the following through the programme’s approved assignment repository when this lab is formally assigned:

```text
lab-01-authentication-triage/
├── incident-report.md
├── evidence-log.md
├── query-journal.md
└── screenshots/
    └── README.md
```

The screenshots folder may contain approved Wazuh views, but do not include credentials, private URLs, unrelated alerts or another pod’s data.

## Review checklist

- [ ] Facts are separated from interpretation.
- [ ] Every important claim cites an evidence ID.
- [ ] Queries include their time ranges and data source.
- [ ] A zero-result search is not treated as proof without checking source health.
- [ ] The cross-pod denial is documented, not reproduced.
- [ ] The telemetry gap is included in the confidence assessment.
- [ ] No secret or private endpoint appears in the submission.
- [ ] The final recommendation stays within SOC Level 1 authority.

## Instructor separation

This public repository intentionally contains no hidden answer key or scenario ground truth. Mentor review material belongs in a separate private repository.
