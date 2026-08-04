#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

[[ -f .env ]] || { printf 'ERROR: Missing .env.\n' >&2; exit 1; }
docker compose --env-file .env stop
printf 'NeoLabs Wazuh services stopped. Persistent volumes and enrolment credentials were retained.\n'
