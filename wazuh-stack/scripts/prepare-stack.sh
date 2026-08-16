#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
STATE_DIR="${ROOT_DIR}/.state"
UPSTREAM_DIR="${STATE_DIR}/wazuh-docker"
GENERATED_DIR="${ROOT_DIR}/generated"
UPSTREAM_REPO="https://github.com/wazuh/wazuh-docker.git"

fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

for command_name in git docker python3; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required."
done

docker compose version >/dev/null 2>&1 || fail 'The Docker Compose plugin is unavailable.'
[[ -f "$ENV_FILE" ]] || fail 'Missing .env. Run ./scripts/generate-local-secrets.sh first.'

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

: "${WAZUH_VERSION:?WAZUH_VERSION is required}"
: "${WAZUH_DOCKER_TAG:?WAZUH_DOCKER_TAG is required}"
: "${WAZUH_DOCKER_COMMIT:?WAZUH_DOCKER_COMMIT is required}"
: "${WAZUH_INDEXER_PASSWORD:?WAZUH_INDEXER_PASSWORD is required}"
: "${WAZUH_API_PASSWORD:?WAZUH_API_PASSWORD is required}"
: "${WAZUH_DASHBOARD_PASSWORD:?WAZUH_DASHBOARD_PASSWORD is required}"

mkdir -p "$STATE_DIR" "$GENERATED_DIR"

if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
  rm -rf "$UPSTREAM_DIR"
  git clone --filter=blob:none --no-checkout "$UPSTREAM_REPO" "$UPSTREAM_DIR"
fi

git -C "$UPSTREAM_DIR" fetch --force --depth 1 origin "refs/tags/${WAZUH_DOCKER_TAG}:refs/tags/${WAZUH_DOCKER_TAG}"
git -C "$UPSTREAM_DIR" checkout --force --detach "refs/tags/${WAZUH_DOCKER_TAG}"

actual_commit="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
case "$actual_commit" in
  "${WAZUH_DOCKER_COMMIT}"*) ;;
  *) fail "Upstream tag resolved to ${actual_commit}, expected ${WAZUH_DOCKER_COMMIT}. Review the release before proceeding." ;;
esac

rm -rf "$GENERATED_DIR/config"
cp -a "$UPSTREAM_DIR/single-node/config" "$GENERATED_DIR/config"
cp "$UPSTREAM_DIR/single-node/generate-indexer-certs.yml" "$GENERATED_DIR/generate-indexer-certs.yml"

manager_config="$GENERATED_DIR/config/wazuh_cluster/wazuh_manager.conf"
cat >> "$manager_config" <<'XML'

<!-- NeoLabs VCC telemetry input. Generated locally; do not edit the upstream source copy. -->
<ossec_config>
  <localfile>
    <location>/var/ossec/logs/vcc/vcc-events.ndjson</location>
    <log_format>json</log_format>
    <label key="neolabs.source">vcc-pod-telemetry</label>
  </localfile>
</ossec_config>
XML

# Render both OpenSearch internal-user hashes and the Wazuh dashboard -> manager
# API credential from the same local .env. This prevents the upstream default
# wazuh-wui password from surviving inside generated/wazuh.yml.
bash "$ROOT_DIR/scripts/render-runtime-credentials.sh"

rm -rf "$GENERATED_DIR/config/wazuh_indexer_ssl_certs"
mkdir -p "$GENERATED_DIR/config/wazuh_indexer_ssl_certs"
(
  cd "$GENERATED_DIR"
  docker compose -f generate-indexer-certs.yml run --rm generator
)

# Wazuh 4.14.x can generate the files successfully and still fail in its own
# final permission step. NeoLabs independently normalises and verifies them.
bash "$ROOT_DIR/scripts/repair-certificate-permissions.sh"

# Preparation is not complete until the heavy runtime images and the local
# collector are available. This keeps first-use downloads before pod login.
bash "$ROOT_DIR/scripts/prepare-runtime-images.sh"

printf 'Prepared Wazuh %s configuration and runtime images from verified upstream commit %s.\n' "$WAZUH_VERSION" "$actual_commit"
printf 'No Wazuh services were started. The NeoLabs launcher will authenticate next.\n'
