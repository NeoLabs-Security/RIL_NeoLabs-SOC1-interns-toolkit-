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
host_state_dir="${ROOT_DIR}/state"
secret_volume="${COMPOSE_PROJECT_NAME}_vcc_runtime_secrets"
state_volume="${COMPOSE_PROJECT_NAME}_vcc_runtime_state"

[[ -d "$secret_dir" ]] || fail 'Missing VCC secret directory.'
mkdir -p "$host_state_dir"
docker image inspect "$image" >/dev/null 2>&1 || fail 'NeoLabs telemetry collector image is not prepared.'

printf '[NeoLabs Wazuh] Staging private VCC credentials and collector runtime state...\n'
docker volume inspect "$secret_volume" >/dev/null 2>&1 || docker volume create "$secret_volume" >/dev/null
docker volume inspect "$state_volume" >/dev/null 2>&1 || docker volume create "$state_volume" >/dev/null

# Keep host sources owner-only. A one-shot root helper copies only the four
# collector credential inputs into a private Docker volume and seeds the
# authoritative server-issued pod into a separate writable runtime-state volume.
# Existing cursor/health state is preserved across launches.
docker run --rm \
  --user 0:0 \
  --mount "type=bind,src=${secret_dir},dst=/secret-source,readonly" \
  --mount "type=bind,src=${host_state_dir},dst=/state-source,readonly" \
  --mount "type=volume,src=${secret_volume},dst=/secret-dest" \
  --mount "type=volume,src=${state_volume},dst=/state-dest" \
  --entrypoint sh \
  "$image" -ceu '
    uid="$(id -u collector)"
    gid="$(id -g collector)"

    rm -f /secret-dest/installation-id /secret-dest/client.crt /secret-dest/client.key /secret-dest/ca.crt
    for name in installation-id client.crt client.key ca.crt; do
      if [ -f "/secret-source/$name" ]; then
        cp "/secret-source/$name" "/secret-dest/$name"
      fi
    done
    chown "$uid:$gid" /secret-dest
    chmod 0700 /secret-dest
    for path in /secret-dest/*; do
      [ -f "$path" ] || continue
      chown "$uid:$gid" "$path"
      chmod 0600 "$path"
    done

    # Host state is not bind-mounted into the long-running collector. Seed only
    # assigned-pod; cursor and health remain collector-owned in the Docker volume.
    if [ -f /state-source/assigned-pod ]; then
      rm -f /state-dest/assigned-pod
      cp /state-source/assigned-pod /state-dest/assigned-pod
    fi
    chown -R "$uid:$gid" /state-dest
    chmod 0700 /state-dest
    find /state-dest -type f -exec chmod 0600 {} +
  ' >/dev/null

# Prove the actual non-root image identity can read private credentials and can
# write/delete its runtime cursor/health state before the service is launched.
docker run --rm \
  --mount "type=volume,src=${secret_volume},dst=/run/vcc-secrets,readonly" \
  --mount "type=volume,src=${state_volume},dst=/runtime-state" \
  --entrypoint sh \
  "$image" -ceu '
    test -r /run/vcc-secrets/installation-id
    if [ -e /run/vcc-secrets/client.crt ] || [ -e /run/vcc-secrets/client.key ] || [ -e /run/vcc-secrets/ca.crt ]; then
      test -r /run/vcc-secrets/client.crt
      test -r /run/vcc-secrets/client.key
      test -r /run/vcc-secrets/ca.crt
    fi
    probe="/runtime-state/.neolabs-state-probe-$$"
    : > "$probe"
    rm -f "$probe"
  ' >/dev/null || fail 'Staged VCC credentials/state are not usable by the unprivileged collector.'

printf '[OK] Private VCC credentials and collector runtime state are ready without loosening host permissions.\n'
