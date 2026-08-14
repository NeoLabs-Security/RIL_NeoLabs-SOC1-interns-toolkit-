# Wazuh SOC Level 1 Handbook — Module 1
# Architecture, Data Flow and the NeoLabs Student Deployment

**NeoLabs tested baseline:** Wazuh 4.14.7  
**Module version:** 1.0  
**Reconciled:** 14 August 2026  
**Audience:** Beginner-to-intermediate SOC Level 1 interns

> Wazuh is not one program running in one window. It is a set of components that collect, analyse, store and display security data. A SOC analyst should be able to identify which stage produced—or failed to produce—the evidence they are looking for.

For the current programme/runtime summary, also read `../../PROGRAMME_CURRENT_STATE.md`.

---

## Learning objectives

By the end of this module, you should be able to:

- explain the roles of the Wazuh manager, Filebeat, indexer and dashboard;
- explain how the NeoLabs VCC telemetry feed differs from a normal Wazuh endpoint agent;
- describe how a VCC event becomes a searchable Wazuh alert;
- distinguish source `event_time`, replay/ingestion metadata and Wazuh index time;
- explain why an empty dashboard is not automatically evidence that no event occurred;
- use the current NeoLabs one-click Windows startup and Doctor workflow;
- explain the Night Watch and Telemetry Health views;
- identify the student/operator trust boundary and pod-isolation controls;
- perform a safe first-line data-flow check without exposing credentials.

---

# 1. What Wazuh is

Wazuh is an open-source security platform that can collect and analyse operating-system, application, network, cloud and security telemetry. In a typical deployment it combines endpoint agents/collectors, a Wazuh server or manager, Filebeat, a Wazuh indexer and a Wazuh dashboard.

For SOC work, think of the stack as a pipeline:

```text
source event
→ collection
→ parsing/decoding
→ rule evaluation
→ alert creation
→ forwarding
→ indexing
→ search/dashboard
```

A failure at one stage can make later stages look empty even when earlier stages are healthy. That is why NeoLabs troubleshooting verifies the full chain rather than only checking that Docker containers are running.

---

# 2. Core Wazuh components

## 2.1 Wazuh agent

A Wazuh agent is software installed on a monitored endpoint. It can collect operating-system/application logs, Windows Event channels, file-integrity activity, system inventory and other endpoint security information.

### NeoLabs VCC boundary

SOC interns do **not** install or administer Wazuh agents inside VCC application pods. The VCC remains operator-managed. The programme exports approved synthetic pod telemetry through a separate protected NeoLabs feed.

Therefore:

- absence of a pod-named Wazuh agent does not mean the VCC feed is absent;
- the student does not receive pod SSH/container access merely because Wazuh can see pod telemetry;
- student pod scope is controlled by the NeoLabs access service, not by a local Wazuh agent selector.

## 2.2 Wazuh manager

The Wazuh manager analyses received events. Important responsibilities include:

- reading configured log sources;
- decoding/parsing events;
- applying rules and correlations;
- writing alert records;
- coordinating supported Wazuh functions and API access.

The NeoLabs Compose service is:

```text
wazuh.manager
```

The current manager configuration reads the shared NeoLabs VCC NDJSON stream at:

```text
/var/ossec/logs/vcc/vcc-events.ndjson
```

with JSON log format.

## 2.3 Filebeat

Filebeat forwards Wazuh alerts from the manager toward the indexer.

This creates an important troubleshooting distinction:

```text
manager parsed/matched the event
but
Filebeat/indexer did not make it searchable
```

That situation is different from a collector failure or a decoder/rule failure.

## 2.4 Wazuh indexer

The Wazuh indexer is the search/storage layer based on OpenSearch technology. It stores documents, mappings and searchable indices.

The NeoLabs Compose service is:

```text
wazuh.indexer
```

Week 1 investigation primarily uses:

```text
wazuh-alerts-*
```

Normal NeoLabs VCC baseline events are deliberately eligible to become searchable alerts so Operation Night Watch can show normal activity, not only high-severity detections.

## 2.5 Wazuh dashboard

The Wazuh dashboard provides the analyst interface for search, Threat Hunting/Discover, saved objects, dashboards and Wazuh modules.

