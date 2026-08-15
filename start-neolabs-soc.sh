#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATEWAY_URL="${NEOLABS_LAB_BASE_URL:-https://pg1wb0sklb.execute-api.us-east-1.amazonaws.com}"
ACTION="start"
NO_BROWSER=0
VALIDATE_ONLY=0

log() { printf '[NeoLabs] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAILED] %s\n' "$*" >&2; exit 1; }

run_root() {
  if (( EUID == 0 )); then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "This first-run setup needs administrator privileges for OS packages/kernel settings. Install sudo or ask the server administrator to run the prerequisite installation."
  fi
}

usage() {
  cat <<'EOF'
Usage: ./start-neolabs-soc.sh [start|doctor|status|login] [--no-browser]

Normal use:
  ./start-neolabs-soc.sh

First run installs/checks Linux prerequisites, Docker Engine + Compose (Ubuntu/Debian),
prepares Wazuh, authenticates to NeoLabs and verifies assigned-pod telemetry.
Subsequent runs reuse the installation and simply start/reconnect/verify Wazuh.
EOF
}

for arg in "$@"; do
  case "$arg" in
    start|doctor|status|login) ACTION="$arg" ;;
    --no-browser) NO_BROWSER=1 ;;
    --validate-only) VALIDATE_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $arg" ;;
  esac
done

if (( VALIDATE_ONLY )); then
  [[ -f "${ROOT_DIR}/tools/cli.py" ]] || fail "tools/cli.py is missing"
  [[ -f "${ROOT_DIR}/wazuh-stack/scripts/generate-local-secrets.sh" ]] || fail "Wazuh secret generator is missing"
  [[ -f "${ROOT_DIR}/wazuh-stack/scripts/prepare-stack.sh" ]] || fail "Wazuh prepare script is missing"
  [[ -f "${ROOT_DIR}/wazuh-stack/scripts/verify-telemetry-pipeline.sh" ]] || fail "Wazuh telemetry verifier is missing"
  ok "Linux one-click SOC launcher contract is valid."
  exit 0
fi

if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  fail "Do not run the whole launcher with sudo. Run it as your normal Linux user; the launcher uses sudo only for the few OS-level installation/kernel steps that require it."
fi

cd "${ROOT_DIR}"

install_base_packages() {
  local missing=0
  for cmd in bash curl git openssl python3; do
    command -v "$cmd" >/dev/null 2>&1 || missing=1
  done
  (( missing == 0 )) && return 0

  log "Installing missing Linux prerequisites..."
  if command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y bash ca-certificates curl git gnupg openssl python3
  elif command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y bash ca-certificates curl git openssl python3
  elif command -v yum >/dev/null 2>&1; then
    run_root yum install -y bash ca-certificates curl git openssl python3
  else
    fail "Unsupported package manager. Install bash, curl, git, openssl and Python 3, then rerun this launcher."
  fi
}

install_docker_ubuntu_debian() {
  [[ -r /etc/os-release ]] || fail "Cannot identify this Linux distribution for Docker installation."
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) ;;
    *) fail "Automatic Docker Engine installation currently supports Ubuntu and Debian. Install Docker Engine + Compose v2 using your distribution's official method, then rerun this launcher." ;;
  esac

  log "Installing Docker Engine and Compose from Docker's official apt repository..."
  run_root apt-get update
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
  run_root install -m 0755 -d /etc/apt/keyrings
  run_root curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  run_root chmod a+r /etc/apt/keyrings/docker.asc

  local codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  [[ -n "$codename" ]] || fail "Could not determine Ubuntu/Debian codename for Docker's apt repository."
  local architecture
  architecture="$(dpkg --print-architecture)"
  local tmp_sources
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
  run_root apt-get update
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

start_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    run_root systemctl enable --now docker >/dev/null
  elif command -v service >/dev/null 2>&1; then
    run_root service docker start >/dev/null
  fi
}

