# Security Policy

## Scope

This repository is designed for authorised defensive training. It must contain only public educational content, synthetic or sanitised telemetry, safe configuration templates and student-facing tooling.

## Never commit

- passwords or API keys;
- VCC enrolment or refresh tokens;
- private keys or issued client certificates;
- private pod hostnames, IP addresses or internal routes;
- AWS account, role or resource identifiers that are not intentionally public;
- student personal information;
- raw screenshots or logs containing unredacted secrets;
- mentor solutions, scenario ground truth or unreleased vulnerabilities.

## Reporting a problem

Report suspected exposure privately to the NeoLabs programme operator. Do not open a public Issue containing a secret, private URL, exploitable lab detail or another learner's information.

## Student environment boundary

The local Wazuh stack is owned and operated by the learner. Connection to VCC telemetry is issued by the VCC enrolment service and restricted to the learner's assigned pod. A local configuration change must not be sufficient to access another pod.

## Supported security controls

The completed stack will include:

- pinned container versions;
- generated local credentials;
- TLS for enrolment and telemetry transport;
- short-lived, single-use bootstrap enrolment tokens;
- pod-scoped issued credentials;
- credential revocation and re-enrolment;
- health checks and safe diagnostics;
- secret scanning and configuration validation in CI;
- clear backup, reset and uninstall procedures.
