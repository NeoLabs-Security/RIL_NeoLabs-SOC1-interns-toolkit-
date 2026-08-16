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
  wazuh-stack/scripts/configure-dashboard-access.sh \
  wazuh-stack/scripts/prepare-runtime-images.sh \
  wazuh-stack/scripts/validate-local-rules.py \
  wazuh-stack/scripts/verify-dashboard-api.sh \
  wazuh-stack/scripts/verify-telemetry-pipeline.sh \
  wazuh-stack/scripts/repair-telemetry-pipeline.sh \
  wazuh-stack/scripts/telemetry-freshness.sh; do
  [[ -f "$path" ]] || fail "Required toolkit file is missing: $path"
done

# A repository copied from Windows or an older checkout can lose executable bits.
# Normalise helper permissions even when the platform runtime is already healthy
# and therefore skipped its AutoFix path.
find internal/common wazuh-stack/scripts -type f -name '*.sh' -exec chmod u+x {} + 2>/dev/null || true

export NEOLABS_LAB_BASE_URL="$GATEWAY_URL"
export NEOLABS_HOST_MODE="$HOST_MODE"

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

# Resolve the dashboard exposure profile before Compose starts. Headless native
# Linux servers publish 8443 on the host; Windows and desktop workstations stay
# loopback-only. Cloud/network firewall policy remains outside the container.
bash wazuh-stack/scripts/configure-dashboard-access.sh "$HOST_MODE" || fail 'Dashboard access profile could not be configured.'

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
# blocks until manager/indexer/dashboard/collector health and dashboard->manager
# API authentication are proven.
log 'Connecting authorised VCC telemetry and starting/reusing Wazuh...'
python3 -m tools.cli connect || fail 'NeoLabs connect/Wazuh startup failed.'

# shellcheck disable=SC1091
source wazuh-stack/.env
dashboard_port="${WAZUH_DASHBOARD_PORT:-8443}"
[[ "$dashboard_port" =~ ^[0-9]{2,5}$ ]] || dashboard_port=8443
dashboard_bind="${WAZUH_DASHBOARD_BIND:-127.0.0.1}"
dashboard_url="https://127.0.0.1:${dashboard_port}"
open_url="$dashboard_url"
if [[ -f wazuh-stack/state/dashboard-objects.ready ]]; then
  open_url="${dashboard_url}/app/dashboards#/view/neolabs-night-watch"
fi

linux_private_ip() {
  hostname -I 2>/dev/null | tr ' ' '\n' | grep -Ev '^(127\.|::1$|$)' | head -n1 || true
}

ec2_public_ip() {
  command -v curl >/dev/null 2>&1 || return 0
  local token=''
  token="$(curl -fsS --connect-timeout 1 --max-time 2 -X PUT \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' \
    http://169.254.169.254/latest/api/token 2>/dev/null || true)"
  [[ -n "$token" ]] || return 0
  curl -fsS --connect-timeout 1 --max-time 2 \
    -H "X-aws-ec2-metadata-token: $token" \
    http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true
}

printf '\n\033[32mWAZUH DASHBOARD READY\033[0m\n'
printf 'Local URL:  %s\n' "$dashboard_url"
if [[ "$HOST_MODE" == linux && "$dashboard_bind" == 0.0.0.0 ]]; then
  private_ip="$(linux_private_ip)"
  public_ip="$(ec2_public_ip)"
  [[ -z "$private_ip" ]] || printf 'Server URL: https://%s:%s\n' "$private_ip" "$dashboard_port"
  [[ -z "$public_ip" ]] || printf 'Public URL: https://%s:%s\n' "$public_ip" "$dashboard_port"
  printf 'Remote access requires the host/cloud firewall to allow TCP %s from the intern\x27s approved source IP.\n' "$dashboard_port"
fi
printf 'Username:   admin\n'
if [[ "$HOST_MODE" == linux && -t 1 && "${NEOLABS_HIDE_DASHBOARD_PASSWORD:-0}" != 1 ]]; then
  # Requested cohort UX: the local Wazuh login is available as soon as the stack
  # is healthy; it is no longer gated on whether the VCC server has emitted an
  # event. Never write this value to repository/runtime diagnostic files.
  printf 'Password:   %s\n' "${WAZUH_INDEXER_PASSWORD}"
  printf '             (private local credential; do not post/share terminal screenshots containing it)\n'
else
  printf 'Password:   kept private in wazuh-stack/.env (Windows copies it to the clipboard).\n'
fi
printf '[OK] Manager, indexer, dashboard, collector and dashboard API connector are healthy.\n'

log 'Confirming current pod/scenario status...'
python3 -m tools.cli status || fail 'Final NeoLabs status check failed.'

telemetry_ready=0
log 'Checking whether assigned-pod VCC telemetry is already searchable in Wazuh...'
telemetry_rc=0
bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --wait 90 || telemetry_rc=$?
case "$telemetry_rc" in
  0)
    telemetry_ready=1
    ;;
  3)
    warn 'The local Wazuh path is healthy, but the VCC server has not emitted an assigned-pod event yet. The dashboard remains fully usable while telemetry is pending.'
    ;;
  2)
    fail 'NeoLabs custom rules failed the live Wazuh rule-engine verification.'
    ;;
  *)
    warn 'Telemetry exists or should exist, but the local telemetry-to-indexer path is not healthy yet. Attempting one bounded repair.'
    repair_rc=0
    bash wazuh-stack/scripts/repair-telemetry-pipeline.sh || repair_rc=$?
    if (( repair_rc != 0 )); then
      fail 'The local telemetry-to-indexer path could not be repaired safely.'
    fi
    telemetry_rc=0
    bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --wait 90 || telemetry_rc=$?
    case "$telemetry_rc" in
      0) telemetry_ready=1 ;;
      3) warn 'Local repair succeeded; the stack is waiting only for the first/current VCC pod event.' ;;
      *) fail 'Assigned-pod telemetry is still not searchable after local repair.' ;;
    esac
    ;;
esac

if (( telemetry_ready )); then
  log 'Checking latest-event freshness...'
  bash wazuh-stack/scripts/telemetry-freshness.sh || warn 'Telemetry is searchable but its freshness needs review; run the root launcher with doctor.'
fi

printf '\n'
if (( telemetry_ready )); then
  printf '\033[32mSOC WORKSTATION READY\033[0m\n'
  printf 'Verified: assigned-pod VCC telemetry is indexed and searchable in Wazuh.\n'
else
  printf '\033[33mSOC WORKSTATION READY - TELEMETRY PENDING\033[0m\n'
  printf 'Wazuh is operational; no assigned-pod VCC event is available to verify yet.\n'
fi
if [[ "$HOST_MODE" == windows ]]; then
  printf 'Windows launcher will copy the private dashboard password and open the browser.\n'
else
  printf 'Troubleshooting: ./start-neolabs-soc.sh doctor\n'
fi

if [[ "$HOST_MODE" == linux && $NO_BROWSER -eq 0 ]] && command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  log 'Opening the NeoLabs SOC dashboard...'
  xdg-open "$open_url" >/dev/null 2>&1 &
elif [[ "$HOST_MODE" == linux && "$dashboard_bind" != 0.0.0.0 ]]; then
  printf '\nHeadless/remote Linux loopback profile: forward the dashboard over SSH:\n'
  printf '  ssh -L %s:127.0.0.1:%s <linux-user>@<server-address>\n' "$dashboard_port" "$dashboard_port"
  printf 'Then open %s in your local browser.\n' "$dashboard_url"
fi
