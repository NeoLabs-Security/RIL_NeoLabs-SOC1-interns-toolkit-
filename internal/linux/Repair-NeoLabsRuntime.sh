#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATE_ONLY=0
DAEMON_WAIT_SECONDS="${NEOLABS_DOCKER_WAIT_SECONDS:-45}"

log() { printf '[NeoLabs AutoFix] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAILED] %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --validate-only) VALIDATE_ONLY=1 ;;
    *) fail "Unknown AutoFix argument: $arg" ;;
  esac
done

run_root() {
  if (( EUID == 0 )); then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "NeoLabs AutoFix needs administrator privileges for Linux packages, Docker service repair and kernel settings. Install sudo or ask the machine administrator to run the prerequisite setup once."
  fi
}

save_diagnostics() {
  local reason="$1"
  local base="${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}"
  local log_dir="${base}/neolabs/logs"
  mkdir -p "$log_dir" 2>/dev/null || log_dir="/tmp/neolabs-logs"
  mkdir -p "$log_dir"
  local stamp path
  stamp="$(date -u +%Y%m%d-%H%M%S)"
  path="${log_dir}/linux-runtime-${stamp}.txt"
  {
    printf 'NeoLabs Linux runtime diagnostics - %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'Reason: %s\n\n' "$reason"
    printf '=== OS ===\n'
    cat /etc/os-release 2>&1 || true
    printf '\n=== KERNEL ===\n'
    uname -a 2>&1 || true
    printf '\n=== MEMORY ===\n'
    free -h 2>&1 || true
    printf '\n=== DISK ===\n'
    df -h 2>&1 || true
    printf '\n=== VM.MAX_MAP_COUNT ===\n'
    cat /proc/sys/vm/max_map_count 2>&1 || true
    printf '\n=== DOCKER VERSION ===\n'
    docker version 2>&1 || true
    printf '\n=== DOCKER COMPOSE ===\n'
    docker compose version 2>&1 || true
    printf '\n=== DOCKER INFO ===\n'
    docker info 2>&1 || true
    printf '\n=== DOCKER SERVICE ===\n'
    if command -v systemctl >/dev/null 2>&1; then
      systemctl status docker --no-pager -l 2>&1 || true
    elif command -v service >/dev/null 2>&1; then
      service docker status 2>&1 || true
    fi
    printf '\n=== RECENT DOCKER JOURNAL ===\n'
    if command -v journalctl >/dev/null 2>&1; then
      journalctl -u docker.service -n 160 --no-pager 2>&1 || true
    fi
    printf '\n=== NETWORK ===\n'
    ip addr 2>&1 || true
    ip route 2>&1 || true
    printf '\n=== DNS ===\n'
    cat /etc/resolv.conf 2>&1 || true
    printf '\n=== APT AUDIT ===\n'
    dpkg --audit 2>&1 || true
  } >"$path"
  warn "Automatic Linux recovery stopped. Diagnostic log: $path"
}

on_error() {
  local code=$?
  local line=${BASH_LINENO[0]:-unknown}
  save_diagnostics "AutoFix command failed at line ${line} with exit code ${code}."
  exit "$code"
}
trap on_error ERR

if (( VALIDATE_ONLY )); then
  command -v bash >/dev/null 2>&1 || fail "bash is required"
  [[ -f "${ROOT_DIR}/start-neolabs-soc.sh" ]] || fail "Root Linux launcher is missing"
  ok "Linux AutoFix contract is valid."
  exit 0
fi

if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
  fail "Do not run the whole NeoLabs launcher with sudo. Run ./start-neolabs-soc.sh as the normal intern user; AutoFix requests sudo only when required."
fi

[[ -r /etc/os-release ]] || fail "Cannot identify this Linux distribution."
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) fail "NeoLabs Linux AutoFix currently supports Ubuntu and Debian hosts. Use an Ubuntu/Debian SOC workstation or install the prerequisites manually for this distribution." ;;
esac
ok "Supported Linux host: ${PRETTY_NAME:-${ID}}"

wait_for_apt() {
  command -v fuser >/dev/null 2>&1 || return 0
  local deadline=$((SECONDS + 120))
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
        fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
        fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      fail "Ubuntu/Debian package manager remained busy for more than two minutes. Let the current apt/update task finish and rerun NeoLabs."
    fi
    log "Waiting for another package-manager task to finish..."
    sleep 3
  done
}

repair_package_state() {
  wait_for_apt
  if command -v dpkg >/dev/null 2>&1 && [[ -n "$(dpkg --audit 2>/dev/null || true)" ]]; then
    log "Repairing an interrupted Ubuntu/Debian package operation..."
    run_root dpkg --configure -a
    run_root env DEBIAN_FRONTEND=noninteractive apt-get -f install -y
  fi
}

install_base_packages() {
  local missing=0
  for cmd in bash curl git openssl python3; do
    command -v "$cmd" >/dev/null 2>&1 || missing=1
  done
  (( missing == 0 )) && return 0
  log "Installing missing Linux prerequisites automatically..."
  wait_for_apt
  run_root apt-get update
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y bash ca-certificates curl git gnupg openssl python3 util-linux procps iproute2
}

