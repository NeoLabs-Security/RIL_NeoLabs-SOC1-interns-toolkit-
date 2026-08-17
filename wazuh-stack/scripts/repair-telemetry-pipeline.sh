#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

[[ -f .env ]] || { printf 'ERROR: wazuh-stack/.env is missing.\n' >&2; exit 2; }

lab_state="$(python3 - "${REPO_ROOT}/runtime/access-manifest.json" <<'PY'
import json,sys
try:
    print(str(json.load(open(sys.argv[1], encoding='utf-8')).get('lab_state') or 'LIVE'))
except Exception:
    print('UNKNOWN')
PY
)"

printf '[repair] Repairing only the local SOC telemetry path; VCC server state and pod scope will not be changed.\n'
printf '[repair] Current lab state: %s\n' "${lab_state}"

# Reassert the existing containers/configuration without deleting named volumes.
docker compose --env-file .env up -d wazuh.indexer wazuh.manager vcc.telemetry.collector wazuh.dashboard >/dev/null
# A newly created named volume is root-owned by default. Reassert the collector
# ownership before replay or live telemetry attempts to create its NDJSON file.
bash ./scripts/prepare-telemetry-volume.sh
# Restart only local consumers of the shared telemetry file. Never reset VCC or
# delete the student's persistent Wazuh/indexer named volumes.
docker compose --env-file .env restart wazuh.manager vcc.telemetry.collector >/dev/null
bash ./scripts/health-check.sh --wait 300

case "${lab_state}" in
  REPLAY|CLOUD_LIVE|ENDPOINT_LIVE)
    replay_state="${HOME}/.neolabs/soc/replayed-objects.json"
    backup="${replay_state}.repair-backup"
    if [[ -f "${replay_state}" ]]; then
      cp "${replay_state}" "${backup}"
      chmod 600 "${backup}" 2>/dev/null || true
      rm -f "${replay_state}"
    fi
    printf '[repair] Re-fetching the currently authorised pod replay pack so Wazuh sees a fresh file append.\n'
    if (cd "${REPO_ROOT}" && python3 tools/neolabs.py connect); then
      rm -f "${backup}"
    else
      if [[ -f "${backup}" ]]; then
        mv -f "${backup}" "${replay_state}"
      fi
      printf 'ERROR: Replay re-sync failed; previous replay-state metadata was restored.\n' >&2
      exit 1
    fi
    ;;
  LIVE)
    printf '[repair] Live mode uses the mTLS collector; waiting for its next pod-scoped poll.\n'
    ;;
  *)
    printf 'ERROR: Current lab state is unavailable; refusing to guess or alter replay metadata.\n' >&2
    exit 2
    ;;
esac

bash ./scripts/verify-telemetry-pipeline.sh --wait 180
printf '[repair] Local VCC telemetry path recovered and is searchable.\n'
