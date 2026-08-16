#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# One preparation authority is shared by the platform launchers and this low-level
# Wazuh entrypoint. It owns the complete generated TLS/config set and image preload.
bash ./scripts/ensure-prepared.sh

# Internal helper scripts are intentionally safe to invoke through Bash rather
# than relying on Git executable-mode preservation. This keeps `neolabs connect`
# working on existing/cross-platform checkouts where helper files are mode 0644.
bash ./scripts/preflight.sh

# Catch deterministic custom-rule mistakes before spending minutes restarting or
# recreating a manager container that can never become healthy.
python3 ./scripts/validate-local-rules.py

docker compose --env-file .env config --quiet

# Containers created from older toolkit locations keep absolute bind-mount source
# paths even after the repository is moved. Remove only those stale containers;
# named volumes/indexer data/telemetry are preserved and recovery recreates them.
bash ./scripts/repair-stale-bind-mounts.sh

printf 'Starting Wazuh through the NeoLabs bounded runtime recovery path...\n'
bash ./scripts/recover-runtime.sh

printf 'Wazuh services were started. Waiting for final health checks...\n'
bash ./scripts/health-check.sh --wait 600

# Post-start UX/maintenance is deliberately fail-soft. A dashboard-object or
# retention-policy provisioning problem must never tear down an otherwise
# healthy Wazuh stack or change VCC server/pod state.
printf 'Applying NeoLabs local retention and dashboard defaults...\n'
if ! bash ./scripts/configure-index-retention.sh; then
  printf '[WARN] Local retention policy provisioning did not complete; Wazuh remains available. Run neolabs doctor for details.\n' >&2
fi
if ! bash ./scripts/provision-dashboard-objects.sh; then
  printf '[WARN] Night Watch saved-object provisioning did not complete; core Threat Hunting remains available.\n' >&2
fi
bash ./scripts/disk-warning.sh || true
