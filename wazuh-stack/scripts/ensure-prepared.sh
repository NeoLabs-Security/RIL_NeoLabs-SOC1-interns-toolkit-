#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() { printf '[NeoLabs Wazuh] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAILED] %s\n' "$*" >&2; exit 1; }

required_generated_paths=(
  generated/config/wazuh_cluster/wazuh_manager.conf
  generated/config/wazuh_indexer/internal_users.yml
  generated/config/wazuh_dashboard/wazuh.yml
  generated/config/wazuh_dashboard/opensearch_dashboards.yml
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

if [[ ! -f .env ]]; then
  log 'First run detected. Generating private local Wazuh credentials...'
  bash ./scripts/generate-local-secrets.sh
fi
chmod 600 .env 2>/dev/null || true

missing=()
for path in "${required_generated_paths[@]}"; do
  [[ -s "$path" ]] || missing+=("$path")
done

if (( ${#missing[@]} > 0 )); then
  warn 'Wazuh preparation is incomplete; repairing the complete generated configuration before authentication.'
  for path in "${missing[@]}"; do warn "  missing/empty: $path"; done
  bash ./scripts/prepare-stack.sh
fi

for path in "${required_generated_paths[@]}"; do
  [[ -s "$path" ]] || fail "Wazuh preparation did not produce required file: $path"
done

# Older launcher iterations may have valid certificates but stale generated
# OpenSearch/dashboard credentials. Re-render them from the current private .env
# on every startup; expensive bcrypt work is fingerprinted and only repeats when
# credentials/configuration actually changed.
bash ./scripts/render-runtime-credentials.sh

# Do not trust the upstream certificate generator's final chmod/chown step.
# Prove the exact host-mounted files are complete and readable by Wazuh before
# any pod authentication or service startup occurs.
bash ./scripts/repair-certificate-permissions.sh

# Pull/build heavyweight runtime images before login. This prevents an intern's
# access session from appearing to hang behind a first-use image download.
bash ./scripts/prepare-runtime-images.sh

# Host VCC credentials deliberately remain owner-only. Stage only the collector
# inputs into a Docker volume owned by the image's unprivileged collector user.
bash ./scripts/stage-vcc-secrets.sh

# The collector is intentionally non-root. Repair the named telemetry volume now
# so both fresh volumes and volumes created by older launcher iterations are
# writable before replay/live events are appended.
bash ./scripts/repair-telemetry-volume.sh

printf '[OK] Wazuh preparation, credentials, TLS files, VCC secrets, telemetry volume and runtime images are ready.\n'
