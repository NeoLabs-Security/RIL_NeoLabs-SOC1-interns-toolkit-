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
2. Prepare the approved local [`wazuh-stack/`](wazuh-stack/).
3. Receive your pod number and private NeoLabs Access Code through the approved private channel.
4. Authenticate and connect:

```bash
python3 tools/neolabs.py login
python3 tools/neolabs.py connect
python3 tools/neolabs.py status
```

5. Wazuh enrols through the existing certificate-based SOC control plane and receives telemetry only for the server-assigned pod.
6. Complete the week's GitHub Issue and submit to `RIL_NeoLabs-Intern-Assignments`.

The student never needs to manually replace a pod IP when the VCC runtime is rebuilt.

## Toolkit contents

- eight beginner-to-intermediate Security Operations modules;
- Wazuh architecture, dashboard, deployment, troubleshooting and recovery guides;
- WQL/OpenSearch/`jq`/Linux/PowerShell query references;
- incident-report, evidence-register and query-journal templates;
- synthetic authentication data and guided defensive labs;
- pinned containerised Wazuh manager, indexer, dashboard and pod-scoped telemetry collector;
- local secret generation, preflight, health, reset, backup and restore controls;
- short-lived Access Code login layered over operator-authoritative SOC enrolment;
- locally generated private key + client certificate for pod-scoped telemetry;
- branded PDF publication pipeline and repository validation workflows.

## Architecture boundary

**Toolkit repo:** Learn + Connect + Operate  
**VCC Security Lab:** Target + Telemetry + Scenario  
**Lab Access Broker:** Authenticate + Resolve Pod + Authorise Resources  
**Central Assignment repo:** Task + Evidence + Submission + Assessment

SOC interns do not choose a telemetry target. The broker binds the generic internship assignment to the existing SOC enrolment assignment, and the telemetry API derives pod scope from the client certificate.

## Security rules

- Never commit Access Codes, broker sessions, enrolment tokens, certificates, private keys, private URLs or unredacted evidence.
- Never edit a local pod label in an attempt to access another pod.
- Use only synthetic data and authorised VCC resources.
- Keep `runtime/`, Wazuh state and certificate material local; these paths are ignored by Git.

## Release status

The toolkit on `main` contains the student-side broker client and the preconfigured SOC stack. Live use still depends on the VCC broker being deployed/enabled, operator-created cohort assignments and successful launch checks for the current scenario.
