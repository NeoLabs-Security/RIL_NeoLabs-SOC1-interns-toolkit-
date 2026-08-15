#!/usr/bin/env bash
set -Eeuo pipefail

VALIDATE_ONLY=0
LOCAL_DOCKER_HOST="unix:///var/run/docker.sock"

for arg in "$@"; do
  case "$arg" in
    --validate-only) VALIDATE_ONLY=1 ;;
    *) printf '[FAILED] Unknown runtime-test argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

if (( VALIDATE_ONLY )); then
  [[ "$LOCAL_DOCKER_HOST" == "unix:///var/run/docker.sock" ]]
  printf '[OK] Native Linux runtime readiness probe contract is valid.\n'
  exit 0
fi

[[ -r /etc/os-release ]] || exit 1
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in ubuntu|debian) ;; *) exit 1 ;; esac

for command_name in bash curl git openssl python3 docker; do
  command -v "$command_name" >/dev/null 2>&1 || exit 1
done
docker compose version >/dev/null 2>&1 || exit 1

# The internship stack belongs on the local Ubuntu/Debian engine. Ignore an
# inherited remote/custom Docker context when the standard native socket exists.
if [[ -S /var/run/docker.sock ]]; then
  value="$(env -u DOCKER_CONTEXT DOCKER_HOST="$LOCAL_DOCKER_HOST" docker info --format '{{.OSType}}' 2>/dev/null || true)"
else
  value="$(docker info --format '{{.OSType}}' 2>/dev/null || true)"
fi
[[ "$value" == "linux" ]] || exit 1

if [[ -r /proc/sys/vm/max_map_count ]]; then
  value="$(cat /proc/sys/vm/max_map_count 2>/dev/null || true)"
  [[ "$value" =~ ^[0-9]+$ ]] || exit 1
  (( value >= 262144 )) || exit 1
fi

exit 0
