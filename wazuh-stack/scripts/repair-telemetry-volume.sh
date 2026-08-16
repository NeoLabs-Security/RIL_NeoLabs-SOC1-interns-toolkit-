#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

[[ -f .env ]] || fail 'Missing wazuh-stack/.env.'
docker image inspect neolabs/vcc-telemetry-collector:0.1.0 >/dev/null 2>&1 || fail 'NeoLabs telemetry collector image is not prepared.'

printf '[NeoLabs Wazuh] Verifying shared VCC telemetry-volume write permissions...\n'
# The collector service deliberately drops every Linux capability. `docker compose
# run --user 0:0` inherits that cap_drop policy, so UID 0 alone cannot chown a
# named volume. Grant only the filesystem capabilities required by this temporary
# repair helper; the long-running collector remains unprivileged with cap_drop ALL.
docker compose --env-file .env run --rm --no-deps \
  --user 0:0 \
  --cap-add CHOWN \
  --cap-add FOWNER \
  --cap-add DAC_OVERRIDE \
  --entrypoint sh \
  vcc.telemetry.collector -ceu '
    uid="$(id -u collector)"
    gid="$(id -g collector)"
    chown -R "$uid:$gid" /data
    chmod 0755 /data
    find /data -type d -exec chmod 0755 {} +
    find /data -type f -exec chmod 0644 {} +
  ' >/dev/null

# Prove the actual service identity can write the volume. This second helper uses
# the Compose service defaults again: USER collector, no-new-privileges and
# cap_drop ALL. Do not declare preparation successful based on a root-only test.
docker compose --env-file .env run --rm --no-deps --entrypoint sh \
  vcc.telemetry.collector -ceu '
    probe="/data/.neolabs-write-probe-$$"
    : > "$probe"
    rm -f "$probe"
  ' >/dev/null || fail 'The telemetry volume was repaired, but the unprivileged collector still cannot write /data.'

printf '[OK] Shared VCC telemetry volume is writable by the unprivileged collector.\n'
