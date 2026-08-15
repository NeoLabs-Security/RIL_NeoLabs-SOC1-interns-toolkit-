#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="start"
NO_BROWSER=0
VALIDATE_ONLY=0
LOCAL_DOCKER_HOST="unix:///var/run/docker.sock"

log() { printf '[NeoLabs] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAILED] %s\n' "$*" >&2; exit 1; }

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null
}

usage() {
  cat <<'EOF'
Usage: ./start-neolabs-soc.sh [start|doctor|status|login] [--no-browser]

Ubuntu/Debian: this launcher proves/repairs the native Docker runtime once, then
hands off to the shared NeoLabs SOC/Wazuh orchestrator. Healthy subsequent runs
do not repeat package installation, sudo setup or Docker service recovery.

Windows/WSL2: use START-NEOLABS-SOC.cmd. If this bash launcher is invoked inside
WSL anyway, it will use Docker Desktop only and will never install native Docker.
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

cd "$ROOT_DIR"

if (( VALIDATE_ONLY )); then
  for path in \
    internal/linux/Test-NeoLabsRuntime.sh \
    internal/linux/Repair-NeoLabsRuntime.sh \
    internal/common/Start-NeoLabsSOC.sh; do
    [[ -f "$path" ]] || fail "Required launcher component is missing: $path"
  done
  bash internal/linux/Test-NeoLabsRuntime.sh --validate-only >/dev/null
  bash internal/linux/Repair-NeoLabsRuntime.sh --validate-only >/dev/null
  bash -n internal/common/Start-NeoLabsSOC.sh
  ok 'Linux one-click launcher convergence contract is valid.'
  exit 0
fi

if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
  fail 'Do not run the whole NeoLabs launcher with sudo. Run it as the normal intern user; AutoFix elevates only the OS operations that actually need it.'
fi

common_args=("$ACTION")
if (( NO_BROWSER )); then common_args+=(--no-browser); fi

if is_wsl; then
  log 'Windows/WSL2 detected. Docker remains owned by Docker Desktop.'
  command -v docker >/dev/null 2>&1 || fail 'Docker Desktop integration is missing inside WSL. Run START-NEOLABS-SOC.cmd from Windows.'
  docker compose version >/dev/null 2>&1 || fail 'Docker Desktop Compose integration is unavailable inside WSL. Run START-NEOLABS-SOC.cmd from Windows.'
  [[ "$(docker info --format '{{.OSType}}' 2>/dev/null || true)" == linux ]] || fail 'Docker Desktop Linux engine is not reachable inside WSL. Run START-NEOLABS-SOC.cmd from Windows.'
  ok 'Docker Desktop integration is healthy; native-Linux Docker installation is intentionally skipped.'
  exec bash internal/common/Start-NeoLabsSOC.sh "${common_args[@]}" --host windows --no-browser
fi

log 'Checking the native Ubuntu/Debian runtime...'
if bash internal/linux/Test-NeoLabsRuntime.sh; then
  ok 'Native Linux runtime is already healthy; skipping sudo/package/Docker repair.'
else
  log 'Runtime is not ready. Running the single bounded Ubuntu/Debian AutoFix...'
  bash internal/linux/Repair-NeoLabsRuntime.sh || fail 'Linux AutoFix could not safely prepare this server. Review the diagnostic log path printed above.'
fi

# If AutoFix just added the intern to the docker group, refresh only this process
# instead of requiring a logout or repeating the installer. The guard prevents a
# loop if an unusual host still cannot use the local socket after group refresh.
if ! bash internal/linux/Test-NeoLabsRuntime.sh; then
  if [[ "${NEOLABS_GROUP_REFRESHED:-0}" != 1 ]] && command -v sg >/dev/null 2>&1 && getent group docker 2>/dev/null | grep -Eq "[:,]${USER}(,|$)"; then
    warn 'Docker access was repaired; refreshing docker-group membership for this launcher process.'
    printf -v quoted_root '%q' "$ROOT_DIR"
    printf -v quoted_action '%q' "$ACTION"
    extra=''
    if (( NO_BROWSER )); then extra=' --no-browser'; fi
    exec sg docker -c "cd ${quoted_root} && NEOLABS_GROUP_REFRESHED=1 exec bash ./start-neolabs-soc.sh ${quoted_action}${extra}"
  fi
  fail 'Ubuntu/Debian AutoFix completed, but the native runtime still fails its positive readiness test. Use the newest ~/.local/state/neolabs/logs/linux-runtime-*.txt for operator review.'
fi

# Pin only this NeoLabs process to the actual local Ubuntu Docker Engine so a
# stale user DOCKER_CONTEXT/DOCKER_HOST cannot redirect Wazuh to another host.
if [[ -S /var/run/docker.sock ]]; then
  unset DOCKER_CONTEXT
  export DOCKER_HOST="$LOCAL_DOCKER_HOST"
fi

exec bash internal/common/Start-NeoLabsSOC.sh "${common_args[@]}" --host linux
