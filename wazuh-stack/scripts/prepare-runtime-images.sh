#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { printf '[FAILED] %s\n' "$*" >&2; exit 1; }
log() { printf '[NeoLabs Wazuh] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }

[[ -f .env ]] || fail 'Missing wazuh-stack/.env.'
# shellcheck disable=SC1091
set -a
source .env
set +a
: "${WAZUH_VERSION:?WAZUH_VERSION is required}"

docker info >/dev/null 2>&1 || fail 'Docker is not reachable while preparing Wazuh runtime images.'
docker compose version >/dev/null 2>&1 || fail 'Docker Compose v2 is unavailable.'

images=(
  "wazuh/wazuh-indexer:${WAZUH_VERSION}"
  "wazuh/wazuh-manager:${WAZUH_VERSION}"
  "wazuh/wazuh-dashboard:${WAZUH_VERSION}"
)
for image in "${images[@]}"; do
  if docker image inspect "$image" >/dev/null 2>&1; then
    printf '[OK] Runtime image already present: %s\n' "$image"
  else
    log "Downloading required runtime image before authentication: $image"
    docker pull "$image"
  fi
done

mkdir -p state
fingerprint="$({
  printf 'collector-v1\n'
  sha256sum collector/Dockerfile collector/collector.py collector/healthcheck.py 2>/dev/null || true
} | sha256sum | awk '{print $1}')"
previous="$(cat state/collector-image-fingerprint 2>/dev/null || true)"

if ! docker image inspect neolabs/vcc-telemetry-collector:0.1.0 >/dev/null 2>&1 || [[ "$fingerprint" != "$previous" ]]; then
  log 'Building the NeoLabs telemetry collector before authentication...'
  docker compose --env-file .env build vcc.telemetry.collector
  printf '%s\n' "$fingerprint" > state/collector-image-fingerprint
else
  ok 'NeoLabs telemetry collector image is already current.'
fi

ok 'All Wazuh runtime images required by this toolkit are available locally.'
