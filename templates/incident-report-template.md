# NeoLabs SOC Incident Report Template

> Use for authorised VCC exercises and approved synthetic investigations. Replace instructional text before submission. Do not include credentials, private keys, enrolment tokens or unredacted personal information.

## 1. Report control

| Field | Entry |
|---|---|
| Report title | |
| Case / assignment ID | |
| Analyst name | |
| Track and cohort | SOC Level 1 / |
| Assigned pod | |
| Report version | 1.0 |
| Prepared at | YYYY-MM-DD HH:MM UTC |
| Reviewer | |
| Classification | Training use / confidential programme material as directed |

## 2. Executive summary

Write 3–6 sentences for a reader who may not know Wazuh or the scenario. State:

- what triggered the investigation;
- the affected account, service or asset;
- the most important confirmed facts;
- the current classification and confidence;
- the recommended next action.

Do not include unsupported claims or long raw-log extracts.

## 3. Alert and detection information

| Field | Entry |
|---|---|
| Alert name | |
| Alert / rule ID | |
| Detection source | |
| Alert creation time | |
| Earliest confirmed event time | |
| Tool-assigned severity | |
| Analyst-assigned priority | |
| Relevant ATT&CK behaviour | Optional; explain mapping |

## 4. Scope

### Affected identities

| Identity | Type | Role / context | Confirmed or suspected impact |
|---|---|---|---|
| | | | |

### Affected assets and services

| Asset / service | Identifier | Criticality / role | Evidence of impact |
|---|---|---|---|
| | | | |

### Network, file and cloud indicators

| Indicator | Type | Source | Relevance and limitation |
|---|---|---|---|
| | | | |

## 5. Observed facts

List facts directly supported by evidence. Number each fact so it can be referenced later.

1. 
2. 
3. 

## 6. Timeline

Use UTC unless the assignment specifies otherwise. Separate event time from ingest or alert time when relevant.

| UTC time | Source | Entity | Observed activity | Evidence reference | Confidence |
|---|---|---|---|---|---|
| | | | | | |

## 7. Evidence reviewed

| Evidence ID | Source | Collection / query method | Time range | Integrity or quality note | Location / reference |
|---|---|---|---|---|---|
| EV-001 | | | | | |

Use the separate evidence log for detailed records.

## 8. Queries performed

| Query ID | Data source | Query / filter | Time range | Result summary | Next pivot |
|---|---|---|---|---|---|
| Q-001 | | | | | |

Use the query journal when more detail is required.

## 9. Analysis

### Interpretation

Explain what the combined facts suggest. Connect evidence through identity, time, process, network, session, request, file or resource pivots.

### Alternative explanations considered

| Alternative | Evidence supporting it | Evidence against it | Status |
|---|---|---|---|
| | | | Open / unlikely / ruled out |

### Visibility gaps and limitations

State missing data, parser failures, disconnected sources, clock issues, retention gaps or permissions that limit the conclusion.

## 10. Classification and confidence

| Field | Entry |
|---|---|
| Classification | False positive / benign positive / suspicious / confirmed incident / insufficient evidence / data-quality issue |
| Confidence | Low / medium / high |
| Confidence reasoning | |
| Potential severity | Informational / low / medium / high / critical, according to assignment definitions |
| Business or lab impact | |

## 11. Actions and recommendations

### Actions already taken

Record only authorised actions actually performed.

1. 
2. 

### Recommended next actions

| Priority | Recommendation | Owner / escalation target | Reason | Deadline |
|---|---|---|---|---|
| | | | | |

Do not claim that a recommendation has been implemented unless evidence confirms it.

## 12. Escalation decision

| Field | Entry |
|---|---|
| Escalated? | Yes / no |
| Escalated to | |
| Time | |
| Reason | |
| Information supplied | |
| Questions requiring higher-tier review | |

## 13. Lessons and detection improvements

- Which field or source was most valuable?
- Which evidence was missing?
- Did the detection title and severity accurately describe the activity?
- What safe tuning, logging or playbook improvement is recommended?
- What should the analyst do differently next time?

## 14. References and attachments

List approved screenshots, exports, evidence IDs, task instructions and public references. Use repository-relative paths where possible. Redact sensitive values.

## 15. Reviewer notes

| Reviewer | Date | Decision | Required corrections |
|---|---|---|---|
| | | Approved / revise | |
