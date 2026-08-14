#!/usr/bin/env bash
set -euo pipefail

# The single-node training stack can run in a constrained Week 1 workstation with
# 7 GiB visible to the Linux/WSL2 VM. Eight GiB remains the preferred floor and
# 12 GiB is recommended for smoother indexing and dashboard use.
HARD_MIN_MEMORY_GIB="${SOC_HARD_MIN_MEMORY_GIB:-7}"
PREFERRED_MEMORY_GIB="${SOC_MIN_MEMORY_GIB:-8}"
RECOMMENDED_MEMORY_GIB="${SOC_RECOMMENDED_MEMORY_GIB:-12}"
MIN_DISK_GIB="${SOC_MIN_DISK_GIB:-25}"
STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0
WARNINGS=0

pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '[FAIL] %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

# A common Windows checkout failure is CRLF line endings. Bash then parses
# `pipefail\r` as an invalid option. Give a useful diagnosis instead of leaving
# the learner to debug the shell itself.
if grep -q $'\r' "$0" 2>/dev/null; then
  printf '[FAIL] This script has Windows CRLF line endings.\n' >&2
  printf '       From the repository root run: git config core.autocrlf false && git reset --hard\n' >&2
  printf '       Or run: sed -i '\''s/\r$//'\'' "%s"\n' "$0" >&2
  exit 1
fi

os_name="$(uname -s 2>/dev/null || echo unknown)"
architecture="$(uname -m 2>/dev/null || echo unknown)"
case "${os_name}" in
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      platform="Windows with WSL2"
    else
      platform="Linux"
    fi
    ;;
  Darwin) platform="macOS" ;;
  MINGW*|MSYS*|CYGWIN*) platform="Windows shell" ;;
  *) platform="${os_name}" ;;
esac

printf 'NeoLabs SOC L1 workstation compatibility check\n'
printf 'Platform: %s\nArchitecture: %s\n\n' "${platform}" "${architecture}"

case "${architecture}" in
  x86_64|amd64|aarch64|arm64) pass "Supported 64-bit architecture detected (${architecture})." ;;
  *) fail "Unsupported or unverified architecture: ${architecture}." ;;
esac

if command -v docker >/dev/null 2>&1; then
  pass "Docker command is installed."
  if docker info >/dev/null 2>&1; then
    pass "Docker engine is reachable."
  else
    fail "Docker is installed but the engine is not reachable. Start Docker Desktop or the Docker service."
  fi
else
  fail "Docker is not installed."
fi

if docker compose version >/dev/null 2>&1; then
  pass "Docker Compose v2 is available."
else
  fail "Docker Compose v2 is unavailable."
fi

if command -v openssl >/dev/null 2>&1; then pass "OpenSSL is available."; else fail "OpenSSL is required."; fi
if command -v python3 >/dev/null 2>&1; then pass "Python 3 is available."; else fail "Python 3 is required."; fi
if command -v curl >/dev/null 2>&1; then pass "curl is available."; else fail "curl is required."; fi

memory_gib=""
if [[ -r /proc/meminfo ]]; then
  memory_kib="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
  memory_gib="$((memory_kib / 1024 / 1024))"
elif command -v sysctl >/dev/null 2>&1; then
  memory_bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"
  if [[ "${memory_bytes}" =~ ^[0-9]+$ ]]; then
    memory_gib="$((memory_bytes / 1024 / 1024 / 1024))"
  fi
fi

if [[ -n "${memory_gib}" ]]; then
  if (( memory_gib < HARD_MIN_MEMORY_GIB )); then
    fail "Only ${memory_gib} GiB RAM detected; this training stack needs at least ${HARD_MIN_MEMORY_GIB} GiB visible to Linux/WSL2."
  elif (( memory_gib < PREFERRED_MEMORY_GIB )); then
    warn "${memory_gib} GiB RAM detected. Week 1 may run, but ${PREFERRED_MEMORY_GIB} GiB is the preferred minimum; close other heavy applications before starting Wazuh."
  elif (( memory_gib < RECOMMENDED_MEMORY_GIB )); then
    warn "${memory_gib} GiB RAM detected; ${RECOMMENDED_MEMORY_GIB} GiB or more is recommended for smoother Wazuh use."
  else
    pass "${memory_gib} GiB RAM detected."
  fi
else
  warn "Unable to determine total system memory."
fi

available_disk_gib="$(df -Pk "${STACK_DIR}" | awk 'NR==2 {print int($4/1024/1024)}')"
if [[ "${available_disk_gib}" =~ ^[0-9]+$ ]]; then
  if (( available_disk_gib < MIN_DISK_GIB )); then
    fail "Only ${available_disk_gib} GiB free disk space; at least ${MIN_DISK_GIB} GiB is required."
  else
    pass "${available_disk_gib} GiB free disk space is available."
  fi
else
  warn "Unable to determine available disk space."
fi

if [[ "${platform}" == "Windows shell" ]]; then
  fail "Git Bash/MSYS/Cygwin cannot host the Wazuh Linux stack. Run the toolkit in any WSL2 Linux distro (Ubuntu, Kali, Debian, etc.) with Docker Desktop WSL integration enabled. A separate Ubuntu Server VM is not required."
elif [[ "${platform}" == "Windows with WSL2" ]]; then
  pass "WSL2 environment detected. Any supported Linux distro is acceptable; Ubuntu is not mandatory."
elif [[ "${platform}" == "macOS" && "${architecture}" == "arm64" ]]; then
  warn "Apple Silicon detected. Confirm every pinned Wazuh image publishes an arm64 manifest; use an x86_64 Linux/WSL2 machine when a release is unavailable."
fi

if command -v sysctl >/dev/null 2>&1 && [[ "${platform}" == "Linux" || "${platform}" == "Windows with WSL2" ]]; then
  vm_max_map_count="$(sysctl -n vm.max_map_count 2>/dev/null || true)"
  if [[ "${vm_max_map_count}" =~ ^[0-9]+$ ]]; then
    if (( vm_max_map_count < 262144 )); then
      fail "vm.max_map_count is ${vm_max_map_count}; Wazuh indexer requires at least 262144."
    else
      pass "vm.max_map_count is ${vm_max_map_count}."
    fi
  else
    warn "Unable to read vm.max_map_count."
  fi
fi

printf '\nResult: %d failure(s), %d warning(s).\n' "${FAILURES}" "${WARNINGS}"
if (( FAILURES > 0 )); then
  exit 1
fi
