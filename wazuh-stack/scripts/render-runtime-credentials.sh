#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
INTERNAL_USERS="${ROOT_DIR}/generated/config/wazuh_indexer/internal_users.yml"
DASHBOARD_WAZUH="${ROOT_DIR}/generated/config/wazuh_dashboard/wazuh.yml"
STATE_DIR="${ROOT_DIR}/state"
DESIRED_STATE="${STATE_DIR}/runtime-credentials.desired.sha256"

fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

[[ -f "$ENV_FILE" ]] || fail 'Missing wazuh-stack/.env.'
[[ -f "$INTERNAL_USERS" ]] || fail 'Missing generated Wazuh indexer internal_users.yml.'
[[ -f "$DASHBOARD_WAZUH" ]] || fail 'Missing generated Wazuh dashboard wazuh.yml.'
# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

: "${WAZUH_VERSION:?WAZUH_VERSION is required}"
: "${WAZUH_INDEXER_PASSWORD:?WAZUH_INDEXER_PASSWORD is required}"
: "${WAZUH_DASHBOARD_PASSWORD:?WAZUH_DASHBOARD_PASSWORD is required}"
: "${WAZUH_API_PASSWORD:?WAZUH_API_PASSWORD is required}"

command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required.'
mkdir -p "$STATE_DIR"

desired="$(printf 'neolabs-runtime-credentials-v2\0%s\0%s\0%s\0' \
  "$WAZUH_INDEXER_PASSWORD" "$WAZUH_DASHBOARD_PASSWORD" "$WAZUH_API_PASSWORD" | sha256sum | awk '{print $1}')"
marker="# NeoLabs runtime credential fingerprint: ${desired}"

hash_password() {
  local password="$1"
  docker run --rm \
    -e NEOLABS_PASSWORD="$password" \
    "wazuh/wazuh-indexer:${WAZUH_VERSION}" \
    bash -lc '/usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "$NEOLABS_PASSWORD"' \
    | awk '/^\$2[ayb]\$/{hash=$0} END{print hash}'
}

current_marker="$(grep -m1 '^# NeoLabs runtime credential fingerprint: ' "$INTERNAL_USERS" 2>/dev/null || true)"
if [[ "$current_marker" != "$marker" ]]; then
  printf '[NeoLabs Wazuh] Synchronising generated indexer user hashes with the current local .env credentials...\n'
  admin_hash="$(hash_password "$WAZUH_INDEXER_PASSWORD")"
  dashboard_hash="$(hash_password "$WAZUH_DASHBOARD_PASSWORD")"
  [[ -n "$admin_hash" ]] || fail 'Could not generate the indexer administrator password hash.'
  [[ -n "$dashboard_hash" ]] || fail 'Could not generate the dashboard service password hash.'

  python3 - "$INTERNAL_USERS" "$admin_hash" "$dashboard_hash" "$marker" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = re.sub(r'^# NeoLabs runtime credential fingerprint: .*\n?', '', text, count=1, flags=re.M)
for username, new_hash in (("admin", sys.argv[2]), ("kibanaserver", sys.argv[3])):
    pattern = rf'({re.escape(username)}:\n  hash: ")[^"]+("\n)'
    text, count = re.subn(pattern, rf'\g<1>{new_hash}\g<2>', text, count=1)
    if count != 1:
        raise SystemExit(f'Could not update hash for {username}')
path.write_text(sys.argv[4] + '\n' + text, encoding='utf-8')
PY
fi

# The upstream dashboard image only creates its API entry when the host id is
# absent. Because the upstream single-node wazuh.yml already contains that id,
# environment variables alone do not replace the default API password. Render
# this file explicitly from NeoLabs' local secret so the dashboard and manager
# always agree on the wazuh-wui credential.
python3 - "$DASHBOARD_WAZUH" "$WAZUH_API_PASSWORD" "$marker" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
password = json.dumps(sys.argv[2])
text = (
    sys.argv[3] + '\n'
    'hosts:\n'
    '  - 1513629884013:\n'
    '      url: "https://wazuh.manager"\n'
    '      port: 55000\n'
    '      username: wazuh-wui\n'
    f'      password: {password}\n'
    '      run_as: true\n'
)
path.write_text(text, encoding='utf-8')
PY
chmod 600 "$DASHBOARD_WAZUH" 2>/dev/null || true
printf '%s\n' "$desired" > "$DESIRED_STATE"
chmod 600 "$DESIRED_STATE" 2>/dev/null || true
printf '[OK] Generated Wazuh indexer/dashboard credentials match the current local .env.\n'
