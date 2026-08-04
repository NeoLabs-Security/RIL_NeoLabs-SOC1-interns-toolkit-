# Wazuh Dashboard Tutorial 01 — Orientation and First Alert Investigation

**NeoLabs tested baseline:** Wazuh 4.14.7  
**Tutorial version:** 0.2-draft  
**Review date:** 1 August 2026  
**Audience:** SOC Level 1 interns

> Dashboard labels can change between releases. Verify the installed version under the dashboard **About** page before following a screenshot or menu path.

## Learning objectives

By the end of this tutorial, a learner should be able to:

- identify the major Wazuh dashboard areas;
- distinguish platform health, agent status, indexed alerts and raw/archive events;
- set and verify the investigation time range;
- open an alert and inspect the event fields that support it;
- add filters, remove inherited filters and pivot to related activity;
- save an investigation view without embedding private information;
- recognise when a missing result may be a data or time-filter problem;
- record evidence and queries in the NeoLabs templates.

---

## 1. Before opening the dashboard

From `wazuh-stack/`, check local service health:

```bash
bash scripts/health-check.sh
```

Expected conditions:

- `wazuh.manager` is running and healthy;
- `wazuh.indexer` is running and healthy;
- `wazuh.dashboard` is running and healthy;
- `vcc.telemetry.collector` is either `healthy` or clearly marked `UNENROLLED` while waiting for authorised credentials.

Open the local dashboard address shown by the health script. The standard NeoLabs profile binds the dashboard to:

```text
https://127.0.0.1:8443
```

The local browser may show a certificate warning while the workstation deployment uses generated training certificates. Confirm the address is the local loopback address and follow the programme’s approved browser procedure. Never bypass a certificate warning for an unknown or public host.

### Record the version

After signing in:

1. Open the upper-left navigation menu.
2. Open **About** in the Wazuh section.
3. Record the dashboard package version and revision in your query journal.
4. Confirm it matches the cohort’s supported baseline.

Why this matters: a tutorial written for another release may use different names, fields or menu locations.

---

## 2. Understand the dashboard areas

The Wazuh home area groups information into broad security functions.

### Endpoint security

Common views include:

- Configuration Assessment;
- Malware Detection;
- File Integrity Monitoring.

These views depend on the modules and telemetry configured for monitored endpoints. An empty panel may mean no findings, no compatible source, a disabled module or a time/filter issue.

### Threat intelligence

Common views include:

- Threat Hunting;
- MITRE ATT&CK-related views;
- vulnerability and intelligence context where configured.

Threat Hunting is useful for reviewing security events and alerts beyond a single prebuilt dashboard.

### Security operations

This area provides operational views such as:

- events and alerts;
- policy or compliance views;
- configuration and platform data.

### Cloud security

Cloud dashboards appear when the relevant AWS, Azure, Microsoft or other integrations are configured and sending supported data.

### Agents management

**Agents management → Summary** shows enrolled Wazuh agents and status categories such as:

- Active;
- Disconnected;
- Pending;
- Never connected.

Important VCC distinction: the NeoLabs pod feed is delivered through a pod-scoped telemetry collector and read by the local Wazuh manager. It is not permission to install or manage an agent inside a VCC pod. Do not interpret the absence of a pod-named Wazuh agent as proof that no pod telemetry exists.

### Server management and app settings

These areas can show manager settings, API connections, configuration and component health. Some actions require administrator permissions and can affect the local deployment. Interns should follow the tutorial and avoid changing settings outside an assigned lab.

---

## 3. Alert data versus archive data

Wazuh commonly uses different index patterns for different purposes.

| Index pattern | Typical purpose | SOC L1 caution |
|---|---|---|
| `wazuh-alerts-*` | Alerts generated when Wazuh rules reach the configured alert threshold | Contains detections, not every received event |
| `wazuh-archives-*` | All events received by the Wazuh server when archive indexing is enabled | Can be high-volume and may not be enabled in every deployment |
| `wazuh-monitoring-*` | Agent status information | Status history is not the same as security-event data |
| `wazuh-statistics-*` | Wazuh server performance and processing statistics | Useful for identifying dropped or delayed events |

