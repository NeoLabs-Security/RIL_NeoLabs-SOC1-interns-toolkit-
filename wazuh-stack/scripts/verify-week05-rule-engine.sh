#!/usr/bin/env bash
# Mentor-only W05 detection acceptance on an existing Wazuh manager/indexer.
# Does NOT mutate any rules, credentials, data, collector cursors or old alerts.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ -f .env ]] || { echo "Missing wazuh-stack/.env" >&2; exit 2; }
mode="logtest"
pod=""
event_id=""
rule_id=""
while (( $# )); do
  case "$1" in
    --logtest) mode="logtest"; shift;;
    --index) mode="index"; shift;;
    --pod) [[ $# -ge 2 ]] || exit 2; pod="$2"; shift 2;;
    --event-id) [[ $# -ge 2 ]] || exit 2; event_id="$2"; shift 2;;
    --rule-id) [[ $# -ge 2 ]] || exit 2; rule_id="$2"; shift 2;;
    *) echo "Unknown option: $1" >&2; exit 2;;
  esac
done
compose=(docker compose --env-file .env)
if [[ "$mode" == logtest ]]; then
  for rule in 100190 100191 100192 100193; do
    payload="$(python3 - "$rule" <<'PY'
import json,sys
rule=sys.argv[1]
event_type = {
    '100190':'file.upload_accepted',
    '100191':'file.upload_accepted',
    '100192':'file.upload_rejected',
    '100193':'file.upload_quarantined'
}[rule]
reason = {
    '100190':'accepted',
    '100191':'extension_only_validation',
    '100192':'unsupported_extension',
    '100193':'support_quarantine',
}[rule]
event={
 'schema_version':'1.0',
 'event_id':'f6e4d922-dca1-4cf1-b8a8-d2b76af38360',
 'event_time':'2026-11-09T10:00:00Z',
 'timestamp':'2026-11-09T10:00:00Z',
 'pod_id':'pod-01',
 'scenario_id':'w05-poisoned-upload',
 'scenario_release':'vulnerable',
 'synthetic':True,'environment':'vcc-security-lab',
 'event_type':event_type,
 'event_category':'file_upload',
 'event_action':event_type.split('.')[-1],
 'request_id':'w05-rule-engine-preview',
 'source_ip':'127.0.0.1',
 'outcome':'success' if event_type=='file.upload_accepted' else 'rejected',
 'metadata':{'reason_code':reason,'upload_id': '00000000000000000000000000000001'}
}
print(json.dumps(event,separators=(',',':')))
PY
)"
    output="$(printf '%s\n' "$payload" | "${compose[@]}" exec -T wazuh.manager /var/ossec/bin/wazuh-logtest 2>&1 || true)"
    if grep -Eq "id: '$rule'([^0-9]|$)|Rule id: $rule([^0-9]|$)" <<< "$output"; then
      echo "PASS Wazuh rule $rule: correct synthetic W05 sample recognized"
    else
      echo "FAIL Wazuh rule $rule: matching rule not observed" >&2
      echo "Confirm the W05 XML rules are mounted and manager configuration has been reloaded." >&2
      exit 1
    fi
  done
  echo "PASS: four W05 rule-engine tests. This does NOT prove central event indexing."
  exit 0
fi
[[ "$pod" =~ ^pod-0[1-5]$ && "$event_id" =~ ^[A-Za-z0-9_-]{8,200}$ && "$rule_id" =~ ^10019[0-3]$ ]] ||
  { echo "--index requires --pod pod-01..05 --event-id <exact-id> --rule-id 100190..100193" >&2; exit 2; }
# The password stays in process environment; never echo values or real payloads.
set -a
# shellcheck disable=SC1091
source .env
set +a
: "${WAZUH_INDEXER_PASSWORD:?Missing indexer password in existing secure .env}"
query="$(python3 - "$pod" "$event_id" "$rule_id" <<'PY'
import json,sys
pod,event,rule=sys.argv[1:]
print(json.dumps({'size':0,'track_total_hits':True,'query':{'bool':{'filter':[
 {'match_phrase':{'rule.id':rule}},
 {'match_phrase':{'data.pod_id':pod}},
 {'match_phrase':{'data.event_id':event}},
 {'bool':{'should':[{'match_phrase':{'data.scenario_id':'w05-poisoned-upload'}},
                    {'match_phrase':{'data.payload.scenario_id':'w05-poisoned-upload'}}],
          'minimum_should_match':1}}
]}}},separators=(',',':')))
PY
)"
json="$(printf '%s' "$query" | "${compose[@]}" exec -T -e NEOLABS_INDEXER_PASSWORD="$WAZUH_INDEXER_PASSWORD" wazuh.indexer sh -c \
  'curl -fsSk -u "admin:${NEOLABS_INDEXER_PASSWORD}" -H "Content-Type: application/json" --data-binary @- "https://localhost:9200/wazuh-alerts-*/_search?ignore_unavailable=true"')"
count="$(printf '%s' "$json" | python3 -c 'import json,sys; d=json.load(sys.stdin); n=d.get("hits",{}).get("total",0);print(n.get("value",0) if isinstance(n,dict) else n)')"
if [[ "$count" =~ ^[0-9]+$ ]] && (( count > 0 )); then
  echo "PASS W05 centrally indexed: pod=$pod rule=$rule_id matching_events=$count"
else
  echo "NOT VERIFIED: no matching central Wazuh index hits for pod=$pod, event_id=$event_id, rule=$rule_id" >&2
  exit 1
fi
