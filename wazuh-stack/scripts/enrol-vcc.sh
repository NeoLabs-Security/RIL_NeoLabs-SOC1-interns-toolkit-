#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

[[ -f "${ENV_FILE}" ]] || { printf 'ERROR: Missing %s.\n' "${ENV_FILE}" >&2; exit 1; }

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

[[ -n "${VCC_ENROLMENT_BASE_URL:-}" ]] || { printf 'ERROR: VCC_ENROLMENT_BASE_URL is empty.\n' >&2; exit 1; }

ca_path="${VCC_ENROLMENT_CA_CERT_PATH:-}"
if [[ -n "${ca_path}" ]]; then
  if [[ "${ca_path}" != /* ]]; then
    ca_path="${ROOT_DIR}/${ca_path#./}"
  fi
  [[ -f "${ca_path}" ]] || { printf 'ERROR: Enrolment CA certificate not found: %s\n' "${ca_path}" >&2; exit 1; }
  export SSL_CERT_FILE="${ca_path}"
fi

exec python3 "${ROOT_DIR}/scripts/enrol-vcc.py" "$@"