The NeoLabs starter investigation uses `wazuh-alerts-*`. Archive indexing will be enabled only after storage and privacy settings are approved and tested.

### Why alerts are not complete evidence

A record can be absent from `wazuh-alerts-*` because:

- it did not match a rule;
- it matched a level below the alert threshold;
- the decoder failed;
- the record arrived outside the selected time range;
- the source never generated or delivered it.

When archive data is available, it helps investigate events that did not become alerts. When it is unavailable, state that limitation.

---

## 4. Start with the global time filter

A wrong time filter is one of the most common reasons analysts miss evidence.

1. Locate the time picker near the top-right of the relevant dashboard or Discover view.
2. Record the displayed time zone.
3. Choose an absolute range that includes the event’s **event time**.
4. Expand the range slightly before and after the alert.
5. Apply the range and confirm the result count changes as expected.

### Relative versus absolute time

- **Relative range:** “Last 15 minutes.” Useful for live monitoring but changes as time passes.
- **Absolute range:** fixed start and end timestamps. Better for a report that another analyst must reproduce.

For submitted investigations, record the absolute UTC range even when you first used a relative range.

### Event time versus ingest time

The indexed `timestamp` used by Wazuh may not be identical to a source’s own `event_time` or the collector’s `ingest_time`. Inspect all available timestamp fields before building a precise timeline.

---

## 5. Open an alert correctly

Use the assigned alert view or **Threat Hunting** view.

1. Set the time range.
2. Clear unrelated saved filters.
3. Find the target alert.
4. Expand the alert row or open its detail panel.
5. Inspect the full field list.
6. Record the rule ID, level, description, event time and affected entities.
7. Locate the original or full-log field where available.

### Fields to identify in a NeoLabs VCC event

The exact path can vary after indexing, but look for the following source fields:

- `schema_version`;
- `event_id`;
- `event_time`;
- `ingest_time`;
- `pod_id`;
- `event_type`;
- `action`;
- `outcome`;
- `user` or other identity field;
- `source_ip`;
- `session_id`;
- `correlation_id`;
- `synthetic`.

Also record Wazuh-added fields:

- rule ID and level;
- rule groups;
- decoder name;
- manager or agent fields;
- indexed timestamp;
- source location.

### Evidence question

For each displayed field ask:

- Did the source generate this value?
- Did a decoder derive it?
- Did enrichment add it?
- Could it be user-controlled?
- Does it directly support the alert description?

---

## 6. Add filters without losing context

Most dashboard event views let you filter by selecting a field value or adding a filter manually.

Useful first pivots include:

- `pod_id` for the server-issued assigned pod;
- `user` for the affected identity;
- `source_ip` for related activity from the same source;
- `session_id` for actions within one application session;
- `correlation_id` for records linked across components;
- rule ID for repeated detections;
- `event_type` and `outcome` for activity categories.

### Include and exclude filters

An include filter narrows to matching records. An exclude filter removes matching records.

Before trusting the result count:

1. inspect every filter pill;
2. check whether a filter is disabled or inverted;
3. check whether the selected data view is correct;
4. record the filter and time range in the query journal.

### Example investigation sequence

For a failure-to-success alert:

1. Filter to the assigned `pod_id`.
2. Filter to the affected `user`.
3. Expand the time range to 30 minutes.
4. Sort by event time ascending.
5. Identify failures and any success.
6. Remove the user filter and search the same `source_ip` for other targeted accounts.
7. Pivot from the success to its `session_id`.
8. Look for account, application and authorization events within that session.
9. Search telemetry-health events for the same time window.

Do not reproduce a denied cross-pod request. Document the denial already present in the synthetic evidence.

---

## 7. WQL is not the same as every dashboard search bar

