# Week 1 Launch Pack — Operation Night Watch

## Your objective

Build a defensible picture of **normal** VCC activity in your assigned pod. This baseline becomes the comparison point for later security incidents.

## Windows — start in this order

1. Pull the latest SOC toolkit.
2. Make sure Docker Desktop is running with WSL2 integration.
3. Double-click:

```text
START-NEOLABS-SOC.cmd
```

4. Enter your assigned pod number + private NeoLabs Access Code only if prompted.
5. Wait for:

```text
SOC WORKSTATION READY
```

Do not start the assignment merely because the browser opens. READY means the toolkit has verified that a real synthetic event for your **server-assigned pod** reached the local Wazuh data path and is searchable in `wazuh-alerts-*`.

The launcher also reports the age of the newest indexed VCC event, checks local alert-index retention/disk health, provisions the Night Watch/Telemetry Health saved objects when supported, copies the local Wazuh `admin` password to the Windows clipboard without printing it, and opens the local dashboard.

### Wazuh login

```text
Dashboard: https://127.0.0.1:8443
Username:  admin
Password:  press Ctrl+V after the launcher reports READY
```

After signing in, copy non-sensitive text to replace the password in the clipboard.

### If startup/telemetry is not healthy

Double-click:

```text
CHECK-NEOLABS-SOC.cmd
```

or run:

```powershell
.\neolabs.cmd doctor
```

Doctor checks NeoLabs authentication → LIVE/REPLAY surface → raw VCC event file → Wazuh rule engine → Filebeat → indexer → dashboard. It also reports telemetry freshness and local index/disk status.

## Manual fallback

From the toolkit root on Windows:

```powershell
.\neolabs.cmd login
.\neolabs.cmd status
.\neolabs.cmd pod info
.\neolabs.cmd connect
.\neolabs.cmd doctor
```

Windows interns do **not** need a global `pip install`, Python Scripts PATH edit or manually entered gateway URL for the normal programme path.

The gateway decides whether the authorised SOC surface is LIVE or REPLAY. Live telemetry uses the pod-scoped protected channel; replay loads only validated archived telemetry for the assigned pod/scenario into the same local Wazuh workflow. Original `event_time` is preserved and replay metadata is separate.

## What to study before the task

Use the material in `publications/` in this order:

1. **Log Literacy for Cybersecurity Analysts** — how to read/correlate security telemetry.
2. **SecOps Foundations / Field Guide** — evidence-first analyst workflow and escalation.
3. **SOC L1 Analyst Handbook** — deeper reference.
4. **Wazuh Deployment and Investigation Guide** — dashboard/query/troubleshooting reference.
5. **SOC L1 Complete Toolkit** — long-form reference; you do not need to read it cover-to-cover before Week 1.

## Where to work in Wazuh

Use the preconfigured **NeoLabs — Operation Night Watch** view/dashboard when available. Otherwise use Threat Hunting/Discover over `wazuh-alerts-*` and filter your server-assigned pod.

The Night Watch view focuses on fields such as:

- `data.pod_id`
- `data.event_type`
- `data.dstuser` (NeoLabs VCC user identity in the current Wazuh mapping)
- `data.source_ip`
- `data.outcome`
- `data.correlation_id`
- `rule.id`, `rule.level`, `rule.description`
- original `data.event_time`

Use the separate **NeoLabs — Telemetry Health** view for rule `100150` and collector/parser/visibility problems. A zero-result query is not proof of absence until telemetry health/freshness is checked.

## Week 1 task

1. Confirm Wazuh shows only the correct assigned pod/scenario context.
2. Record the newest VCC event freshness and note any telemetry-health warning.
3. Identify at least one normal successful sign-in and an ordinary failed sign-in if present.
4. Identify normal application/API activity and useful identity/source/outcome/session/correlation fields.
5. Identify storage or other approved telemetry visible for your pod.
6. Create/save at least **three reusable baseline searches/filters**.
7. Build a short normal-activity timeline using at least two event types and original event time.
8. Record one visibility gap: a question the current telemetry cannot answer and what additional source/field would help.
9. Do **not** label activity malicious simply because it looks unusual. Week 1 is the reference baseline.

## Deliverables

- `baseline-log-report.md`
- `timeline.md`
- `evidence-log.md`
- `query-journal.md`
- redacted screenshots where useful

Official graded work goes to `RIL_NeoLabs-Intern-Assignments`, not this toolkit repository.

## Baseline report headings

- Scope and assigned pod
- Telemetry freshness/health at investigation start
- Sources visible in Wazuh
- Normal authentication pattern
- Normal application/API pattern
- Normal storage/other telemetry
- Three saved baseline queries
- Visibility gaps and limitations
- What you would compare against during a future incident

## Evidence standard

- Use original event time for the incident sequence; record replay/ingestion/index time separately when relevant.
- Preserve request/event/correlation IDs where available.
- Separate observed facts from interpretation.
- Redact Access Codes, Wazuh passwords, tokens, signed URLs, certificates/private keys and personal data.
- Never include another pod's data in your report.

## Stop conditions

Stop and contact a mentor if you receive another pod's events, real personal/production information, credentials/private keys, unexpected infrastructure access or service instability.

## Before submission

- [ ] `SOC WORKSTATION READY` was reached.
- [ ] Current status shows the correct pod, track and Week 1 scenario.
- [ ] Latest VCC event freshness/telemetry health was checked.
- [ ] Three baseline searches/filters are recorded.
- [ ] Timeline uses at least two event types and original event time.
- [ ] Evidence references are reproducible.
- [ ] Screenshots are redacted.
- [ ] Conclusions are supported by evidence.
