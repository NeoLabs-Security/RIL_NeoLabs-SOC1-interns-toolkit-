# Week 05 — SOC Level 1: Operation Poisoned Upload

**Status:** engineering/mentor validation. Keep W04 monitoring online until authorized scenario change. The existing single central Wazuh dashboard is the monitoring destination; the pod-scoped preview API is NOT a substitute for indexing.

## Scenario telemetry

The five W05 upload pods each emit canonical synthetic security events:
- `file.upload_accepted` → **100190** normal baseline accepted, **100191** if the `metadata.reason_code` is `extension_only_validation` (critical proof of mismatch).
- `file.upload_rejected` → **100192** validation denied.
- `file.upload_quarantined` → **100193** approved Support containment.

Required correlation: `scenario_id=w05-poisoned-upload`, `pod_id=pod-XX`, `event_id`, `event_time` (UTC), `request_id`, `metadata.reason_code`. A high-severity 100191 matching one event may supersede the lower-level 100190 in Wazuh; do not assume both appear for the same request.

## Actual central architecture

```text
Pentest browser -> W05 localhost-only gateway -> assigned W05 upload pod
                                          |
                                          +-> pod-XX security-events.jsonl
                                               |
                                     per-pod nonroot W05 exporter
                                               |
                    approved SSH -L 127.0.0.1:18426 -> central broker 127.0.0.1:18416
                                               |
                       central SOC event database (dedup by event_id)
                                               |
                          existing per-pod mTLS SOC collector
                                               |
                         existing Wazuh manager rules XML
                                               |
                            Filebeat -> Wazuh indexer
                                               |
                             central Wazuh dashboard
```

The separate Week 5 EC2 host has **no access to** `vcc-w04-mentor_default`: it is an entirely different Docker host. The new W05-only overlay explicitly uses a restricted operator-approved SSH loopback forward. **No public SOC ingest port is opened** and no W04 Docker resources or Wazuh credentials are altered by generating the overlay.

The exporter uses a persistent per-pod byte cursor. Central ingest responds 202 and deduplicates by `event_id`. The cursor advances **only after** a validated acknowledgement; a failed tunnel leaves the cursor intact. This demonstrates durable broker delivery, not Wazuh indexing. Distinct central SOC collectors remain pod-scoped by their existing mTLS assignments.

## Validate detection rules on actual Wazuh manager

On the authorized SOC/Wazuh host after updating this toolkit branch and ensuring the W05 custom rules file is deployed/mounted:

```bash
bash wazuh-stack/scripts/verify-week05-rule-engine.sh --logtest
```

This sends four harmless synthetic JSON events **only to wazuh-logtest**. It does not insert them into the event index, and does not claim delivery from the new VCC instance. All rules 100190, 100191, 100192 and 100193 should return PASS. If the manager has not loaded the updated rule file, coordinate a controlled configuration update first, leaving W04 rules in place.

Next, take an exact uploaded `event_id` from the authorized Pentest dashboard and confirm it is indexed on the central Wazuh machine:

```bash
bash wazuh-stack/scripts/verify-week05-rule-engine.sh --index \
  --pod pod-01 \
  --event-id '<REAL_W05_EVENT_ID>' \
  --rule-id 100191
```

Choose the rule matching that actual event: 100190 for legitimate accepted PNG; 100191 for vulnerable mismatch; 100192 for rejected file; 100193 for support quarantine. The script demands a matching *rule*, *pod*, *scenario*, *event ID* in `wazuh-alerts-*`. A broker response 202 or a CLI raw event does not prove a matching index hit.

## Mentor-only standalone preview

The provisional CLI `python3 tools/week05_client.py login && python3 tools/week05_client.py events` shows up to 100 raw synthetic events from exactly the pod assigned by a mentor-only W05 Access Code. This preview does not verify central Wazuh. Do not give the preview Access Codes to interns as replacements for their current broker logins.

Only publish Week 5 to interns after the original NeoLabs broker, SOC collector enrolments, the cross-host exporter and all five pods' real indexed correlation are accepted. Do not reset the central SOC cursor, W04 event history, W04 key or certificate authority.
