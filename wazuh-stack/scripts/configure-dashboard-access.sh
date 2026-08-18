#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

host_mode="${1:-linux}"
[[ "$host_mode" == linux || "$host_mode" == windows ]] || { printf 'ERROR: host mode must be linux or windows.\n' >&2; exit 2; }
[[ -f .env ]] || { printf 'ERROR: Missing wazuh-stack/.env.\n' >&2; exit 2; }
# shellcheck disable=SC1091
set -a
source .env
set +a

requested="${NEOLABS_DASHBOARD_EXPOSURE:-auto}"
requested="${requested,,}"
case "$requested" in auto|loopback|server) ;; *) requested=auto ;; esac

resolved=loopback
if [[ "$host_mode" == linux ]]; then
  case "$requested" in
    server) resolved=server ;;
    loopback) resolved=loopback ;;
    auto)
      if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && ! grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null; then
        resolved=server
      fi
      ;;
  esac
elif [[ "$requested" == server ]]; then
  printf '[WARN] Remote dashboard publishing is not enabled by the Windows workstation profile; using loopback.\n' >&2
fi

if [[ "$resolved" == server ]]; then bind=0.0.0.0; else bind=127.0.0.1; fi

python3 - .env "$requested" "$bind" <<'PY'
from pathlib import Path
import sys
path=Path(sys.argv[1])
updates={
    'NEOLABS_DASHBOARD_EXPOSURE': sys.argv[2],
    'WAZUH_DASHBOARD_BIND': sys.argv[3],
}
lines=path.read_text(encoding='utf-8').splitlines()
out=[]; seen=set()
for line in lines:
    if '=' in line and not line.lstrip().startswith('#'):
        key=line.split('=',1)[0].strip()
        if key in updates:
            out.append(f'{key}={updates[key]}'); seen.add(key); continue
    out.append(line)
for key,value in updates.items():
    if key not in seen: out.append(f'{key}={value}')
path.write_text('\n'.join(out)+'\n', encoding='utf-8')
PY
chmod 600 .env 2>/dev/null || true
mkdir -p state
printf '%s\n' "$resolved" > state/dashboard-access.mode
chmod 600 state/dashboard-access.mode 2>/dev/null || true

if [[ "$resolved" == server ]]; then
  printf '[OK] Headless Linux server profile: Wazuh dashboard will publish on host TCP %s.\n' "${WAZUH_DASHBOARD_PORT:-8443}"
else
  printf '[OK] Workstation profile: Wazuh dashboard remains loopback-only.\n'
fi
