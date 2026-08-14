# NeoLabs SOC L1 Workstation Compatibility

## Supported baseline

The student Wazuh stack is designed for a personally controlled workstation used only for authorised NeoLabs/RIL training. Run the compatibility check before downloading images or starting the stack:

```bash
bash wazuh-stack/scripts/compatibility-check.sh
```

A supported workstation should provide:

| Requirement | Hard floor | Preferred minimum | Recommended |
|---|---:|---:|---:|
| CPU architecture | 64-bit x86_64 or arm64 | 64-bit x86_64 | x86_64 |
| CPU capacity | 4 logical cores | 4 logical cores | 6 or more logical cores |
| System memory | 7 GiB visible to Linux/WSL2 | 8 GiB | 12–16 GiB |
| Free disk space | 25 GiB | 25 GiB | 50 GiB |
| Container runtime | Docker Engine/Desktop | Docker Engine/Desktop | Current supported Docker release |
| Compose | Docker Compose v2 | Docker Compose v2 | Current supported v2 release |
| Linux kernel setting | `vm.max_map_count=262144` | `262144` | `262144` or higher |

Seven GiB is accepted for Week 1 as a constrained training configuration. Close heavy applications before starting the stack. Below 7 GiB remains unsupported because the Wazuh indexer, manager and dashboard may become unstable.

The stack also needs Python 3, OpenSSL and curl for validation and secure enrolment.

## Platform guidance

### Ubuntu or another current Linux distribution

This is the preferred student platform. Docker must be running, and the learner's account must be permitted to use it. Set the indexer mapping limit before startup when the compatibility check reports a failure:

```bash
sudo sysctl -w vm.max_map_count=262144
```

Make the setting persistent using the operating system's approved sysctl configuration process.

### Windows 11 with WSL2

WSL2 is required for the Linux Wazuh stack, but **Ubuntu is not mandatory**. Ubuntu, Kali, Debian or another current WSL2 Linux distribution is acceptable when Bash, Docker access, Python 3, OpenSSL and curl are available. You do **not** need to install a separate Ubuntu Server virtual machine.

Use Docker Desktop with WSL integration enabled for the distro you intend to use. Store the repository inside the Linux filesystem, such as `~/neolabs-soc1-toolkit`, rather than under `/mnt/c/`; Linux filesystem storage provides more predictable permissions and container performance.

Do not run the Wazuh stack directly from Git Bash, MSYS or Cygwin. The Windows `.cmd` launcher is only an entry point; the Linux stack itself belongs inside WSL2.

#### If Bash reports `invalid option name: ... pipefail`

That normally means the repository was checked out with Windows CRLF line endings and Bash is reading `pipefail\r`. The repository now forces LF endings for shell scripts. For an older checkout, from the repository root run:

```bash
git config core.autocrlf false
git reset --hard
```

If you have uncommitted work you need to keep, do not use `git reset --hard`; instead repair only the affected script:

```bash
sed -i 's/\r$//' wazuh-stack/scripts/compatibility-check.sh
```

Then run the check again with Bash.

### macOS on Intel

Docker Desktop is supported when the machine meets the memory and disk requirements. Allocate enough Docker Desktop memory for the indexer, manager, dashboard and telemetry collector.

### macOS on Apple Silicon

The scripts and learning materials work on arm64, but each pinned Wazuh container release must publish a compatible arm64 image. The compatibility check therefore reports Apple Silicon as a review warning rather than an unconditional pass. Use an x86_64 Linux or WSL2 workstation when the pinned release does not provide the required image architecture.

## Unsupported configurations

The following configurations are outside the supported student baseline:

- 32-bit operating systems;
- Docker Toolbox or legacy Compose v1;
- production servers or shared company infrastructure;
- public cloud hosts exposed directly to the internet;
- systems with less than 7 GiB memory visible to Linux/WSL2;
- systems where the learner does not control local Docker access;
- mobile devices and browser-only coding environments.

## Pre-start checklist

1. Run `compatibility-check.sh` and resolve every failure.
2. Confirm that the repository is on a local, trusted Linux/WSL2 filesystem.
3. Run the toolkit workstation setup so `wazuh-stack/.env` and local secrets are prepared.
4. Run `preflight.sh` and `prepare-stack.sh`.
5. Start the stack and run `health-check.sh`.
6. Complete VCC enrolment only with a private, operator-issued token.

A warning may be accepted only when its risk is understood and documented. A failure must be corrected before the learner starts the Wazuh stack.
