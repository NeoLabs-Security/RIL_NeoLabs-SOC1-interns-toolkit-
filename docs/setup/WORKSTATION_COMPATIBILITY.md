# NeoLabs SOC L1 Workstation Compatibility

For current startup behaviour see [`../../PROGRAMME_CURRENT_STATE.md`](../../PROGRAMME_CURRENT_STATE.md).

## Supported baseline

| Requirement | Hard floor | Preferred minimum | Recommended |
|---|---:|---:|---:|
| CPU architecture | 64-bit x86_64 or arm64 | 64-bit x86_64 | x86_64 |
| CPU capacity | 4 logical cores | 4 | 6+ |
| Memory visible to Linux/WSL2 | 7 GiB | 8 GiB | 12–16 GiB |
| Free disk | 25 GiB | 25 GiB | 50 GiB |
| Container runtime | Docker Engine/Desktop | Docker Engine/Desktop | current supported release |
| Compose | v2 | v2 | current supported v2 |
| `vm.max_map_count` | 262144 | 262144 | >=262144 |

Seven GiB is the constrained Week 1 memory floor. The launchers can install software and configure a kernel setting; they cannot fix insufficient RAM, CPU, disk capacity, blocked virtualisation or organisation policy.

## Windows 11 + WSL2

Use only:

```text
START-NEOLABS-SOC.cmd
```

The launcher owns the supported Windows prerequisite flow:

- WSL2 detection/bootstrap;
- an existing current WSL2 distribution, or Ubuntu installation only when no Linux distro exists;
- Docker Desktop detection/installation/startup;
- Linux container engine + WSL integration verification;
- missing Linux packages inside WSL;
- `vm.max_map_count` adjustment through the WSL root account;
- Wazuh first-run preparation and subsequent startup.

Ubuntu is not mandatory when the intern already has a suitable Kali, Debian, Ubuntu or other current WSL2 distro. Git Bash/MSYS/Cygwin is not a supported Wazuh runtime.

Windows can require one restart after enabling WSL or one initial launch of a newly installed Linux distro to create its Linux user. Rerun the same root CMD afterward.

The repository forces LF endings for shell scripts. The launcher also normalises executable permissions of internal shell scripts in case the toolkit was copied through a Windows filesystem.

## Ubuntu / Debian Linux

Use:

```bash
bash start-neolabs-soc.sh
```

Run it as the normal Linux account, **not** with `sudo` in front of the whole command. The launcher invokes administrator privileges itself only for:

- package/repository installation;
- Docker service/group setup;
- `vm.max_map_count` configuration/persistence.

When Docker is absent on Ubuntu/Debian, the launcher installs Docker Engine + Compose v2 and then gives the normal user Docker access. Wazuh runtime commands themselves should then run without `sudo`.

## Other Linux distributions

The root Bash launcher can operate when its prerequisites already exist. Automatic Docker installation is intentionally bounded to Ubuntu/Debian. On another distribution, install Docker Engine + Compose v2 through that distribution's supported method, then rerun the same launcher.

## Headless Linux server

Wazuh still binds the dashboard to loopback. If the server has no desktop/browser, the launcher prints a secure SSH local-port-forward example. Do not change the dashboard binding to `0.0.0.0` merely to make remote access easier.

## Unsupported configurations

- 32-bit operating systems;
- Docker Compose v1/legacy Docker Toolbox;
- less than 7 GiB Linux/WSL2-visible memory;
- systems where local Docker cannot be used;
- Git Bash/MSYS/Cygwin as the Wazuh runtime;
- public exposure of the local Wazuh administrative services;
- production/company shared infrastructure used as an internship target/workstation without explicit approval.

## Diagnostics

Windows:

```text
START-NEOLABS-SOC.cmd doctor
```

Linux:

```bash
./start-neolabs-soc.sh doctor
```

Mentors/advanced troubleshooting may still run `bash wazuh-stack/scripts/compatibility-check.sh`, but that internal check is diagnostic only. Students should not repair its failures by guessing where to add `sudo`; the platform launcher owns supported setup changes.