configure_docker_repository() {
  local codename architecture tmp_sources
  codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  [[ -n "$codename" ]] || fail "Could not determine the Ubuntu/Debian release codename required for Docker packages."
  architecture="$(dpkg --print-architecture)"

  wait_for_apt
  run_root apt-get update
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
  run_root install -m 0755 -d /etc/apt/keyrings
  run_root curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  run_root chmod a+r /etc/apt/keyrings/docker.asc

  tmp_sources="$(mktemp)"
  cat >"$tmp_sources" <<EOF
Types: deb
URIs: https://download.docker.com/linux/${ID}
Suites: ${codename}
Components: stable
Architectures: ${architecture}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  run_root cp "$tmp_sources" /etc/apt/sources.list.d/docker.sources
  rm -f "$tmp_sources"
  wait_for_apt
  run_root apt-get update
}

install_docker_engine() {
  configure_docker_repository
  log "Installing Docker Engine, Buildx and Compose v2 automatically..."
  wait_for_apt
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

ensure_compose_v2() {
  docker compose version >/dev/null 2>&1 && return 0
  log "Docker Compose v2 is missing; repairing it automatically..."
  wait_for_apt
  run_root apt-get update
  if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-v2
  else
    configure_docker_repository
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin
  fi
  docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is still unavailable after automatic repair."
}

start_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    run_root systemctl enable docker >/dev/null 2>&1 || true
    run_root systemctl start docker >/dev/null
  elif command -v service >/dev/null 2>&1; then
    run_root service docker start >/dev/null
  else
    fail "No supported service manager was found to start Docker."
  fi
}

restart_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    run_root systemctl daemon-reload >/dev/null 2>&1 || true
    run_root systemctl restart docker >/dev/null
  elif command -v service >/dev/null 2>&1; then
    run_root service docker restart >/dev/null
  fi
}

daemon_healthy() {
  if docker info >/dev/null 2>&1; then return 0; fi
  if (( EUID == 0 )); then return 1; fi
  run_root docker info >/dev/null 2>&1
}

wait_for_docker() {
  local seconds="$1"
  local deadline=$((SECONDS + seconds))
  while (( SECONDS < deadline )); do
    daemon_healthy && return 0
    sleep 2
  done
  return 1
}

upgrade_official_docker_packages() {
  dpkg-query -W -f='${Status}' docker-ce 2>/dev/null | grep -q 'install ok installed' || return 1
  log "Updating the installed Docker Engine packages as a bounded recovery step..."
  configure_docker_repository
  wait_for_apt
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

ensure_docker_engine() {
  if ! command -v docker >/dev/null 2>&1; then
    install_docker_engine
  fi

  ensure_compose_v2
  start_docker_service
  if wait_for_docker "$DAEMON_WAIT_SECONDS"; then
    ok "Docker Engine is healthy."
  else
    warn "Docker is installed but its daemon is not responding. Restarting the service automatically."
    restart_docker_service
    if wait_for_docker 45; then
      ok "Docker recovered after service restart."
    else
      warn "Docker still is not healthy. Trying one package update/recovery pass."
      if upgrade_official_docker_packages; then
        restart_docker_service
      fi
      if ! wait_for_docker 60; then
        save_diagnostics "Docker daemon did not recover after service restart and package recovery."
        trap - ERR
        exit 1
      fi
      ok "Docker recovered after package repair."
    fi
  fi

  if ! docker info >/dev/null 2>&1 && (( EUID != 0 )) && run_root docker info >/dev/null 2>&1; then
    log "Granting ${USER} Docker access so interns do not need sudo for Wazuh commands..."
    run_root groupadd -f docker
    run_root usermod -aG docker "$USER"
    warn "Docker group membership was repaired. The main launcher will refresh it automatically for this run when possible."
  fi
}

ensure_kernel_settings() {
  [[ -r /proc/sys/vm/max_map_count ]] || return 0
  local current
  current="$(cat /proc/sys/vm/max_map_count)"
  [[ "$current" =~ ^[0-9]+$ ]] || fail "Could not read vm.max_map_count."
  if (( current < 262144 )); then
    log "Applying the Wazuh indexer kernel setting automatically..."
    run_root sysctl -w vm.max_map_count=262144 >/dev/null
  fi
  if [[ -d /etc/sysctl.d ]]; then
    local tmp
    tmp="$(mktemp)"
    printf 'vm.max_map_count=262144\n' >"$tmp"
    run_root cp "$tmp" /etc/sysctl.d/99-neolabs-wazuh.conf
    rm -f "$tmp"
  fi
  ok "Wazuh kernel setting vm.max_map_count is ready."
}

repair_script_permissions() {
  find "${ROOT_DIR}/wazuh-stack/scripts" -type f -name '*.sh' -exec chmod u+x {} + 2>/dev/null || true
  chmod u+x "${ROOT_DIR}/start-neolabs-soc.sh" 2>/dev/null || true
}

repair_package_state
install_base_packages
ensure_docker_engine
ensure_kernel_settings
repair_script_permissions

trap - ERR
ok "Ubuntu/Debian runtime AutoFix completed. Continuing to NeoLabs SOC."