Wazuh Query Language (WQL) is used in specialised Wazuh tabs and Wazuh server API filtering. Its general structure is:

```text
field operator value
```

Common operators include:

```text
=   equality
!=  inequality
>   greater than
<   less than
~   like/contains-style matching
```

WQL uses:

```text
;   AND
,   OR
()  grouping
```

Example:

```text
status=active;os.name=Ubuntu
```

Values containing spaces must be quoted. WQL is case-sensitive.

However, **Explore → Discover** and some alert-search views use index/search syntax provided by the Wazuh dashboard and OpenSearch layer rather than WQL. Do not paste a WQL expression into every search bar and assume the same meaning. The query reference identifies which language belongs to which interface.

---

## 8. Save a reproducible view

A saved search or dashboard view can preserve:

- selected fields;
- sort order;
- filters;
- query text;
- time range, depending on the interface.

Use a neutral name such as:

```text
LAB01-authentication-timeline-student03
```

Do not put passwords, tokens, private URLs or personal information in saved-view names.

In the report, still write the query and time range. A saved object can be changed or deleted and may not be available to the reviewer.

---

## 9. Screenshot evidence

Take a screenshot only when it adds visual context. A strong screenshot should show:

- the relevant dashboard/view name;
- the absolute time range;
- active filters;
- essential fields or chart labels;
- enough context to understand what is being shown.

Before submission:

- crop unrelated browser content;
- hide passwords and private URLs;
- remove unrelated alerts and personal data;
- name the file using its evidence ID;
- record the screenshot in the evidence log;
- preserve the underlying event or query result when available.

A screenshot is not a substitute for searchable evidence.

---

## 10. Troubleshooting missing results

### No alerts in the selected period

Check:

1. correct time range and time zone;
2. correct index/data view;
3. hidden filters;
4. Wazuh manager and indexer health;
5. collector status and cursor movement;
6. whether the event should have triggered a rule;
7. decoder and rule loading;
8. source record presence.

### Fields are missing

Check:

- the expanded raw/full event;
- schema version;
- whether the JSON decoder recognised the event;
- recent field-name changes;
- index mappings;
- whether the source omitted the field.

### Counts seem too high

Check:

- duplicate ingestion;
- grouped versus individual alerts;
- repeated rule matches for one event;
- the selected date histogram interval;
- whether several pods or sources are included.

### Dashboard works but the VCC feed is empty

Check local collector health and enrolment state. Do not change pod identifiers or request parameters to test another pod. Escalate certificate, assignment or feed problems to the programme operator.

---

## 11. Guided exercise

Using Practice Lab 01:

1. Set an absolute UTC range covering the dataset.
2. Find the repeated authentication-failure alert.
3. Record its rule ID and source fields.
4. Filter by `svc-backup`.
5. Pivot to `203.0.113.44`.
6. Pivot to the successful session.
7. identify the authorization denial and account change;
8. identify the telemetry-health gap;
9. save a view;
10. complete the query journal and one evidence statement.

### Required reflection

Explain why the successful login and later account change are stronger together than either event in isolation. Then explain how the telemetry gap limits conclusions about process activity.

---

## 12. Review questions

1. What is the difference between `wazuh-alerts-*` and `wazuh-archives-*`?
2. Why should an analyst use an absolute time range in a final report?
3. Name five useful VCC correlation fields.
4. Why might an event exist without an alert?
5. What is the difference between a WQL filter and a Discover search?
6. What should a screenshot contain to be useful evidence?
7. Why is an empty dashboard not proof that nothing happened?
8. Which step prevents an intern from accessing another pod’s telemetry?

---

## Authoritative references

- Wazuh, *Navigating the Wazuh dashboard*.
- Wazuh, *Filtering data using Wazuh Query Language*.
- Wazuh, *Wazuh indexer indices*.
- Wazuh, *Log data analysis* and *Event logging*.
- Wazuh, *Wazuh agent connection*.
- `research/AUTHORITATIVE_SOURCE_REGISTER.md`.
