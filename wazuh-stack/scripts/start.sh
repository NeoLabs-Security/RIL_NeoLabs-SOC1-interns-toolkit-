#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

./scripts/preflight.sh

required_paths=(
  generated/config/wazuh_cluster/wazuh_manager.conf
  generated/config/wazuh_indexer/internal_users.yml
  generated/config/wazuh_indexer_ssl_certs/root-ca.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.indexer.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.manager.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.dashboard.pem
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "${path}" ]]; then
    printf 'ERROR: Missing generated file %s. Run ./scripts/prepare-stack.sh first.\n' "${path}" >&2
    exit 1
  fi
done

docker compose --env-file .env config --quiet
docker compose --env-file .env up -d --build

printf 'Wazuh services were started. Waiting for health checks...\n'
./scripts/health-check.sh --wait 600
