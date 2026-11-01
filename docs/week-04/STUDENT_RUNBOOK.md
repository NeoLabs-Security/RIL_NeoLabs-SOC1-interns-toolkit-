# Week 4 Student Runbook — SOC | Broken Gate

**Scenario:** `w04-broken-gate` · **Scope:** server-assigned pod only · **Work:** individual, noncompetitive

This is the student-facing operational guide. Read [authorization investigation](authorization-investigation.md) for interpretation and the [central submission handbook](https://github.com/NeoLabs-Security/RIL_NeoLabs-Intern-Assignments/blob/main/assignments/week-04/SUBMISSION_HANDBOOK.md) for delivery requirements.

## 1. Confirm your assignment and monitoring surface

- Receive your **SOC** NeoLabs access code, assigned pod, and approved investigation window from the mentor. Never use the Pentest access code or another pod.
- The mentor will provide the **central Wazuh dashboard URL and a separately authorized dashboard account**. The URL and credentials are not defined in this repository. Do not assume the dashboard URL is `https://127.0.0.1:8443` or that your locally generated Wazuh `admin` password grants access to the central service.
- **Architecture boundary:** This toolkit currently provisions an **individual/local Wazuh manager, collector, indexer and dashboard** with `bash start-neolabs-soc.sh`. A shared central dashboard is only authoritative if the mentor has configured it to index the assigned-pod events. Local successful installation does *not* establish shared dashboard ingestion. Do not open or duplicate Internet-facing Wazuh dashboard ports to build a central dashboard yourself.
- For an assigned local SOC workstation, open a terminal in this repository and run:

```bash
git pull --ff-only origin main
bash start-neolabs-soc.sh --validate-only
bash start-neolabs-soc.sh
bash neolabs status
bash neolabs doctor
```

The first launcher may install Docker/Wazuh. Do not run it with `sudo`, delete Docker volumes, reset the collector cursor or copy account passwords into a command. On an existing workstation `bash neolabs doctor` checks authentication, raw delivery, rules, Filebeat, indexer and dashboard.

## 2. In the mentor-provided **central** dashboard

1. Sign in with the credentials issued for the central dashboard.
2. Open **Threat Hunting** (or the equivalent Discover/search view exposed by the mentor).
3. Confirm the index pattern/data view is `wazuh-alerts-*` and that the time window covers the **original event time**; begin with **Last 24 hours**, expand to cover earlier evidence if necessary.
4. Apply *all* scope filters: `data.pod_id = pod-XX` (your assigned pod), `data.scenario_id = w04-broken-gate`, and `data.event_type = authorization.check`.
5. For normal authorization checks, filter `rule.id = 100141`. For a confirmed policy-violating allow, filter `rule.id = 100142`. Use a request ID or event ID supplied by the Pentest evidence to verify one exact event.
6. Record `@timestamp`, `data.event_time`, `data.request_id`, `data.event_id`, `data.synthetic_user_id`, `data.metadata.course_id`, `data.metadata.resource_id`, `data.metadata.actual_decision`, `data.metadata.policy_expected_decision`, and `data.metadata.http_status`. Some dashboard mappings show these as individual `data.*` fields.
7. Do not treat a 200 response alone as a vulnerability: rule **100142** requires an actual **allow**, policy **deny**, HTTP **200**, and `policy_violation` outcome together. A normal 403 is a valid security decision, not a confirmed breach.
8. A tunneled `source_ip` may represent the ingress socket peer rather than the Pentest EC2 IP. Use the actor ID, pod, course/resource and request ID for correlation.

### How Pentest activity creates the events

The Pentest trainee logs into an assigned synthetic account and runs one authorized read of an exact, assigned course resource:

```bash
bash neolabs http GET /api/courses/<course-id>/resources/<resource-id> --profile <assigned-profile-alias> --save
```

That runs **from the Pentest toolkit and its authorized tunnel**, *not* from the SOC server.

| VCC activity | Expected SOC evidence |
|---|---|
| Successful assigned-profile login | Authentication event, usually rule `100120` |
| Authenticated resource read (allowed or denied) | `authorization.check`, rule `100141` |
| Deliberately weak, explicitly enabled in-scope fixture actually returns a policy-violating allow | `authorization.check`, rule `100142` |
| VCC exporter health probe | `host.runtime_health`, usually rule `100180`; **does not** prove an authorization exploit |

One `GET /api/courses` request lists courses but does **not** itself exercise the course-resource authorization audit route. Exact target paths, aliases and IDs must come from the current Pentest manifest; there is no universal object ID or automatic attack command.

## 3. When alerts are missing

Check the central dashboard filters/time range first, then ask the mentor to compare that request ID against VCC Pod security log → SOC exporter → broker → collector → Wazuh manager → indexer. The local toolkit diagnostics are:

```bash
bash neolabs doctor
bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --scenario-id w04-broken-gate
```

Those commands validate **your local** Wazuh stack; they cannot certify the centrally administered dashboard. A healthy collector with zero new events means no new events were fetched in that poll, not proof of missing history or an attacker. Never delete data to force a new alert.

## 4. Submit your investigation

Submit in **NeoLabs-Security/RIL_NeoLabs-Intern-Assignments**, not this repository. Work under `submissions/week-04/soc/<github-username>/` on branch `week-04/soc/<github-username>-broken-gate` and open a PR against `main`. Do not merge it yourself.

Use `assignments/week-04/templates/incident-report.md` as `incident-report.md`. Include a UTC timeline, query journal (`queries.md`), an evidence register (`evidence-register.md`), and a short detection/response note (`detection-note.md`); attach only sanitized evidence. Distinguish raw/ingestion/indexing gaps, expected denials and actual policy violations. Never commit Access Codes, dashboard credentials, session tokens, cookies, passwords or cross-pod data.

The central assignment [submission handbook](https://github.com/NeoLabs-Security/RIL_NeoLabs-Intern-Assignments/blob/main/assignments/week-04/SUBMISSION_HANDBOOK.md) provides exact Git commands.
