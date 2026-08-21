#!/usr/bin/env python3
"""NeoLabs internship pod access client.

The always-available NeoLabs access gateway is authoritative for pod, track,
scenario and runtime state. During LIVE windows it can hand SOC a short-lived
live enrolment token. During replay/cloud/endpoint windows this client downloads
only the authenticated pod's S3 replay bundles and feeds validated events into
the same local Wazuh telemetry file used by the live collector.
"""
from __future__ import annotations

import argparse
import getpass
import gzip
import hashlib
import io
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
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

TRACK = "SOC"
TRACK_DIR = "soc"
POD_RE = re.compile(r"^pod-[0-9]{2}$")
ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "runtime"
RUNTIME_MANIFEST = RUNTIME_DIR / "access-manifest.json"
EVIDENCE_DIR = RUNTIME_DIR / "evidence"
HOME_STATE = Path.home() / ".neolabs" / TRACK_DIR
SESSION_FILE = HOME_STATE / "session.json"
INSTALLATION_FILE = HOME_STATE / "installation-id"
REPLAY_STATE_FILE = HOME_STATE / "replayed-objects.json"
REPLAY_PENDING_FILE = HOME_STATE / "replay-pending.json"
CURRENT_RELEASE_FILE = HOME_STATE / "current-release.json"
CLIENT_VERSION_FILE = ROOT / "NEOLABS_SOC_CLIENT_VERSION"
MAX_HTTP_BYTES = 25 * 1024 * 1024
MAX_REPLAY_BYTES = 64 * 1024 * 1024
MAX_REPLAY_EVENTS = 50_000


def fail(message: str, code: int = 2) -> "NoReturn":
    raise SystemExit(f"ERROR: {message}")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


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
    context = ssl.create_default_context()
    ca_file = os.environ.get("NEOLABS_CA_FILE", "").strip()
    if ca_file:
        path = Path(ca_file).expanduser()
        if not path.is_file():
            fail(f"NEOLABS_CA_FILE does not exist: {path}")
        context.load_verify_locations(cafile=str(path))
    return context


def request_json(base_url: str, path: str, *, method: str = "GET", payload: dict[str, Any] | None = None, token: str | None = None) -> dict[str, Any]:
    endpoint = urllib.parse.urljoin(base_url.rstrip("/") + "/", path.lstrip("/"))
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Accept": "application/json", "User-Agent": f"NeoLabs-{TRACK}-Toolkit/1.1"}
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


def download_bytes(url: str) -> bytes:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        fail("replay gateway returned an invalid download URL")
    request = urllib.request.Request(url, headers={"User-Agent": "NeoLabs-SOC-Replay/1.1"})
    try:
        with urllib.request.urlopen(request, context=ssl_context(), timeout=45) as response:
            body = response.read(MAX_HTTP_BYTES + 1)
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, ssl.SSLError):
        fail("could not download an authorised replay object")
    if len(body) > MAX_HTTP_BYTES:
        fail("replay object exceeded the allowed download size")
    return body


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


def client_version() -> str:
    try:
        return CLIENT_VERSION_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        return "0.0.0"


def version_tuple(value: str) -> tuple[int, int, int]:
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", value.strip())
    if not match:
        fail(f"server returned an invalid minimum_client_version: {value!r}")
    return tuple(int(part) for part in match.groups())


