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
WARN_PERCENT="${NEOLABS_DISK_WARN_PERCENT:-85}"
CRITICAL_PERCENT="${NEOLABS_DISK_CRITICAL_PERCENT:-92}"
for value in "${WARN_PERCENT}" "${CRITICAL_PERCENT}"; do
  [[ "${value}" =~ ^[0-9]+$ ]] || { printf 'ERROR: disk thresholds must be numeric.\n' >&2; exit 2; }
done
if (( WARN_PERCENT < 50 || WARN_PERCENT >= CRITICAL_PERCENT || CRITICAL_PERCENT > 98 )); then
  printf 'ERROR: expected 50 <= warning < critical <= 98.\n' >&2
  exit 2
fi

id="$(docker compose --env-file .env ps -q wazuh.indexer 2>/dev/null || true)"
[[ -n "${id}" ]] || { printf '[WARN] Indexer disk check skipped because wazuh.indexer is not running.\n'; exit 0; }

usage_line="$(docker compose --env-file .env exec -T wazuh.indexer sh -c "df -Pk /var/lib/wazuh-indexer | tail -n 1" 2>/dev/null || true)"
if [[ -z "${usage_line}" ]]; then
  printf '[WARN] Could not read the Docker filesystem usage for the Wazuh indexer.\n'
  exit 0
fi

read -r _ blocks used available percent _ <<<"${usage_line}"
percent="${percent%%%}"
[[ "${percent}" =~ ^[0-9]+$ ]] || { printf '[WARN] Could not parse indexer disk usage.\n'; exit 0; }

store_json="$(docker compose --env-file .env exec -T \
  -e NEOLABS_INDEXER_PASSWORD="${WAZUH_INDEXER_PASSWORD}" wazuh.indexer sh -c \
  'curl -fsSk -u "admin:${NEOLABS_INDEXER_PASSWORD}" "https://localhost:9200/_cat/indices/wazuh-alerts-*?format=json&bytes=mb&h=index,store.size,docs.count"' 2>/dev/null || true)"

read -r alert_mb alert_docs < <(printf '%s' "${store_json:-[]}" | python3 -c 'import json,sys
try: rows=json.load(sys.stdin)
except Exception: rows=[]
mb=docs=0.0
for row in rows if isinstance(rows,list) else []:
    try: mb += float(row.get("store.size") or 0)
    except Exception: pass
    try: docs += float(row.get("docs.count") or 0)
    except Exception: pass
print(f"{mb:.1f}", int(docs))')

available_gib="$(python3 - "${available}" <<'PY'
import sys
print(f"{int(sys.argv[1]) / 1024 / 1024:.1f}")
PY
)"

printf 'Indexer disk: %s%% used; %s GiB available; Wazuh alert indices: %s MiB / %s documents.\n' \
  "${percent}" "${available_gib}" "${alert_mb}" "${alert_docs}"
if (( percent >= CRITICAL_PERCENT )); then
  printf '[CRITICAL] Local Docker/indexer storage is above %s%%. Free host disk space before continuing heavy lab work.\n' "${CRITICAL_PERCENT}"
elif (( percent >= WARN_PERCENT )); then
  printf '[WARN] Local Docker/indexer storage is above %s%%. Retention is configured, but the intern should free disk space soon.\n' "${WARN_PERCENT}"
else
  printf '[OK] Local indexer storage is below the NeoLabs warning threshold.\n'
fi
