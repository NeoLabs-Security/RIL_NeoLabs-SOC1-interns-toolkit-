#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

WAIT_SECONDS=0
if [[ "${1:-}" == "--wait" ]]; then
  WAIT_SECONDS="${2:-180}"
fi
[[ "${WAIT_SECONDS}" =~ ^[0-9]+$ ]] || { printf 'ERROR: wait value must be numeric.\n' >&2; exit 2; }
[[ -f .env ]] || { printf 'ERROR: wazuh-stack/.env is missing.\n' >&2; exit 2; }
# shellcheck disable=SC1091
set -a
source .env
set +a

: "${WAZUH_INDEXER_PASSWORD:?WAZUH_INDEXER_PASSWORD is required}"

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

service_is_healthy() {
  local service="$1" id status health
  id="$(docker compose --env-file .env ps -q "${service}" 2>/dev/null || true)"
  [[ -n "${id}" ]] || return 1
  status="$(docker inspect --format '{{.State.Status}}' "${id}" 2>/dev/null || true)"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}" 2>/dev/null || true)"
  [[ "${status}" == running && ( "${health}" == healthy || "${health}" == none ) ]]
}

raw_event_present() {
  local pod="$1"
  docker compose --env-file .env exec -T vcc.telemetry.collector \
    python - "$pod" <<'PY' >/dev/null 2>&1
import json, pathlib, sys
pod=sys.argv[1]
path=pathlib.Path('/data/vcc-events.ndjson')
if not path.is_file():
    raise SystemExit(1)
for raw in path.read_text(encoding='utf-8', errors='replace').splitlines()[-50000:]:
    try:
        event=json.loads(raw)
    except Exception:
        continue
    if event.get('synthetic') is True and event.get('pod_id') == pod:
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
  local pod="$1" query response
  query="{\"size\":0,\"track_total_hits\":true,\"query\":{\"bool\":{\"filter\":[{\"match_phrase\":{\"data.pod_id\":\"${pod}\"}},{\"terms\":{\"rule.id\":[\"100100\",\"100110\",\"100111\",\"100112\",\"100120\",\"100121\",\"100130\",\"100140\",\"100150\"]}}]}}}"
  response="$(printf '%s' "${query}" | docker compose --env-file .env exec -T \
    -e NEOLABS_INDEXER_PASSWORD="${WAZUH_INDEXER_PASSWORD}" wazuh.indexer sh -c \
    'curl -fsSk -u "admin:${NEOLABS_INDEXER_PASSWORD}" -H "Content-Type: application/json" --data-binary @- "https://localhost:9200/wazuh-alerts-*/_search"' 2>/dev/null || true)"
  [[ -n "${response}" ]] || { printf '0'; return; }
  printf '%s' "${response}" | python3 -c 'import json,sys; d=json.load(sys.stdin); t=d.get("hits",{}).get("total",0); print(t.get("value",0) if isinstance(t,dict) else t)'
}

check_once() {
  local pod hits
  pod="$(resolve_pod | tail -n1 | tr -d '\r\n')"
  [[ "${pod}" =~ ^pod-[0-9]{2}$ ]] || { printf '[WAIT] No server-issued pod manifest is available yet.\n' >&2; return 1; }

  for service in wazuh.manager wazuh.indexer wazuh.dashboard vcc.telemetry.collector; do
    service_is_healthy "${service}" || { printf '[WAIT] %s is not healthy yet.\n' "${service}" >&2; return 1; }
  done

  raw_event_present "${pod}" || { printf '[WAIT] No validated VCC event for %s is present in the shared telemetry volume yet.\n' "${pod}" >&2; return 1; }
  rules_are_loaded "${pod}" || { printf '[FAIL] NeoLabs VCC custom rules are not active in wazuh-analysisd.\n' >&2; return 2; }

  hits="$(indexed_hits "${pod}" 2>/dev/null || printf '0')"
  [[ "${hits}" =~ ^[0-9]+$ ]] || hits=0
  if (( hits < 1 )); then
    printf '[WAIT] VCC events exist locally but are not searchable in wazuh-alerts-* yet.\n' >&2
    return 1
  fi

  printf '[OK] VCC_TELEMETRY_SEARCHABLE pod=%s alerts=%s\n' "${pod}" "${hits}"
  printf '[OK] Manager JSON input, NeoLabs rules, Filebeat/indexer path and dashboard backing index are working.\n'
  return 0
}

started="$(date +%s)"
while true; do
  rc=0
  check_once || rc=$?
  if (( rc == 0 )); then
    exit 0
  fi
  if (( rc == 2 )); then
    exit 2
  fi
  now="$(date +%s)"
  if (( WAIT_SECONDS == 0 || now - started >= WAIT_SECONDS )); then
    printf 'ERROR: Assigned-pod VCC telemetry did not become searchable within %ss.\n' "${WAIT_SECONDS}" >&2
    exit 1
  fi
  sleep 10
done