The NeoLabs service is:

```text
wazuh.dashboard
```

The normal student profile binds the dashboard to loopback:

```text
https://127.0.0.1:8443
```

The dashboard, Wazuh API and indexer must not be exposed publicly merely to simplify student access.

---

# 3. The current NeoLabs student topology

```text
VCC synthetic pod activity
        │
        ├─ LIVE: protected pod-scoped telemetry channel
        │
        └─ REPLAY: authorised archived pod/scenario telemetry
                    │
                    ▼
      vcc.telemetry.collector / replay append
                    │
          shared vcc_telemetry volume
                    │
                    ▼
 /var/ossec/logs/vcc/vcc-events.ndjson
                    │
                    ▼
              wazuh.manager
        JSON decoder + NeoLabs rules
                    │
                    ▼
                 Filebeat
                    │
                    ▼
              wazuh.indexer
             wazuh-alerts-*
                    │
                    ▼
              wazuh.dashboard
  Night Watch / Telemetry Health / Threat Hunting
```

## Persistence

Docker named volumes retain manager/indexer/dashboard state across ordinary stops. A normal `git pull` or stack restart does not require students to delete Wazuh volumes or regenerate credentials.

A destructive reset is a separate local-only operation and is **not** normal troubleshooting.

---

# 4. How VCC telemetry reaches the student

The programme separates **telemetry access** from **infrastructure access**.

A SOC intern receives:

- the SOC toolkit;
- a private NeoLabs Access Code;
- the server-assigned pod/track/scenario context;
- a local Wazuh workstation;
- only the synthetic telemetry/evidence authorised for that assignment.

The intern does **not** receive:

- EC2 or pod shell access;
- database/container administration;
- broad AWS credentials;
- another pod's telemetry;
- mentor ground truth;
- a client-side control that authorises a different pod.

## Server-authoritative scope

The student may type a pod number during login as confirmation, but the server-side assignment is authoritative. A local edit cannot turn a student into another pod/track.

Both live and replay paths validate the assigned scope. Replay additionally validates that records are synthetic, belong to the assigned pod and contain required event fields before they are appended to the local Wazuh telemetry stream.

---

# 5. LIVE versus REPLAY

The VCC uses a cost-aware hybrid runtime. The main VCC EC2 does not have to remain on for every hour of an investigation.

The same student access flow can represent different authorised SOC states:

- **LIVE** — protected live pod telemetry during approved interactive windows;
- **REPLAY** — archived telemetry for the assigned pod/scenario;
- **CLOUD_LIVE / ENDPOINT_LIVE** — scenario-specific cloud/endpoint evidence surfaces where applicable;
- **OFFLINE/no surface** — the toolkit must not pretend data is available.

## Event time during replay

Replay preserves the original source:

```text
event_time
```

and adds replay metadata separately.

For an incident timeline, order events by original event time unless the assignment specifically asks you to analyse collection/replay delay.

---

# 6. How Wazuh analyses a NeoLabs event

A simplified event path is:

```text
NDJSON event
→ JSON decoding
→ NeoLabs base rule
→ child/correlation rules where applicable
→ alert record
→ Filebeat
→ Wazuh indexer
→ dashboard search
```

A synthetic VCC event may contain fields such as:

```json
{
  "schema_version": "1.0",
  "event_id": "evt-auth-0009",
  "event_time": "2026-08-14T09:18:07Z",
  "pod_id": "pod-03",
  "event_type": "authentication",
  "action": "login",
  "outcome": "success",
  "user": "student.synthetic",
  "source_ip": "203.0.113.44",
  "session_id": "sess-902",
  "correlation_id": "corr-902",
  "synthetic": true
}
```

Wazuh may expose NeoLabs dynamic fields under `data.*`. In the current mapping, the NeoLabs user identity is commonly visible as `data.dstuser` in the saved Week 1 view.

---

# 7. NeoLabs custom rules

The current NeoLabs VCC rule set includes training rules for:

- normal VCC baseline events;
- authentication failures;
- repeated authentication failures;
- successful authentication;
- success after earlier failures;
- sensitive account changes;
- protected authorisation denials;
- telemetry collection/parser/visibility problems.

