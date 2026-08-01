# Module 5 — Windows and Sysmon Investigation

## Learning objectives

By the end of this module, a SOC Level 1 analyst should be able to:

- distinguish Windows security, system, PowerShell and Sysmon telemetry;
- build a short authentication and process timeline;
- recognise common high-value event relationships;
- separate suspicious behaviour from confirmed malicious activity;
- document evidence without exposing credentials or private infrastructure.

## 1. Windows evidence sources

A Windows investigation rarely depends on one event. The analyst correlates records that answer different questions.

| Source | Typical questions |
|---|---|
| Security log | Who signed in, from where, with which account and logon type? |
| System log | Did a service, driver or operating-system component fail or change? |
| PowerShell logs | What commands or script blocks were executed? |
| Microsoft Defender logs | Was malware, a potentially unwanted application or suspicious behaviour detected? |
| Sysmon | Which process, network, file, registry or image-loading activity occurred? |
| Application logs | Did the affected business application report authentication or execution errors? |

No single event source is complete. Missing telemetry must be recorded as an investigation limitation rather than silently treated as evidence that nothing happened.

## 2. Authentication timeline

Begin with the account, device and time window supplied in the alert. Expand the window enough to see activity immediately before and after the trigger.

Important Windows authentication concepts include:

- successful and failed logons;
- interactive, network, service, batch and remote-interactive logon types;
- source workstation or network address;
- privileged-logon indicators;
- account lockout and password-change activity;
- logoff or session termination.

A useful timeline might show:

```text
09:12:03  repeated failed network logons for trainee-a
09:13:20  successful remote-interactive logon for trainee-a
09:13:42  privileged process created in the new session
09:14:10  outbound connection to an unusual destination
09:16:02  session terminated
```

The timeline does not prove compromise by itself. It establishes sequence, scope and the next questions to test.

## 3. Process investigation

For each suspicious process, capture:

- process image and full path;
- parent process and parent path;
- command line;
- user and session identifier;
- hash when available;
- signature or publisher information when available;
- start time;
- network, file or registry activity linked to the process.

A process name is weak evidence. Attackers can rename files, while legitimate tools can appear suspicious when used by administrators. Parent-child relationships and command-line context are usually more useful.

Examples of questions:

- Was the process launched by the expected parent?
- Did an Office application, browser or script host create a command shell unexpectedly?
- Was the executable started from a user-writable or temporary path?
- Did the command line contain encoded content, credential access attempts or unusual download behaviour?
- Did the process create persistence or connect externally?

## 4. Sysmon relationships

Sysmon records detailed activity, but the analyst still needs correlation. High-value relationships include:

```text
process creation
  -> network connection
  -> file creation
  -> registry change
  -> child process
```

Use stable identifiers, such as process GUIDs, when they are available. Process IDs can be reused after a process ends and should not be treated as globally unique.

### Process creation

Capture the image, command line, parent, user, hashes and process GUID. Compare the path and parent relationship with the host's normal pattern.

### Network connection

Link the connection back to the process. Record destination IP or hostname, port, protocol, connection direction and whether the destination is expected for that application.

### File creation and modification

Record the path, creating process and timestamp. Files in temporary directories, startup folders or unusual user-profile locations deserve context, not automatic conviction.

### Registry activity

Focus on persistence locations, security-setting changes and application-specific configuration. A registry modification is meaningful only when the key, value, actor and timing are understood.

## 5. PowerShell review

PowerShell is a legitimate administrative tool and a common attack surface. Review:

- script-block content where available;
- module and engine events;
- parent process;
- user and session;
- encoded or obfuscated content;
- download, execution-policy or security-control changes;
- follow-on process and network activity.

Do not paste sensitive command output into public repositories. Redact tokens, passwords, private URLs and identifying student information.

## 6. Triage decision

Use an evidence-based disposition:

### Benign or expected

The activity matches an approved administrative or learning task, the account and device are expected, and no contradictory evidence is present.

### Suspicious — investigate further

The activity is unusual or incomplete, but available evidence does not yet establish malicious intent or impact.

### Likely malicious — escalate

Multiple independent signals support unauthorised activity, such as an unexpected remote logon followed by suspicious process execution and external communication.

### False positive or detection-quality issue

The event is real, but the rule or enrichment produced misleading severity or context. Preserve the evidence and recommend a safe tuning change.

## 7. Evidence checklist

For every Windows investigation, record:

1. alert identifier and trigger time;
2. affected host and account;
3. investigation time range and timezone;
4. relevant event sources;
5. authentication sequence;
6. process tree or key parent-child relationship;
7. network, file and registry evidence;
8. missing evidence and limitations;
9. disposition and confidence;
10. recommended containment or escalation.

## 8. Practice exercise

Using a synthetic dataset, identify a failed-login sequence followed by a successful remote-interactive logon. Build a five-event timeline, identify the first process created in the session and decide whether the evidence supports benign activity, suspicious activity or escalation.

Submit the result using the evidence-log, query-journal and incident-report templates. Do not include credentials, private pod addresses or mentor-only ground truth.
