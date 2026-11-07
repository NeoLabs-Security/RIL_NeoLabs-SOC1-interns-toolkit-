# Week 05 — Poisoned Upload (SOC preview)

**Under development; not a student launch announcement.**

The Wazuh local rules file now includes:
- `100190`: normal accepted synthetic W05 upload, level 3.
- `100191`: accepted synthetic content mismatch in intentionally vulnerable release, level 10.
- `100192`: denied synthetic W05 upload, level 5.
- `100193`: confirmed Support quarantine action, level 5.

All W05 rules depend on the existing canonical synthetic event rule `100100`. W04 rule IDs `100141/100142` are preserved. Actual Wazuh processing still requires an authorized W05 server exporter -> broker -> collector -> manager -> indexer chain.

Offline-only case triage for a mentor-authorized, assigned-pod NDJSON export:

```bash
python3 tools/week05_upload_triage.py --file ./approved-w05-events.ndjson \
  --assigned-pod pod-01 --out ./w05-soc-triage.md
```

The tool refuses cross-pod or nonsynthetic W05 records, preserves UTC event time and request IDs, and writes sanitized evidence. **This report is not proof the events were indexed in Wazuh.** The mentor must independently confirm rule 100191 and the exact event IDs in the central dashboard, plus rule 100193 after quarantine.

Remaining integration: compatible W05 SOC resource publication, central broker routing, exporter sidecar, saved dashboard filters and Wazuh `wazuh-logtest` execution and complete indexed-event verification. Keep Week 04 dashboards and rules intact.