The base VCC event rule is intentionally searchable at a non-zero alert level so normal Week 1 activity can appear in `wazuh-alerts-*`.

Telemetry-health problems are represented around rule:

```text
100150
```

A Wazuh rule match means the configured condition was observed. It does **not** automatically prove malicious intent or impact.

---

# 8. Current Windows setup and startup

The normal student workflow has changed from the older manual enrolment sequence.

## First/current startup

From the latest toolkit checkout:

1. Start Docker Desktop with WSL2 integration.
2. Double-click:

```text
START-NEOLABS-SOC.cmd
```

The launcher automatically:

1. verifies WSL2/toolkit prerequisites;
2. performs first-time Wazuh preparation only when needed;
3. preserves an existing `.env` and Wazuh data;
4. reuses a valid NeoLabs session or asks for assigned pod + private Access Code;
5. connects to the current authorised LIVE/REPLAY surface;
6. starts/waits for manager, indexer, dashboard and telemetry collector;
7. reloads the current NeoLabs rule file in the manager;
8. proves an assigned-pod VCC event is searchable in `wazuh-alerts-*`;
9. reports latest-event freshness;
10. applies/checks local alert-index retention/disk safety;
11. provisions Night Watch/Telemetry Health saved objects where supported;
12. copies the local Wazuh `admin` password to the Windows clipboard without printing it; and
13. opens the local dashboard.

Do not begin cohort analysis until the launcher displays:

```text
SOC WORKSTATION READY
```

## No global CLI/manual gateway requirement

For the normal Windows programme path, students do **not** need to:

- run `python -m pip install -e .`;
- add Python Scripts to Windows PATH;
- copy a private/manual gateway URL;
- manually enrol with a token file;
- manually select another telemetry target.

Advanced/manual scripts still exist for troubleshooting and non-Windows operation, but they are not the primary student onboarding sequence.

---

# 9. Wazuh dashboard login

After READY, the normal dashboard is:

```text
https://127.0.0.1:8443
```

Use:

```text
Username: admin
Password: the locally generated WAZUH_INDEXER_PASSWORD
```

On Windows, the launcher copies the password to the clipboard without displaying it. Press `Ctrl+V` at the login page, then replace the clipboard contents with non-sensitive text after login.

The following are **not** the human dashboard password:

- `WAZUH_API_PASSWORD` — internal Wazuh API/service communication;
- `WAZUH_DASHBOARD_PASSWORD` — internal dashboard service account.

Never paste the local Wazuh password into an assignment, screenshot, Slack post or Git commit.

---

# 10. Night Watch and Telemetry Health views

## NeoLabs — Operation Night Watch

The toolkit attempts to provision a Week 1 pod-scoped saved view/dashboard containing important investigation fields such as:

- `data.pod_id`;
- `data.event_type`;
- synthetic user identity;
- `data.source_ip`;
- `data.outcome`;
- `data.correlation_id`;
- Wazuh `rule.id`, `rule.level`, `rule.description`;
- original `data.event_time`.

Use it to establish normal authentication/application/API behaviour and build reusable Week 1 searches.

## NeoLabs — Telemetry Health

This view focuses on telemetry-quality problems, especially rule `100150`, so students can distinguish “no suspicious event” from “the collection/search pipeline is unhealthy.”

Saved-object provisioning is fail-soft. If an import is unavailable on a local dashboard instance, Threat Hunting/Discover remains the supported fallback.

---

# 11. Freshness and local retention

The current toolkit reports the newest assigned-pod event indexed in Wazuh.

Default freshness warning:

```text
90 minutes
```

This is a health signal—not proof that an attack should happen every 90 minutes.

Current local alert-index defaults:

```text
wazuh-alerts-* retention: 30 days
filesystem warning:       85%
filesystem critical:      92%
```

This retention applies only to the student's local Wazuh alert indices. It does **not** delete VCC server-side telemetry archives/evidence and does not force-overwrite unrelated existing index-management policies.

---

# 12. NeoLabs Doctor

On Windows, double-click:

```text
CHECK-NEOLABS-SOC.cmd
```

or run:

```powershell
.\neolabs.cmd doctor
```

Doctor checks the pipeline in order:

