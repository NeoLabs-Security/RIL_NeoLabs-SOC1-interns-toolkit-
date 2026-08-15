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

[[ -d "${CERT_DIR}" ]] || fail "Wazuh certificate directory is missing."

# Wazuh 4.14.x's certificate-generator image can finish certificate generation
# even when its own final permission step emits errors (including a missing
# `find` command). Repair permissions ourselves with the already-pinned indexer
# image. On normal Linux/WSL ext4 this produces strict UID 1000 / mode 0400
# files, matching the indexer/dashboard runtime UID. Some Windows-backed WSL
# filesystems do not implement POSIX chown exactly; in that case actual runtime
# readability is authoritative and is tested immediately below.
printf '[NeoLabs] Normalising generated Wazuh certificate ownership and permissions...\n'
if ! docker run --rm --user 0:0 \
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
then
  printf '[WARN] The host filesystem did not accept strict POSIX ownership changes; validating container readability instead.\n' >&2
fi

# First prove the complete files exist and are non-empty as root. These are the
# exact certificate/key files consumed by docker-compose.yml.
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
    done
  '

# Then prove the non-root UID used by both Wazuh indexer and dashboard can
# actually read every file those services consume. This is more reliable than
# trusting host-side stat/chown semantics across native Linux and Docker
# Desktop/WSL bind mounts.
docker run --rm --user 1000:1000 \
  -v "${CERT_DIR}:/certificates:ro" \
  "wazuh/wazuh-indexer:${WAZUH_VERSION}" \
  bash -ceu '
    for name in \
      root-ca.pem admin.pem admin-key.pem \
      wazuh.indexer.pem wazuh.indexer-key.pem \
      wazuh.dashboard.pem wazuh.dashboard-key.pem
    do
      path="/certificates/$name"
      [ -r "$path" ] || { echo "Wazuh service UID cannot read certificate/key: $name" >&2; exit 1; }
    done
  '

printf '[OK] Wazuh certificate/key files are complete and readable by the services that consume them.\n'
