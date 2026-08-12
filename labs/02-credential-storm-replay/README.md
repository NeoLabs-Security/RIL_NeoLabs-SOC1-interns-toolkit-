# Practice Lab 02 — Credential Storm Replay Investigation

**Track:** SOC Analyst Level 1  
**Scenario:** `w03-credential-storm`  
**Mode:** Post-exercise replay investigation  
**Difficulty:** Beginner → intermediate  
**Estimated time:** 2–3 hours  
**Version:** 0.1  
**Review date:** 2026-08-12

## Scenario

The VCC authentication service experienced a controlled high-volume login campaign during an authorised red-vs-blue exercise. The live exercise window has ended and the main target may no longer be available. Your SOC task is to reconstruct what happened from your server-assigned pod telemetry using the NeoLabs Replay Gateway and your local investigation tools.

You are not being asked to reproduce the attack. You are being asked to investigate it defensibly.

## Learning objectives

By the end of this lab you should be able to:

- distinguish credential stuffing from password spraying and ordinary brute-force activity;
- establish a normal authentication baseline before classifying a burst as suspicious;
- correlate failures, successes, sessions and later application activity;
- identify affected synthetic accounts without assuming every successful login is compromised;
- preserve event-time order when replay/ingest time differs from original event time;
- document evidence, uncertainty and data-quality limitations;
- propose a practical SOC detection improvement and a defensible containment recommendation;
- produce an escalation package suitable for Level 1 review.

## Key terminology

### Credential stuffing
Testing previously obtained username/password pairs against another service, relying on password reuse. MITRE ATT&CK maps this to **T1110.004 — Credential Stuffing**.

### Password spraying
Trying one or a small number of common passwords against many accounts. MITRE ATT&CK maps this to **T1110.003 — Password Spraying**.

### Brute force
A broader family of repeated password-guessing techniques. A high failure count by itself does not tell you which subtype occurred.

### Authentication success after failures
A successful login after a burst of failures is an important pivot, not automatic proof of compromise. Context matters: account, source, device/session, timing, later activity and visibility gaps.

## Safety boundary

- Use only your server-assigned VCC pod and the synthetic telemetry made available through the approved NeoLabs access flow.
- Do not test public systems, third-party systems, production systems or another pod.
- Do not attempt to replay the attack against the VCC service unless a mentor opens an explicit live exercise window.
- Do not place NeoLabs Access Codes, session tokens, certificates, private URLs or other secrets in screenshots, reports or Git commits.
- A replay URL or object URL is temporary evidence access, not permission to enumerate the underlying bucket.

## Preparation

Review before starting:

1. `labs/01-authentication-triage/README.md`
2. `docs/secops-foundations/02-alert-triage-evidence-and-escalation.md`
3. `docs/secops-foundations/03-siem-pipelines-and-log-quality.md`
4. the Log Literacy material on event time, ingest time, correlation IDs and evidence statements
5. the programme's Week 3 assignment Issue for the authorised time window and submission deadline

Authoritative references:

- MITRE ATT&CK T1110.004 — Credential Stuffing
- MITRE ATT&CK T1110.003 — Password Spraying
- OWASP Credential Stuffing Prevention Cheat Sheet
- OWASP Authentication Cheat Sheet

## Connect to the assigned replay

From the SOC toolkit root, use the programme-provided gateway configuration and your privately delivered Access Code:

```bash
python3 tools/neolabs.py login
python3 tools/neolabs.py connect
python3 tools/neolabs.py status
```

When the scenario state is replay/offline, the client should present only the replay resources authorised for your server-assigned pod. Do not try to override pod selection.

If the toolkit exposes approved evidence for the scenario, use:

```bash
python3 tools/neolabs.py evidence
```

Record the scenario ID, pod assignment and runtime state in your query journal, but do not record raw credentials or private signed URLs.

## Part A — Validate the evidence source

Before investigating the attack pattern:

1. confirm you are working on `w03-credential-storm`;
2. confirm the pod ID matches your programme assignment;
3. confirm the records are synthetic training telemetry;
4. identify the available telemetry sources;
5. identify the earliest and latest **event_time** in scope;
6. note whether replay/ingest timestamps differ from original event time;
7. record any telemetry-health or collection-gap events.

Your report must state what data you had, not only what conclusions you reached.

## Part B — Establish the baseline

