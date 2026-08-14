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
STALE_MINUTES="${NEOLABS_TELEMETRY_STALE_MINUTES:-90}"
[[ "${STALE_MINUTES}" =~ ^[0-9]+$ ]] || { printf 'ERROR: NEOLABS_TELEMETRY_STALE_MINUTES must be numeric.\n' >&2; exit 2; }

resolve_pod() {
  if [[ -s state/assigned-pod ]]; then
    tr -d '\r\n' < state/assigned-pod
    return
  fi
  local manifest="${REPO_ROOT}/runtime/access-manifest.json"
  if [[ -f "${manifest}" ]]; then
    python3 - "${manifest}" <<'PY'
import json,re,sys
try: pod=str(json.load(open(sys.argv[1],encoding='utf-8')).get('pod_id',''))
except Exception: pod=''
if re.fullmatch(r'pod-[0-9]{2}', pod): print(pod)
PY
  fi
}

pod="$(resolve_pod | tail -n1 | tr -d '\r\n')"
[[ "${pod}" =~ ^pod-[0-9]{2}$ ]] || { printf '[WARN] Last-event freshness unavailable: no server-issued pod.\n'; exit 1; }

query="{\"size\":1,\"sort\":[{\"timestamp\":{\"order\":\"desc\"}}],\"_source\":[\"timestamp\",\"data.event_time\",\"data.event_id\",\"data.event_type\",\"data.pod_id\"],\"query\":{\"bool\":{\"filter\":[{\"match_phrase\":{\"data.pod_id\":\"${pod}\"}},{\"terms\":{\"rule.id\":[\"100100\",\"100110\",\"100111\",\"100112\",\"100120\",\"100121\",\"100130\",\"100140\",\"100150\"]}}]}}}"
response="$(printf '%s' "${query}" | docker compose --env-file .env exec -T \
  -e NEOLABS_INDEXER_PASSWORD="${WAZUH_INDEXER_PASSWORD}" wazuh.indexer sh -c \
  'curl -fsSk -u "admin:${NEOLABS_INDEXER_PASSWORD}" -H "Content-Type: application/json" --data-binary @- "https://localhost:9200/wazuh-alerts-*/_search"' 2>/dev/null || true)"

if [[ -z "${response}" ]]; then
  printf '[WARN] Last-event freshness unavailable: indexer query failed.\n'
  exit 1
fi

printf '%s' "${response}" | python3 - "${pod}" "${STALE_MINUTES}" <<'PY'
import datetime as dt, json, sys
pod=sys.argv[1]
stale_minutes=int(sys.argv[2])
try:
    data=json.load(sys.stdin)
    hits=data.get('hits',{}).get('hits',[])
except Exception:
    hits=[]
if not hits:
    print(f'[WARN] Last VCC event: none indexed yet for {pod}.')
    raise SystemExit(1)
src=hits[0].get('_source',{})
indexed=src.get('timestamp')
event=(src.get('data') or {}).get('event_time')
event_type=(src.get('data') or {}).get('event_type')

def parse(value):
    if not isinstance(value,str) or not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace('Z','+00:00')).astimezone(dt.timezone.utc)
    except ValueError:
        return None

def human(seconds):
    seconds=max(0,int(seconds))
    if seconds < 60: return f'{seconds}s ago'
    minutes, sec=divmod(seconds,60)
    if minutes < 60: return f'{minutes}m {sec}s ago'
    hours, minutes=divmod(minutes,60)
    if hours < 48: return f'{hours}h {minutes}m ago'
    days, hours=divmod(hours,24)
    return f'{days}d {hours}h ago'

when=parse(indexed)
if when is None:
    print(f'[WARN] Last VCC event for {pod} has an unreadable Wazuh index timestamp.')
    raise SystemExit(1)
age=(dt.datetime.now(dt.timezone.utc)-when).total_seconds()
label=human(age)
print(f'Last VCC event indexed: {label} | pod={pod} | type={event_type or "unknown"} | source event_time={event or "unknown"}')
if age > stale_minutes*60:
    print(f'[WARN] Telemetry is older than the NeoLabs freshness threshold ({stale_minutes} minutes). Run CHECK-NEOLABS-SOC.cmd.')
    raise SystemExit(3)
print('[OK] VCC telemetry freshness is within the configured threshold.')
PY
