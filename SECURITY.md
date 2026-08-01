# Security Policy

## Authorised use only

This repository supports authorised, isolated and synthetic defensive training. Do not use its tools, examples or labs against systems without written permission.

## Never commit

- VCC enrolment tokens or pod credentials;
- private keys, certificates or generated passwords;
- real pod endpoints or private network details;
- AWS credentials, account identifiers or session tokens;
- unredacted student evidence or personal information;
- mentor-only scenario answers or ground truth;
- production data or production configuration.

## Pod isolation

An intern's Wazuh deployment must receive telemetry only from the pod assigned by the programme. Pod identity is established by the VCC Security Lab control plane and is not trusted from a student-controlled environment variable alone.

The intended flow is:

1. The programme issues a short-lived, single-use enrolment token.
2. The intern's local enrolment client sends the token over HTTPS.
3. The VCC enrolment API validates the token, intern status, cohort and assigned pod.
4. The service issues a revocable pod-scoped credential and configuration.
5. The telemetry gateway authorises every connection using the server-side assignment.

Changing a local `POD_ID` value must not grant access to another pod.

## Local deployment

- Bind administrative services to localhost unless the guide explicitly requires otherwise.
- Use strong generated passwords and restricted file permissions.
- Keep Docker, Compose and host operating-system packages updated.
- Disable active response by default.
- Run secret scanning before every pull request.

## Reporting a problem

Do not place secrets or exploit details in a public issue. Notify the NeoLabs programme operator through the approved private channel and include only the minimum evidence required.
