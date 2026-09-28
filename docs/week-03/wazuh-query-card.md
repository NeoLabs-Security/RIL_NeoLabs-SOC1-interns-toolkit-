# Week 3 Wazuh query card

Use the fields actually present in the event. These patterns are examples for the Wazuh/OpenSearch search bar; they do not change account state.

```text
data.scenario_id:"w03-credential-storm"
```

```text
data.scenario_id:"w03-credential-storm" AND data.account_id:"syn-credential-storm-pod-01-01"
```

```text
data.scenario_id:"w03-credential-storm" AND event.outcome:("failure" OR "success")
```

Set an explicit UTC time window. Add the exact account ID before exporting or screenshotting evidence. If these fields are unmapped, inspect one raw event and use its corresponding account/outcome fields. Never widen the search to unrelated indexes, pods or systems.
