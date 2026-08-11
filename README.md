# NeoLabs SOC Level 1 Intern Toolkit

The **NeoLabs × RIL SOC Level 1 Intern Toolkit** is the student-side **Learn + Connect + Operate** repository for authorised SOC training through the VCC Security Lab.

It contains NeoLabs-branded educational material, synthetic telemetry/labs, analyst templates, a preconfigured local Wazuh stack and the NeoLabs pod-access client. Official weekly assignments, evidence and graded submissions belong in the separate central assignments repository.

## Current week

**Week 02 — The Ghost Login**

- Learning source: `docs/week-02/ghost-login-learning-pack.md`
- Branded PDF: `publications/NeoLabs_SOC_L1_Week_02_Ghost_Login.pdf`
- Practical task: issued through `RIL_NeoLabs-Intern-Assignments`

## Student flow

1. Read [`START_HERE.md`](START_HERE.md) and [`LEARNING_PATH.md`](LEARNING_PATH.md).
2. Prepare the approved local [`wazuh-stack/`](wazuh-stack/), then install the repo CLI once with `python3 -m pip install --user -e .`.
3. Receive your pod number, stable NeoLabs lab URL and private NeoLabs Access Code through the approved private channel.
4. Authenticate and connect:

```bash
neolabs login
neolabs connect
neolabs status
```

5. `neolabs connect` follows the current NeoLabs runtime automatically:
   - **LIVE** — Wazuh uses the existing certificate-based SOC control plane and receives telemetry only for the server-assigned pod.
   - **REPLAY** — the large VCC server can be off; the client downloads only your pod/scenario S3 telemetry packs, validates them and appends them to the same Wazuh telemetry file.
   - **CLOUD_LIVE / ENDPOINT_LIVE** — archived/approved cloud or endpoint telemetry remains available even when the main VCC EC2 is off.
6. Use `neolabs evidence` when the current task includes approved native CloudTrail/S3/endpoint evidence.
7. Complete the week's GitHub Issue and submit to `RIL_NeoLabs-Intern-Assignments`.

The original security-event `event_time` is preserved during replay. A separate `neolabs_replay` field records when and from which S3 object the event was replayed.

The student never needs to manually replace a pod IP or know whether NeoLabs has stopped/restarted the underlying EC2.

## Toolkit contents

- eight beginner-to-intermediate Security Operations modules;
- Wazuh architecture, dashboard, deployment, troubleshooting and recovery guides;
- WQL/OpenSearch/`jq`/Linux/PowerShell query references;
- incident-report, evidence-register and query-journal templates;
- synthetic authentication data and guided defensive labs;
- pinned containerised Wazuh manager, indexer, dashboard and pod-scoped telemetry collector;
- local secret generation, preflight, health, reset, backup and restore controls;
- stable serverless Access Code login with live SOC enrolment handoff when required;
- S3 replay ingestion into the same Wazuh telemetry volume;
- locally generated private key + client certificate for live pod-scoped telemetry;
- branded PDF publication pipeline and repository validation workflows.

## Architecture boundary

**Toolkit repo:** Learn + Connect + Operate  
**Replay Gateway:** Always-available Authentication + Runtime State + S3 Replay  
**VCC Security Lab:** On-demand Target + Live Telemetry + Scenario  
**Private S3:** Durable pod-scoped Telemetry + Native Evidence  
**Central Assignment repo:** Task + Evidence + Submission + Assessment

SOC interns do not choose a telemetry target. Live pod scope is certificate-controlled; replay pod scope is derived from the authenticated assignment and S3 prefix.

## Useful commands

```text
neolabs login       authenticate with your pod + Access Code
neolabs connect     automatically use live telemetry or S3 replay
neolabs status      show LIVE / REPLAY / CLOUD_LIVE / ENDPOINT_LIVE state
neolabs evidence    download approved native evidence for your pod/scenario
neolabs pod info    show server-assigned pod information
neolabs disconnect  remove the local access-gateway session
```

## Security rules

- Never commit Access Codes, broker sessions, enrolment tokens, certificates, private keys, private URLs or unredacted evidence.
- Never edit a local pod label in an attempt to access another pod.
- Use only synthetic data and authorised VCC resources.
- Keep `runtime/`, Wazuh state, replay state and certificate material local; these paths are ignored by Git.
- Students never receive AWS credentials or bucket-wide S3 access.

## Release status

The toolkit on `main` contains the installable student client, preconfigured SOC stack, automatic live/replay behavior and the current branded Week 2 learning pack. Real cohort use still depends on the NeoLabs Replay Gateway/live broker being deployed, operator-created cohort assignments and the current scenario launch/replay checks.
