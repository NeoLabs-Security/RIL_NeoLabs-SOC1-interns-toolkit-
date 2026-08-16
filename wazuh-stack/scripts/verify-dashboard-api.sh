#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WAIT_SECONDS="${1:-90}"
[[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || { printf 'ERROR: dashboard API wait must be numeric.\n' >&2; exit 2; }
[[ -f .env ]] || { printf 'ERROR: Missing wazuh-stack/.env.\n' >&2; exit 2; }
# shellcheck disable=SC1091
set -a
source .env
set +a
: "${WAZUH_API_PASSWORD:?WAZUH_API_PASSWORD is required}"

check_once() {
  docker compose --env-file .env exec -T \
    -e NEOLABS_WAZUH_API_PASSWORD="$WAZUH_API_PASSWORD" \
    wazuh.dashboard sh -ceu '
      config=/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
      test -s "$config"
      grep -Fq "url: \"https://wazuh.manager\"" "$config"
      grep -Fq "username: wazuh-wui" "$config"
      grep -Fq "password: \"${NEOLABS_WAZUH_API_PASSWORD}\"" "$config"
      token="$(curl -skf -u "wazuh-wui:${NEOLABS_WAZUH_API_PASSWORD}" -X POST \
        "https://wazuh.manager:55000/security/user/authenticate?raw=true")"
      test -n "$token"
      curl -skf -H "Authorization: Bearer ${token}" "https://wazuh.manager:55000/?pretty=false" >/dev/null
    ' >/dev/null 2>&1
}

start=$SECONDS
while true; do
  if check_once; then
    printf '[OK] Wazuh dashboard API connector authenticated to wazuh.manager:55000.\n'
    exit 0
  fi
  if (( SECONDS - start >= WAIT_SECONDS )); then
    printf '[FAILED] Wazuh dashboard cannot authenticate to the manager API with the current local credential.\n' >&2
    exit 1
  fi
  sleep 3
done