Before classifying the burst, answer:

1. What does normal authentication volume look like immediately before the exercise window?
2. Which accounts normally authenticate during that baseline period?
3. Which source addresses, user agents or client types are typical?
4. What is the ordinary success-to-failure pattern?
5. Are there known service accounts or automated clients whose behaviour could resemble an attack?

A large count without a baseline is not enough for a defensible finding.

## Part C — Characterise the credential attack

Use exact queries and evidence IDs to determine:

1. when the abnormal authentication activity begins and ends;
2. how many accounts are targeted;
3. how many distinct source addresses are involved;
4. whether sources rotate or remain stable;
5. whether username/password-pair behaviour is more consistent with credential stuffing, password spraying or another pattern;
6. whether rate limiting, lockout or other controls appear to trigger;
7. whether any authentication succeeds during or shortly after the burst;
8. which accounts require deeper investigation.

Do not label the technique solely from volume. Explain why the observed pattern supports your classification.

## Part D — Pivot from success to session activity

For every suspicious successful authentication:

1. identify the resulting session/correlation identifier where available;
2. trace subsequent application or authorisation activity;
3. compare that activity to the account's baseline;
4. identify sensitive actions, privilege changes or unusual resource access;
5. document any denied or contained actions;
6. identify the point at which the session/account is contained, revoked or otherwise remediated if that evidence exists.

Separate direct evidence from interpretation.

## Part E — Build the incident timeline

Create a timeline that includes at minimum:

- pre-attack baseline;
- first abnormal authentication burst;
- meaningful changes in source/account pattern;
- suspicious authentication successes;
- session creation and post-login actions;
- SOC/support containment events if present;
- telemetry-health events that affect confidence;
- the end of the authorised exercise window.

Use **event time** as the primary ordering field. Note replay/ingest delay separately.

## Part F — Detection engineering proposal

Propose one Wazuh/SIEM detection improvement. It should define:

- data source(s);
- fields used;
- grouping key(s), such as account, source or time bucket;
- threshold or behavioural condition;
- time window;
- likely false positives;
- one enrichment/pivot an analyst should perform before escalation;
- how the rule would distinguish credential stuffing from normal user mistakes where possible.

You are being graded on reasoning, not on choosing the highest possible threshold.

## Part G — Containment and escalation recommendation

Write the Level 1 recommendation you would hand to a senior analyst. Address:

- affected synthetic account(s);
- whether active sessions should be revoked;
- whether password reset/MFA review is appropriate;
- whether source blocking/rate controls alone would be sufficient;
- what additional evidence should be collected;
- confidence level and major uncertainty;
- whether the incident should be escalated.

OWASP recommends defence in depth for automated authentication attacks; do not present a single IP block as a complete credential-stuffing control.

## Common analyst mistakes

- treating all failed logins as compromise;
- treating one later success as automatic proof of credential theft;
- confusing password spraying with credential stuffing;
- sorting replay data by ingest time rather than original event time;
- ignoring rotating sources because no single IP exceeds a threshold;
- failing to compare suspicious activity with baseline behaviour;
- interpreting zero results as proof when collection health is unknown;
- copying temporary signed URLs or Access Codes into evidence;
- reproducing the attack instead of investigating the approved telemetry.

## Required working notes

Use the toolkit templates for:

- incident report;
- evidence log;
- query journal;
- timeline.

Every material claim should point to an evidence/event identifier or a reproducible query.

## Graded assignment

The graded submission instructions live in the central Intern Assignments repository under the Week 3 SOC assignment. Follow that repository's branch, submission-path and Pull Request rules.

## Self-review checklist

- [ ] I confirmed scenario and server-assigned pod before analysis.
- [ ] I established a baseline before classifying the burst.
- [ ] I distinguished credential stuffing from password spraying with evidence.
- [ ] I investigated suspicious successes and later session activity.
- [ ] My timeline uses original event time.
- [ ] I recorded telemetry gaps/limitations.
- [ ] My detection proposal includes fields, grouping, threshold/window and false positives.
- [ ] My escalation recommendation separates fact, inference and uncertainty.
- [ ] My submission contains no secret, private URL or another pod's data.

## Instructor separation

This public student repository intentionally contains no answer key, affected-account list, attack source list, exact ground-truth timeline or unreleased VCC vulnerability details. Those belong only in mentor-controlled material.
