#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CONFIRM=false
INCLUDE_ENROLMENT=false
for argument in "$@"; do
  case "${argument}" in
    --confirm-destroy-local-data) CONFIRM=true ;;
    --include-enrolment) INCLUDE_ENROLMENT=true ;;
    *) printf 'ERROR: Unknown option: %s\n' "${argument}" >&2; exit 2 ;;
  esac
done

if [[ "${CONFIRM}" != true ]]; then
  cat >&2 <<'TEXT'
This command deletes local Wazuh containers, volumes, generated configuration,
collector state and locally stored telemetry. It does not revoke a VCC credential.

Re-run with --confirm-destroy-local-data after reviewing the operator guidance.
Add --include-enrolment only after the VCC operator has revoked the credential.
TEXT
  exit 2
fi

[[ -f .env ]] || { printf 'ERROR: Missing .env.\n' >&2; exit 1; }
docker compose --env-file .env down --volumes --remove-orphans
rm -rf generated .state
rm -f state/vcc-telemetry.cursor state/collector-health.json

# The replay ledger lives outside the stack directory, while the replayed event
# data lives in the vcc_telemetry Docker volume removed above. Clear both sides
# together so the next authorised connect fetches the current replay packs
# instead of incorrectly treating the now-deleted events as already ingested.
replay_state="${HOME}/.neolabs/soc/replayed-objects.json"
rm -f "${replay_state}" "${replay_state}.repair-backup"

if [[ "${INCLUDE_ENROLMENT}" == true ]]; then
  rm -f \
    secrets/vcc/client.key \
    secrets/vcc/client.crt \
    secrets/vcc/ca.crt \
    state/enrolment.json \
    state/assigned-pod
  printf 'Local enrolment material removed. Confirm server-side revocation with the VCC operator.\n'
else
  printf 'Enrolment credential retained. Re-run prepare-stack before the next startup.\n'
fi
