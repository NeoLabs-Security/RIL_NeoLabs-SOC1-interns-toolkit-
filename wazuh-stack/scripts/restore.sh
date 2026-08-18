#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${STACK_DIR}/.env"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"
VERIFY_SCRIPT="${STACK_DIR}/scripts/verify-backup.sh"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-neolabs-soc1-wazuh}"
FORCE=false

usage() {
  cat <<'EOF'
Usage: restore.sh BACKUP_DIRECTORY --force

Restores Wazuh Docker volumes from a verified NeoLabs backup. The existing
stack must be stopped. The command refuses to continue unless --force is
provided because volume contents will be replaced.

Credential material is never restored. Re-enrol with a new operator-issued
bootstrap token after recovery.
EOF
}

[[ $# -ge 1 ]] || { usage >&2; exit 2; }
BACKUP_DIR="$1"
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "${FORCE}" == true ]] || {
  echo "Restore refused: pass --force after confirming this is the correct backup." >&2
  exit 2
}
[[ -f "${ENV_FILE}" ]] || {
  echo "Missing ${ENV_FILE}. Recreate the local stack configuration first." >&2
  exit 1
}

bash "${VERIFY_SCRIPT}" "${BACKUP_DIR}"
BACKUP_DIR="$(cd "${BACKUP_DIR}" && pwd)"

compose() {
  COMPOSE_PROJECT_NAME="${PROJECT_NAME}" docker compose \
    --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
}

if compose ps --status running --services | grep -q .; then
  echo "Restore refused: stop the Wazuh stack before restoring." >&2
  exit 1
fi

mapfile -t KNOWN_VOLUMES < <(compose config --volumes | sed '/^[[:space:]]*$/d')
declare -A ALLOWED=()
for volume in "${KNOWN_VOLUMES[@]}"; do
  ALLOWED["${volume}"]=1
done

restored=0
while IFS= read -r -d '' archive; do
  filename="$(basename "${archive}")"
  volume="${filename%.tar.gz}"
  [[ -n "${ALLOWED[${volume}]:-}" ]] || {
    echo "Restore refused: archive is not a declared stack volume: ${volume}" >&2
    exit 1
  }

  docker_volume="${PROJECT_NAME}_${volume}"
  echo "Restoring ${docker_volume}..."
  docker volume create "${docker_volume}" >/dev/null
  docker run --rm \
    --mount "type=volume,source=${docker_volume},target=/target" \
    --mount "type=bind,source=${BACKUP_DIR}/volumes,target=/backup,readonly" \
    alpine:3.20 \
    sh -eu -c "find /target -mindepth 1 -maxdepth 1 -exec rm -rf {} +; tar -xzf /backup/${filename} -C /target"
  restored=$((restored + 1))
done < <(find "${BACKUP_DIR}/volumes" -type f -name '*.tar.gz' -print0 | sort -z)

[[ "${restored}" -gt 0 ]] || {
  echo "No volumes were restored." >&2
  exit 1
}

rm -rf "${STACK_DIR}/secrets/vcc"
mkdir -p "${STACK_DIR}/secrets/vcc" "${STACK_DIR}/state"
chmod 700 "${STACK_DIR}/secrets/vcc" "${STACK_DIR}/state"
rm -f "${STACK_DIR}/state/assigned-pod" \
      "${STACK_DIR}/state/vcc-telemetry.cursor" \
      "${STACK_DIR}/state/collector-health.json"

echo "Restore completed for ${restored} volume(s)."
echo "Next: run compatibility-check.sh, start.sh, health-check.sh and complete a fresh VCC enrolment."
