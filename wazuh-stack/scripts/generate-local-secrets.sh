#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"
ENV_FILE="${ROOT_DIR}/.env"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

command -v openssl >/dev/null 2>&1 || fail "OpenSSL is required to generate local secrets."
[[ -f "${ENV_EXAMPLE}" ]] || fail "Missing ${ENV_EXAMPLE}."

if [[ -f "${ENV_FILE}" ]]; then
  fail "${ENV_FILE} already exists. Remove it only after backing up any required local configuration."
fi

cp "${ENV_EXAMPLE}" "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

indexer_password="$(openssl rand -hex 24)"
# Wazuh server API passwords are policy-checked separately from indexer users:
# include uppercase, lowercase, a number and a symbol while retaining high entropy.
api_password="Na7!$(openssl rand -hex 20)"
dashboard_password="$(openssl rand -hex 24)"

python3 - "${ENV_FILE}" "${indexer_password}" "${api_password}" "${dashboard_password}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
replacements = {
    "WAZUH_INDEXER_PASSWORD=CHANGE_ME_GENERATE_STRONG_SECRET": f"WAZUH_INDEXER_PASSWORD={sys.argv[2]}",
    "WAZUH_API_PASSWORD=CHANGE_ME_GENERATE_STRONG_SECRET": f"WAZUH_API_PASSWORD={sys.argv[3]}",
    "WAZUH_DASHBOARD_PASSWORD=CHANGE_ME_GENERATE_STRONG_SECRET": f"WAZUH_DASHBOARD_PASSWORD={sys.argv[4]}",
}
text = path.read_text(encoding="utf-8")
for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f"Expected placeholder not found: {old}")
    text = text.replace(old, new)
path.write_text(text, encoding="utf-8")
PY

install -d -m 700 "${ROOT_DIR}/secrets/vcc" "${ROOT_DIR}/state" "${ROOT_DIR}/generated"

if [[ ! -f "${ROOT_DIR}/secrets/vcc/installation-id" ]]; then
  openssl rand -hex 16 > "${ROOT_DIR}/secrets/vcc/installation-id"
  chmod 600 "${ROOT_DIR}/secrets/vcc/installation-id"
fi

printf 'Created %s with generated local passwords.\n' "${ENV_FILE}"
printf 'The values were not printed. Keep the file private and do not commit it.\n'
