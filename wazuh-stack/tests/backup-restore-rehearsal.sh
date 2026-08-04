#!/usr/bin/env bash
set -euo pipefail

for command in docker sha256sum tar; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Required command not found: ${command}" >&2
    exit 1
  }
done

WORK_DIR="$(mktemp -d)"
VOLUME="neolabs-soc1-backup-rehearsal-${RANDOM}-${RANDOM}"
MARKER="synthetic-recovery-marker-${RANDOM}"

cleanup() {
  docker volume rm -f "${VOLUME}" >/dev/null 2>&1 || true
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

docker volume create "${VOLUME}" >/dev/null
docker run --rm --mount "type=volume,source=${VOLUME},target=/data" alpine:3.20 \
  sh -eu -c "printf '%s\n' '${MARKER}' > /data/marker.txt"

docker run --rm \
  --mount "type=volume,source=${VOLUME},target=/source,readonly" \
  --mount "type=bind,source=${WORK_DIR},target=/backup" \
  alpine:3.20 sh -eu -c 'cd /source && tar -czf /backup/rehearsal.tar.gz .'

(
  cd "${WORK_DIR}"
  sha256sum rehearsal.tar.gz > SHA256SUMS
  sha256sum --check --strict SHA256SUMS
)
tar -tzf "${WORK_DIR}/rehearsal.tar.gz" | grep -q 'marker.txt'

docker volume rm "${VOLUME}" >/dev/null
docker volume create "${VOLUME}" >/dev/null
docker run --rm \
  --mount "type=volume,source=${VOLUME},target=/target" \
  --mount "type=bind,source=${WORK_DIR},target=/backup,readonly" \
  alpine:3.20 sh -eu -c 'tar -xzf /backup/rehearsal.tar.gz -C /target'

restored="$(docker run --rm --mount "type=volume,source=${VOLUME},target=/data,readonly" alpine:3.20 cat /data/marker.txt)"
[[ "${restored}" == "${MARKER}" ]]

echo "Backup/restore rehearsal passed with synthetic Docker volume data."
