# Broken Gate authorization investigation

Version 1.0.1. Reviewed 2026-10-26. Staged: use only after the mentor publishes `w04-broken-gate` for your assigned pod. This is individual, noncompetitive work.

## Objectives and terminology

Authentication identifies an account. Authorization decides whether that account may perform an action on a resource. Course enrolment and resource ownership are separate authorization relationships. Investigate both blocked attempts and successful access that violates the expected policy.

## Start and establish visibility

Use the existing root launcher: `bash start-neolabs-soc.sh` on Linux or `.\START-NEOLABS-SOC.cmd` on supported Windows. Use the current server-assigned pod/scenario and wait for verified READY. Old Week 1/3 alerts do not establish Week 4 readiness. Never select another pod or substitute a public target.

In Threat Hunting, select the original event-time investigation window and constrain every search to your assigned `data.pod_id` and `data.scenario_id: "w04-broken-gate"`. Add `data.event_type: "authorization.check"`. This contract retains the existing schema_version 1.0 envelope and source fields; it does not require another collector or SIEM.

Rule 100141 keeps authorization checks searchable at baseline level 3. Rule 100142 raises an alert only when actual allow, expected deny, HTTP 200 and policy_violation agree. A protected 403 alone is not evidence of disclosure. A successful 200 alone is not evidence of an authorization violation.

## Guided investigation

1. Establish a normal allowed check and an expected denial from the assigned evidence. Record event IDs, original `event_time`, request IDs and actor aliases.
2. Compare `data.metadata.actual_decision` with `data.metadata.policy_expected_decision`. A synthetic example of `allow` versus `deny` with status 200 warrants investigation of the actual returned material and its intended audience.
3. Pivot on `data.synthetic_user_id`, `data.metadata.course_id`, `data.metadata.resource_id` and `data.request_id`, preserving the pod/scenario filters. Build a UTC timeline; keep replay/ingestion time separate.
4. Record `data.source_ip`, `data.metadata.ingress_peer_ip` and `data.metadata.source_ip_provenance`. Socket-peer attribution through a tunnel may identify an intermediary rather than the intern's EC2. Do not replace it with the collector/agent address or claim IP alone proves identity.
5. Separate observation, policy evidence, hypothesis, conclusion and confidence. Link a Support escalation when authorized, using evidence IDs rather than credentials or copied private URLs.
6. Write an incident report and detection limitation note. Do not automatically block IPs, change roles or alter the lab.

## Review and common mistakes

- Why can successful authentication precede denied course access?
- What evidence distinguishes expected denial from successful policy-violating disclosure?
- Which actor/resource relationships support attribution when a tunnel hides original source IP?
- Explain why a missing alert might indicate missing ingestion/indexing rather than absence of a policy violation.

These rules do not prove that replay delivery, field mappings or indexing work. Mentor validation must test the real event-to-index path and a fixed retest before publication. Retain normal checks even when no high-severity alert fires. Never share tokens, session files, credentials, signed URLs or another pod's data.

After authorized enrolment and startup, the existing pipeline verifier accepts
`--scenario-id w04-broken-gate` and `--event-id` with an event ID from your assigned
evidence. It checks both Week 4 rule-engine branches and requires a matching
event in the collector volume and alert index. The index query includes rules
100141 and 100142. A local parser check or a successful rule-engine probe alone
does not establish end-to-end delivery. Verify representative expected denials
as well as policy violations; one searchable event does not prove all activities
were delivered. The event ID filters evidence; it does not grant pod access.

## References

The VCC `w04-broken-gate` integration contract is the event authority. Background references: [Wazuh rule syntax](https://documentation.wazuh.com/current/user-manual/ruleset/ruleset-xml-syntax/rules.html) and [OWASP authorization guidance](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html). Use the central assignment for deadline, submission path and grading requirements.
