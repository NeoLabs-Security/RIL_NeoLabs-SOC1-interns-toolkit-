# Module 6 — Linux, Web and Cloud Log Investigation

## Learning objectives

By the end of this module, a SOC Level 1 analyst should be able to:

- identify useful Linux, web-server, application and cloud-audit sources;
- correlate authentication, process, network and application events;
- recognise evidence-quality problems caused by time, parsing or missing fields;
- build a cross-source timeline without assuming that every unusual event is malicious;
- escalate findings with clear scope and limitations.

## 1. Linux evidence sources

Common Linux sources include:

| Source | Typical evidence |
|---|---|
| `journald` or system logs | service starts, failures, kernel and authentication messages |
| Authentication logs | SSH, sudo, account and session activity |
| Audit logs | system calls, file access, process execution and policy events |
| Shell history | limited user-command context when available and trustworthy |
| Package-manager logs | software installation, upgrade and removal |
| Cron and systemd timers | scheduled execution and persistence |
| Web-server logs | requests, response codes, user agents and source addresses |
| Application logs | authentication, errors, business events and API activity |
| Database logs | connection, authentication and query-related events |
| Cloud audit logs | API calls, identity, source address and resource changes |

Shell history is not a complete or tamper-resistant record. Treat it as supporting context, not as the only evidence of execution.

## 2. Linux authentication triage

For SSH or privilege-related alerts, capture:

- account name;
- source address;
- authentication method;
- success or failure;
- session start and end;
- `sudo` or privilege-transition activity;
- processes created in the session;
- changes to accounts, keys or authentication configuration.

A repeated-failure sequence followed by a success is important only when combined with context. Questions include:

- Is the source expected for the learner or administrator?
- Was the account active at that time?
- Did the successful session perform unusual activity?
- Were authorised maintenance or lab exercises scheduled?
- Did the source attempt multiple accounts or hosts?

## 3. Process and persistence review

Review execution from temporary, user-writable and hidden locations carefully. Record the process, parent, user, command line and linked network activity.

Common persistence locations to examine in an authorised investigation include:

- user and system cron entries;
- systemd services and timers;
- shell profile files;
- SSH `authorized_keys`;
- application startup hooks;
- container restart policies;
- cloud-init or deployment scripts.

Presence in one of these locations is not automatically malicious. Package installers and administrators use them legitimately. The analyst must determine who created the entry, when, why and what it executes.

## 4. Web-server investigation

Web access logs often provide:

```text
source address
request time
HTTP method
request path
status code
response size
referrer
user agent
request duration
```

Application and reverse-proxy logs may add authenticated user, request ID, route name, upstream status and error details.

### High-value patterns

Investigate patterns such as:

- many failed logins followed by a success;
- repeated requests to non-existent administrative paths;
- unusual methods or content types;
- path traversal strings or unexpected encoded paths;
- a request producing an application exception;
- upload activity followed by execution-like behaviour;
- a single request ID appearing across proxy, application and database logs.

A suspicious request does not prove successful exploitation. Confirm the response, application behaviour, downstream logs and resulting system changes.

## 5. Application and database correlation

Application logs provide business context that infrastructure logs may lack. Use correlation identifiers where available.

Example timeline:

```text
10:21:03  reverse proxy accepts POST /login from source A
10:21:03  application records failed authentication for user trainee-b
10:21:04  database records expected account lookup
10:22:18  reverse proxy accepts another POST /login from source A
10:22:18  application records successful authentication
10:22:24  application records export request for an unusual resource
```

Confirm that clocks and timezones align before ordering events. A two-minute clock difference can create a misleading sequence.

## 6. Cloud audit investigation

Cloud audit records commonly include:

- identity or role;
- API action;
- resource;
- source address and user agent;
- region;
- success or error result;
- request parameters;
- request or event identifier.

For an unexpected cloud action, determine:

1. which identity performed it;
2. how the identity authenticated;
3. whether the source and user agent are expected;
4. which resources were affected;
5. whether related actions occurred before or after it;
6. whether the action matches an approved lab scenario.

Never copy live cloud keys, session tokens or unredacted account identifiers into the public toolkit.

## 7. Data-quality checks

Before making a conclusion, check:

- timestamp format and timezone;
- host and source identity;
- duplicate events;
- parser or decoder errors;
- missing fields;
- delayed ingestion;
- inconsistent field names across sources;
- truncation of commands, URLs or messages;
- whether logs are synthetic, sanitised or live.

A data-quality defect can be the root cause of a misleading alert. Record it separately from the security disposition.

## 8. Correlation method

Use a repeatable method:

1. define the alert entity and time window;
2. collect the original event;
3. pivot by account, host, source address, process, request ID or resource;
4. normalise time and field names;
5. place events in chronological order;
6. test benign and malicious explanations;
7. identify gaps;
8. assign disposition and confidence;
9. document escalation or tuning recommendations.

## 9. Practice exercise

Investigate a synthetic web-login alert that includes Linux authentication events, reverse-proxy requests and application records. Determine whether the successful login is connected to the earlier failures, identify any follow-on activity and produce a short evidence-based escalation note.

The submission must state which logs were available, which were missing and how those limitations affected confidence.
