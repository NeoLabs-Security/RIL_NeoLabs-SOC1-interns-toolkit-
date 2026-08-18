# Week 1 Timeline


## Operation Night Watch — Pod-03

| # | Timestamp (UTC) | Event Type | Outcome | Activity / Observation | Significance |
|---|---|---|---|---|---|
| 1 | 09:14:00 | scenario-control.start | Success | Operation Night Watch scenario started for pod-03. | Establishes the beginning of the baseline activity. |
| 2 | 09:14:12 | authentication.login | Failure | Login failed because of invalid credentials. | Identified by the telemetry as an ordinary baseline password mistype. |
| 3 | 09:14:25 | authentication.login | Success | Synthetic learner successfully authenticated. | Successful login follows the failed attempt. |
| 4 | 09:14:26 | session.created | Success | A synthetic learning session was created. | Confirms successful session establishment. |
| 5 | 09:14:40 | authorization.access | Success | User accessed the profile API. | Normal authorized application activity. |
| 6 | 09:14:55 | authorization.access | Success | User accessed the course catalogue. | Normal authorized application activity. |
| 7 | 09:15:10 | authorization.access | Success | User accessed the lesson list. | Normal learning activity. |
| 8 | 09:15:25 | authorization.access | Success | User accessed lesson assets. | Normal authorized resource access. |
| 9 | 09:15:40 | authorization.access | Success | User updated lesson-progress information. | Normal learning-session activity. |
| 10 | 09:16:05 | session.closed | Success | User logged out and the session was closed. | Normal session termination. |
| 11 | 09:16:35 | authentication.login | Success | A second synthetic learner successfully logged in. | Establishes another normal authentication event. |
| 12 | 09:17:00 | scenario-control.verification | Success | Baseline telemetry verification completed successfully. | Confirms required baseline event families were present. |

## Timeline Summary

- **Scenario:** `w01-night-watch-baseline`
- **Assigned pod:** `pod-03`
- **Start:** 09:14:00 UTC
- **End:** 09:17:00 UTC
- **Duration:** 3 minutes
- **Event records:** 12
- **Authentication failures:** 1
- **Authentication successes:** 2
- **Confirmed malicious activity:** None identified in the supplied baseline telemetry
- **Primary event families:** Authentication, session, authorization, and scenario-control
