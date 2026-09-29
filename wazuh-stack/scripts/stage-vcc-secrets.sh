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

# Keep host sources owner-only. A one-shot root helper copies only the selected
# collector credential inputs into a private Docker volume and seeds the
# authoritative server-issued scope into a separate writable runtime-state volume.
# Cursor/health survive ordinary restarts but are reset if pod assignment changes.
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

    rm -f /secret-dest/installation-id /secret-dest/client.crt /secret-dest/client.key /secret-dest/ca.crt /secret-dest/arena-token /secret-dest/arena-ca.crt
    for name in installation-id client.crt client.key ca.crt arena-token arena-ca.crt; do
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

    old_pod=""
    new_pod=""
    old_scope=""
    new_scope=""
    [ ! -f /state-dest/assigned-pod ] || old_pod="$(tr -d "\r\n" < /state-dest/assigned-pod)"
    [ ! -f /state-source/assigned-pod ] || new_pod="$(tr -d "\r\n" < /state-source/assigned-pod)"
    [ ! -f /state-dest/collector-scope ] || old_scope="$(tr -d "\r\n" < /state-dest/collector-scope)"
    if [ -f /state-source/collector-scope ]; then
      new_scope="$(tr -d "\r\n" < /state-source/collector-scope)"
    elif [ -n "$new_pod" ]; then
      new_scope="pod:$new_pod"
    fi

    if [ -n "$new_pod" ]; then
      # A cursor is scoped to the server-issued pod. Preserve it only when the
      # assignment is unchanged; never carry an old pod cursor into a new pod.
      if [ "$old_pod" != "$new_pod" ] || [ "$old_scope" != "$new_scope" ]; then
        rm -f /state-dest/vcc-telemetry.cursor /state-dest/collector-health.json
      fi
      rm -f /state-dest/assigned-pod
      cp /state-source/assigned-pod /state-dest/assigned-pod
      printf "%s\n" "$new_scope" > /state-dest/collector-scope
    else
      # No current authoritative pod: clear only ephemeral collector state. Raw
      # telemetry/indexer data and host enrolment material remain untouched.
      rm -f /state-dest/assigned-pod /state-dest/collector-scope /state-dest/vcc-telemetry.cursor /state-dest/collector-health.json
    fi

    rm -f /state-dest/ip-watchlist.txt
    if [ -f /state-source/ip-watchlist.txt ]; then
      cp /state-source/ip-watchlist.txt /state-dest/ip-watchlist.txt
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
    if [ -e /run/vcc-secrets/arena-token ]; then
      test -r /run/vcc-secrets/arena-token
    elif [ -e /run/vcc-secrets/client.crt ] || [ -e /run/vcc-secrets/client.key ] || [ -e /run/vcc-secrets/ca.crt ]; then
      test -r /run/vcc-secrets/client.crt
      test -r /run/vcc-secrets/client.key
      test -r /run/vcc-secrets/ca.crt
    else
      exit 1
    fi
    probe="/runtime-state/.neolabs-state-probe-$$"
    : > "$probe"
    rm -f "$probe"
  ' >/dev/null || fail 'Staged VCC credentials/state are not usable by the unprivileged collector.'

printf '[OK] Private VCC credentials and collector runtime state are ready without loosening host permissions.\n'
