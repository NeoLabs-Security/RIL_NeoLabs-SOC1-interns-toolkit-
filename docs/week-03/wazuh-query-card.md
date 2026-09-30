# Week 3 Wazuh query card

Use the fields actually present in the event. These patterns are examples for the Wazuh/OpenSearch search bar; they do not change account state.

```text
data.scenario_id:"w03-credential-storm"
```

```text
data.scenario_id:"w03-credential-storm" AND data.synthetic_user_id:"syn-credential-storm-pod-01-01"
```

```text
data.scenario_id:"w03-credential-storm" AND data.outcome:("failure" OR "success")
```

```text
data.scenario_id:"w03-credential-storm" AND data.event_type:"network.https_request"
```

```text
rule.id:"100160"
```

Rule `100160` is the high-priority local alert produced when an exact IP on the analyst's detection-only `ip-blacklist` makes an HTTPS request to the arena.

```text
rule.id:"100122"
```

Rule `100122` is informational confirmed-hijack telemetry. It includes `data.synthetic_username`, `data.synthetic_user_id` and `data.source_ip`, but is deliberately level 3 rather than a prominent alert.

```text
data.scenario_id:"w03-credential-storm" AND data.event_type:host.*
```

Open **NeoLabs — Week 3 Arena Operations** for four live tables: network requests, account activity, sanitised machine/runtime health and blacklisted-IP hits. Use a short time range such as **Last 15 minutes** during the exercise.

Set an explicit UTC time window. Add the exact account ID before exporting or screenshotting evidence. If these fields are unmapped, inspect one raw event and use its corresponding account/outcome fields. Never widen the search to unrelated indexes, pods or systems.
