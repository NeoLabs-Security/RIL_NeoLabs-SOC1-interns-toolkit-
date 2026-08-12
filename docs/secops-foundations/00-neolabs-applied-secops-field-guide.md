# NeoLabs Applied SecOps Field Guide

This field guide enriches the programme's SecOps research material with the operational workflow used in the NeoLabs × Renaissance Innovation Labs internship. Use it with the deeper SecOps chapters already in this toolkit.

## The SecOps loop
Security Operations is the disciplined loop of **observe → validate → investigate → document → escalate → improve**. In the VCC training environment all telemetry is synthetic and pod-scoped. Your job is not to make dramatic conclusions; it is to make defensible conclusions from evidence.

| Analyst question | Evidence-first answer |
|---|---|
| What happened? | Build a timeline from timestamps, event types, request IDs and identity fields. |
| Who/what was involved? | Use only synthetic identity/device/application fields visible in your assigned pod. |
| Is it expected? | Compare against the Week 1 baseline before calling something suspicious. |
| How confident am I? | State what the logs prove, what they suggest and what remains unknown. |
| What next? | Close, monitor, enrich or escalate with evidence and a reason. |

## Week 1 — Operation Night Watch
Week 1 establishes normal activity. This baseline becomes the comparison point for later credential, authorization, cloud and malware scenarios.

1. Confirm your Wazuh stack is healthy and bound to the pod assigned by NeoLabs.
2. Find the synthetic verification event and confirm pod/scenario fields.
3. Identify normal successful authentication and ordinary authentication failures.
4. Identify normal application/API activity and useful correlation fields.
5. Save at least three baseline searches or filters.
6. Build a short timeline using at least two event types.
7. Record one visibility gap and the source/field that would close it.

> **Baseline rule:** unusual is not automatically malicious. Week 1 is about learning what normal looks like.

## Wazuh L1 investigation workflow

### 1. Validate
- Confirm the time range and assigned pod.
- Check event source and synthetic/scenario context.
- Read the underlying event before relying on an alert title.

### 2. Extract useful fields
Capture timestamp, event/rule type, synthetic identity, source/destination when present, HTTP method/path/status when present, outcome, request/correlation ID, host/service and any field that links the event to another record.

### 3. Pivot safely
Use narrow searches: same identity, request ID, adjacent time window, route/service or outcome. Do not widen into another pod or an external target.

### 4. Build a timeline
Put evidence in time order. Separate observed facts from interpretations.

### 5. Decide and document
Use one of four dispositions: **expected baseline**, **needs monitoring**, **needs more evidence**, or **escalate**. Record why.

## Evidence quality standard
A strong analyst note allows another person to reproduce the conclusion. Every important claim should point to an event, query/filter, screenshot or named evidence item. Redact secrets and personal information. Never paste NeoLabs Access Codes, session tokens or private keys into reports.

## Escalation triggers
Escalate immediately if you see another pod's data, real personal information, credentials/private keys, unexpected infrastructure access, service instability or evidence outside the authorised training boundary. In later incident weeks, also escalate when impact, persistence, privilege change, confirmed unauthorized access or insufficient visibility makes L1 closure unsafe.

## Common L1 mistakes
- Treating a single failed login as an attack without context.
- Reading only the alert title and not the event.
- Ignoring time zones or confusing event time with ingestion/replay time.
- Searching too broadly and losing event sequence.
- Writing conclusions without evidence references.
- Failing to state what cannot be proven from current logs.
- Sharing screenshots containing credentials or private values.

## Minimum investigation note
For every investigation record: **scope, time window, question, data sources, queries/filters, evidence IDs, findings, limitations, disposition and next action**.

## Three-query baseline pattern
1. **Authentication baseline:** group successes/failures by synthetic user and short time bucket.
2. **Application/API baseline:** count normal routes/methods/status codes and identify common correlation IDs.
3. **Exception baseline:** isolate errors, denials and uncommon outcomes, then verify whether they are expected noise or meaningful deviations.

## Handover sentence template
"Within pod `<pod>`, between `<start>` and `<end>`, I observed `<facts>` in `<sources>`. The evidence supports `<disposition>` with `<confidence>` confidence. I could not determine `<limitation>`. Recommended next action: `<action>`."

## Week 1 readiness checklist
- [ ] Toolkit cloned and editable install completed.
- [ ] `neolabs login` succeeds with your assigned pod and private Access Code.
- [ ] `neolabs status` shows the correct track, pod and scenario.
- [ ] Wazuh passes its local health check.
- [ ] You can locate your pod's baseline telemetry.
- [ ] You know where to save the baseline report, timeline, evidence log and query journal.
- [ ] You understand the stop conditions and escalation channel.

## Continue into the full SecOps handbook
After this field guide, study the toolkit's chapters on:
- Security Operations foundations and SOC roles
- Alert triage, evidence and escalation
- SIEM pipelines and log quality
- Incident response and playbook development
- Windows/Sysmon investigations
- Linux, web and cloud log investigations
- Wazuh alert investigation and tuning
- Case management, reporting and capstone work
