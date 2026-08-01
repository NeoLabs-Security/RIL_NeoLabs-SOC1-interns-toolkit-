#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: verify-backup.sh BACKUP_DIRECTORY"
}

[[ $# -eq 1 ]] || { usage >&2; exit 2; }
BACKUP_DIR="$(cd "$1" && pwd)"

for required in manifest.env SHA256SUMS RESTORE_NOTICE.txt volumes; do
  [[ -e "${BACKUP_DIR}/${required}" ]] || {
    echo "Backup is incomplete: missing ${required}" >&2
    exit 1
  }
done

grep -qx 'format_version=1' "${BACKUP_DIR}/manifest.env" || {
  echo "Unsupported or missing backup format version." >&2
  exit 1
}

grep -qx 'credential_material_included=false' "${BACKUP_DIR}/manifest.env" || {
  echo "Backup credential policy marker is missing or unsafe." >&2
  exit 1
}

(
  cd "${BACKUP_DIR}"
  sha256sum --check --strict SHA256SUMS
)

archive_count="$(find "${BACKUP_DIR}/volumes" -type f -name '*.tar.gz' | wc -l | tr -d ' ')"
[[ "${archive_count}" -gt 0 ]] || {
  echo "Backup contains no volume archives." >&2
  exit 1
}

while IFS= read -r -d '' archive; do
  tar -tzf "${archive}" >/dev/null
  if tar -tzf "${archive}" | grep -Eq '(^|/)(client\.key|bootstrap-token|enrolment\.json|\.env)$'; then
    echo "Credential-like material was found in ${archive}." >&2
    exit 1
  fi
done < <(find "${BACKUP_DIR}/volumes" -type f -name '*.tar.gz' -print0)

echo "Backup integrity verified: ${BACKUP_DIR}"
