#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || fail "Docker is not installed or is not on PATH."
docker compose version >/dev/null 2>&1 || fail "The Docker Compose plugin is unavailable."

[[ -f "${ENV_FILE}" ]] || fail "Missing wazuh-stack/.env. Copy .env.example to .env and configure it."

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

required_vars=(
  WAZUH_VERSION
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
  [[ ${#value} -ge 16 ]] || fail "${name} must contain at least 16 characters."
done

[[ "${WAZUH_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "WAZUH_VERSION must be pinned to an exact semantic version."
[[ "${WAZUH_DASHBOARD_PORT}" =~ ^[0-9]+$ ]] || fail "WAZUH_DASHBOARD_PORT must be numeric."

if [[ "${POD_LABEL:-UNENROLLED}" != "UNENROLLED" ]]; then
  printf 'NOTICE: POD_LABEL is only a local display label; it does not grant pod access.\n'
fi

printf 'Preflight checks passed. No containers were started.\n'
