# Week 05 — SOC standalone test guide (draft)

**Authorized target:** localhost gateway forwarded from mentor's separate Week 5 test server (TCP 18600). Authenticate only with your mentor-issued, pod-scoped **W05 SOC Access Code**.

```bash
python3 tools/week05_client.py login
python3 tools/week05_client.py status
python3 tools/week05_client.py target
python3 tools/week05_client.py events
python3 tools/week05_client.py logout
```

`events` returns up to 20 current raw synthetic events from the **assigned pod only**. It is **not** a Wazuh dashboard or proof of index ingestion.

New W05 Wazuh rules in the draft local rule file:
- 100190: upload accepted (baseline)
- 100191: content-mismatched file accepted by vulnerable release (high)
- 100192: upload rejected (normal audit)
- 100193: Support quarantined one synthetic upload

The synthetic event contract preserves `schema_version=1.0`, `scenario_id=w05-poisoned-upload`, exact `pod_id`, `event_id`, UTC `event_time`, `request_id` and `metadata.reason_code`.

For detached mentor-approved logs, `python3 tools/week05_upload_triage.py --file <approved.ndjson> --assigned-pod pod-01` produces a readable timeline. Wazuh live integration is a separate release gate and must show the actual event IDs in `wazuh-alerts-*`. No intern should claim indexing based only on this client.

The existing `bash neolabs` Wazuh setup and scope commands remain unchanged for Week 4; Week 5 switching remains pending release integration.
