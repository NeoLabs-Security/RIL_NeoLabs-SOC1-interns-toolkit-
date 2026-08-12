# Week 1 Launch Pack — Operation Night Watch

## Your objective
Build a defensible picture of **normal** VCC activity in your assigned pod. This baseline becomes the comparison point for later security incidents.

## Start in this order
1. Clone this SOC toolkit repository.
2. In the repository folder install the NeoLabs CLI:

```bash
python -m pip install -e .
```

3. Prepare the local Wazuh stack using `wazuh-stack/README.md` and its preflight steps.
4. Set the NeoLabs lab gateway URL supplied in your onboarding message.
5. Authenticate:

```bash
neolabs login
```

Enter **only your assigned pod number** and your private NeoLabs Access Code.

6. Verify your assignment:

```bash
neolabs status
neolabs pod info
```

7. Connect:

```bash
neolabs connect
```

When the lab is LIVE this enrols your local Wazuh through the pod-scoped mTLS channel. During REPLAY windows the same command loads only your authorised archived telemetry into the local Wazuh data path.

## What to study before the task
Use the material in `publications/` in this order:

1. **Log Literacy for Cybersecurity Analysts** — how to read and correlate security telemetry.
2. **SecOps Foundations / Field Guide** — evidence-first analyst workflow and escalation.
3. **SOC L1 Analyst Handbook** — deeper reference.
4. **Wazuh Deployment and Investigation Guide** — setup, dashboard workflow and troubleshooting.
5. **SOC L1 Complete Toolkit** — long-form reference; you do not need to read it cover-to-cover before Week 1.

## Week 1 task
1. Verify that the supplied synthetic verification event appears in Wazuh with the correct pod and scenario context.
2. Identify at least one normal successful sign-in and an ordinary failed sign-in if present.
3. Identify normal application/API activity and record useful fields such as timestamp, synthetic identity, request/event type, result/status and request/correlation identifier where available.
4. Identify storage or other approved telemetry visible for your pod.
5. Create and save at least **three reusable baseline searches/filters**.
6. Build a short normal-activity timeline using at least two event types.
7. Record one visibility gap: a question the current telemetry cannot answer and what additional source/field would help.
8. Do **not** label activity malicious simply because it looks unusual. Week 1 is the reference baseline.

## Deliverables
- `baseline-log-report.md`
- `timeline.md`
- `evidence-log.md`
- `query-journal.md`
- redacted screenshots where useful

## Baseline report headings
- Scope and assigned pod
- Sources visible in Wazuh
- Normal authentication pattern
- Normal application/API pattern
- Normal storage/other telemetry
- Three saved baseline queries
- Visibility gaps and limitations
- What you would compare against during a future incident

## Evidence standard
- Use event time, not only ingestion/replay time.
- Preserve request/event IDs where available.
- Separate observed facts from interpretation.
- Redact Access Codes, tokens, private keys and personal data.
- Never include another pod's data in your report.

## Stop conditions
Stop and contact a mentor if you receive another pod's events, real personal information, a private credential, unexpected infrastructure access or service instability.

## Before submission
- [ ] `neolabs status` shows the correct pod, track and Week 1 scenario.
- [ ] Wazuh is healthy.
- [ ] Three baseline queries are recorded.
- [ ] Timeline uses at least two event types.
- [ ] Evidence references are reproducible.
- [ ] Screenshots are redacted.
- [ ] Conclusions are supported by evidence.