def record_current_release(manifest: dict[str, Any]) -> bool:
    """Persist public release metadata only; never replace enrolment/replay state."""
    previous: dict[str, Any] = {}
    try:
        loaded = json.loads(CURRENT_RELEASE_FILE.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            previous = loaded
    except (OSError, json.JSONDecodeError):
        pass
    fields = ("scenario_id", "scenario_release", "release_generation", "release_id", "pod_id", "student_ready", "lab_state", "runtime_mode")
    current = {key: manifest[key] for key in fields if key in manifest}
    current["observed_at"] = utc_now()
    changed = previous.get("release_generation") != current.get("release_generation")
    atomic_write(CURRENT_RELEASE_FILE, json.dumps(current, indent=2, sort_keys=True) + "\n")
    return changed


def ensure_compatible(manifest: dict[str, Any]) -> None:
    minimum = manifest.get("minimum_client_version")
    if minimum is None:
        return
    if not isinstance(minimum, str) or version_tuple(client_version()) < version_tuple(minimum):
        fail(f"this toolkit client ({client_version()}) is too old; server requires {minimum}. Preserve local work, then update from origin/main or ask NeoLabs support")


def refresh(session: dict[str, Any]) -> dict[str, Any]:
    base_url = validate_base_url(str(session.get("base_url", "")))
    result = request_json(base_url, "/api/v1/lab-access/manifest", token=str(session["session_token"]))
    manifest = manifest_from(result)
    session["manifest"] = manifest
    if isinstance(result.get("expires_at"), str):
        session["expires_at"] = result["expires_at"]
    atomic_write(SESSION_FILE, json.dumps(session, indent=2, sort_keys=True) + "\n")
    save_runtime_manifest(manifest)
    ensure_compatible(manifest)
    changed = record_current_release(manifest)
    if changed:
        print(f"[NeoLabs] New server release observed: generation={manifest.get('release_generation', 'not published')} scenario={manifest.get('scenario_id', 'not published')}")
    return manifest


def student_is_ready(manifest: dict[str, Any]) -> bool:
    # Absent means compatible with the pre-Pass-1 broker.
    return manifest.get("student_ready", True) is not False


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
    if isinstance(response.get("live_handoff"), dict):
        state["live_handoff"] = response["live_handoff"]
    elif isinstance(response.get("soc_enrolment"), dict):
        # Backward compatibility when directly connected to the live broker.
        state["live_handoff"] = {"available": True, "live_base_url": base_url, "soc_enrolment": response["soc_enrolment"]}
    atomic_write(SESSION_FILE, json.dumps(state, indent=2, sort_keys=True) + "\n")
    save_runtime_manifest(manifest)
    ensure_compatible(manifest)
    record_current_release(manifest)
    print("✓ Authentication successful")
    print(f"✓ Assigned pod: {manifest['pod_id']}")
    print("✓ Track: SOC")
    print(f"✓ Lab state: {manifest.get('lab_state', 'LIVE')}")
    print(f"✓ Scenario: {manifest.get('scenario_id') or 'not published'}")
    if not student_is_ready(manifest):
        print("[WAIT] Current scenario is deployed but student access has not been published yet.")
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


def start_wazuh_stack() -> Path:
    stack = ROOT / "wazuh-stack"
    env_path = stack / ".env"
    if not env_path.is_file():
        fail("Wazuh stack is not prepared. Run the toolkit workstation/setup step first so wazuh-stack/.env exists.")
    start_script = stack / "scripts" / "start.sh"
    if not start_script.is_file():
        fail("Wazuh start script is missing")
    try:
        subprocess.run(["bash", str(start_script)], cwd=stack, check=True)
    except (OSError, subprocess.CalledProcessError):
        fail("the local Wazuh stack could not be started; run its health/setup guide")
    return stack


def connect_soc_live(session: dict[str, Any], manifest: dict[str, Any]) -> None:
    stack = ROOT / "wazuh-stack"
    env_path = stack / ".env"
    state_path = stack / "state" / "enrolment.json"
    if not env_path.is_file():
        fail("Wazuh stack is not prepared. Run the toolkit workstation/setup step first so wazuh-stack/.env exists.")

    if not state_path.is_file():
        handoff = session.get("live_handoff")
        if not isinstance(handoff, dict) or handoff.get("available") is not True:
            reason = handoff.get("reason") if isinstance(handoff, dict) else "not-issued"
            fail(f"the lab is live but a fresh SOC enrolment handoff is unavailable ({reason}); run `neolabs login` again during the live window")
        live_base_url = validate_base_url(str(handoff.get("live_base_url", "")))
        enrolment = handoff.get("soc_enrolment")
        if not isinstance(enrolment, dict) or not isinstance(enrolment.get("bootstrap_token"), str):
            fail("live SOC handoff did not include a valid enrolment token")
        update_simple_env(env_path, {"VCC_ENROLMENT_BASE_URL": live_base_url})
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
        session.pop("live_handoff", None)
        atomic_write(SESSION_FILE, json.dumps(session, indent=2, sort_keys=True) + "\n")

    start_wazuh_stack()
    print(f"✓ LIVE mode: Wazuh is bound to {manifest['pod_id']} through the NeoLabs mTLS telemetry channel.")


def replayed_keys() -> set[str]:
    try:
        value = json.loads(REPLAY_STATE_FILE.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return set()
    return {str(item) for item in value if isinstance(item, str)} if isinstance(value, list) else set()


def save_replayed_keys(keys: set[str]) -> None:
    atomic_write(REPLAY_STATE_FILE, json.dumps(sorted(keys), indent=2) + "\n")


def replay_pending() -> dict[str, str]:
    try:
        value = json.loads(REPLAY_PENDING_FILE.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}
    return {str(key): str(event_id) for key, event_id in value.items() if isinstance(key, str) and isinstance(event_id, str)} if isinstance(value, dict) else {}


def save_replay_pending(value: dict[str, str]) -> None:
    atomic_write(REPLAY_PENDING_FILE, json.dumps(value, indent=2, sort_keys=True) + "\n")


def verify_replay_indexed(stack: Path, manifest: dict[str, Any], event_id: str, wait: int = 60) -> bool:
    scenario = str(manifest.get("scenario_id") or "")
    if not scenario or not event_id:
        return False
    result = subprocess.run(
        ["bash", "scripts/verify-telemetry-pipeline.sh", "--scenario-id", scenario, "--event-id", event_id, "--wait", str(wait)],
        cwd=stack,
        check=False,
    )
    return result.returncode == 0


def decode_replay_pack(raw: bytes, manifest: dict[str, Any], object_key: str) -> str:
    try:
        with gzip.GzipFile(fileobj=io.BytesIO(raw), mode="rb") as zipped:
            decoded = zipped.read(MAX_REPLAY_BYTES + 1)
    except (OSError, EOFError):
        fail(f"replay object is not a valid gzip stream: {object_key}")
    if len(decoded) > MAX_REPLAY_BYTES:
        fail(f"replay object expands beyond the allowed size: {object_key}")
    try:
        text = decoded.decode("utf-8")
    except UnicodeDecodeError:
        fail(f"replay object is not UTF-8 NDJSON: {object_key}")

    pod = str(manifest["pod_id"])
    scenario = str(manifest.get("scenario_id") or "")
    output: list[str] = []
    for line_number, raw_line in enumerate(text.splitlines(), 1):
        line = raw_line.strip()
        if not line:
            continue
        if len(output) >= MAX_REPLAY_EVENTS:
            fail(f"replay object contains too many events: {object_key}")
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            fail(f"invalid NDJSON in replay object {object_key} line {line_number}")
        if not isinstance(event, dict) or event.get("synthetic") is not True or event.get("pod_id") != pod:
            fail(f"replay object failed synthetic/pod validation: {object_key}")
        event_scenario = event.get("scenario_id")
        if scenario and event_scenario not in (None, "", scenario):
            fail(f"replay object contains a different scenario: {object_key}")
        if not isinstance(event.get("event_time"), str) or not isinstance(event.get("event_id"), str):
            fail(f"replay object is missing required event fields: {object_key}")
        # Preserve the original event_time. Replay metadata is separate so students can
        # distinguish collection time from replay time in Wazuh.
        event["neolabs_replay"] = {"source": "s3", "replayed_at": utc_now(), "object_key": object_key}
        output.append(json.dumps(event, separators=(",", ":"), sort_keys=True))
    return "\n".join(output) + ("\n" if output else "")


def append_to_wazuh(stack: Path, ndjson: str) -> None:
    if not ndjson:
        return
    command = [
        "docker", "compose", "--env-file", ".env", "exec", "-T",
        "vcc.telemetry.collector", "sh", "-c", "cat >> /data/vcc-events.ndjson"
    ]
    try:
        subprocess.run(command, cwd=stack, input=ndjson, text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        fail("could not append validated replay events to the local Wazuh telemetry volume")


def replay_soc(session: dict[str, Any], manifest: dict[str, Any]) -> None:
    stack = start_wazuh_stack()
    response = request_json(validate_base_url(str(session["base_url"])), "/api/v1/lab-access/replay", token=str(session["session_token"]))
    packs = response.get("telemetry_packs", [])
    if not isinstance(packs, list):
        fail("replay gateway returned an invalid telemetry pack list")
    seen = replayed_keys()
    pending = replay_pending()
    added_events = 0
    added_packs = 0
    for pack in packs:
        if not isinstance(pack, dict):
            continue
        key = pack.get("key")
        url = pack.get("url")
        if not isinstance(key, str) or not isinstance(url, str) or key in seen:
            continue
        if key in pending:
            if verify_replay_indexed(stack, manifest, pending[key]):
                seen.add(key)
                pending.pop(key, None)
                save_replayed_keys(seen)
                save_replay_pending(pending)
                added_packs += 1
            continue
        ndjson = decode_replay_pack(download_bytes(url), manifest, key)
        if ndjson:
            representative = str(json.loads(ndjson.splitlines()[0]).get("event_id") or "")
            append_to_wazuh(stack, ndjson)
            added_events += ndjson.count("\n")
            pending[key] = representative
            save_replay_pending(pending)
            if verify_replay_indexed(stack, manifest, representative):
                seen.add(key)
                pending.pop(key, None)
                save_replayed_keys(seen)
                save_replay_pending(pending)
                added_packs += 1
            else:
                print(f"NOTICE: Replay pack {key} was delivered but remains pending until its current-scenario event is searchable.")
    print(f"✓ REPLAY mode: {added_packs} new telemetry pack(s), {added_events} event(s) appended for {manifest['pod_id']}.")
    if not packs:
        print("NOTICE: No telemetry replay packs are published yet for this pod/scenario.")


def evidence_local_path(key: str) -> Path:
    name = Path(key).name or "evidence.bin"
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", name)[:120]
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()[:10]
    return EVIDENCE_DIR / f"{digest}-{safe}"


def do_evidence(_: argparse.Namespace) -> None:
    session = read_session()
    manifest = refresh(session)
    response = request_json(validate_base_url(str(session["base_url"])), "/api/v1/lab-access/replay", token=str(session["session_token"]))
    evidence = response.get("evidence", [])
    if not isinstance(evidence, list):
        fail("replay gateway returned an invalid evidence list")
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    downloaded = 0
    for item in evidence:
        if not isinstance(item, dict) or not isinstance(item.get("key"), str) or not isinstance(item.get("url"), str):
            continue
        destination = evidence_local_path(item["key"])
        if destination.is_file():
            continue
        destination.write_bytes(download_bytes(item["url"]))
        try:
            os.chmod(destination, 0o600)
        except OSError:
            pass
        downloaded += 1
    print(f"✓ Downloaded {downloaded} new approved evidence file(s) for {manifest['pod_id']} to {EVIDENCE_DIR}.")


def do_connect(_: argparse.Namespace) -> None:
    session = read_session()
    manifest = refresh(session)
    if not student_is_ready(manifest):
        print("[WAIT] Current scenario is deployed but student access has not been published yet.")
        return
    lab_state = str(manifest.get("lab_state") or "LIVE")
    if lab_state == "LIVE":
        connect_soc_live(session, manifest)
        return
    if lab_state in {"REPLAY", "CLOUD_LIVE", "ENDPOINT_LIVE"}:
        replay_soc(session, manifest)
        return
    fail("no SOC learning surface is currently active; check the scheduled live/replay window")


def do_status(_: argparse.Namespace) -> None:
    session = read_session()
    manifest = refresh(session)
    print("NEOLABS SECURITY LAB")
    print(f"State:    {manifest.get('lab_state') or 'LIVE'}")
    print(f"Mode:     {manifest.get('runtime_mode') or 'live-control-plane'}")
    print(f"Track:    {manifest['track']}")
    print(f"Pod:      {manifest['pod_id']}")
    print(f"Scenario: {manifest.get('scenario_id') or 'not published'}")
    print(f"Release:  {manifest.get('scenario_release') or 'not published'}")
    print(f"Client:   {client_version()}")
    print(f"Access:   {'READY' if student_is_ready(manifest) else 'PENDING'}")
    if not student_is_ready(manifest):
        print("[WAIT] Current scenario is deployed but student access has not been published yet.")
    print(f"Session:  expires {session.get('expires_at') or 'unknown'}")


def do_pod_info(_: argparse.Namespace) -> None:
    manifest = refresh(read_session())
    print("NEOLABS SECURITY LAB")
    print(f"Pod:      {manifest['pod_id']}")
    print(f"Track:    {manifest['track']}")
    print(f"Scenario: {manifest.get('scenario_id') or 'not published'}")
    print(f"State:    {manifest.get('lab_state') or 'LIVE'}")
    print("Scope is server-managed. The pod value shown here is informational, not user-selectable.")


def do_scope(_: argparse.Namespace) -> None:
    manifest = refresh(read_session())
    print(f"Authorised pod: {manifest['pod_id']}")
    print("SOC target selection is intentionally hidden. Live telemetry and replay are both pod-scoped by NeoLabs.")


def do_targets(_: argparse.Namespace) -> None:
    refresh(read_session())
    print("SOC target selection is intentionally hidden. Use `neolabs connect` for live/replay telemetry and `neolabs evidence` for approved native evidence.")


def do_disconnect(_: argparse.Namespace) -> None:
    stop_script = ROOT / "wazuh-stack" / "scripts" / "stop.sh"
    if stop_script.is_file():
        subprocess.run(["bash", str(stop_script)], cwd=stop_script.parent.parent, check=False)
    for path in (SESSION_FILE, RUNTIME_MANIFEST):
        try:
            path.unlink()
        except FileNotFoundError:
            pass
    print("✓ Local NeoLabs session disconnected. Long-lived SOC certificate and replay history, if present, were not deleted.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="NeoLabs SOC internship pod access client")
    sub = parser.add_subparsers(dest="command", required=True)
    login = sub.add_parser("login", help="authenticate with your pod number and private NeoLabs Access Code")
    login.add_argument("--pod")
    login.add_argument("--base-url", default=None)
    login.set_defaults(func=do_login)
    connect = sub.add_parser("connect", help="connect to live telemetry or replay the current S3 evidence automatically")
    connect.set_defaults(func=do_connect)
    status = sub.add_parser("status", help="show current live/replay state")
    status.set_defaults(func=do_status)
    evidence = sub.add_parser("evidence", help="download approved native CloudTrail/S3/endpoint evidence for this pod")
    evidence.set_defaults(func=do_evidence)
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
