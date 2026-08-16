#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

[[ -f .env ]] || fail 'Missing wazuh-stack/.env.'
docker image inspect neolabs/vcc-telemetry-collector:0.1.0 >/dev/null 2>&1 || fail 'NeoLabs telemetry collector image is not prepared.'

printf '[NeoLabs Wazuh] Verifying shared VCC telemetry-volume write permissions...\n'
# Named Docker volumes are initially root-owned. The collector deliberately runs
# as an unprivileged user, so a fresh or older volume can otherwise produce
# `cannot create /data/vcc-events.ndjson: Permission denied`. Use the collector
# image itself to discover its UID/GID and repair only the telemetry volume.
docker compose --env-file .env run --rm --no-deps --user 0:0 --entrypoint sh \
  vcc.telemetry.collector -ceu '
    uid="$(id -u collector)"
    gid="$(id -g collector)"
    chown -R "$uid:$gid" /data
    chmod 0755 /data
    find /data -type d -exec chmod 0755 {} +
    find /data -type f -exec chmod 0644 {} +
    test -w /data
  ' >/dev/null

printf '[OK] Shared VCC telemetry volume is writable by the unprivileged collector.\n'
