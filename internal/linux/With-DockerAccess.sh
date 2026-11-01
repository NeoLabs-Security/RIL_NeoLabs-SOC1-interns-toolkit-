#!/usr/bin/env bash
# Use an already-authorized Docker group for this NeoLabs command without
# changing the caller's SSH shell, daemon, containers, or host permissions.
set -Eeuo pipefail

(($# > 0)) || { printf '[FAILED] No NeoLabs command supplied to Docker group helper.\n' >&2; exit 2; }

# The root CLI only calls this on native Linux. In WSL, Docker Desktop owns
# group/runtime access; never invoke local Linux group management there.
if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null; then
  exec "$@"
fi

socket="${NEOLABS_DOCKER_SOCKET:-/var/run/docker.sock}"
if [[ ! -S "$socket" ]] || [[ "$(stat -c '%G' -- "$socket" 2>/dev/null || true)" != docker ]]; then
  exec "$@"
fi

# Avoid remote Docker contexts and always target the local Linux engine.
unset DOCKER_CONTEXT
export DOCKER_HOST="unix://$socket"

# A Docker group can be present in the account database but absent from the
# *current* SSH shell. Child processes cannot modify their parent's groups.
if [[ " $(id -nG 2>/dev/null || true) " == *" docker "* ]]; then
  exec "$@"
fi

account="$(id -un)"
if [[ " $(id -nG "$account" 2>/dev/null || true) " != *" docker "* ]]; then
  printf '[FAILED] %s is not authorized for the Docker group. Run bash start-neolabs-soc.sh to perform the supported one-time runtime setup.\n' "$account" >&2
  exit 2
fi

if [[ "${NEOLABS_DOCKER_GROUP_REFRESHED:-0}" == 1 ]]; then
  printf '[FAILED] Docker group refresh did not become effective; reconnect your SSH session.\n' >&2
  exit 2
fi
command -v sg >/dev/null 2>&1 || {
  printf '[FAILED] The sg utility is missing. Install util-linux or reconnect SSH after Docker group membership is applied.\n' >&2
  exit 2
}

printf '[NeoLabs] Refreshing Docker group for this command; the parent SSH shell remains unchanged.\n' >&2
printf -v quoted '%q ' "$@"
# sg is only invoked after checking that this account already belongs to the
# Docker group, so it must never prompt for a privileged group password.
exec sg docker -c "NEOLABS_DOCKER_GROUP_REFRESHED=1 exec ${quoted}"
