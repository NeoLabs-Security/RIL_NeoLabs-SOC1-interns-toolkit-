#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

[[ -f .env ]] || { printf 'ERROR: Missing wazuh-stack/.env.\n' >&2; exit 1; }

# collector/Dockerfile creates the unprivileged collector account as UID 100;
# Wazuh reads local files as group 999. The manager mounts the same named volume
# and runs as root, so it is the bounded authority used to assign collector
# ownership plus manager-group read access before the collector starts. Never
# make telemetry storage world-writable.
COLLECTOR_UID=100
MANAGER_GID=999
MANAGER_TELEMETRY_PATH=/var/ossec/logs/vcc

manager_id="$(docker compose --env-file .env ps -q wazuh.manager 2>/dev/null || true)"
[[ -n "${manager_id}" ]] || {
  printf 'ERROR: Wazuh manager must be running before telemetry-volume preparation.\n' >&2
  exit 1
}

docker compose --env-file .env exec -T --user 0 wazuh.manager sh -ceu \
  'path="$1"; uid="$2"; gid="$3"; mkdir -p "$path"; chown "$uid:$gid" "$path"; chmod 0750 "$path"' \
  sh "${MANAGER_TELEMETRY_PATH}" "${COLLECTOR_UID}" "${MANAGER_GID}"

actual="$(docker compose --env-file .env exec -T --user 0 wazuh.manager \
  stat -c '%u:%g:%a' "${MANAGER_TELEMETRY_PATH}")"
[[ "${actual}" == "${COLLECTOR_UID}:${MANAGER_GID}:750" ]] || {
  printf 'ERROR: Telemetry volume has unexpected ownership/mode: %s\n' "${actual}" >&2
  exit 1
}

printf '[OK] Shared telemetry volume is writable by the collector and readable by the Wazuh manager group.\n'
