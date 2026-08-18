#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${STACK_DIR}/.env"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"
BACKUP_ROOT="${SOC_BACKUP_ROOT:-${STACK_DIR}/backups}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-neolabs-soc1-wazuh}"
AUTO_RESTART=true

usage() {
  cat <<'EOF'
Usage: backup.sh [--output DIRECTORY] [--no-restart]

Creates a consistent backup of the named Docker volumes used by the NeoLabs
student Wazuh stack. The stack is stopped before archiving and restarted unless
--no-restart is supplied.

The backup intentionally excludes .env, enrolment tokens, client private keys,
client certificates and VCC endpoint details. Re-enrol after a restore.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || { echo "--output requires a directory" >&2; exit 2; }
      BACKUP_DIR="$2"
      shift 2
      ;;
    --no-restart)
      AUTO_RESTART=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for command in docker sha256sum tar; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Required command not found: ${command}" >&2
    exit 1
  }
done

docker compose version >/dev/null
[[ -f "${ENV_FILE}" ]] || {
  echo "Missing ${ENV_FILE}. Run prepare-stack.sh first." >&2
  exit 1
}

compose() {
  COMPOSE_PROJECT_NAME="${PROJECT_NAME}" docker compose \
    --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
}

mapfile -t VOLUMES < <(compose config --volumes | sed '/^[[:space:]]*$/d')
[[ ${#VOLUMES[@]} -gt 0 ]] || {
  echo "No Compose volumes were discovered." >&2
  exit 1
}

mkdir -p "${BACKUP_DIR}/volumes"
chmod 700 "${BACKUP_DIR}" "${BACKUP_DIR}/volumes"

was_running=false
if compose ps --status running --services | grep -q .; then
  was_running=true
  echo "Stopping the Wazuh stack for a consistent backup..."
  compose stop
fi

restart_if_needed() {
  status=$?
  if [[ "${was_running}" == true && "${AUTO_RESTART}" == true ]]; then
    echo "Restarting the Wazuh stack..."
    compose start >/dev/null || true
  fi
  exit "${status}"
}
trap restart_if_needed EXIT

printf 'format_version=1\n' > "${BACKUP_DIR}/manifest.env"
printf 'created_at=%s\n' "${TIMESTAMP}" >> "${BACKUP_DIR}/manifest.env"
printf 'compose_project=%s\n' "${PROJECT_NAME}" >> "${BACKUP_DIR}/manifest.env"
printf 'credential_material_included=false\n' >> "${BACKUP_DIR}/manifest.env"

for volume in "${VOLUMES[@]}"; do
  docker_volume="${PROJECT_NAME}_${volume}"
  if ! docker volume inspect "${docker_volume}" >/dev/null 2>&1; then
    echo "Skipping absent volume: ${docker_volume}"
    continue
  fi

  echo "Backing up ${docker_volume}..."
  docker run --rm \
    --mount "type=volume,source=${docker_volume},target=/source,readonly" \
    --mount "type=bind,source=${BACKUP_DIR}/volumes,target=/backup" \
    alpine:3.20 \
    sh -eu -c "cd /source && tar -czf /backup/${volume}.tar.gz ."
done

(
  cd "${BACKUP_DIR}"
  find volumes -type f -name '*.tar.gz' -print0 | sort -z | xargs -0 -r sha256sum > SHA256SUMS
)

cat > "${BACKUP_DIR}/RESTORE_NOTICE.txt" <<'EOF'
This backup contains Wazuh Docker volume data only.

It does not contain .env, VCC bootstrap tokens, client private keys, client
certificates, CA trust files or private VCC endpoint details. After restoring,
run the compatibility and health checks, then complete an operator-approved
re-enrolment before collecting VCC telemetry.
EOF
chmod 600 "${BACKUP_DIR}/manifest.env" "${BACKUP_DIR}/SHA256SUMS" "${BACKUP_DIR}/RESTORE_NOTICE.txt"

echo "Backup completed: ${BACKUP_DIR}"
