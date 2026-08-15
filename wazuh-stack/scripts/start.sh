#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

./scripts/preflight.sh

# A previous/interrupted preparation can leave enough generated files for the
# outer launcher to think the stack is reusable while TLS keys/CA files are
# still missing. Treat the generated Wazuh configuration as one atomic set.
generated_required_paths=(
  generated/config/wazuh_cluster/wazuh_manager.conf
  generated/config/wazuh_indexer/internal_users.yml
  generated/config/wazuh_indexer_ssl_certs/root-ca.pem
  generated/config/wazuh_indexer_ssl_certs/root-ca-manager.pem
  generated/config/wazuh_indexer_ssl_certs/admin.pem
  generated/config/wazuh_indexer_ssl_certs/admin-key.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.indexer.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.indexer-key.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.manager.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.manager-key.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.dashboard.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.dashboard-key.pem
)

needs_preparation=0
for path in "${generated_required_paths[@]}"; do
  if [[ ! -f "${path}" ]]; then
    printf '[WARN] Wazuh generated configuration is incomplete; missing %s.\n' "${path}" >&2
    needs_preparation=1
  fi
done

if (( needs_preparation )); then
  printf '[NeoLabs] Repairing the generated Wazuh configuration automatically...\n'
  bash ./scripts/prepare-stack.sh
fi

required_paths=(
  "${generated_required_paths[@]}"
  config/rules/neolabs_vcc_rules.xml
  dashboard/neolabs-saved-objects.ndjson.template
  scripts/repair-certificate-permissions.sh
  scripts/recover-runtime.sh
  scripts/configure-index-retention.sh
  scripts/provision-dashboard-objects.sh
  scripts/disk-warning.sh
  scripts/telemetry-freshness.sh
  scripts/doctor.sh
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "${path}" ]]; then
    printf 'ERROR: Missing required Wazuh file %s after automatic preparation. Pull the latest toolkit and rerun the NeoLabs launcher.\n' "${path}" >&2
    exit 1
  fi
done

# Repair generator-side permission/ownership drift even on an already prepared
# workstation. This runs before Compose so bad host-mounted keys cannot trap the
# manager in an unhealthy restart/recreate loop.
bash ./scripts/repair-certificate-permissions.sh

docker compose --env-file .env config --quiet

# Start in dependency-safe stages instead of one monolithic `compose up`.
# An existing unhealthy manager must not cause Compose to abort the entire run
# before NeoLabs gets a chance to repair it. The recovery helper preserves the
# indexer data, pod telemetry and VCC secrets while doing bounded manager/
# dashboard/collector repair.
printf 'Starting Wazuh through the NeoLabs bounded runtime recovery path...\n'
bash ./scripts/recover-runtime.sh

printf 'Wazuh services were started. Waiting for final health checks...\n'
./scripts/health-check.sh --wait 600

# Post-start UX/maintenance is deliberately fail-soft. A dashboard-object or
# retention-policy provisioning problem must never tear down an otherwise
# healthy Wazuh stack or change VCC server/pod state.
printf 'Applying NeoLabs local retention and dashboard defaults...\n'
if ! ./scripts/configure-index-retention.sh; then
  printf '[WARN] Local retention policy provisioning did not complete; Wazuh remains available. Run neolabs doctor for details.\n' >&2
fi
if ! ./scripts/provision-dashboard-objects.sh; then
  printf '[WARN] Night Watch saved-object provisioning did not complete; core Threat Hunting remains available.\n' >&2
fi
./scripts/disk-warning.sh || true
