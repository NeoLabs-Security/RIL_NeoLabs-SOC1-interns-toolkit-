#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[[ -f .env ]] || { printf 'ERROR: Missing wazuh-stack/.env.\n' >&2; exit 1; }

normalize_path() {
  local value="$1"
  # Docker Desktop reports Windows bind sources through /run/desktop/mnt/host/X
  # while WSL sees the same files under /mnt/x. Normalize those forms before
  # deciding that a container is attached to an old checkout.
  if [[ "$value" =~ ^/run/desktop/mnt/host/([A-Za-z])/(.*)$ ]]; then
    printf '/mnt/%s/%s\n' "${BASH_REMATCH[1],,}" "${BASH_REMATCH[2]}"
    return
  fi
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$value" 2>/dev/null || printf '%s\n' "$value"
  else
    printf '%s\n' "$value"
  fi
}

current_root="$(normalize_path "$ROOT_DIR")"
services=(wazuh.indexer wazuh.manager wazuh.dashboard vcc.telemetry.collector)
repaired=0

for service in "${services[@]}"; do
  id="$(docker compose --env-file .env ps -aq "$service" 2>/dev/null | head -n1 || true)"
  [[ -n "$id" ]] || continue

  stale=0
  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    normalized="$(normalize_path "$source")"
    case "$normalized" in
      "$current_root"|"$current_root"/*) ;;
      *) stale=1; break ;;
    esac
  done < <(docker inspect --format '{{range .Mounts}}{{if eq .Type "bind"}}{{println .Source}}{{end}}{{end}}' "$id" 2>/dev/null || true)

  if (( stale )); then
    printf '[WARN] %s is still bound to a previous toolkit directory. Recreating only that container; named volumes and data are preserved.\n' "$service" >&2
    docker compose --env-file .env rm -sf "$service" >/dev/null 2>&1 || true
    repaired=$((repaired + 1))
  fi
done

if (( repaired == 0 )); then
  printf '[OK] Existing Wazuh containers use the current toolkit bind-mount path.\n'
else
  printf '[OK] Removed %s stale-path container(s); the normal recovery path will recreate them from this checkout.\n' "$repaired"
fi
