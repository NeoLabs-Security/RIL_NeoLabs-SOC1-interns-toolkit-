#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

[[ -f .env ]] || { printf 'ERROR: wazuh-stack/.env is missing.\n' >&2; exit 2; }
# shellcheck disable=SC1091
set -a
source .env
set +a

: "${WAZUH_INDEXER_PASSWORD:?WAZUH_INDEXER_PASSWORD is required}"
DASHBOARD_PORT="${WAZUH_DASHBOARD_PORT:-8443}"
TEMPLATE="${ROOT_DIR}/dashboard/neolabs-saved-objects.ndjson.template"
STATE_FILE="${ROOT_DIR}/state/dashboard-objects.ready"

resolve_pod() {
  if [[ -s state/assigned-pod ]]; then
    tr -d '\r\n' < state/assigned-pod
    return
  fi
  local manifest="${REPO_ROOT}/runtime/access-manifest.json"
  if [[ -f "${manifest}" ]]; then
    python3 - "${manifest}" <<'PY'
import json, re, sys
try:
    data=json.load(open(sys.argv[1], encoding='utf-8'))
    pod=str(data.get('pod_id',''))
except Exception:
    pod=''
if re.fullmatch(r'pod-[0-9]{2}', pod):
    print(pod)
PY
  fi
}

pod="$(resolve_pod | tail -n1 | tr -d '\r\n')"
[[ "${pod}" =~ ^pod-[0-9]{2}$ ]] || {
  printf '[WARN] Dashboard objects were not provisioned because no server-issued pod is available yet.\n' >&2
  exit 1
}
[[ -f "${TEMPLATE}" ]] || { printf 'ERROR: Missing dashboard object template.\n' >&2; exit 2; }

mkdir -p state
rendered="$(mktemp)"
response="$(mktemp)"
trap 'rm -f "${rendered}" "${response}"' EXIT
sed "s/__POD_ID__/${pod}/g" "${TEMPLATE}" > "${rendered}"

# Validate every NDJSON object before it is handed to the dashboard API.
python3 - "${rendered}" <<'PY'
import json, sys
required = {
    'neolabs-vcc-alerts': 'index-pattern',
    'neolabs-night-watch-search': 'search',
    'neolabs-telemetry-health-search': 'search',
    'neolabs-night-watch': 'dashboard',
    'neolabs-telemetry-health': 'dashboard',
}
seen = {}
for number, raw in enumerate(open(sys.argv[1], encoding='utf-8'), 1):
    if not raw.strip():
        continue
    item = json.loads(raw)
    if not isinstance(item.get('attributes'), dict) or not isinstance(item.get('references'), list):
        raise SystemExit(f'invalid saved object at line {number}')
    seen[item.get('id')] = item.get('type')
if seen != required:
    raise SystemExit(f'unexpected saved object set: {seen!r}')
PY

url="https://127.0.0.1:${DASHBOARD_PORT}/api/saved_objects/_import?overwrite=true"
http_code="$(curl -skS -u "admin:${WAZUH_INDEXER_PASSWORD}" \
  -H 'osd-xsrf: true' \
  -H 'securitytenant: global_tenant' \
  -F "file=@${rendered};type=application/ndjson" \
  -o "${response}" -w '%{http_code}' "${url}" || true)"

if [[ "${http_code}" != 200 ]]; then
  printf '[WARN] Wazuh dashboard saved-object import returned HTTP %s. Core telemetry remains available.\n' "${http_code}" >&2
  rm -f "${STATE_FILE}"
  exit 1
fi

python3 - "${response}" <<'PY'
import json, sys
try:
    value=json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as exc:
    raise SystemExit(f'invalid import response: {exc}')
if value.get('success') is not True or int(value.get('successCount', 0)) < 5:
    raise SystemExit(f'saved-object import incomplete: {value!r}')
PY

printf '%s\n' "${pod}" > "${STATE_FILE}"
chmod 600 "${STATE_FILE}" || true
printf '[OK] NeoLabs Night Watch and Telemetry Health saved objects are ready for %s.\n' "${pod}"
printf '[OK] Night Watch dashboard: https://127.0.0.1:%s/app/dashboards#/view/neolabs-night-watch\n' "${DASHBOARD_PORT}"
printf '[OK] Telemetry Health dashboard: https://127.0.0.1:%s/app/dashboards#/view/neolabs-telemetry-health\n' "${DASHBOARD_PORT}"
