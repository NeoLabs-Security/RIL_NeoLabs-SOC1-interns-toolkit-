#!/usr/bin/env python3
"""Exchange a short-lived VCC bootstrap token for a pod-scoped client certificate.

The request never contains a learner-selected pod. The VCC control plane derives pod
scope from the operator-managed assignment linked to the bootstrap token.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import ssl
import stat
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

POD_PATTERN = re.compile(r"^pod-[0-9]{2}$")
REQUIRED_RESPONSE_FIELDS = {
    "assigned_pod",
    "certificate_pem",
    "ca_certificate_pem",
    "telemetry_endpoint",
    "credential_id",
    "expires_at",
}


def fail(message: str) -> "NoReturn":
    raise SystemExit(f"ERROR: {message}")


def parse_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def atomic_write(path: Path, content: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, delete=False
    ) as temporary:
        temporary.write(content)
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)
    os.chmod(temporary_path, mode)
    temporary_path.replace(path)


def require_private_file(path: Path, description: str) -> None:
    if not path.is_file():
        fail(f"Missing {description}: {path}")
    mode = stat.S_IMODE(path.stat().st_mode)
    if mode & 0o077:
        fail(f"{description} permissions are too broad ({mode:o}); run chmod 600 {path}")


def validate_https_url(value: str, name: str) -> str:
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme != "https" or not parsed.netloc:
        fail(f"{name} must be an absolute HTTPS URL")
    if parsed.username or parsed.password or parsed.fragment:
        fail(f"{name} must not contain embedded credentials or a fragment")
    return value


def generate_key_and_csr(key_path: Path, csr_path: Path, installation_id: str) -> None:
    key_path.parent.mkdir(parents=True, exist_ok=True)
    subject = f"/CN=neolabs-soc-{installation_id[:24]}"
    subprocess.run(
        [
            "openssl",
            "req",
            "-new",
            "-newkey",
            "ec",
            "-pkeyopt",
            "ec_paramgen_curve:prime256v1",
            "-nodes",
            "-keyout",
            str(key_path),
            "-out",
            str(csr_path),
            "-subj",
            subject,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    os.chmod(key_path, 0o600)
    os.chmod(csr_path, 0o600)


def exchange(
    endpoint: str,
    token: str,
    installation_id: str,
    csr_pem: str,
) -> dict[str, Any]:
    payload = json.dumps(
        {
            "bootstrap_token": token,
            "installation_id": installation_id,
            "certificate_signing_request_pem": csr_pem,
            "client": {
                "name": "neolabs-soc-wazuh-toolkit",
                "protocol_version": "1.0",
            },
        }
    ).encode("utf-8")

    request = urllib.request.Request(
        endpoint,
        data=payload,
        method="POST",
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "NeoLabs-SOC-Enrolment-Client/0.1.0",
        },
    )
    context = ssl.create_default_context()
    try:
        with urllib.request.urlopen(request, context=context, timeout=30) as response:
            body = response.read(1024 * 1024 + 1)
    except urllib.error.HTTPError as exc:
        if exc.code in (400, 401, 403, 409, 410, 422):
            fail("The bootstrap token was rejected, expired, already used or does not match an active assignment")
        fail(f"The enrolment service returned HTTP {exc.code}")
    except (urllib.error.URLError, TimeoutError, ssl.SSLError):
        fail("Could not establish a verified HTTPS connection to the enrolment service")

    if len(body) > 1024 * 1024:
        fail("The enrolment response exceeded the allowed size")
    try:
        result = json.loads(body)
    except json.JSONDecodeError:
        fail("The enrolment service returned invalid JSON")
    if not isinstance(result, dict):
        fail("The enrolment response must be a JSON object")
    missing = sorted(REQUIRED_RESPONSE_FIELDS.difference(result))
    if missing:
        fail(f"The enrolment response omitted required fields: {', '.join(missing)}")
    return result


def update_env(path: Path, updates: dict[str, str]) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    seen: set[str] = set()
    output: list[str] = []
    for line in lines:
        if "=" in line and not line.lstrip().startswith("#"):
            key = line.split("=", 1)[0].strip()
            if key in updates:
                output.append(f"{key}={updates[key]}")
                seen.add(key)
                continue
        output.append(line)
    for key, value in updates.items():
        if key not in seen:
            output.append(f"{key}={value}")
    atomic_write(path, "\n".join(output) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Exchange a VCC bootstrap token for a pod-scoped telemetry credential."
    )
    parser.add_argument("--token-file", required=True, type=Path)
    parser.add_argument(
        "--replace-existing",
        action="store_true",
        help="Replace an existing local certificate after operator revocation or reassignment.",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    env_path = root / ".env"
    require_private_file(env_path, "Wazuh environment file")
    require_private_file(args.token_file, "bootstrap token file")

    env = parse_env(env_path)
    base_url = validate_https_url(env.get("VCC_ENROLMENT_BASE_URL", ""), "VCC_ENROLMENT_BASE_URL")
    endpoint = urllib.parse.urljoin(base_url.rstrip("/") + "/", "api/v1/soc/enrolments/exchange")

    installation_path = root / env.get(
        "VCC_INSTALLATION_ID_PATH", "./secrets/vcc/installation-id"
    ).removeprefix("./")
    require_private_file(installation_path, "installation identifier")
    installation_id = installation_path.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"[0-9a-f]{32}", installation_id):
        fail("The installation identifier has an unexpected format")

    secret_dir = root / "secrets" / "vcc"
    key_path = secret_dir / "client.key"
    cert_path = secret_dir / "client.crt"
    ca_path = secret_dir / "ca.crt"
    state_path = root / "state" / "enrolment.json"
    assigned_pod_path = root / "state" / "assigned-pod"

    existing = [path for path in (key_path, cert_path, ca_path, state_path) if path.exists()]
    if existing and not args.replace_existing:
        fail("A local enrolment already exists. Use operator-approved revocation before replacement")

    token = args.token_file.read_text(encoding="utf-8").strip()
    if len(token) < 32 or len(token) > 512 or any(character.isspace() for character in token):
        fail("The bootstrap token has an unexpected format")

    secret_dir.mkdir(parents=True, exist_ok=True)
    os.chmod(secret_dir, 0o700)
    with tempfile.TemporaryDirectory(dir=secret_dir) as temporary_directory:
        temporary = Path(temporary_directory)
        temporary_key = temporary / "client.key"
        csr_path = temporary / "client.csr"
        generate_key_and_csr(temporary_key, csr_path, installation_id)
        result = exchange(
            endpoint,
            token,
            installation_id,
            csr_path.read_text(encoding="utf-8"),
        )

        assigned_pod = str(result["assigned_pod"])
        if not POD_PATTERN.fullmatch(assigned_pod):
            fail("The server returned an invalid assigned pod identifier")
        telemetry_endpoint = validate_https_url(
            str(result["telemetry_endpoint"]), "telemetry endpoint"
        )
        certificate = str(result["certificate_pem"])
        ca_certificate = str(result["ca_certificate_pem"])
        if "BEGIN CERTIFICATE" not in certificate or "BEGIN CERTIFICATE" not in ca_certificate:
            fail("The server returned an invalid certificate chain")

        atomic_write(key_path, temporary_key.read_text(encoding="utf-8"))
        atomic_write(cert_path, certificate.rstrip() + "\n")
        atomic_write(ca_path, ca_certificate.rstrip() + "\n")
        atomic_write(assigned_pod_path, assigned_pod + "\n")
        atomic_write(
            state_path,
            json.dumps(
                {
                    "assigned_pod": assigned_pod,
                    "credential_id": str(result["credential_id"]),
                    "expires_at": str(result["expires_at"]),
                    "telemetry_endpoint": telemetry_endpoint,
                    "installation_id": installation_id,
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
        )

    update_env(
        env_path,
        {
            "POD_LABEL": assigned_pod,
            "VCC_TELEMETRY_ENDPOINT": telemetry_endpoint,
        },
    )

    try:
        args.token_file.write_text("CONSUMED\n", encoding="utf-8")
        os.chmod(args.token_file, 0o600)
    except OSError:
        pass

    print(f"Enrolment completed for the server-issued scope {assigned_pod}.")
    print("The credential values were not displayed. Restart the collector to begin polling.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
