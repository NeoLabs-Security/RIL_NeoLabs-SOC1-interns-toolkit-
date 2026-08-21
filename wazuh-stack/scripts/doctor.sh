#!/usr/bin/env bash
set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

pod="${NEOLABS_DOCTOR_POD:-}"
lab_state="${NEOLABS_DOCTOR_LAB_STATE:-unknown}"
replay_packs="${NEOLABS_DOCTOR_REPLAY_PACKS:-unknown}"
scenario="${NEOLABS_DOCTOR_SCENARIO:-}"
failures=0

pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
fail_stage() { printf '[FAIL] %s\n' "$1"; failures=$((failures + 1)); }

if [[ ! "${pod}" =~ ^pod-[0-9]{2}$ || -z "${scenario}" ]]; then
  fail_stage '2/7 VCC telemetry surface — server-issued pod was not supplied to doctor.'
  exit 2
fi
if [[ ! -f .env ]]; then
  fail_stage '2/7 VCC telemetry surface — wazuh-stack/.env is missing.'
  exit 2
fi
# shellcheck disable=SC1091
set -a
source .env
set +a

service_healthy() {
  local service="$1" id state health
  id="$(docker compose --env-file .env ps -q "${service}" 2>/dev/null || true)"
  [[ -n "${id}" ]] || return 1
  state="$(docker inspect --format '{{.State.Status}}' "${id}" 2>/dev/null || true)"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}" 2>/dev/null || true)"
  [[ "${state}" == running && ( "${health}" == healthy || "${health}" == none ) ]]
}

# 2/7 — VCC learning surface / collector availability.
if [[ "${lab_state}" == REPLAY || "${lab_state}" == CLOUD_LIVE || "${lab_state}" == ENDPOINT_LIVE ]]; then
  if [[ "${replay_packs}" =~ ^[0-9]+$ ]]; then
    pass "2/7 VCC telemetry surface — ${lab_state}; gateway reports ${replay_packs} authorised replay pack(s) for ${pod}."
  else
    pass "2/7 VCC telemetry surface — ${lab_state}; server authorisation is active for ${pod}."
  fi
elif [[ "${lab_state}" == LIVE ]]; then
  if service_healthy vcc.telemetry.collector; then
    pass "2/7 VCC telemetry surface — LIVE collector is healthy for the server-issued ${pod} scope."
  else
    fail_stage '2/7 VCC telemetry surface — LIVE collector is not healthy.'
  fi
else
  warn "2/7 VCC telemetry surface — unexpected lab state '${lab_state}'."
fi

# 3/7 — Raw event exists in the shared telemetry volume for this pod.
raw_result="$(docker compose --env-file .env exec -T vcc.telemetry.collector python - "${pod}" "${scenario}" <<'PY' 2>/dev/null || true
import json, pathlib, sys
pod,scenario=sys.argv[1:3]
path=pathlib.Path('/data/vcc-events.ndjson')
count=0
latest=''
if path.is_file():
    for raw in path.read_text(encoding='utf-8', errors='replace').splitlines()[-50000:]:
        try: e=json.loads(raw)
        except Exception: continue
        if e.get('synthetic') is True and e.get('pod_id') == pod and e.get('scenario_id') == scenario:
            count += 1
            ts=str(e.get('event_time') or '')
            if ts > latest: latest=ts
print(f'{count}|{latest}')
PY
)"
raw_count="${raw_result%%|*}"
raw_latest="${raw_result#*|}"
if [[ "${raw_count}" =~ ^[0-9]+$ ]] && (( raw_count > 0 )); then
  pass "3/7 Current telemetry delivery — ${raw_count} event(s) for pod=${pod} scenario=${scenario}; newest source event_time=${raw_latest:-unknown}."
else
  if service_healthy vcc.telemetry.collector; then
    warn "3/7 Raw VCC event file — local collector is healthy, but no validated event for ${pod} has arrived yet."
  else
    fail_stage "3/7 Raw VCC event file — no validated event for ${pod} is present and the collector is not healthy."
  fi
fi

# 4/7 — Rule engine actually loads and matches the NeoLabs rules.
rule_output="$(printf '%s\n' "{\"schema_version\":\"1.0\",\"event_id\":\"doctor-probe\",\"event_time\":\"2026-01-01T00:00:00Z\",\"pod_id\":\"${pod}\",\"event_type\":\"authentication\",\"synthetic\":true,\"outcome\":\"success\",\"user\":\"doctor-probe\",\"source_ip\":\"127.0.0.1\"}" | docker compose --env-file .env exec -T wazuh.manager /var/ossec/bin/wazuh-logtest 2>&1 || true)"
if grep -Eq "100120|Rule id: 100120|id: '100120'" <<<"${rule_output}"; then
  pass '4/7 Wazuh rule engine — NeoLabs authentication rule 100120 matched the synthetic probe.'
else
  fail_stage '4/7 Wazuh rule engine — NeoLabs rules are not loaded/matching in wazuh-analysisd.'
fi

# 5/7 — Filebeat can reach the local indexer over the configured TLS path.
filebeat_output="$(docker compose --env-file .env exec -T wazuh.manager filebeat test output 2>&1 || true)"
if grep -Eqi 'talk to server.*OK|connection.*OK|version:' <<<"${filebeat_output}"; then
  pass '5/7 Filebeat — output test reached the local Wazuh indexer.'
else
  fail_stage '5/7 Filebeat — output test could not verify the manager-to-indexer path.'
fi

