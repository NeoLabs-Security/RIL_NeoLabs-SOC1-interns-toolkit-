# Practice Lab 02 — Credential Storm Replay Investigation

**Track:** SOC Analyst Level 1  
**Scenario:** `w03-credential-storm`  
**Mode:** live exercise + post-exercise replay investigation  
**Difficulty:** Beginner → intermediate  
**Estimated time:** 2–3 hours  
**Version:** 1.0  
**Reconciled:** 2026-08-14

> **Staged material:** Do not begin this scenario until the Week 3 assignment/Issue is released and the NeoLabs server reports `w03-credential-storm` for your assigned pod.

## Scenario

The VCC authentication service experiences a controlled high-volume login campaign during an authorised red-vs-blue exercise. The interactive window may end while the SOC investigation continues from the assigned pod's archived telemetry through the Replay Gateway.

You are not being asked to reproduce an attack outside the approved window. You are being asked to investigate it defensibly.

## Learning objectives

By the end of the lab you should be able to distinguish credential stuffing from password spraying/ordinary brute force, establish a baseline, correlate failures/successes/sessions/application activity, preserve original event-time order during replay, identify evidence/telemetry limitations, propose a practical detection improvement and write a Level 1 escalation recommendation.

## Safety boundary

Use only your server-assigned synthetic VCC pod/scenario. Never test public/third-party/production systems or another pod. Do not reproduce credential attacks unless a mentor opens an explicit authorised live exercise window. Do not place Access Codes, Wazuh passwords, session tokens, certificates/private keys, signed URLs or private infrastructure details in screenshots, reports or Git commits.

## Preparation

Review:

1. `labs/01-authentication-triage/README.md`
2. `docs/secops-foundations/02-alert-triage-evidence-and-escalation.md`
3. `docs/secops-foundations/03-siem-pipelines-and-log-quality.md`
4. Log Literacy material on event time, ingest/index time, correlation IDs and evidence statements
5. the current Week 3 assignment Issue/window

## Connect and verify

### Windows recommended path

Pull the latest toolkit, make sure Docker Desktop/WSL2 is running and double-click:

```text
START-NEOLABS-SOC.cmd
```

Wait for `SOC WORKSTATION READY`, then confirm:

```powershell
.\neolabs.cmd status
```

The scenario must be `w03-credential-storm` and the pod must match the server assignment. If telemetry appears missing/stale, use:

```text
CHECK-NEOLABS-SOC.cmd
```

or:

```powershell
.\neolabs.cmd doctor
```

Do not interpret zero results until the telemetry path/freshness is healthy.

If the scenario publishes additional approved evidence, use:

```powershell
.\neolabs.cmd evidence
```

The NeoLabs client automatically handles the authorised LIVE/REPLAY mode. Do not enter a copied gateway URL or override pod selection.

## Part A — Validate the evidence source

Before analysing the attack:

1. confirm scenario `w03-credential-storm`;
2. confirm the server-assigned pod;
3. confirm records are synthetic;
4. identify available telemetry sources;
5. check the latest-event freshness and Telemetry Health view/rule `100150`;
6. identify earliest/latest original `event_time` in scope;
7. note replay/ingest/index timing separately;
8. record any collection/parser/visibility gaps.

Your report must state what data was available, not only conclusions.

## Part B — Establish the baseline

Determine normal authentication volume, ordinary success/failure behaviour, common synthetic accounts/service accounts, typical source/client characteristics and known benign automation immediately before the exercise.

A high count without a baseline is not enough for a defensible finding.

## Part C — Characterise the credential activity

Use reproducible Wazuh searches and evidence IDs to determine when abnormal authentication begins/ends, accounts targeted, distinct sources/source rotation, whether the pattern better fits credential stuffing/password spraying/another brute-force subtype, controls triggered, suspicious successes and accounts that require deeper review.

Do not classify solely from the scenario name or event volume.

## Part D — Pivot from success to session/application activity

For each suspicious successful authentication, pivot using available user/source/session/correlation identifiers. Trace later application/authorisation activity, compare it to baseline, identify sensitive/unusual actions and note containment/session revocation evidence if present. Separate direct observation from interpretation.

## Part E — Build the incident timeline

Include the pre-attack baseline, first abnormal burst, meaningful source/account-pattern changes, suspicious successes, session/post-login actions, containment/recovery signals, telemetry-health events that affect confidence and the end of the approved exercise window.

Use original **event time** as the primary ordering field. Replay/ingest/index delay is metadata, not the incident sequence.

## Part F — Detection engineering proposal

Propose one Wazuh/SIEM detection improvement. Define data source(s), fields, grouping keys, time window, threshold/behavioural condition, likely false positives, one analyst validation pivot and how ordinary user mistakes are reduced.

## Part G — Containment/escalation recommendation

Write the SOC L1 recommendation for a senior analyst. Address affected/potentially affected synthetic accounts, session revocation/password reset/MFA review where appropriate, additional evidence needed, confidence/uncertainty and whether escalation is warranted. Do not present a single source-IP block as a complete automated-login defence.

## Common analyst mistakes

- treating every failed login as compromise;
- treating one success after failures as automatic proof of theft;
- confusing spraying/stuffing/brute-force subtypes;
- sorting replay data by ingestion/index time instead of original event time;
- ignoring rotating sources;
- failing to establish baseline behaviour;
- interpreting zero results while telemetry health is unknown;
- copying private URLs/Access Codes/credentials into evidence;
- reproducing the attack instead of investigating approved telemetry.

## Working notes and graded assignment

Use the toolkit incident/evidence/query/timeline templates. Every material claim should point to an event/evidence identifier or reproducible query.

The graded submission instructions live in `NeoLabs-Security/RIL_NeoLabs-Intern-Assignments` under the Week 3 SOC brief. Follow that repository's branch, submission-path and Pull Request rules.

## Self-review

- [ ] Current server state confirms Week 3 + my assigned pod.
- [ ] `SOC WORKSTATION READY`/Doctor proves the telemetry path.
- [ ] Telemetry freshness/health was checked before interpreting gaps.
- [ ] I established a baseline before classifying the burst.
- [ ] I distinguished the technique using evidence.
- [ ] I investigated suspicious successes and later activity.
- [ ] My timeline uses original event time.
- [ ] I recorded evidence/telemetry limitations.
- [ ] My detection proposal includes fields, grouping, window/condition and false positives.
- [ ] My escalation recommendation separates fact, inference and uncertainty.
- [ ] My submission contains no secret/private URL/another pod's data.

## Instructor separation

This public student repository intentionally contains no answer key, affected-account list, attack-source list, exact ground-truth timeline or unreleased VCC weakness. Those remain mentor-controlled.
