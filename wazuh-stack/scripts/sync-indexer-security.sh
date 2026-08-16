#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
log() { printf '[NeoLabs Wazuh] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }

[[ -f .env ]] || fail 'Missing wazuh-stack/.env.'
# shellcheck disable=SC1091
set -a
source .env
set +a
: "${WAZUH_INDEXER_PASSWORD:?WAZUH_INDEXER_PASSWORD is required}"

desired_file="state/runtime-credentials.desired.sha256"
applied_file="state/indexer-security.applied.sha256"
[[ -s "$desired_file" ]] || fail 'Desired indexer security fingerprint is missing; run ensure-prepared.sh first.'
desired="$(tr -d '\r\n' < "$desired_file")"
applied="$(tr -d '\r\n' < "$applied_file" 2>/dev/null || true)"

indexer_id="$(docker compose --env-file .env ps -q wazuh.indexer 2>/dev/null || true)"
[[ -n "$indexer_id" ]] || fail 'Wazuh indexer container is not running.'

admin_auth_works() {
  docker compose --env-file .env exec -T \
    -e NEOLABS_INDEXER_PASSWORD="$WAZUH_INDEXER_PASSWORD" \
    wazuh.indexer sh -c \
    'curl -fsSk -u "admin:${NEOLABS_INDEXER_PASSWORD}" https://localhost:9200/_cluster/health >/dev/null' \
    >/dev/null 2>&1
}

if [[ "$applied" == "$desired" ]] && admin_auth_works; then
  ok 'Persisted OpenSearch security users already match the current NeoLabs credentials.'
  exit 0
fi

log 'Applying the current generated OpenSearch security configuration to the persistent indexer state...'
# The indexer data volume persists the OpenSearch Security index. Updating the
# bind-mounted internal_users.yml alone does not mutate that persisted state, so
# securityadmin must be run whenever the NeoLabs credential fingerprint changes
# or the current admin password cannot authenticate.
docker compose --env-file .env exec -T wazuh.indexer bash -lc '
  set -e
  export JAVA_HOME=/usr/share/wazuh-indexer/jdk
  tool=/usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh
  conf=/usr/share/wazuh-indexer/config/opensearch-security
  certs=/usr/share/wazuh-indexer/config/certs
  test -x "$tool"
  test -s "$conf/internal_users.yml"
  bash "$tool" -cd "$conf" -nhnv \
    -cacert "$certs/root-ca.pem" \
    -cert "$certs/admin.pem" \
    -key "$certs/admin-key.pem" \
    -h 127.0.0.1 -p 9200 -icl
'

for _ in $(seq 1 30); do
  if admin_auth_works; then
    printf '%s\n' "$desired" > "$applied_file"
    chmod 600 "$applied_file" 2>/dev/null || true
    ok 'Persistent indexer security state is synchronized with .env.'
    exit 0
  fi
  sleep 2
done

fail 'securityadmin completed, but the current NeoLabs indexer administrator credential is still rejected.'
