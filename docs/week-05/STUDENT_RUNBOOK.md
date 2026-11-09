# Week 05 SOC — Local Wazuh Workstation + VCC Live Telemetry

**Scenario:** `w05-poisoned-upload` · **Track:** SOC · **Assignment:** Your NeoLabs broker-issued pod

## Start on Ubuntu/Debian (including AWS SOC VPS)

From the SOC toolkit repository root:

```bash
git pull --ff-only origin main
bash start-neolabs-soc.sh
```

The original launcher prepares local prerequisites and, when required, installs Docker Engine/Compose, generates the local Wazuh 4.14.7 configuration/certificates, builds the telemetry collector, obtains your broker-assigned SOC live enrollment and starts your **own local Wazuh manager, indexer and dashboard**. Only use the repository's launcher; do not manually reset Docker or run an individual internal script.

Alternatively, after prerequisites are prepared, from the same repository root:

```bash
bash neolabs login --pod XX
bash neolabs connect
```

Replace `XX` with your assigned pod (e.g. `01`). Login accepts the *existing* NeoLabs Access Code. `connect` obtains the live SOC mTLS telemetry enrollment from the broker and starts or reuses your prepared local Wazuh stack. The Week 5 release's `INTERACTIVE_TEST` runtime mode is supported specifically for an authorized `SOC` `WAZUH_LIVE` assignment; it does not remove local Wazuh startup.

**First-run order:** prepare runtime → authenticate/login → obtain signed SOC bootstrap credentials → stage the issued collector credentials → start Wazuh → prove current pod/scenario telemetry is searchable. The launcher must never fail merely because there was no collector credential *before login*. It must reject incomplete credentials after an enrollment attempt, however.

## Dashboard and incident response

Once the launcher prints `SOC WORKSTATION READY`, open the **local Wazuh dashboard** URL it reports (normally HTTPS port 8443, subject to the approved VPS firewall). The Wazuh password is generated and stored privately in `wazuh-stack/.env`; never commit or paste it into a shared channel.

The mentor-operated **central Wazuh dashboard is also available separately** for the cohort. It does not replace your local Wazuh installation or authorize crossing into another pod. Use only the dashboard access and role permissions issued by the mentor.

For Week 5:

1. Filter `data.scenario_id = w05-poisoned-upload` and `data.pod_id = pod-XX`.
2. Correlate the Pentest `upload_id`, original `event_id`, request ID and detected/declared MIME.
3. Investigate rule **100190** (normal accepted), **100191** (suspicious accepted), **100192** (rejected) and **100193** (quarantined).
4. Share evidence for rule 100191 with authorized IT Support; after an approved quarantine verify the **new** containment event ID and rule 100193.
5. Record sanitized screenshots, UTC timestamps and indexed evidence. Do not share raw files, API tokens, access codes, TLS private keys or another pod's events.

**Submission:** Follow `assignments/week-05/soc.md` and `SUBMISSION_HANDBOOK.md` in the NeoLabs Intern Assignments repository. Submit `incident-report.md` and `evidence-register.md` in `submissions/week-05/soc/<github-username>/` by the mentor-issued deadline.

## Troubleshooting

- If the toolkit reports *local changes*, run `git status --short` and preserve local work before updating. Do **not** use `git reset --hard` or delete `wazuh-stack/.env`/generated credentials.
- If `connect` says live enrollment is unavailable, rerun `bash neolabs login --pod XX` to obtain a fresh authorized SOC bootstrap handoff, then rerun `connect`.
- If the local stack starts but current Week 5 events are missing, run `bash neolabs doctor` and report the failure stage. Do not claim READY until current pod/scenario events are actually indexed.
- A Docker group membership change may require a new SSH session for raw `docker` commands; the NeoLabs launcher handles approved child-process refresh automatically.
