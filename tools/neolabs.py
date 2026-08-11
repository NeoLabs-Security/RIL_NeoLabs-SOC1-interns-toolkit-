#!/usr/bin/env python3
"""NeoLabs internship pod access client.

This client never chooses its own lab scope. It authenticates to the NeoLabs
broker and writes the server-returned manifest to an ignored runtime directory.
"""
from __future__ import annotations

import argparse
import getpass
import json
import os
import re
import secrets
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

TRACK = "SOC"
TRACK_DIR = "soc"
POD_RE = re.compile(r"^pod-[0-9]{2}$")
ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "runtime"
RUNTIME_MANIFEST = RUNTIME_DIR / "access-manifest.json"
HOME_STATE = Path.home() / ".neolabs" / TRACK_DIR
SESSION_FILE = HOME_STATE / "session.json"
INSTALLATION_FILE = HOME_STATE / "installation-id"


def fail(message: str, code: int = 2) -> "NoReturn":
    raise SystemExit(f"ERROR: {message}")


def atomic_write(path: Path, text: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as temp:
        temp.write(text)
        temp.flush()
        os.fsync(temp.fileno())
        tmp = Path(temp.name)
    try:
        os.chmod(tmp, mode)
    except OSError:
        pass
    tmp.replace(path)


def normalize_pod(value: str) -> str:
    raw = value.strip().lower()
    if raw.startswith("pod-"):
        pod = raw
    elif raw.isdigit():
        pod = f"pod-{int(raw):02d}"
    else:
        fail("pod must be a number such as 3/03 or an identifier such as pod-03")
    if not POD_RE.fullmatch(pod):
        fail("pod must be between pod-00 and pod-99 using the pod-XX format")
    return pod


def validate_base_url(value: str) -> str:
    parsed = urllib.parse.urlsplit(value.strip())
    if parsed.scheme != "https" or not parsed.netloc:
        fail("NEOLABS_LAB_BASE_URL must be an absolute HTTPS URL")
    if parsed.username or parsed.password or parsed.fragment:
        fail("lab base URL must not contain embedded credentials or a fragment")
    return value.rstrip("/")


def ssl_context() -> ssl.SSLContext:
    ca_file = os.environ.get("NEOLABS_CA_FILE", "").strip()
    if ca_file:
        path = Path(ca_file).expanduser()
        if not path.is_file():
            fail(f"NEOLABS_CA_FILE does not exist: {path}")
        return ssl.create_default_context(cafile=str(path))
    return ssl.create_default_context()


def request_json(base_url: str, path: str, *, method: str = "GET", payload: dict[str, Any] | None = None, token: str | None = None) -> dict[str, Any]:
    endpoint = urllib.parse.urljoin(base_url.rstrip("/") + "/", path.lstrip("/"))
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Accept": "application/json", "User-Agent": f"NeoLabs-{TRACK}-Toolkit/1.0"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(endpoint, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, context=ssl_context(), timeout=25) as response:
            body = response.read(2 * 1024 * 1024 + 1)
    except urllib.error.HTTPError as exc:
        detail = exc.read(4096).decode("utf-8", errors="replace")
        if exc.code in (401, 403):
            fail("authentication or pod/track authorization was rejected; verify your access code and assigned pod")
        if exc.code == 503:
            fail("the NeoLabs lab access service is not enabled for this environment")
        fail(f"lab access service returned HTTP {exc.code}: {detail}")
    except (urllib.error.URLError, TimeoutError, ssl.SSLError):
        fail("could not establish a verified HTTPS connection to the NeoLabs lab service")
    if len(body) > 2 * 1024 * 1024:
        fail("lab access response exceeded the allowed size")
    try:
        result = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        fail("lab access service returned invalid JSON")
    if not isinstance(result, dict):
        fail("lab access response must be a JSON object")
    return result


def installation_id() -> str:
    if INSTALLATION_FILE.is_file():
        value = INSTALLATION_FILE.read_text(encoding="utf-8").strip()
        if re.fullmatch(r"[0-9a-f]{32}", value):
            return value
    value = secrets.token_hex(16)
    atomic_write(INSTALLATION_FILE, value + "\n")
    return value


def read_session() -> dict[str, Any]:
    if not SESSION_FILE.is_file():
        fail("no NeoLabs session found; run `neolabs login` first")
    try:
        value = json.loads(SESSION_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        fail("local NeoLabs session is unreadable; run `neolabs login` again")
    if not isinstance(value, dict) or not isinstance(value.get("session_token"), str):
        fail("local NeoLabs session is incomplete; run `neolabs login` again")
    return value


def manifest_from(value: dict[str, Any]) -> dict[str, Any]:
    manifest = value.get("manifest")
    if not isinstance(manifest, dict):
        fail("server response did not contain a valid access manifest")
    if manifest.get("track") != TRACK:
        fail("server returned a manifest for a different internship track")
    pod = manifest.get("pod_id")
    if not isinstance(pod, str) or not POD_RE.fullmatch(pod):
        fail("server returned an invalid pod identifier")
    resources = manifest.get("resources")
    if not isinstance(resources, dict):
        fail("server returned an invalid resource manifest")
    return manifest


def save_runtime_manifest(manifest: dict[str, Any]) -> None:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    atomic_write(RUNTIME_MANIFEST, json.dumps(manifest, indent=2, sort_keys=True) + "\n")


def refresh(session: dict[str, Any]) -> dict[str, Any]:
    base_url = validate_base_url(str(session.get("base_url", "")))
    result = request_json(base_url, "/api/v1/lab-access/manifest", token=str(session["session_token"]))
    manifest = manifest_from(result)
    session["manifest"] = manifest
    if isinstance(result.get("expires_at"), str):
        session["expires_at"] = result["expires_at"]
    atomic_write(SESSION_FILE, json.dumps(session, indent=2, sort_keys=True) + "\n")
    save_runtime_manifest(manifest)
    return manifest


def do_login(args: argparse.Namespace) -> None:
    base_url = validate_base_url(args.base_url or os.environ.get("NEOLABS_LAB_BASE_URL", ""))
    pod = normalize_pod(args.pod or input("Pod number: "))
    access_code = getpass.getpass("NeoLabs Access Code: ").strip()
    if len(access_code) < 12 or any(ch.isspace() for ch in access_code):
        fail("access code has an unexpected format")
    response = request_json(base_url, "/api/v1/lab-access/login", method="POST", payload={"access_code": access_code, "pod_number": pod, "track": TRACK, "installation_id": installation_id()})
    token = response.get("session_token")
    if not isinstance(token, str) or not token:
        fail("server did not return a lab session")
    manifest = manifest_from(response)
    state: dict[str, Any] = {"base_url": base_url, "session_token": token, "expires_at": response.get("expires_at"), "manifest": manifest}
    if isinstance(response.get("soc_enrolment"), dict):
        state["soc_enrolment"] = response["soc_enrolment"]
    atomic_write(SESSION_FILE, json.dumps(state, indent=2, sort_keys=True) + "\n")
    save_runtime_manifest(manifest)
    print("✓ Authentication successful")
    print(f"✓ Assigned pod: {manifest['pod_id']}")
    print("✓ Track: SOC")
    print("Next: run `neolabs connect`.")


def update_simple_env(path: Path, updates: dict[str, str]) -> None:
    if not path.is_file():
        fail(f"missing expected configuration file: {path}")
    lines = path.read_text(encoding="utf-8").splitlines()
    output: list[str] = []
    seen: set[str] = set()
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


def connect_soc(session: dict[str, Any], manifest: dict[str, Any]) -> None:
    stack = ROOT / "wazuh-stack"
    env_path = stack / ".env"
    state_path = stack / "state" / "enrolment.json"
    base_url = validate_base_url(str(session["base_url"]))
    if not env_path.is_file():
        fail("Wazuh stack is not prepared. Run the toolkit workstation/setup step first so wazuh-stack/.env exists.")
    update_simple_env(env_path, {"VCC_ENROLMENT_BASE_URL": base_url})
    if not state_path.is_file():
        enrolment = session.get("soc_enrolment")
        if not isinstance(enrolment, dict) or not isinstance(enrolment.get("bootstrap_token"), str):
            fail("this session has no fresh SOC enrolment token; run `neolabs login` again")
        token_file = HOME_STATE / "soc-bootstrap-token"
        atomic_write(token_file, str(enrolment["bootstrap_token"]).strip() + "\n")
        try:
            subprocess.run([sys.executable, str(stack / "scripts" / "enrol-vcc.py"), "--token-file", str(token_file)], cwd=stack, check=True)
        except subprocess.CalledProcessError as exc:
            fail(f"Wazuh pod enrolment failed with exit code {exc.returncode}")
        finally:
            try:
                token_file.unlink()
            except FileNotFoundError:
                pass
        session.pop("soc_enrolment", None)
        atomic_write(SESSION_FILE, json.dumps(session, indent=2, sort_keys=True) + "\n")
    start_script = stack / "scripts" / "start.sh"
    if start_script.is_file():
        try:
            subprocess.run(["bash", str(start_script)], cwd=stack, check=True)
        except (OSError, subprocess.CalledProcessError):
            fail("pod enrolment succeeded, but the local Wazuh stack could not be started; run its health/setup guide")
    print(f"✓ Wazuh is bound to {manifest['pod_id']} through the NeoLabs mTLS telemetry channel.")


def do_connect(_: argparse.Namespace) -> None:
    session = read_session()
    manifest = refresh(session)
    save_runtime_manifest(manifest)
    connect_soc(session, manifest)


def do_status(_: argparse.Namespace) -> None:
    session = read_session()
    manifest = refresh(session)
    print("NEOLABS SECURITY LAB")
    print("Status:   ONLINE SESSION")
    print(f"Track:    {manifest['track']}")
    print(f"Pod:      {manifest['pod_id']}")
    print(f"Scenario: {manifest.get('scenario_id') or 'not published'}")
    print(f"Session:  expires {session.get('expires_at') or 'unknown'}")


def do_pod_info(_: argparse.Namespace) -> None:
    manifest = refresh(read_session())
    print("NEOLABS SECURITY LAB")
    print(f"Pod:      {manifest['pod_id']}")
    print(f"Track:    {manifest['track']}")
    print(f"Scenario: {manifest.get('scenario_id') or 'not published'}")
    print("Scope is server-managed. The pod value shown here is informational, not user-selectable.")


def do_scope(_: argparse.Namespace) -> None:
    manifest = refresh(read_session())
    print(f"Authorised pod: {manifest['pod_id']}")
    print("SOC target selection is intentionally hidden. Wazuh receives only server-assigned pod telemetry.")


def do_targets(_: argparse.Namespace) -> None:
    refresh(read_session())
    print("SOC target selection is intentionally hidden. Wazuh receives only server-assigned pod telemetry.")


def do_disconnect(_: argparse.Namespace) -> None:
    stop_script = ROOT / "wazuh-stack" / "scripts" / "stop.sh"
    if stop_script.is_file():
        subprocess.run(["bash", str(stop_script)], cwd=stop_script.parent.parent, check=False)
    for path in (SESSION_FILE, RUNTIME_MANIFEST):
        try:
            path.unlink()
        except FileNotFoundError:
            pass
    print("✓ Local NeoLabs session disconnected. Long-lived SOC certificate material, if present, was not deleted.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="NeoLabs SOC internship pod access client")
    sub = parser.add_subparsers(dest="command", required=True)
    login = sub.add_parser("login", help="authenticate with your pod number and private NeoLabs Access Code")
    login.add_argument("--pod")
    login.add_argument("--base-url", default=None)
    login.set_defaults(func=do_login)
    connect = sub.add_parser("connect", help="refresh the live manifest and configure Wazuh")
    connect.set_defaults(func=do_connect)
    status = sub.add_parser("status", help="show current connection/session status")
    status.set_defaults(func=do_status)
    scope = sub.add_parser("scope", help="show server-authorised scope")
    scope.set_defaults(func=do_scope)
    targets = sub.add_parser("targets", help="show current authorised targets/resources")
    targets.set_defaults(func=do_targets)
    pod = sub.add_parser("pod", help="pod information")
    pod_sub = pod.add_subparsers(dest="pod_command", required=True)
    info = pod_sub.add_parser("info", help="show assigned pod information")
    info.set_defaults(func=do_pod_info)
    disconnect = sub.add_parser("disconnect", help="remove the local broker session")
    disconnect.set_defaults(func=do_disconnect)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