ensure_docker_access() {
  if ! command -v docker >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      install_docker_ubuntu_debian
    else
      fail "Docker is not installed. Automatic Docker installation is currently supported on Ubuntu/Debian only."
    fi
  fi

  if ! docker compose version >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      log "Docker Compose v2 is missing; installing a Compose v2 package..."
      run_root apt-get update
      if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
        run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-v2
      elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
        run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin
      fi
    fi
  fi
  docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is unavailable."

  start_docker_service

  if docker info >/dev/null 2>&1; then
    return 0
  fi

  # If root can reach Docker but this normal user cannot, grant the standard
  # docker-group access and immediately re-enter the launcher with that group.
  if (( EUID != 0 )) && run_root docker info >/dev/null 2>&1; then
    log "Granting the current user access to Docker without requiring sudo on every Wazuh command..."
    run_root groupadd -f docker
    run_root usermod -aG docker "${USER}"
    if command -v sg >/dev/null 2>&1; then
      local reargs="$ACTION"
      if (( NO_BROWSER )); then reargs+=" --no-browser"; fi
      exec sg docker -c "cd $(printf '%q' "$ROOT_DIR") && exec bash ./start-neolabs-soc.sh ${reargs}"
    fi
    fail "Docker access was granted to ${USER}, but this shell cannot refresh group membership automatically. Log out/in once and rerun ./start-neolabs-soc.sh."
  fi

  fail "Docker is installed but the daemon is not reachable. Check the Docker service and rerun this launcher."
}

ensure_kernel_setting() {
  [[ -r /proc/sys/vm/max_map_count ]] || return 0
  local current
  current="$(cat /proc/sys/vm/max_map_count)"
  [[ "$current" =~ ^[0-9]+$ ]] || fail "Could not read vm.max_map_count."
  if (( current < 262144 )); then
    log "Configuring vm.max_map_count=262144 for the Wazuh indexer..."
    run_root sysctl -w vm.max_map_count=262144 >/dev/null
    if [[ -d /etc/sysctl.d ]]; then
      local tmp_sysctl
      tmp_sysctl="$(mktemp)"
      printf 'vm.max_map_count=262144\n' >"$tmp_sysctl"
      run_root cp "$tmp_sysctl" /etc/sysctl.d/99-neolabs-wazuh.conf
      rm -f "$tmp_sysctl"
    fi
  fi
}

install_base_packages
ensure_docker_access
ensure_kernel_setting

# Make executable bits deterministic even when a repository was copied from a
# Windows filesystem. LF line endings are enforced separately by .gitattributes.
find wazuh-stack/scripts -type f -name '*.sh' -exec chmod u+x {} +
chmod u+x start-neolabs-soc.sh

if [[ "$ACTION" == "status" ]]; then
  export NEOLABS_LAB_BASE_URL="$GATEWAY_URL"
  exec python3 -m tools.cli status
fi
if [[ "$ACTION" == "login" ]]; then
  export NEOLABS_LAB_BASE_URL="$GATEWAY_URL"
  exec python3 -m tools.cli login
fi
if [[ "$ACTION" == "doctor" ]]; then
  export NEOLABS_LAB_BASE_URL="$GATEWAY_URL"
  exec python3 -m tools.cli doctor
fi

log "Checking workstation compatibility..."
bash wazuh-stack/scripts/compatibility-check.sh || fail "Compatibility check found a blocking issue."

first_run=0
if [[ ! -f wazuh-stack/.env ]]; then
  first_run=1
  log "First run detected. Generating private Wazuh credentials..."
  bash wazuh-stack/scripts/generate-local-secrets.sh || fail "Could not generate local Wazuh credentials."
fi

if (( first_run )) || [[ ! -f wazuh-stack/generated/config/wazuh_cluster/wazuh_manager.conf ]]; then
  log "Preparing the pinned Wazuh stack. The first run can take several minutes while images/configuration are downloaded..."
  bash wazuh-stack/scripts/prepare-stack.sh || fail "Wazuh stack preparation failed."
