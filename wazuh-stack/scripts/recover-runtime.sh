#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

log() { printf '[NeoLabs Wazuh] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAILED] %s\n' "$*" >&2; exit 1; }

[[ -f .env ]] || fail "Missing wazuh-stack/.env. Run the approved NeoLabs launcher once so local credentials can be prepared."
# shellcheck disable=SC1091
set -a
source .env
set +a

: "${COMPOSE_PROJECT_NAME:=neolabs-soc1-wazuh}"

service_status() {
  local service="$1" id state health
  id="$(docker compose --env-file .env ps -q "$service" 2>/dev/null || true)"
  if [[ -z "$id" ]]; then
    printf 'missing'
    return 0
  fi
  state="$(docker inspect --format '{{.State.Status}}' "$id" 2>/dev/null || printf unknown)"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id" 2>/dev/null || printf unknown)"
  printf '%s/%s' "$state" "$health"
}

wait_healthy() {
  local service="$1" seconds="$2" deadline status
  deadline=$((SECONDS + seconds))
  while (( SECONDS < deadline )); do
    status="$(service_status "$service")"
    case "$status" in
      running/healthy|running/none) return 0 ;;
    esac
    sleep 5
  done
  return 1
}

runtime_fingerprint() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum \
      config/rules/neolabs_vcc_rules.xml \
      generated/config/wazuh_cluster/wazuh_manager.conf \
      2>/dev/null | sha256sum | awk '{print $1}'
  else
    printf 'unknown'
  fi
}

save_diagnostics() {
  local reason="$1" stamp path
  mkdir -p state/runtime-diagnostics
  stamp="$(date -u +%Y%m%d-%H%M%S)"
  path="state/runtime-diagnostics/wazuh-runtime-${stamp}.txt"
  {
    printf 'NeoLabs Wazuh runtime diagnostics - %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'Reason: %s\n\n' "$reason"
    printf '=== COMPOSE PS ===\n'
    docker compose --env-file .env ps 2>&1 || true
    for service in wazuh.manager wazuh.indexer wazuh.dashboard vcc.telemetry.collector; do
      printf '\n=== %s STATE ===\n' "$service"
      printf '%s\n' "$(service_status "$service")"
      printf '\n=== %s RECENT LOGS ===\n' "$service"
      docker compose --env-file .env logs --no-color --tail 180 "$service" 2>&1 || true
    done
    printf '\n=== DOCKER INFO SUMMARY ===\n'
    docker info --format 'Server={{.ServerVersion}} OSType={{.OSType}} Containers={{.Containers}} Running={{.ContainersRunning}} Paused={{.ContainersPaused}} Stopped={{.ContainersStopped}}' 2>&1 || true
    printf '\n=== HOST MEMORY ===\n'
    free -h 2>&1 || true
    printf '\n=== DISK ===\n'
    df -h . 2>&1 || true
    printf '\n=== VM.MAX_MAP_COUNT ===\n'
    cat /proc/sys/vm/max_map_count 2>&1 || true
  } >"$path"
  warn "Saved Wazuh runtime diagnostics: ${ROOT_DIR}/${path}"
}

recover_indexer() {
  log "Starting the Wazuh indexer first..."
  docker compose --env-file .env up -d --no-deps wazuh.indexer
  if wait_healthy wazuh.indexer 360; then
    ok "Wazuh indexer is healthy."
    return 0
  fi

  save_diagnostics "Wazuh indexer did not become healthy after normal start."
  warn "Indexer is unhealthy. Restarting it once while preserving all index data."
  docker compose --env-file .env restart wazuh.indexer >/dev/null 2>&1 || true
  if wait_healthy wazuh.indexer 180; then
    ok "Wazuh indexer recovered after restart."
    return 0
  fi

  warn "Indexer still is not healthy. Recreating only its container; the persistent wazuh-indexer-data volume is preserved."
  docker compose --env-file .env up -d --force-recreate --no-deps wazuh.indexer
  if wait_healthy wazuh.indexer 240; then
    ok "Wazuh indexer recovered after container recreation."
    return 0
  fi

  save_diagnostics "Wazuh indexer did not recover after restart/container recreation."
  return 1
}

