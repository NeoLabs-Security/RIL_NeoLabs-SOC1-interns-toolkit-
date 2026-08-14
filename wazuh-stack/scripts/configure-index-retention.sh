#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

[[ -f .env ]] || { printf 'ERROR: wazuh-stack/.env is missing.\n' >&2; exit 2; }
# shellcheck disable=SC1091
set -a
source .env
set +a

: "${WAZUH_INDEXER_PASSWORD:?WAZUH_INDEXER_PASSWORD is required}"
RETENTION_DAYS="${NEOLABS_ALERT_RETENTION_DAYS:-30}"
[[ "${RETENTION_DAYS}" =~ ^[0-9]+$ ]] || { printf 'ERROR: NEOLABS_ALERT_RETENTION_DAYS must be numeric.\n' >&2; exit 2; }
if (( RETENTION_DAYS < 14 || RETENTION_DAYS > 90 )); then
  printf 'ERROR: NEOLABS_ALERT_RETENTION_DAYS must be between 14 and 90 days.\n' >&2
  exit 2
fi

POLICY_ID="neolabs-wazuh-alert-retention"
INDEXER="https://localhost:9200"

request() {
  local method="$1" path="$2" body="${3:-}"
  if [[ -n "${body}" ]]; then
    printf '%s' "${body}" | docker compose --env-file .env exec -T \
      -e NEOLABS_INDEXER_PASSWORD="${WAZUH_INDEXER_PASSWORD}" wazuh.indexer sh -c \
      "curl -fsSk -u \"admin:\${NEOLABS_INDEXER_PASSWORD}\" -X ${method} -H 'Content-Type: application/json' --data-binary @- '${INDEXER}${path}'"
  else
    docker compose --env-file .env exec -T \
      -e NEOLABS_INDEXER_PASSWORD="${WAZUH_INDEXER_PASSWORD}" wazuh.indexer sh -c \
      "curl -fsSk -u \"admin:\${NEOLABS_INDEXER_PASSWORD}\" -X ${method} '${INDEXER}${path}'"
  fi
}

policy_json="$(python3 - "${RETENTION_DAYS}" <<'PY'
import json, sys
age=f"{int(sys.argv[1])}d"
print(json.dumps({
  "policy": {
    "description": "NeoLabs SOC workstation retention for local Wazuh alert indices. Server-side VCC archives are unaffected.",
    "default_state": "retained",
    "states": [
      {
        "name": "retained",
        "actions": [],
        "transitions": [{"state_name": "delete", "conditions": {"min_index_age": age}}]
      },
      {
        "name": "delete",
        "actions": [{"retry": {"count": 3, "backoff": "exponential", "delay": "1m"}, "delete": {}}],
        "transitions": []
      }
    ],
    "ism_template": [{"index_patterns": ["wazuh-alerts-*"], "priority": 100}]
  }
}, separators=(",", ":")))
PY
)"

existing="$(request GET "/_plugins/_ism/policies/${POLICY_ID}" 2>/dev/null || true)"
if [[ -n "${existing}" ]]; then
  read -r seq primary < <(printf '%s' "${existing}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("_seq_no",""), d.get("_primary_term",""))')
  if [[ "${seq}" =~ ^[0-9]+$ && "${primary}" =~ ^[0-9]+$ ]]; then
    request PUT "/_plugins/_ism/policies/${POLICY_ID}?if_seq_no=${seq}&if_primary_term=${primary}" "${policy_json}" >/dev/null
  else
    printf '[WARN] Existing ISM policy metadata could not be parsed; leaving it unchanged.\n' >&2
    exit 1
  fi
else
  request PUT "/_plugins/_ism/policies/${POLICY_ID}" "${policy_json}" >/dev/null
fi

# Apply only to Wazuh alert indices. Never use a broad '*' wildcard here.
# Existing indices with another policy are intentionally left untouched by the ISM add API.
add_response="$(request POST '/_plugins/_ism/add/wazuh-alerts-*' "{\"policy_id\":\"${POLICY_ID}\"}" 2>/dev/null || true)"
if [[ -n "${add_response}" ]]; then
  failures="$(printf '%s' "${add_response}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(str(bool(d.get("failures"))).lower())' 2>/dev/null || printf true)"
  if [[ "${failures}" == true ]]; then
    printf '[WARN] Some existing alert indices already have another retention policy; they were not overridden.\n' >&2
  fi
fi

printf '[OK] Local wazuh-alerts-* retention is configured for %s days.\n' "${RETENTION_DAYS}"
printf '[OK] This policy affects only the intern workstation indexer; VCC server archives and evidence are not deleted.\n'