# 6/7 — Indexer health plus assigned-pod searchable alert count.
if service_healthy wazuh.indexer; then
  cluster="$(docker compose --env-file .env exec -T -e NEOLABS_INDEXER_PASSWORD="${WAZUH_INDEXER_PASSWORD}" wazuh.indexer sh -c 'curl -fsSk -u "admin:${NEOLABS_INDEXER_PASSWORD}" https://localhost:9200/_cluster/health' 2>/dev/null || true)"
  cluster_status="$(printf '%s' "${cluster}" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("status","unknown"))
except Exception: print("unknown")')"
  query="{\"size\":0,\"track_total_hits\":true,\"query\":{\"bool\":{\"filter\":[{\"match_phrase\":{\"data.pod_id\":\"${pod}\"}},{\"match_phrase\":{\"data.scenario_id\":\"${scenario}\"}},{\"terms\":{\"rule.id\":[\"100100\",\"100110\",\"100111\",\"100112\",\"100120\",\"100121\",\"100130\",\"100140\",\"100150\"]}}]}}}"
  indexed="$(printf '%s' "${query}" | docker compose --env-file .env exec -T -e NEOLABS_INDEXER_PASSWORD="${WAZUH_INDEXER_PASSWORD}" wazuh.indexer sh -c 'curl -fsSk -u "admin:${NEOLABS_INDEXER_PASSWORD}" -H "Content-Type: application/json" --data-binary @- "https://localhost:9200/wazuh-alerts-*/_search"' 2>/dev/null || true)"
  hits="$(printf '%s' "${indexed:-{}}" | python3 -c 'import json,sys
try:
 d=json.load(sys.stdin); t=d.get("hits",{}).get("total",0); print(t.get("value",0) if isinstance(t,dict) else t)
except Exception: print(0)')"
  if [[ "${cluster_status}" =~ ^(green|yellow)$ && "${hits}" =~ ^[0-9]+$ ]] && (( hits > 0 )); then
    pass "6/7 Wazuh indexer — cluster=${cluster_status}; ${hits} NeoLabs alert(s) searchable for pod=${pod} scenario=${scenario}."
  elif [[ "${cluster_status}" =~ ^(green|yellow)$ && "${raw_count:-0}" =~ ^[0-9]+$ ]] && (( ${raw_count:-0} == 0 )); then
    pass "6/7 Wazuh indexer — cluster=${cluster_status}; indexer is healthy while assigned-pod telemetry is still pending."
  else
    fail_stage "6/7 Wazuh indexer — cluster=${cluster_status}; assigned-pod searchable alerts=${hits}."
  fi
else
  fail_stage '6/7 Wazuh indexer — container is not healthy.'
fi

# 7/7 — Prove both the authenticated dashboard security endpoint and the
# dashboard -> wazuh.manager API connection shown under Dashboard > Server APIs.
dash_code="$(curl -sk -u "admin:${WAZUH_INDEXER_PASSWORD}" -o /dev/null -w '%{http_code}' "https://127.0.0.1:${WAZUH_DASHBOARD_PORT:-8443}/api/status" 2>/dev/null || printf 000)"
api_ok=0
if bash ./scripts/verify-dashboard-api.sh 15 >/dev/null 2>&1; then api_ok=1; fi
if [[ "${dash_code}" == 200 && $api_ok -eq 1 ]]; then
  if [[ -f state/dashboard-objects.ready ]] && [[ "$(tr -d '\r\n' < state/dashboard-objects.ready)" == "${pod}" ]]; then
    pass '7/7 Wazuh dashboard — authenticated API status is reachable, manager API connector is online, and NeoLabs saved objects are provisioned.'
  else
    pass '7/7 Wazuh dashboard — authenticated API status is reachable and the manager API connector is online.'
    warn 'Saved NeoLabs dashboard objects are not confirmed; rerun the root launcher to retry provisioning.'
  fi
else
  fail_stage "7/7 Wazuh dashboard — authenticated /api/status HTTP=${dash_code}; manager API connector=$([[ $api_ok -eq 1 ]] && printf online || printf offline)."
fi

printf '\n'
./scripts/telemetry-freshness.sh || true
./scripts/disk-warning.sh || true

retention="$(docker compose --env-file .env exec -T -e NEOLABS_INDEXER_PASSWORD="${WAZUH_INDEXER_PASSWORD}" wazuh.indexer sh -c 'curl -fsSk -u "admin:${NEOLABS_INDEXER_PASSWORD}" https://localhost:9200/_plugins/_ism/policies/neolabs-wazuh-alert-retention' 2>/dev/null || true)"
if [[ -n "${retention}" ]]; then
  retention_days="$(printf '%s' "${retention}" | python3 -c 'import json,sys,re
try:
 d=json.load(sys.stdin); p=d.get("policy",{}); s=str(p); m=re.search(r"min_index_age.?[: ]+.?([0-9]+)d", s); print(m.group(1) if m else "configured")
except Exception: print("configured")')"
  pass "Retention — local Wazuh alert ISM policy is present (${retention_days} day setting when detected)."
else
  warn 'Retention — NeoLabs local alert retention policy was not found.'
fi

printf '\n'
if (( failures == 0 )); then
  printf 'NEOLABS_DOCTOR_OK — the local Wazuh/API path is healthy; VCC event arrival may still be pending when noted above.\n'
  exit 0
fi
printf 'NEOLABS_DOCTOR_FAILED — %s core stage(s) need attention.\n' "${failures}" >&2
exit 1
