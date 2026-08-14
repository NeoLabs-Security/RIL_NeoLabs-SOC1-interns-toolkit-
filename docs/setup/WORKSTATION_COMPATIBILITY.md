# NeoLabs SOC L1 Workstation Compatibility

For current programme/startup behaviour see [`../../PROGRAMME_CURRENT_STATE.md`](../../PROGRAMME_CURRENT_STATE.md).

## Supported baseline

Run before/when troubleshooting setup:

```bash
bash wazuh-stack/scripts/compatibility-check.sh
```

| Requirement | Hard floor | Preferred minimum | Recommended |
|---|---:|---:|---:|
| CPU architecture | 64-bit x86_64 or arm64 | 64-bit x86_64 | x86_64 |
| CPU capacity | 4 logical cores | 4 | 6+ |
| Memory visible to Linux/WSL2 | 7 GiB | 8 GiB | 12–16 GiB |
| Free disk | 25 GiB | 25 GiB | 50 GiB |
| Container runtime | Docker Engine/Desktop | Docker Engine/Desktop | current supported release |
| Compose | v2 | v2 | current supported v2 |
| `vm.max_map_count` | 262144 | 262144 | >=262144 |

Seven GiB is accepted as the constrained Week 1 floor. Below 7 GiB is unsupported because manager/indexer/dashboard may become unstable. Python 3, OpenSSL and curl are also required by toolkit validation/access tooling.

## Windows 11 + WSL2 — recommended cohort path

WSL2 is required for the Linux Wazuh stack, but Ubuntu is **not** mandatory. Kali, Ubuntu, Debian or another current WSL2 distribution is acceptable when Bash, Docker access, Python 3, OpenSSL and curl are present.

Enable Docker Desktop WSL integration for the distro being used. The current Windows entry point is:

```text
START-NEOLABS-SOC.cmd
```

The launcher/setup checks the workstation, prepares the stack only if needed and runs the Linux tooling through WSL2. Do not run the Wazuh stack directly from Git Bash/MSYS/Cygwin.

An existing toolkit checkout on the Windows filesystem can work when WSL2/Docker can access it; for best Linux container performance/permissions, a WSL/Linux filesystem checkout is preferred. Do not move a working cohort checkout mid-assignment merely to satisfy a preference if the compatibility/startup checks already pass.

### CRLF issue

The repository forces LF endings for shell scripts. If an old checkout reports `pipefail\r`/invalid option errors, repair line endings or re-checkout safely. Do not run `git reset --hard` when uncommitted student evidence/work must be preserved.

## Linux

Current Linux distributions are supported when Docker/Compose prerequisites and kernel settings pass. If required:

```bash
sudo sysctl -w vm.max_map_count=262144
```

Make persistence changes using the OS-approved sysctl mechanism.

## macOS

Intel Docker Desktop can be used when memory/disk requirements are satisfied. Apple Silicon is a review-warning path because each pinned Wazuh image must support the architecture; use a supported x86_64 Linux/WSL2 workstation when the pinned image set does not.

## Unsupported configurations

- 32-bit operating systems;
- legacy Docker Toolbox/Compose v1;
- browser-only/mobile environments;
- less than 7 GiB Linux/WSL2-visible memory;
- systems where the student cannot use local Docker;
- production/company shared infrastructure;
- public cloud hosts exposed as a student Wazuh server;
- Git Bash/MSYS/Cygwin as the Wazuh runtime.

## Current pre-start checklist

### Windows normal path

1. Pull the latest toolkit.
2. Start Docker Desktop/WSL2 integration.
3. Double-click `START-NEOLABS-SOC.cmd`.
4. Resolve any compatibility/setup failure it reports.
5. Do not begin Week 1 until `SOC WORKSTATION READY` confirms assigned-pod VCC telemetry is searchable.

### Manual/advanced path

1. Run compatibility check.
2. Prepare/reuse `.env` and generated Wazuh configuration.
3. Run preflight/start/health checks.
4. Use the NeoLabs toolkit access client for current LIVE/REPLAY assignment.
5. Run the telemetry pipeline verifier/Doctor before treating missing Wazuh data as an investigation result.

A warning may be accepted only when its risk is understood/documented. A failure must be corrected before the learner relies on the workstation for assignment evidence.