```text
1. NeoLabs authentication
2. current LIVE/REPLAY telemetry surface
3. raw VCC event file
4. Wazuh rule engine
5. Filebeat
6. Wazuh indexer
7. Wazuh dashboard
```

It also reports telemetry freshness and local index/disk state.

This is the preferred first troubleshooting tool because it prevents the common mistake of changing Wazuh rules when the real failure is earlier in the pipeline.

---

# 13. Why an empty dashboard may be misleading

Before writing “no events were found,” confirm:

1. Doctor/indexer health passes;
2. the latest VCC event is reasonably fresh for the current assignment/window;
3. the filter uses the assigned `pod_id`;
4. the correct `wazuh-alerts-*` data view is selected;
5. the time range includes the original event times;
6. Telemetry Health does not show a collection/parser/visibility problem.

A zero-result query becomes useful evidence only after these assumptions are checked.

---

# 14. Alerts versus archives

`wazuh-alerts-*` contains searchable alert documents. The current NeoLabs Week 1 base rule ensures normal approved VCC baseline events can be represented there.

Wazuh archive indexing, when enabled, can provide additional events that did not become alerts. Archive indexing may not be available on every student workstation because it increases storage/resource/privacy requirements.

Do not assume `wazuh-archives-*` exists. If the assignment needs evidence that is not available in alerts, record the visibility limitation and use only mentor-approved evidence sources.

---

# 15. Network exposure and security boundaries

Common Wazuh ports can include agent communication/enrolment, server API, indexer and dashboard ports. In the NeoLabs student workstation:

- the dashboard is loopback-only by default;
- the Wazuh API/indexer are not intentionally published for student network access;
- internal components communicate on the Compose network;
- VCC telemetry scope is server-managed;
- students must not expose the local stack publicly for convenience.

The fact that Wazuh is a security tool does not make an insecure Wazuh deployment acceptable.

---

# 16. Safe manual checks

Advanced/manual checks remain available from the toolkit root, for example:

```bash
bash wazuh-stack/scripts/compatibility-check.sh
bash wazuh-stack/scripts/health-check.sh
bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --wait 180
bash wazuh-stack/scripts/telemetry-freshness.sh
bash wazuh-stack/scripts/doctor.sh
```

Use `wazuh-logtest` through the supported verifier/Doctor workflow when checking decoding/rules. Do not broadly raise rule levels, disable TLS, publish indexer/API ports or delete volumes simply to make a dashboard show data.

---

# 17. Evidence and confidentiality

Useful Week 1 evidence includes:

- Wazuh event/rule IDs;
- assigned pod and explicit time range;
- relevant source event fields;
- saved/reproducible filters;
- original event-time timeline;
- telemetry-health/freshness notes;
- redacted screenshots.

Never submit:

- NeoLabs Access Code;
- Wazuh local password;
- session token;
- signed private URL;
- private key/certificate contents;
- AWS credentials;
- another pod's data;
- real customer/production information.

---

# 18. Week 1 practical checklist

For Operation Night Watch:

1. Start with `START-NEOLABS-SOC.cmd`.
2. Wait for `SOC WORKSTATION READY`.
3. Log in to the local Wazuh dashboard as `admin`.
4. Open NeoLabs — Operation Night Watch or Threat Hunting.
5. Confirm your assigned pod filter.
6. Record latest-event freshness and inspect Telemetry Health.
7. Find normal authentication and application/API activity.
8. Pivot using identity/source/session/correlation fields.
9. Save/reuse at least three baseline searches.
10. Build a short original-event-time timeline.
11. Record one visibility limitation.
12. Submit only redacted evidence through the central assignments repository.

---

# 19. Completion standard

You understand the NeoLabs Wazuh architecture when you can answer all of these without guessing:

- Where did this event originate?
- How did it reach the local telemetry file?
- Did Wazuh decode and match a rule?
- Did Filebeat/indexer make it searchable?
- Am I using the correct assigned pod and time range?
- Is the newest telemetry fresh/healthy?
- Is this rule an observation or proof of compromise?
- What can the current telemetry prove, and what can it not prove?

That pipeline awareness is one of the most important habits of a Level 1 SOC analyst.