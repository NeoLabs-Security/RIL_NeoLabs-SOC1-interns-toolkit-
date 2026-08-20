#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

WAIT_SECONDS=0
REQUESTED_SCENARIO=''
REQUESTED_EVENT_ID=''
while (( $# > 0 )); do
  case "$1" in
    --wait)
      [[ $# -ge 2 ]] || { printf 'ERROR: --wait requires seconds.\n' >&2; exit 2; }
      WAIT_SECONDS="$2"; shift 2 ;;
    --scenario-id)
      [[ $# -ge 2 ]] || { printf 'ERROR: --scenario-id requires a value.\n' >&2; exit 2; }
      REQUESTED_SCENARIO="$2"; shift 2 ;;
    --event-id)
      [[ $# -ge 2 ]] || { printf 'ERROR: --event-id requires a value.\n' >&2; exit 2; }
      REQUESTED_EVENT_ID="$2"; shift 2 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "${WAIT_SECONDS}" =~ ^[0-9]+$ ]] || { printf 'ERROR: wait value must be numeric.\n' >&2; exit 2; }
[[ -f .env ]] || { printf 'ERROR: wazuh-stack/.env is missing.\n' >&2; exit 2; }
# shellcheck disable=SC1091
set -a
source .env
set +a

: "${WAZUH_INDEXER_PASSWORD:?WAZUH_INDEXER_PASSWORD is required}"

manifest_value() {
  local field="$1" manifest="${REPO_ROOT}/runtime/access-manifest.json"
  [[ -f "${manifest}" ]] || return 0
  python3 - "${manifest}" "$field" <<'PY'
import json,sys
try:
    data=json.load(open(sys.argv[1], encoding='utf-8'))
    value=data.get(sys.argv[2])
except Exception:
    value=''
if isinstance(value,str): print(value)
PY
}

resolve_pod() {
  if [[ -s state/assigned-pod ]]; then
    tr -d '\r\n' < state/assigned-pod
    return
  fi
  manifest_value pod_id
}

resolve_scenario() {
  if [[ -n "${REQUESTED_SCENARIO}" ]]; then
    printf '%s\n' "${REQUESTED_SCENARIO}"
    return
  fi
  manifest_value scenario_id
}

service_is_healthy() {
  local service="$1" id status health
  id="$(docker compose --env-file .env ps -q "${service}" 2>/dev/null || true)"
  [[ -n "${id}" ]] || return 1
  status="$(docker inspect --format '{{.State.Status}}' "${id}" 2>/dev/null || true)"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}" 2>/dev/null || true)"
  [[ "${status}" == running && ( "${health}" == healthy || "${health}" == none ) ]]
}

raw_event_present() {
  local pod="$1" scenario="$2" event_id="$3"
  docker compose --env-file .env exec -T vcc.telemetry.collector \
    python - "$pod" "$scenario" "$event_id" <<'PY' >/dev/null 2>&1
import json, pathlib, sys
pod,scenario,event_id=sys.argv[1:4]
path=pathlib.Path('/data/vcc-events.ndjson')
if not path.is_file(): raise SystemExit(1)
for raw in path.read_text(encoding='utf-8', errors='replace').splitlines()[-50000:]:
    try: event=json.loads(raw)
    except Exception: continue
    if event.get('synthetic') is not True or event.get('pod_id') != pod: continue
    if scenario and event.get('scenario_id') not in (scenario, None, ''): continue
    if event_id and event.get('event_id') != event_id: continue
    raise SystemExit(0)
raise SystemExit(1)
PY
}

rules_are_loaded() {
  local pod="$1" output
  output="$(printf '%s\n' "{\"schema_version\":\"1.0\",\"event_id\":\"pipeline-probe\",\"event_time\":\"2026-01-01T00:00:00Z\",\"pod_id\":\"${pod}\",\"event_type\":\"authentication\",\"synthetic\":true,\"outcome\":\"success\",\"user\":\"pipeline-probe\",\"source_ip\":\"127.0.0.1\"}" \
    | docker compose --env-file .env exec -T wazuh.manager /var/ossec/bin/wazuh-logtest 2>&1 || true)"
  grep -Eq "id: '100120'|Rule id: 100120|100120" <<<"${output}"
}

indexed_hits() {
  local pod="$1" scenario="$2" event_id="$3" query response
  query="$(python3 - "$pod" "$scenario" "$event_id" <<'PY'
import json,sys
pod,scenario,event_id=sys.argv[1:4]
filters=[
    {'match_phrase': {'data.pod_id': pod}},
    {'terms': {'rule.id': ['100100','100110','100111','100112','100120','100121','100130','100140','100150']}},
]
if scenario:
    filters.append({'match_phrase': {'data.scenario_id': scenario}})
if event_id:
    filters.append({'match_phrase': {'data.event_id': event_id}})
print(json.dumps({'size':0,'track_total_hits':True,'query':{'bool':{'filter':filters}}}, separators=(',',':')))
PY
)"
  response="$(printf '%s' "${query}" | docker compose --env-file .env exec -T \
    -e NEOLABS_INDEXER_PASSWORD="${WAZUH_INDEXER_PASSWORD}" wazuh.indexer sh -c \
    'curl -fsSk -u "admin:${NEOLABS_INDEXER_PASSWORD}" -H "Content-Type: application/json" --data-binary @- "https://localhost:9200/wazuh-alerts-*/_search?ignore_unavailable=true"' 2>/dev/null || true)"
  [[ -n "${response}" ]] || { printf '0'; return; }
  printf '%s' "${response}" | python3 -c 'import json,sys; d=json.load(sys.stdin); t=d.get("hits",{}).get("total",0); print(t.get("value",0) if isinstance(t,dict) else t)'
}

# Return codes:
#   0 = fully searchable for the current pod/scenario (and event when requested)
#   1 = telemetry delivery/indexing is not ready
#   2 = deterministic rule-engine/configuration failure
check_once() {
  local pod scenario hits scope
  pod="$(resolve_pod | tail -n1 | tr -d '\r\n')"
  scenario="$(resolve_scenario | tail -n1 | tr -d '\r\n')"
  [[ "${pod}" =~ ^pod-[0-9]{2}$ ]] || { printf '[WAIT] No server-issued pod manifest is available yet.\n' >&2; return 1; }
  if [[ -n "${scenario}" && ! "${scenario}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf '[FAIL] Current scenario identifier has an unexpected format.\n' >&2
    return 2
  fi

  for service in wazuh.manager wazuh.indexer wazuh.dashboard vcc.telemetry.collector; do
    service_is_healthy "${service}" || { printf '[WAIT] %s is not healthy yet.\n' "${service}" >&2; return 1; }
  done

  rules_are_loaded "${pod}" || { printf '[FAIL] NeoLabs VCC custom rules are not active in wazuh-analysisd.\n' >&2; return 2; }

  scope="pod=${pod} scenario=${scenario:-any}"
  [[ -z "${REQUESTED_EVENT_ID}" ]] || scope+=" event_id=${REQUESTED_EVENT_ID}"
  if ! raw_event_present "${pod}" "${scenario}" "${REQUESTED_EVENT_ID}"; then
    printf '[WAIT] Current VCC telemetry has not reached the local shared telemetry volume yet (%s).\n' "${scope}" >&2
    return 1
  fi

  hits="$(indexed_hits "${pod}" "${scenario}" "${REQUESTED_EVENT_ID}" 2>/dev/null || printf '0')"
  [[ "${hits}" =~ ^[0-9]+$ ]] || hits=0
  if (( hits < 1 )); then
    printf '[WAIT] Current VCC events exist locally but are not searchable in wazuh-alerts-* yet (%s).\n' "${scope}" >&2
    return 1
  fi

  printf '[OK] VCC_TELEMETRY_SEARCHABLE %s alerts=%s\n' "${scope}" "${hits}"
  printf '[OK] Current-scenario delivery, Manager JSON input, NeoLabs rules and Filebeat/indexer search path are working.\n'
  return 0
}

started="$(date +%s)"
while true; do
  rc=0
  check_once || rc=$?
  if (( rc == 0 )); then exit 0; fi
  if (( rc == 2 )); then exit 2; fi
  now="$(date +%s)"
  if (( WAIT_SECONDS == 0 || now - started >= WAIT_SECONDS )); then
    printf 'ERROR: Current assigned-pod/scenario telemetry did not become searchable within %ss.\n' "${WAIT_SECONDS}" >&2
    exit 1
  fi
  sleep 10
done