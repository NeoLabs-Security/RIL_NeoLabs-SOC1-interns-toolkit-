#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

[[ -f .env ]] || fail 'Missing wazuh-stack/.env.'
# shellcheck disable=SC1091
set -a
source .env
set +a
: "${COMPOSE_PROJECT_NAME:=neolabs-soc1-wazuh}"

image='neolabs/vcc-telemetry-collector:0.1.0'
secret_dir="${ROOT_DIR}/secrets/vcc"
volume="${COMPOSE_PROJECT_NAME}_vcc_runtime_secrets"

[[ -d "$secret_dir" ]] || fail 'Missing VCC secret directory.'
docker image inspect "$image" >/dev/null 2>&1 || fail 'NeoLabs telemetry collector image is not prepared.'

printf '[NeoLabs Wazuh] Staging private VCC credentials for the unprivileged telemetry collector...\n'
docker volume inspect "$volume" >/dev/null 2>&1 || docker volume create "$volume" >/dev/null

# The host copy stays owner-only (0700 directory / 0600 files). A short-lived
# root helper copies only the four collector inputs into a Docker volume and then
# transfers ownership to the image's unprivileged collector identity. The normal
# collector mounts this volume read-only with cap_drop: ALL.
docker run --rm \
  --user 0:0 \
  --mount "type=bind,src=${secret_dir},dst=/source,readonly" \
  --mount "type=volume,src=${volume},dst=/dest" \
  --entrypoint sh \
  "$image" -ceu '
    uid="$(id -u collector)"
    gid="$(id -g collector)"
    rm -f /dest/installation-id /dest/client.crt /dest/client.key /dest/ca.crt
    for name in installation-id client.crt client.key ca.crt; do
      if [ -f "/source/$name" ]; then
        cp "/source/$name" "/dest/$name"
      fi
    done
    chown "$uid:$gid" /dest
    chmod 0700 /dest
    for path in /dest/*; do
      [ -f "$path" ] || continue
      chown "$uid:$gid" "$path"
      chmod 0600 "$path"
    done
  ' >/dev/null

# Prove the real unprivileged image identity can traverse/read the staged volume.
docker run --rm \
  --mount "type=volume,src=${volume},dst=/run/vcc-secrets,readonly" \
  --entrypoint sh \
  "$image" -ceu '
    test -r /run/vcc-secrets/installation-id
    if [ -e /run/vcc-secrets/client.crt ] || [ -e /run/vcc-secrets/client.key ] || [ -e /run/vcc-secrets/ca.crt ]; then
      test -r /run/vcc-secrets/client.crt
      test -r /run/vcc-secrets/client.key
      test -r /run/vcc-secrets/ca.crt
    fi
  ' >/dev/null || fail 'Staged VCC credentials are not readable by the unprivileged collector.'

printf '[OK] Private VCC collector credentials are staged and readable without loosening the host secret permissions.\n'
