#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
STATE_DIR="${ROOT_DIR}/.state"
UPSTREAM_DIR="${STATE_DIR}/wazuh-docker"
GENERATED_DIR="${ROOT_DIR}/generated"
UPSTREAM_REPO="https://github.com/wazuh/wazuh-docker.git"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

for command_name in git docker python3; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "${command_name} is required."
done

docker compose version >/dev/null 2>&1 || fail "The Docker Compose plugin is unavailable."
[[ -f "${ENV_FILE}" ]] || fail "Missing .env. Run ./scripts/generate-local-secrets.sh first."

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

: "${WAZUH_VERSION:?WAZUH_VERSION is required}"
: "${WAZUH_DOCKER_TAG:?WAZUH_DOCKER_TAG is required}"
: "${WAZUH_DOCKER_COMMIT:?WAZUH_DOCKER_COMMIT is required}"
: "${WAZUH_INDEXER_PASSWORD:?WAZUH_INDEXER_PASSWORD is required}"
: "${WAZUH_DASHBOARD_PASSWORD:?WAZUH_DASHBOARD_PASSWORD is required}"

mkdir -p "${STATE_DIR}" "${GENERATED_DIR}"

if [[ ! -d "${UPSTREAM_DIR}/.git" ]]; then
  rm -rf "${UPSTREAM_DIR}"
  git clone --filter=blob:none --no-checkout "${UPSTREAM_REPO}" "${UPSTREAM_DIR}"
fi

git -C "${UPSTREAM_DIR}" fetch --force --depth 1 origin "refs/tags/${WAZUH_DOCKER_TAG}:refs/tags/${WAZUH_DOCKER_TAG}"
git -C "${UPSTREAM_DIR}" checkout --force --detach "refs/tags/${WAZUH_DOCKER_TAG}"

actual_commit="$(git -C "${UPSTREAM_DIR}" rev-parse HEAD)"
case "${actual_commit}" in
  "${WAZUH_DOCKER_COMMIT}"*) ;;
  *) fail "Upstream tag resolved to ${actual_commit}, expected ${WAZUH_DOCKER_COMMIT}. Review the release before proceeding." ;;
esac

rm -rf "${GENERATED_DIR}/config"
cp -a "${UPSTREAM_DIR}/single-node/config" "${GENERATED_DIR}/config"
cp "${UPSTREAM_DIR}/single-node/generate-indexer-certs.yml" "${GENERATED_DIR}/generate-indexer-certs.yml"

manager_config="${GENERATED_DIR}/config/wazuh_cluster/wazuh_manager.conf"
cat >> "${manager_config}" <<'XML'

<!-- NeoLabs VCC telemetry input. Generated locally; do not edit the upstream source copy. -->
<ossec_config>
  <localfile>
    <location>/var/ossec/logs/vcc/vcc-events.ndjson</location>
    <log_format>json</log_format>
    <label key="neolabs.source">vcc-pod-telemetry</label>
  </localfile>
</ossec_config>
XML

hash_password() {
  local password="$1"
  docker run --rm \
    -e NEOLABS_PASSWORD="${password}" \
    "wazuh/wazuh-indexer:${WAZUH_VERSION}" \
    bash -lc '/usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "$NEOLABS_PASSWORD"' \
    | awk '/^\$2[ayb]\$/{hash=$0} END{print hash}'
}

printf 'Generating local password hashes using the pinned Wazuh indexer image...\n'
admin_hash="$(hash_password "${WAZUH_INDEXER_PASSWORD}")"
dashboard_hash="$(hash_password "${WAZUH_DASHBOARD_PASSWORD}")"
[[ -n "${admin_hash}" ]] || fail "Could not generate the indexer administrator password hash."
[[ -n "${dashboard_hash}" ]] || fail "Could not generate the dashboard service password hash."

python3 - "${GENERATED_DIR}/config/wazuh_indexer/internal_users.yml" "${admin_hash}" "${dashboard_hash}" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

for username, new_hash in (("admin", sys.argv[2]), ("kibanaserver", sys.argv[3])):
    pattern = rf'({re.escape(username)}:\n  hash: ")[^"]+("\n)'
    text, count = re.subn(pattern, rf'\g<1>{new_hash}\g<2>', text, count=1)
    if count != 1:
        raise SystemExit(f"Could not update hash for {username}")

path.write_text(text, encoding="utf-8")
PY

rm -rf "${GENERATED_DIR}/config/wazuh_indexer_ssl_certs"
mkdir -p "${GENERATED_DIR}/config/wazuh_indexer_ssl_certs"
(
  cd "${GENERATED_DIR}"
  docker compose -f generate-indexer-certs.yml run --rm generator
)

# The upstream 4.14.x cert-generator can complete generation while its own
# final permission step emits errors on some hosts. Always apply and verify the
# permissions ourselves before declaring preparation complete.
bash "${ROOT_DIR}/scripts/repair-certificate-permissions.sh"

printf 'Prepared Wazuh %s configuration from verified upstream commit %s.\n' "${WAZUH_VERSION}" "${actual_commit}"
printf 'No Wazuh services were started. Run ./scripts/start.sh after preflight validation.\n'
