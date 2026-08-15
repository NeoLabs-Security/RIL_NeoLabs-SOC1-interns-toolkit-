#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATEWAY_URL="${NEOLABS_LAB_BASE_URL:-https://pg1wb0sklb.execute-api.us-east-1.amazonaws.com}"
ACTION="start"
HOST_MODE="linux"
NO_BROWSER=0

log() { printf '[NeoLabs] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAILED] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: internal/common/Start-NeoLabsSOC.sh [start|doctor|status|login] [--host linux|windows] [--no-browser]

This is the shared post-runtime SOC orchestrator. Platform launchers must first
prove/repair Docker, then hand off here. Students should normally run only the
root START-NEOLABS-SOC.cmd or ./start-neolabs-soc.sh entrypoint.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    start|doctor|status|login) ACTION="$1"; shift ;;
    --host)
      [[ $# -ge 2 ]] || fail '--host requires linux or windows'
      HOST_MODE="$2"; shift 2 ;;
    --no-browser) NO_BROWSER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown shared SOC argument: $1" ;;
  esac
done
[[ "$HOST_MODE" == "linux" || "$HOST_MODE" == "windows" ]] || fail '--host must be linux or windows'

cd "$ROOT_DIR"
for path in \
  tools/cli.py tools/__init__.py \
  wazuh-stack/scripts/compatibility-check.sh \
  wazuh-stack/scripts/ensure-prepared.sh \
  wazuh-stack/scripts/prepare-runtime-images.sh \
  wazuh-stack/scripts/validate-local-rules.py \
  wazuh-stack/scripts/verify-telemetry-pipeline.sh \
  wazuh-stack/scripts/repair-telemetry-pipeline.sh \
  wazuh-stack/scripts/telemetry-freshness.sh; do
  [[ -f "$path" ]] || fail "Required toolkit file is missing: $path"
done

export NEOLABS_LAB_BASE_URL="$GATEWAY_URL"

case "$ACTION" in
  login)
    exec python3 -m tools.cli login
    ;;
  status)
    exec python3 -m tools.cli status
    ;;
  doctor)
    exec python3 -m tools.cli doctor
    ;;
esac

log 'Checking SOC workstation compatibility...'
bash wazuh-stack/scripts/compatibility-check.sh || fail 'Compatibility check found a blocking issue.'

# This is the one preparation gate for both native Ubuntu/Debian and Windows/WSL.
# It generates private local credentials if needed, repairs the complete TLS set,
# and downloads/builds heavyweight images before any NeoLabs access-code login.
log 'Ensuring the complete Wazuh installation is prepared before authentication...'
bash wazuh-stack/scripts/ensure-prepared.sh || fail 'Wazuh preparation could not be completed.'

python3 wazuh-stack/scripts/validate-local-rules.py || fail 'NeoLabs custom Wazuh rules are invalid; startup stopped before container recovery.'

if [[ ! -f "${HOME}/.neolabs/soc/session.json" ]]; then
  log 'Sign in with your assigned pod number and private NeoLabs Access Code.'
  python3 -m tools.cli login || fail 'NeoLabs login failed.'
else
  log 'Checking your saved NeoLabs session...'
  if ! python3 -m tools.cli status; then
    warn 'Saved session is expired or no longer accepted; requesting a fresh login.'
    python3 -m tools.cli login || fail 'NeoLabs login failed.'
  fi
fi

# `neolabs connect` is the only stack-start authority at this layer. It enters
# wazuh-stack/scripts/start.sh, which performs the shared staged recovery and
# blocks until manager/indexer/dashboard/collector health is proven.
log 'Connecting authorised VCC telemetry and starting/reusing Wazuh...'
python3 -m tools.cli connect || fail 'NeoLabs connect/Wazuh startup failed.'

log 'Confirming current pod/scenario status...'
python3 -m tools.cli status || fail 'Final NeoLabs status check failed.'

log 'Proving that assigned-pod VCC telemetry is searchable in Wazuh...'
if ! bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --wait 180; then
  warn 'Telemetry is not searchable yet. Attempting one bounded local telemetry repair.'
  bash wazuh-stack/scripts/repair-telemetry-pipeline.sh || fail 'The local telemetry-to-indexer path could not be verified after one safe repair attempt.'
  bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --wait 90 || fail 'Assigned-pod telemetry is still not searchable after repair.'
fi

log 'Checking latest-event freshness...'
bash wazuh-stack/scripts/telemetry-freshness.sh || warn 'Telemetry is searchable but its freshness needs review; run the root launcher with doctor.'

# shellcheck disable=SC1091
source wazuh-stack/.env
dashboard_port="${WAZUH_DASHBOARD_PORT:-8443}"
[[ "$dashboard_port" =~ ^[0-9]{2,5}$ ]] || dashboard_port=8443
dashboard_url="https://127.0.0.1:${dashboard_port}"
open_url="$dashboard_url"
if [[ -f wazuh-stack/state/dashboard-objects.ready ]]; then
  open_url="${dashboard_url}/app/dashboards#/view/neolabs-night-watch"
fi

printf '\n\033[32mSOC WORKSTATION READY\033[0m\n'
printf 'Dashboard: %s\n' "$dashboard_url"
printf 'Username:  admin\n'
printf 'Password:  kept private in wazuh-stack/.env (WAZUH_INDEXER_PASSWORD).\n'
printf 'Verified: assigned-pod VCC telemetry is indexed and searchable in Wazuh.\n'
if [[ "$HOST_MODE" == "windows" ]]; then
  printf 'Windows launcher will copy the private dashboard password and open the browser.\n'
else
  printf 'Troubleshooting: ./start-neolabs-soc.sh doctor\n'
fi

if [[ "$HOST_MODE" == "linux" && $NO_BROWSER -eq 0 ]] && command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  log 'Opening the NeoLabs SOC dashboard...'
  xdg-open "$open_url" >/dev/null 2>&1 &
elif [[ "$HOST_MODE" == "linux" ]]; then
  printf '\nHeadless/remote Linux: Wazuh is running, but there is no local GUI browser to open.\n'
  printf 'From your own computer, forward the loopback dashboard over SSH:\n'
  printf '  ssh -L %s:127.0.0.1:%s <linux-user>@<server-address>\n' "$dashboard_port" "$dashboard_port"
  printf 'Then open %s in your local browser.\n' "$dashboard_url"
fi
