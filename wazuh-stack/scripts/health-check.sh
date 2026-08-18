#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

WAIT_SECONDS=0
if [[ "${1:-}" == "--wait" ]]; then
  WAIT_SECONDS="${2:-600}"
fi
[[ "${WAIT_SECONDS}" =~ ^[0-9]+$ ]] || { printf 'ERROR: wait value must be numeric.\n' >&2; exit 2; }

services=(wazuh.manager wazuh.indexer wazuh.dashboard vcc.telemetry.collector)
started_at="$(date +%s)"

service_health() {
  local service="$1"
  local container_id state health
  container_id="$(docker compose --env-file .env ps -q "${service}")"
  [[ -n "${container_id}" ]] || { printf 'missing'; return; }
  state="$(docker inspect --format '{{.State.Status}}' "${container_id}")"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container_id}")"
  printf '%s/%s' "${state}" "${health}"
}

server_issued_pod() {
  if [[ -s state/assigned-pod ]]; then
    tr -d '\r\n' < state/assigned-pod
    return
  fi
  local manifest="${REPO_ROOT}/runtime/access-manifest.json"
  [[ -f "$manifest" ]] || return 0
  python3 - "$manifest" <<'PY'
import json,re,sys
try:
    pod=str(json.load(open(sys.argv[1], encoding='utf-8')).get('pod_id') or '')
except Exception:
    pod=''
if re.fullmatch(r'pod-[0-9]{2}', pod):
    print(pod)
PY
}

while true; do
  all_healthy=true
  printf 'NeoLabs Wazuh health status:\n'
  for service in "${services[@]}"; do
    status="$(service_health "${service}")"
    printf '  %-26s %s\n' "${service}" "${status}"
    case "${status}" in
      running/healthy|running/none) ;;
      *) all_healthy=false ;;
    esac
  done

  if [[ "${all_healthy}" == true ]]; then
    # shellcheck disable=SC1091
    source .env
    printf 'Dashboard: https://%s:%s\n' "${WAZUH_DASHBOARD_BIND}" "${WAZUH_DASHBOARD_PORT}"
    pod="$(server_issued_pod | tail -n1 | tr -d '\r\n')"
    if [[ "$pod" =~ ^pod-[0-9]{2}$ ]]; then
      printf 'Server-issued pod: %s\n' "$pod"
    else
      printf 'Server-issued pod: PENDING LOGIN/ASSIGNMENT\n'
    fi
    exit 0
  fi

  now="$(date +%s)"
  elapsed=$(( now - started_at ))
  if (( WAIT_SECONDS == 0 || elapsed >= WAIT_SECONDS )); then
    printf 'One or more services are not healthy. Review docker compose logs without publishing secrets.\n' >&2
    exit 1
  fi

  sleep 10
  printf '\n'
done
