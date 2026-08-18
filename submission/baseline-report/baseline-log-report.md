# Week 1 Baseline Log Report

## 1. Alert / Investigation Summary

Operation Night Watch — Week 1 baseline review of pod-03 telemetry.

## 2. Scope

- Pod: pod-03
- Scenario: w01-night-watch-baseline
- Environment: vcc-security-lab
- Traffic profile: quiet-learning
- Telemetry type: Synthetic training telemetry

## 3. Telemetry Observed

- 1 scenario start event
- 3 authentication events
- 2 session events
- 5 authorized application/API access events
- 1 scenario verification event
- Total: 12 events

## 4. Normal Authentication Finding

One failed authentication was observed at 09:14:12 UTC.

The event was caused by invalid credentials and is identified in the telemetry as an ordinary baseline password mistype.

A successful authentication followed at 09:14:25 UTC.

## 5. Normal Application / API Activity

Five successful authorization events were observed.

The activity involved normal access to:
- Profile
- Course catalogue
- Lesson list
- Lesson assets
- Lesson progress

## 6. Baseline Queries

Reference query-journal.md.

## 7. Normal Activity Timeline

#	Time (UTC)	Activity	        Outcome	L1 Analyst Interpretation
1	09:14:00	Scenario started        success	Operation Night Watch baseline begins
2	09:14:12	Login attempt	        failure	Ordinary password mistype
3	09:14:25	Login	                success	User successfully authenticated
4	09:14:26	Session created	        success	User session established
5	09:14:40	Profile access	        success	Authorized API activity
6	09:14:55	Course catalogue access	success	Authorized API activity
7	09:15:10	Lesson list access	success	Authorized API activity
8	09:15:25	Lesson assets access	success	Authorized API activity
9	09:15:40	Lesson progress update	success	Authorized API activity
10	09:16:05	Session closed / logout	success	Normal session termination
11	09:16:35	Second login	        success	Another synthetic learner authenticated
12	09:17:00	Baseline verification	success	Telemetry presence verified

## 8. Visibility / Limitations

The dataset is a synthetic fallback replay pack rather than live production telemetry. It is sanitized/redacted and should be treated as training evidence. It lacks Wazuh alerts,firewall/network logs and endpoint telemetry.

## 9. Baseline Conclusion

The observed activity is consistent with the expected Week 1 quiet-baseline. No confirmed malicious activity was identified from the supplied telemetry.

the failed login should be retained as a baseline authentication event rather than treated as an attack/incident.