else
  ok "Existing Wazuh installation/configuration found; it will be reused."
fi

export NEOLABS_LAB_BASE_URL="$GATEWAY_URL"
if [[ ! -f "${HOME}/.neolabs/soc/session.json" ]]; then
  log "Sign in with your assigned pod number and private NeoLabs Access Code."
  python3 -m tools.cli login || fail "NeoLabs login failed."
else
  log "Checking your saved NeoLabs session..."
  if ! python3 -m tools.cli status; then
    warn "Saved session is expired or no longer accepted; requesting a fresh login."
    python3 -m tools.cli login || fail "NeoLabs login failed."
  fi
fi

log "Connecting authorised VCC telemetry and starting Wazuh..."
python3 -m tools.cli connect || fail "NeoLabs connect/Wazuh startup failed."

log "Waiting for Wazuh health..."
bash wazuh-stack/scripts/health-check.sh --wait 600 || fail "Wazuh did not become healthy within the allowed startup period."

log "Confirming current pod/scenario status..."
python3 -m tools.cli status || fail "Final NeoLabs status check failed."

log "Proving that assigned-pod VCC telemetry is searchable in Wazuh..."
if ! bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --wait 180; then
  warn "Telemetry is not searchable yet. Attempting one bounded local repair."
  bash wazuh-stack/scripts/repair-telemetry-pipeline.sh || fail "The telemetry-to-indexer path could not be verified after one safe repair attempt."
fi

log "Checking latest-event freshness..."
bash wazuh-stack/scripts/telemetry-freshness.sh || warn "Telemetry is searchable but its freshness needs review; run ./start-neolabs-soc.sh doctor."

# shellcheck disable=SC1091
source wazuh-stack/.env
dashboard_port="${WAZUH_DASHBOARD_PORT:-8443}"
[[ "$dashboard_port" =~ ^[0-9]{2,5}$ ]] || dashboard_port=8443
dashboard_url="https://127.0.0.1:${dashboard_port}"
open_url="$dashboard_url"
if [[ -f wazuh-stack/state/dashboard-objects.ready ]]; then
  open_url="${dashboard_url}/app/dashboards#/view/neolabs-night-watch"
fi

clipboard="no"
password="${WAZUH_INDEXER_PASSWORD:-}"
if [[ "$password" =~ ^[0-9a-fA-F]{48}$ ]]; then
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$password" | wl-copy
    clipboard="yes"
  elif [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
    printf '%s' "$password" | xclip -selection clipboard
    clipboard="yes"
  fi
fi
unset password

printf '\n\033[32mSOC WORKSTATION READY\033[0m\n'
printf 'Dashboard: %s\n' "$dashboard_url"
printf 'Username:  admin\n'
if [[ "$clipboard" == "yes" ]]; then
  printf 'Password:  copied to your Linux desktop clipboard.\n'
else
  printf 'Password:  kept private in wazuh-stack/.env (WAZUH_INDEXER_PASSWORD).\n'
fi
printf 'Verified: assigned-pod VCC telemetry is indexed and searchable in Wazuh.\n'
printf 'Troubleshooting: ./start-neolabs-soc.sh doctor\n'

if (( NO_BROWSER == 0 )) && command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  log "Opening the NeoLabs SOC dashboard..."
  xdg-open "$open_url" >/dev/null 2>&1 &
else
  printf '\nHeadless/remote Linux: Wazuh is running, but there is no local GUI browser to open.\n'
  printf 'From your own computer you can forward the loopback dashboard over SSH, for example:\n'
  printf '  ssh -L %s:127.0.0.1:%s <linux-user>@<server-address>\n' "$dashboard_port" "$dashboard_port"
  printf 'Then open %s in your local browser.\n' "$dashboard_url"
fi
