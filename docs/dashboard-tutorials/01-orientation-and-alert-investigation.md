# Wazuh Dashboard Tutorial 01 — Orientation and First Investigation

**NeoLabs tested baseline:** Wazuh 4.14.7  
**Reconciled:** 2026-08-14  
**Audience:** SOC Level 1 interns

Dashboard labels can vary by release. Current startup behaviour is documented in `../../PROGRAMME_CURRENT_STATE.md`.

## Before opening the dashboard

Start through the platform root launcher:

```text
Windows: START-NEOLABS-SOC.cmd
Linux:   ./start-neolabs-soc.sh
```

On a first Linux run, `bash start-neolabs-soc.sh` is also valid.

Wait for `SOC WORKSTATION READY`. This means the toolkit verified service health **and** that assigned-pod VCC telemetry is searchable in the local Wazuh indexer.

If anything looks wrong:

```text
Windows: START-NEOLABS-SOC.cmd doctor
Linux:   ./start-neolabs-soc.sh doctor
```

Normal dashboard URL:

```text
https://127.0.0.1:8443
```

Login username is `admin`. The launcher prints the locally generated password after a successful start. From another device, use one of the `https://<host-ip>:8443` URLs printed on the READY screen.

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

Saved-object provisioning is fail-soft. If these views are unavailable, use **Threat Hunting/Discover** against `wazuh-alerts-*`; do not reset Wazuh because a saved view did not import.

## Alerts versus raw/archive data

Week 1 begins with `wazuh-alerts-*`. Normal VCC baseline events are deliberately eligible for searchable alerts so interns can see normal Night Watch activity, not only higher-severity detections.

`wazuh-archives-*` may not be enabled on every student workstation. If archive data is unavailable, state the visibility limitation rather than assuming the event never existed.

## Time is evidence

For assignment evidence:

1. locate the relevant event(s);
2. choose an absolute UTC range around their **original event time**;
3. record that range in the query journal;
4. distinguish source `event_time` from replay/ingest/indexed timestamp.

Replay preserves original `event_time` and stores replay metadata separately.

## First Week 1 investigation flow

1. Open **NeoLabs — Operation Night Watch** or Threat Hunting.
2. Confirm the assigned `pod_id`. If another pod appears, stop and contact a mentor.
3. Check latest-event freshness reported by the launcher/Doctor.
4. Inspect any Telemetry Health warning before interpreting missing data.
5. Set an absolute time range around Week 1 events.
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

Rule IDs/severity are pivots. Inspect underlying event fields/context before disposition.

## Filters and pivots

A practical pivot sequence is:

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

Wazuh Query Language, OpenSearch/Discover query syntax and UI filter pills are not interchangeable everywhere. Prefer UI field filters when following this tutorial. If using a query language, record which view/search bar accepted it so another analyst can reproduce the result.

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

A useful screenshot should show enough context to prove the claim: view/search name, time range, active filters and relevant event/rule fields. Redact the local Wazuh password, NeoLabs Access Code/session, signed URLs, private keys/certificates and unrelated personal data.

## Dashboard/agent distinction

The NeoLabs VCC pod feed is consumed as a protected telemetry stream/local file path; it is not permission to install/manage an agent inside a VCC pod. Absence of a pod-named Wazuh agent does not mean the VCC feed is absent.

## When to use Doctor instead of changing settings

Use the platform launcher `doctor` action before editing dashboard/indexer/manager settings. Doctor identifies whether the break is at authentication, replay/live access, raw event, rule engine, Filebeat, indexer or dashboard.

Do not weaken TLS, expose indexer/API ports, disable rules broadly or delete local volumes simply to make the dashboard show data.

## Completion check

You can complete this tutorial when you can explain the assigned pod, current data source/time range, one normal authentication sequence, one application/API pivot, the meaning of the relevant Wazuh rule, one saved/reproducible filter and one visibility limitation—without confusing replay/index time with source event time.
