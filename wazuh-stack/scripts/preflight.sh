#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

warn() {
  printf 'WARNING: %s\n' "$1" >&2
}

for command_name in docker git openssl python3 curl; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "${command_name} is not installed or is not on PATH."
done

docker compose version >/dev/null 2>&1 || fail "The Docker Compose plugin is unavailable."
docker info >/dev/null 2>&1 || fail "The Docker daemon is not running or the current user cannot access it."

[[ -f "${ENV_FILE}" ]] || fail "Missing wazuh-stack/.env. Run ./scripts/generate-local-secrets.sh first."

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

required_vars=(
  WAZUH_VERSION
  WAZUH_DOCKER_TAG
  WAZUH_DOCKER_COMMIT
  WAZUH_INDEXER_PASSWORD
  WAZUH_API_PASSWORD
  WAZUH_DASHBOARD_PASSWORD
  WAZUH_DASHBOARD_BIND
  WAZUH_DASHBOARD_PORT
)

for name in "${required_vars[@]}"; do
  [[ -n "${!name:-}" ]] || fail "Required variable ${name} is empty."
done

for name in WAZUH_INDEXER_PASSWORD WAZUH_API_PASSWORD WAZUH_DASHBOARD_PASSWORD; do
  value="${!name}"
  [[ "${value}" != CHANGE_ME* ]] || fail "${name} still contains the placeholder value."
  [[ ${#value} -ge 24 ]] || fail "${name} must contain at least 24 characters."
done

# Wazuh server API users enforce a stricter composition policy than the indexer
# users. render-runtime-credentials.sh migrates old hex-only values before this
# preflight, so reaching this point with an invalid API secret is a hard error.
[[ ${#WAZUH_API_PASSWORD} -le 64 ]] || fail "WAZUH_API_PASSWORD must not exceed 64 characters."
[[ "$WAZUH_API_PASSWORD" =~ [A-Z] ]] || fail "WAZUH_API_PASSWORD must contain an uppercase letter."
[[ "$WAZUH_API_PASSWORD" =~ [a-z] ]] || fail "WAZUH_API_PASSWORD must contain a lowercase letter."
[[ "$WAZUH_API_PASSWORD" =~ [0-9] ]] || fail "WAZUH_API_PASSWORD must contain a number."
[[ "$WAZUH_API_PASSWORD" =~ [^A-Za-z0-9] ]] || fail "WAZUH_API_PASSWORD must contain a symbol."

[[ "${WAZUH_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "WAZUH_VERSION must be pinned to an exact semantic version."
[[ "${WAZUH_DOCKER_TAG}" == "v${WAZUH_VERSION}" ]] || fail "WAZUH_DOCKER_TAG must match WAZUH_VERSION."
[[ "${WAZUH_DOCKER_COMMIT}" =~ ^[0-9a-f]{40}$ ]] || fail "WAZUH_DOCKER_COMMIT must be a full 40-character commit SHA."
[[ "${WAZUH_DASHBOARD_PORT}" =~ ^[0-9]+$ ]] || fail "WAZUH_DASHBOARD_PORT must be numeric."
(( WAZUH_DASHBOARD_PORT >= 1024 && WAZUH_DASHBOARD_PORT <= 65535 )) || fail "WAZUH_DASHBOARD_PORT must be between 1024 and 65535."

exposure="${NEOLABS_DASHBOARD_EXPOSURE:-auto}"
exposure="${exposure,,}"
case "$exposure" in auto|loopback|server) ;; *) fail "NEOLABS_DASHBOARD_EXPOSURE must be auto, loopback or server." ;; esac
case "${WAZUH_DASHBOARD_BIND}" in
  127.0.0.1|::1|localhost)
    ;;
  0.0.0.0)
    [[ "${NEOLABS_HOST_MODE:-}" == linux ]] || fail "Publishing the dashboard on all interfaces is allowed only by the native Linux server profile."
    [[ "$exposure" != loopback ]] || fail "Dashboard exposure is loopback but WAZUH_DASHBOARD_BIND is 0.0.0.0."
    ;;
  *)
    fail "Unsupported WAZUH_DASHBOARD_BIND. Use loopback or the approved native-Linux server profile."
    ;;
esac

python3 - "${ENV_FILE}" <<'PY'
from pathlib import Path
import stat
import sys

path = Path(sys.argv[1])
mode = stat.S_IMODE(path.stat().st_mode)
if mode & 0o077:
    raise SystemExit(f"ERROR: {path} permissions are too broad ({mode:o}); run chmod 600 {path}")
PY

if [[ -r /proc/sys/vm/max_map_count ]]; then
  max_map_count="$(cat /proc/sys/vm/max_map_count)"
  if (( max_map_count < 262144 )); then
    fail "vm.max_map_count is ${max_map_count}; Wazuh indexer requires at least 262144. Follow the setup guide before startup."
  fi
fi

if [[ -r /proc/meminfo ]]; then
  memory_kib="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
  if [[ -n "${memory_kib}" ]] && (( memory_kib < 7 * 1024 * 1024 )); then
    warn "Less than approximately 7 GiB RAM is visible. The all-in-one Wazuh stack may be unstable or slow."
  fi
fi

if [[ "${POD_LABEL:-UNENROLLED}" != "UNENROLLED" ]]; then
  printf 'NOTICE: POD_LABEL is only a local display label; it does not grant pod access.\n'
fi

for secret_path in \
  "${VCC_CLIENT_KEY_PATH:-}" \
  "${VCC_CLIENT_CERT_PATH:-}" \
  "${VCC_CA_CERT_PATH:-}"; do
  if [[ -n "${secret_path}" && -e "${ROOT_DIR}/${secret_path#./}" ]]; then
    python3 - "${ROOT_DIR}/${secret_path#./}" <<'PY'
from pathlib import Path
import stat
import sys
path = Path(sys.argv[1])
mode = stat.S_IMODE(path.stat().st_mode)
if mode & 0o077:
    raise SystemExit(f"ERROR: credential permissions are too broad ({mode:o}): {path}")
PY
  fi
done

printf 'Preflight checks passed. No containers were started.\n'
