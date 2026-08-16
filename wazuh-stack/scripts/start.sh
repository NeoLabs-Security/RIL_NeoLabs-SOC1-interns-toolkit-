#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# One preparation authority is shared by the platform launchers and this low-level
# Wazuh entrypoint. It owns the complete generated TLS/config set and image preload.
bash ./scripts/ensure-prepared.sh

# Internal helpers are invoked explicitly through Bash rather than relying on Git
# executable-mode preservation. This keeps the root `neolabs connect` path safe on
# copied/cross-platform checkouts where helper scripts are mode 0644.
bash ./scripts/preflight.sh

# Catch deterministic custom-rule mistakes before spending minutes restarting or
# recreating a manager container that can never become healthy.
python3 ./scripts/validate-local-rules.py

docker compose --env-file .env config --quiet

# Containers created from older toolkit locations keep absolute bind-mount source
# paths even after the repository is moved. Remove only those stale containers;
# named volumes/indexer data/telemetry are preserved and recovery recreates them.
bash ./scripts/repair-stale-bind-mounts.sh

# First-run dashboard/API state legitimately has no applied fingerprint yet. Create
# an empty marker once so recover-runtime can treat it as "not yet applied" without
# Bash printing a misleading missing-file error. Never overwrite a real fingerprint.
mkdir -p state
if [[ ! -e state/dashboard-api.applied.sha256 ]]; then
  : > state/dashboard-api.applied.sha256
  chmod 600 state/dashboard-api.applied.sha256 2>/dev/null || true
fi

printf 'Starting Wazuh through the NeoLabs bounded runtime recovery path...\n'
printf '[INFO] First dashboard startup can take a few minutes. NeoLabs will print a heartbeat while health checks are still running.\n'

# recover-runtime intentionally performs bounded waits while Wazuh services warm up.
# Run it as a foreground-owned child with a lightweight heartbeat so a healthy slow
# dashboard does not look like a frozen launcher on lower-resource intern machines.
recovery_rc=0
recovery_elapsed=0
bash ./scripts/recover-runtime.sh &
recovery_pid=$!
while kill -0 "$recovery_pid" 2>/dev/null; do
  sleep 5
  recovery_elapsed=$((recovery_elapsed + 5))
  if (( recovery_elapsed % 20 == 0 )) && kill -0 "$recovery_pid" 2>/dev/null; then
    printf '[WAIT] Wazuh startup/recovery is still progressing (%ss elapsed)...\n' "$recovery_elapsed"
  fi
done
wait "$recovery_pid" || recovery_rc=$?
if (( recovery_rc != 0 )); then
  exit "$recovery_rc"
fi

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
