# Week 03 — Credential Storm Blue detection guide

**Version:** 1.0  
**Reviewed:** 2026-09-28  
**Classification:** authorised synthetic training only

## Objective

Detect and document authentication activity for the 15 synthetic arena accounts, then give IT Security Support enough evidence to make an approved containment decision. Do not attempt account or firewall changes from the SOC workstation.

## Start-of-shift checklist

- Confirm the current assignment names `w03-credential-storm` and gives the dedicated arena hostname.
- Confirm Wazuh telemetry is fresh before treating an empty result as “no activity.”
- Use UTC and the exact account ID `syn-credential-storm-pod-01-01` through `-15`.
- Create an evidence ledger copy for your shift. Never overwrite the repository template.

## Triage loop

1. Find the earliest failed authentication event for an in-scope account.
2. Record event time, account ID, source address, event/result, alert or correlation ID and the query/time window used.
3. Look for a later successful login and any intervening containment event.
4. If failure exists and no success has occurred, send a containment request to the IT Security Support responder. Include only the account ID, alert/event ID, UTC time and concise reason.
5. Re-query after the response and record whether containment was confirmed.
6. Escalate disagreements or missing telemetry to the facilitator. Do not guess a winner.

## Decision rules

| Observation | Analyst action | Provisional state |
|---|---|---|
| Failure, no success, no containment | Request containment | pending |
| Failure, containment, then blocked attempt | Preserve linked events | Blue candidate |
| Success before containment | Preserve success event | Red candidate |
| No trustworthy telemetry | Run health checks and escalate | unclaimed |

A screenshot alone is not SOC ground truth. The facilitator reconciles Red screenshots with server events and the Blue ledger.

## Useful Wazuh fields

Field names can differ by decoder. Prefer the mapped field present in the event rather than inventing one: `@timestamp`, `data.scenario_id`, `data.account_id` or `user.id`, `source.ip`, `event.action`, `event.outcome`, `rule.id`, `rule.description`, `correlation.id`.

See [`wazuh-query-card.md`](wazuh-query-card.md) for bounded search patterns.

## Common mistakes

- awarding a Blue point for a lock performed after success;
- using ingest time instead of event time without saying so;
- searching all accounts but failing to record the time window;
- copying a password, token or cookie into evidence;
- treating a missing alert as proof when the telemetry pipeline is unhealthy.

## Exercise

For one facilitator-selected account, build a three-row timeline containing the initial failure, responder action and next authentication outcome. State whether the evidence supports Red, Blue or unclaimed, and name one limitation.

## References

- NIST SP 800-61 Rev. 2, Computer Security Incident Handling Guide.
- Wazuh documentation, threat hunting and dashboard query guidance.
- MITRE ATT&CK, Valid Accounts (T1078), used here only as a defensive classification reference.
