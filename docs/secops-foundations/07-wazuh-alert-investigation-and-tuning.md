# Module 7 — Wazuh Alert Investigation and Safe Tuning

## Learning objectives

By the end of this module, a SOC Level 1 analyst should be able to:

- move from a Wazuh alert to the underlying evidence;
- identify decoder, rule, agent and event fields that affect interpretation;
- use filters and pivots to build an investigation timeline;
- distinguish alert disposition from rule-quality feedback;
- propose safe tuning without hiding meaningful security activity.

## 1. Start with the alert record

Capture the original alert before changing filters or running broader searches. Record:

- alert identifier;
- rule ID, level and description;
- agent or source identity;
- event timestamp and ingestion timestamp;
- decoder or integration name;
- full original event when available;
- relevant structured fields;
- scenario or assignment context.

The rule description is a hypothesis, not the final incident conclusion.

## 2. Understand the Wazuh processing path

A simplified path is:

```text
source event
  -> collection
  -> decoding and field extraction
  -> rule evaluation
  -> alert creation
  -> indexing
  -> dashboard search and visualisation
```

An investigation can fail at any stage. A missing alert may mean:

- the source did not generate the event;
- the collector did not receive it;
- the event was malformed;
- the decoder did not extract expected fields;
- the rule conditions did not match;
- the alert was indexed under an unexpected time or field;
- the dashboard filter excluded it.

Do not jump directly to changing a rule before checking the earlier stages.

## 3. Alert-to-evidence pivots

Useful pivots include:

- agent ID or host name;
- account;
- source and destination address;
- process image, process ID or process GUID;
- rule ID;
- event ID;
- request or correlation ID;
- file path or hash;
- scenario ID;
- pod ID supplied by the server-authorised telemetry stream.

Begin with a narrow time window and expand only when needed. Preserve the timezone in the query journal.

## 4. Rule fields and interpretation

When reviewing an alert, separate:

### Source facts

Values that came from the original event, such as account, process, source address, path or result.

### Decoder output

Fields extracted or normalised by Wazuh. A decoder error can mislabel, omit or split data.

### Rule metadata

Rule ID, level, groups, description, frequency and relationship to parent or child rules.

### Enrichment

Information added from inventories, threat intelligence or lookup data. Enrichment can be missing, stale or incorrect and must not replace source evidence.

## 5. Investigation workflow

1. Save the original alert.
2. Confirm the affected entity and timestamp.
3. Inspect the raw event and decoded fields.
4. Search for the same entity immediately before and after the alert.
5. Pivot to related authentication, process, network, file or application activity.
6. Compare the behaviour with approved lab activity.
7. Record gaps and data-quality concerns.
8. Assign a disposition and confidence.
9. Escalate, close or recommend tuning.

## 6. Disposition and rule quality are different

An alert can be a true positive event but still have poor severity. It can also be a false positive caused by a decoder or rule issue.

Use two separate conclusions:

### Security disposition

- expected activity;
- suspicious activity requiring more evidence;
- likely malicious activity requiring escalation;
- confirmed authorised simulation.

### Detection-quality assessment

- rule behaved correctly;
- severity too high or too low;
- missing context or enrichment;
- duplicate or noisy alert;
- decoder issue;
- field-mapping issue;
- rule logic requires review.

This separation prevents analysts from weakening a rule simply because one event was benign.

## 7. Safe tuning principles

A tuning proposal should be narrow, testable and reversible.

Good proposals may:

- add a condition based on a stable, well-understood field;
- reduce duplicate alerts while preserving the first and most important signal;
- correct a decoder or field mapping;
- add context to the alert description;
- change severity based on verified impact or privilege;
- create an allow-list limited to an approved account, host, process path and time-bound use case.

Avoid broad exclusions such as:

```text
ignore all PowerShell
ignore this source network
ignore all administrator logons
ignore the entire rule group
```

Broad suppression can hide unrelated malicious activity.

## 8. Tuning proposal template

Document:

- rule ID and current behaviour;
- evidence showing the problem;
- proposed change;
- expected effect;
- possible blind spots;
- test dataset;
- rollback method;
- reviewer and approval status.

Students propose tuning. They do not change shared VCC control-plane rules, mentor dashboards or production detections.

## 9. Validation cases

Every proposed change should be tested against:

1. the benign event that created noise;
2. a similar malicious or suspicious event that must still alert;
3. unrelated events that should remain unchanged;
4. malformed or missing-field events;
5. duplicate events;
6. the expected rule level and groups.

Use synthetic or sanitised fixtures. Do not copy live incidents into this public repository.

## 10. Escalation package

A strong Wazuh escalation contains:

- alert and rule details;
- raw event evidence;
- timeline of related activity;
- affected entities;
- analyst queries;
- security disposition and confidence;
- detection-quality observation;
- recommended containment or next action;
- limitations.

## 11. Practice exercise

Investigate a synthetic Wazuh authentication alert that fires repeatedly for the same sequence. Determine the security disposition, identify whether duplication is caused by repeated source events or rule behaviour, and write a tuning proposal that reduces noise without suppressing the successful-login event.
