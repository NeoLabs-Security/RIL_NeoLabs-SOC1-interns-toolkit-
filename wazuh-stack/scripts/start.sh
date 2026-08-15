#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

./scripts/preflight.sh

# A previous/interrupted preparation can leave enough generated files for the
# outer launcher to think the stack is reusable while the TLS certificates are
# still missing. Treat the generated Wazuh configuration as an atomic set. If
# any required generated artifact is absent, repair it automatically before
# attempting to start containers.
generated_required_paths=(
  generated/config/wazuh_cluster/wazuh_manager.conf
  generated/config/wazuh_indexer/internal_users.yml
  generated/config/wazuh_indexer_ssl_certs/root-ca.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.indexer.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.manager.pem
  generated/config/wazuh_indexer_ssl_certs/wazuh.dashboard.pem
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
  ./scripts/prepare-stack.sh
fi

required_paths=(
  "${generated_required_paths[@]}"
  config/rules/neolabs_vcc_rules.xml
  dashboard/neolabs-saved-objects.ndjson.template
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

docker compose --env-file .env config --quiet
docker compose --env-file .env up -d --build

# Bind-mounted custom rules can change after an intern pulls a newer toolkit.
# `docker compose up` does not necessarily restart an already-running manager,
# so explicitly restart it to guarantee wazuh-analysisd loads the current
# NeoLabs VCC rule set before we declare the workstation ready.
printf 'Reloading current NeoLabs VCC rules in the Wazuh manager...\n'
docker compose --env-file .env restart wazuh.manager >/dev/null

printf 'Wazuh services were started. Waiting for health checks...\n'
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
