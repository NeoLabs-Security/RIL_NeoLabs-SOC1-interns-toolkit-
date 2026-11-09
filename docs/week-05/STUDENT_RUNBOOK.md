# Week 05 SOC L1 — Central Wazuh student runbook

**Operation:** Poisoned Upload · **Scenario:** `w05-poisoned-upload` · **Track:** SOC

## Start here (Ubuntu / SOC VPS)

From the SOC toolkit repository root:

```bash
git switch main
git pull --ff-only origin main
bash neolabs login --pod XX
bash neolabs connect
```

Replace `XX` with your **assigned** pod number and enter the existing private NeoLabs Access Code at the prompt. Use your own assignment; never choose another pod.

For Week 05, successful `connect` displays **WEEK 05 CENTRAL SOC ACCESS READY** after verifying that the live broker publishes `SOC`, `STUDENT_READY`, your exact pod, `INTERACTIVE_TEST` or `LIVE`, and the `WAZUH_LIVE` central-dashboard resource.

**Do not run a new local Wazuh installation for Week 05.** You use the *existing shared central Wazuh dashboard* and the mentor-issued dashboard credentials. The `bash start-neolabs-soc.sh` launcher also detects an existing authenticated Week 05 SOC session and takes this central route without installing Docker or regenerating a local Wazuh instance.

No SSH tunnel or local collector enrollment is necessary for the Week 05 central-dashboard workflow. The NeoLabs access code authorizes the assignment; it is **not** a Wazuh dashboard password. Use the Wazuh login details delivered privately by the mentor. Dashboard access must follow the mentor's approved network and role restrictions.

## Investigation checklist

Open your authorized central Wazuh dashboard. In Threat Hunting:

- Filter `data.scenario_id = w05-poisoned-upload`.
- Filter `data.pod_id = pod-XX` for your *actual* authorized pod.
- Correlate exact original `event_id` and `upload_id` reported by Pentesting.
- Check rule **100190** for valid accepted PNG, **100191** for suspicious accepted mismatch, **100192** for rejected upload, and **100193** for approved Support quarantine.
- Record UTC event time, indexed time, request ID, observed action, and Wazuh alert/rule ID.
- Distinguish central-indexed proof from raw exporter/broker logs. Authentication alone **does not** prove an event is indexed.

Share the suspicious upload ID and confirmed rule 100191 alert with Support. After mentor-approved quarantine, check the **new** containment event ID against rule 100193 in the central index. Do not modify or delete any raw evidence or attempt other pods.

## Submission

In the central Intern Assignments repository, use the official Week 05 SOC brief and submission handbook. Under
`submissions/week-05/soc/<github-username>/` submit `incident-report.md` and `evidence-register.md`, with sanitized screenshots or event references. Open a PR to `main` and leave it open for assessment. The official Week 05 mentor Issue determines the due date.

Do not commit passwords, SSH material, access codes, bearer tokens, session files or private dashboard URLs.

## Troubleshooting

If `connect` says **Week 05 SOC central Wazuh scope is not published**, first confirm your broker-assigned track/pod with `bash neolabs status`; report the exact error to the mentor. Do **not** change the scenario or add local client credentials.

If `bash start-neolabs-soc.sh` still starts installing a local Wazuh stack, update `main`, verify you are using the expected repository root, and run `bash neolabs login --pod XX` before invoking the launcher. The early central route requires an existing saved Week 05 SOC session; a fresh machine with no session may enter the legacy local launcher.

If broker access succeeds but Wazuh shows no assigned-pod events, notify the mentor to check central Wazuh indexing and pod authorization. Do not assume that installation of local Docker or Wazuh will repair central telemetry.