recover_manager() {
  local before fingerprint previous_fingerprint
  before="$(service_status wazuh.manager)"
  fingerprint="$(runtime_fingerprint)"
  previous_fingerprint="$(cat state/wazuh-runtime-fingerprint 2>/dev/null || true)"

  log "Starting the Wazuh manager independently so an unhealthy manager cannot block the dashboard dependency chain..."
  docker compose --env-file .env up -d --no-deps wazuh.manager

  # Fast subsequent-run path: if the manager was already healthy and the
  # bind-mounted NeoLabs rule/config fingerprint did not change, reuse it.
  if [[ "$before" == "running/healthy" && -n "$previous_fingerprint" && "$fingerprint" == "$previous_fingerprint" ]]; then
    if wait_healthy wazuh.manager 30; then
      ok "Existing Wazuh manager is healthy and current; reusing it without a restart."
      return 0
    fi
  fi

  # New/stopped/unhealthy containers, or a toolkit pull that changed rules,
  # receive one manager restart so wazuh-analysisd loads the current config.
  docker compose --env-file .env restart wazuh.manager >/dev/null 2>&1 || true
  if wait_healthy wazuh.manager 240; then
    printf '%s\n' "$fingerprint" > state/wazuh-runtime-fingerprint
    ok "Wazuh manager is healthy."
    return 0
  fi

  save_diagnostics "Wazuh manager remained unhealthy after normal start/restart."
  warn "Manager is still unhealthy. Recreating only the manager container; indexer data and pod telemetry are preserved."
  docker compose --env-file .env up -d --force-recreate --no-deps wazuh.manager
  if wait_healthy wazuh.manager 180; then
    printf '%s\n' "$fingerprint" > state/wazuh-runtime-fingerprint
    ok "Wazuh manager recovered after container recreation."
    return 0
  fi

  save_diagnostics "Wazuh manager remained unhealthy after container recreation."
  warn "Applying one final bounded manager-configuration repair. Only the Wazuh manager configuration volume will be rebuilt; indexer data, telemetry, enrolment state and private VCC credentials are preserved."
  docker compose --env-file .env stop wazuh.manager >/dev/null 2>&1 || true
  docker compose --env-file .env rm -f wazuh.manager >/dev/null 2>&1 || true
  docker volume rm "${COMPOSE_PROJECT_NAME}_wazuh_etc" >/dev/null 2>&1 || true
  docker compose --env-file .env up -d --no-deps wazuh.manager
  if wait_healthy wazuh.manager 240; then
    printf '%s\n' "$fingerprint" > state/wazuh-runtime-fingerprint
    ok "Wazuh manager recovered after rebuilding its local configuration volume."
    return 0
  fi

  save_diagnostics "Wazuh manager did not recover after all bounded local repairs."
  return 1
}

log "Validating Docker Compose before runtime recovery..."
docker compose --env-file .env config --quiet

if ! recover_indexer; then
  fail "Wazuh indexer could not be recovered automatically. Its data volume was deliberately preserved. Check the diagnostic file above; low RAM/disk or damaged index data requires operator review."
fi

if ! recover_manager; then
  fail "Wazuh manager could not be recovered automatically. Use the diagnostic file above; do not delete the indexer or telemetry volumes manually."
fi

log "Starting/rebuilding the NeoLabs telemetry collector..."
docker compose --env-file .env up -d --build --no-deps vcc.telemetry.collector

log "Starting the Wazuh dashboard only after manager and indexer health is proven..."
docker compose --env-file .env up -d --no-deps wazuh.dashboard
if ! wait_healthy wazuh.dashboard 360; then
  save_diagnostics "Wazuh dashboard did not become healthy after manager/indexer recovery."
  warn "Dashboard did not become healthy on the first attempt. Recreating only the dashboard container."
  docker compose --env-file .env up -d --force-recreate --no-deps wazuh.dashboard
  if ! wait_healthy wazuh.dashboard 240; then
    save_diagnostics "Wazuh dashboard did not recover after container recreation."
    fail "Wazuh dashboard could not be recovered automatically."
  fi
fi
ok "Wazuh dashboard is healthy."

if ! wait_healthy vcc.telemetry.collector 150; then
  save_diagnostics "NeoLabs telemetry collector did not become healthy."
  warn "Telemetry collector is not healthy yet. Recreating it once without changing pod credentials or telemetry history."
  docker compose --env-file .env up -d --build --force-recreate --no-deps vcc.telemetry.collector
  if ! wait_healthy vcc.telemetry.collector 150; then
    save_diagnostics "NeoLabs telemetry collector did not recover after recreation."
    fail "NeoLabs telemetry collector could not be recovered automatically."
  fi
fi
ok "NeoLabs telemetry collector is healthy."

printf 'Wazuh core services recovered/started successfully.\n'
