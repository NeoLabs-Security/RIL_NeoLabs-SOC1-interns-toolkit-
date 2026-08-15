#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
CERT_DIR="${ROOT_DIR}/generated/config/wazuh_indexer_ssl_certs"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

[[ -f "${ENV_FILE}" ]] || fail "Missing wazuh-stack/.env."
# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a
: "${WAZUH_VERSION:?WAZUH_VERSION is required}"

required_certs=(
  root-ca.pem
  root-ca-manager.pem
  admin.pem
  admin-key.pem
  wazuh.indexer.pem
  wazuh.indexer-key.pem
  wazuh.manager.pem
  wazuh.manager-key.pem
  wazuh.dashboard.pem
  wazuh.dashboard-key.pem
)

[[ -d "${CERT_DIR}" ]] || fail "Wazuh certificate directory is missing."

# Wazuh 4.14.x's certificate-generator image can finish certificate generation
# even when its internal permission-normalisation step fails (for example when
# `find` is absent in that generator image). Do not depend on that final step.
# Re-normalise the bind-mounted certificate directory with the pinned indexer
# image, whose runtime user is UID/GID 1000. The manager container runs as root,
# so the same 0400 files remain readable there as well.
printf '[NeoLabs] Normalising generated Wazuh certificate ownership and permissions...\n'
docker run --rm --user 0:0 \
  -v "${CERT_DIR}:/certificates" \
  "wazuh/wazuh-indexer:${WAZUH_VERSION}" \
  bash -ceu '
    chown -R 1000:1000 /certificates
    chmod 700 /certificates
    for path in /certificates/*; do
      [ -e "$path" ] || continue
      if [ -d "$path" ]; then
        chmod 700 "$path"
      else
        chmod 400 "$path"
      fi
    done
  '

# Verify the exact certificate/key set consumed by docker-compose.yml from
# inside a root helper container. This avoids false failures when the host user
# intentionally cannot read 0400 files owned by the Wazuh service UID.
docker run --rm --user 0:0 \
  -v "${CERT_DIR}:/certificates:ro" \
  "wazuh/wazuh-indexer:${WAZUH_VERSION}" \
  bash -ceu '
    for name in \
      root-ca.pem root-ca-manager.pem \
      admin.pem admin-key.pem \
      wazuh.indexer.pem wazuh.indexer-key.pem \
      wazuh.manager.pem wazuh.manager-key.pem \
      wazuh.dashboard.pem wazuh.dashboard-key.pem
    do
      path="/certificates/$name"
      [ -s "$path" ] || { echo "Missing or empty certificate/key: $name" >&2; exit 1; }
      owner="$(stat -c "%u:%g" "$path")"
      mode="$(stat -c "%a" "$path")"
      [ "$owner" = "1000:1000" ] || { echo "Unexpected owner on $name: $owner" >&2; exit 1; }
      [ "$mode" = "400" ] || { echo "Unexpected mode on $name: $mode" >&2; exit 1; }
    done
  '

printf '[OK] Wazuh certificate/key ownership and permissions are healthy.\n'
