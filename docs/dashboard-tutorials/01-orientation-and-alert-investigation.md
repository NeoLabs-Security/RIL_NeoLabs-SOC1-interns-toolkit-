# Wazuh Dashboard Tutorial 01 — Orientation and First Investigation

**NeoLabs tested baseline:** Wazuh 4.14.7  
**Reconciled:** 2026-08-14  
**Audience:** SOC Level 1 interns

Dashboard labels can vary by release. Current programme/startup behaviour is documented in `../../PROGRAMME_CURRENT_STATE.md`.

## Before opening the dashboard

On Windows, normally start with:

```text
START-NEOLABS-SOC.cmd
```

Wait for `SOC WORKSTATION READY`. That means the toolkit has already verified service health **and** that assigned-pod VCC telemetry is searchable in the local Wazuh indexer.

If anything looks wrong:

```text
CHECK-NEOLABS-SOC.cmd
```

or:

```powershell
.\neolabs.cmd doctor
```

Normal dashboard URL:

```text
https://127.0.0.1:8443
```

Login username is `admin`; the one-click Windows launcher copies the locally generated password to the clipboard without printing it.

## Current NeoLabs investigation views

### NeoLabs — Operation Night Watch

Use this preconfigured pod-scoped saved view/dashboard for Week 1 when provisioning succeeds. It focuses on:

- assigned `pod_id`;
- `event_type`;
- NeoLabs user identity (`data.dstuser` in the current Wazuh mapping);
- `source_ip`;
- `outcome`;
- `correlation_id`;
- Wazuh rule ID/level/description;
- original source `event_time`.

### NeoLabs — Telemetry Health

Use this saved view for collector/parser/visibility problems, especially NeoLabs rule `100150`.

Saved-object provisioning is fail-soft. If these views are unavailable, use **Threat Hunting/Discover** against `wazuh-alerts-*`; do not reset Wazuh just because a saved view did not import.

## Alerts versus raw/archive data

The current NeoLabs Week 1 workflow begins with `wazuh-alerts-*`. Normal VCC baseline events are deliberately eligible for searchable alerts so interns can see normal Night Watch activity, not only high-severity detections.

`wazuh-archives-*` may not be enabled on every student workstation. If raw/archive data is unavailable, state that visibility limitation rather than assuming the event never existed.

## Time is evidence

The global time picker is one of the most common causes of false “no data” conclusions.

For assignment evidence:

1. locate the relevant event(s);
2. choose an absolute UTC range around their **original event time**;
3. record that range in the query journal;
4. distinguish source `event_time` from replay/ingest/indexed timestamp.

Replay preserves original `event_time` and stores replay metadata separately.

## First Week 1 investigation flow

1. Open **NeoLabs — Operation Night Watch** or Threat Hunting.
2. Confirm the assigned `pod_id`. If another pod appears, stop and contact a mentor.
3. Check the latest event freshness reported by the launcher/Doctor.
4. Inspect any Telemetry Health warning before interpreting missing data.
5. Set an absolute time range around the Week 1 events.
6. Expand a record and capture `event_id`, original `event_time`, `event_type`, identity, source, outcome, session/correlation IDs and Wazuh rule metadata where available.
7. Find normal successful authentication and an ordinary failed authentication if present.
8. Pivot by identity → source IP → session/correlation ID to related application/API activity.
9. Identify storage/other approved telemetry visible to the pod.
10. Save/reuse at least three baseline filters/searches.
11. Build a short original-event-time timeline.
12. Record one visibility gap.

Week 1 is baseline building. “Unusual” does not automatically mean “malicious.”

## Useful NeoLabs rule families

Current training rules include normal baseline events plus authentication failure/repeated failure, authentication success/success-after-failures, sensitive account change, authorisation denial and telemetry-health alerts.

Rule IDs/severity are pivots. Always inspect underlying event fields/context before disposition.

## Filters and pivots

Useful pivots include assigned pod, identity, source IP, event type, outcome, session/correlation ID and rule ID. Before trusting a result count, inspect every active filter and the current time range.

A practical sequence:

```text
pod
→ identity
→ source_ip
→ session_id / correlation_id
→ related application/auth/account activity
→ telemetry health for the same window
```

Do not reproduce denied/cross-pod requests merely to create evidence.

## WQL/search-bar caution

Wazuh Query Language, OpenSearch/Discover query syntax and UI filter pills are not interchangeable everywhere. Prefer UI field filters when following this Week 1 tutorial. If you use a query language, record exactly which view/search bar accepted it so another analyst can reproduce the result.

## Zero results are not automatically evidence of absence

Before writing “no events found”:

- confirm Doctor/indexer PASS;
- confirm latest VCC event freshness;
- confirm the correct data view/index pattern;
- confirm the assigned pod filter;
- confirm absolute time range/time zone;
- inspect Telemetry Health / rule `100150`;
- state missing archive/source coverage if relevant.

## Evidence capture

A useful screenshot should show enough context to prove the claim: view/search name, time range, active filters and relevant event/rule fields. Redact local Wazuh password, NeoLabs Access Code/session, signed URLs, private keys/certificates and unrelated personal data.

For every material conclusion, retain the event/evidence ID or reproducible search in the query journal.

## Dashboard/agent distinction

The NeoLabs VCC pod feed is consumed as a protected telemetry stream/local file path; it is not permission to install/manage an agent inside a VCC pod. Absence of a pod-named Wazuh agent does not mean the VCC feed is absent.

## When to use Doctor instead of changing settings

If you suspect ingestion/indexing failure, run `CHECK-NEOLABS-SOC.cmd` / `.\neolabs.cmd doctor` before editing dashboard/indexer/manager settings. The Doctor is designed to identify whether the break is at authentication, replay/live access, raw event, rule engine, Filebeat, indexer or dashboard.

Do not weaken TLS, expose indexer/API ports, disable rules broadly or delete local volumes simply to make a dashboard show data.

## Completion check

You can complete this tutorial when you can explain the assigned pod, current data source/time range, one normal auth sequence, one application/API pivot, the meaning of the relevant Wazuh rule, one saved/reproducible filter and one visibility limitation—without confusing replay/index time with source event time.
