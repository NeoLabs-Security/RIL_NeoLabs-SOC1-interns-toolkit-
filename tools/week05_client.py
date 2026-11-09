#!/usr/bin/env python3
"""Week 05 standalone exercise client (mentor rehearsal, scoped to localhost).

Login uses server-authoritative track/pod codes. This client never asks you to
select a pod and stores only the short-lived session in a private local file.
"""
from __future__ import annotations
import argparse
import base64
import getpass
import json
import os
from pathlib import Path
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

SESSION = Path.home() / ".neolabs-w05" / "session.json"
PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNwaDgAAAKEAYEml6crAAAAAElFTkSuQmCC")
FIXTURES = {
    "valid_png": ("valid_1x1.png", "image/png", PNG),
    "mismatched_jpg": ("inert_mime_mismatch.jpg", "image/jpeg",
                        b"NeoLabs Week 05 benign TEXT fixture, not a JPEG.\n"),
    "unsupported_txt": ("unsupported_extension.txt", "text/plain",
                          b"NeoLabs Week 05 benign unsupported extension test.\n"),
}


def valid_url(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost") or parsed.port != 18600 or parsed.username or parsed.password or parsed.path not in ("", "/") or parsed.query or parsed.fragment:
        raise ValueError("Only an SSH-forwarded or locally published 127.0.0.1:18600 W05 gateway is allowed")
    return "http://127.0.0.1:18600"


def call(url: str, route: str, token: str | None = None,
         payload: bytes | None = None, method: str = "GET", headers: dict | None = None):
    meta = dict(headers or {})
    if token:
        meta["Authorization"] = "Bearer " + token
    req = Request(url + route, method=method, data=payload, headers=meta)
    try:
        with urlopen(req, timeout=10) as resp:
            return resp.status, json.load(resp)
    except HTTPError as err:
        try:
            return err.code, json.load(err)
        except ValueError:
            return err.code, {"error": "invalid_response"}


def save_session(data: dict):
    SESSION.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(SESSION.parent, 0o700)
    if SESSION.is_symlink():
        raise RuntimeError("Refusing symlinked session")
    fd = os.open(str(SESSION), os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump(data, stream)
        stream.write("\n")
    os.chmod(SESSION, 0o600)


def load_session() -> dict:
    if not SESSION.is_file() or SESSION.is_symlink() or SESSION.stat().st_mode & 0o077:
        raise RuntimeError("No private session. Run login on your authorized gateway.")
    value = json.loads(SESSION.read_text())
    if value.get("expires_at_epoch", 0) <= time.time():
        raise RuntimeError("W05 session expired; login again")
    valid_url(value["url"])
    return value


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)
    login = sub.add_parser("login")
    login.add_argument("--url", default="http://127.0.0.1:18600")
    for name in ("status", "target", "uploads", "events", "logout"):
        sub.add_parser(name)
    upload = sub.add_parser("upload")
    upload.add_argument("--case", choices=list(FIXTURES), required=True)
    q = sub.add_parser("quarantine")
    q.add_argument("--upload-id", required=True)
    q.add_argument("--incident", required=True)
    q.add_argument("--confirm", action="store_true")
    args = p.parse_args()
    try:
        if args.command == "login":
            url = valid_url(args.url)
            code = getpass.getpass("Mentor-issued W05 Access Code (hidden): ")
            status, data = call(url, "/auth/login", payload=json.dumps({"access_code": code}).encode(),
                                method="POST", headers={"Content-Type": "application/json"})
            if status != 200:
                raise RuntimeError(f"Access denied HTTP {status}. Check assigned track and code.")
            session = {"url": url, "token": data["token"],
                       "role": data["role"], "pod_id": data["pod_id"],
                       "scenario_id": data["scenario_id"],
                       "expires_at_epoch": int(time.time()) + min(data.get("expires_in", 3600), 3600) - 10}
            save_session(session)
            print(f"Authorized {session['role']} / {session['pod_id']} / {session['scenario_id']}")
            return
        if args.command == "logout":
            SESSION.unlink(missing_ok=True)
            print("Session file deleted")
            return
        s = load_session()
        role, token, url = s["role"], s["token"], s["url"]
        if args.command == "status":
            status, data = call(url, "/api/session", token)
        elif args.command == "target":
            status, data = call(url, "/api/target-health", token)
        elif args.command == "upload":
            if role != "pentest":
                raise RuntimeError("Upload tests are only available to the assigned Pentest track")
            name, mime, contents = FIXTURES[args.case]
            status, data = call(url, "/api/uploads", token, contents, "POST",
                                {"X-Upload-Filename": name, "Content-Type": mime})
        elif args.command == "uploads":
            if role != "support":
                raise RuntimeError("Only assigned Support can inspect upload records")
            status, data = call(url, "/api/admin/uploads", token)
        elif args.command == "quarantine":
            if role != "support" or not args.confirm:
                raise RuntimeError("Quarantine requires Support role, approved incident and --confirm")
            if not args.incident.startswith("INC-W05-"):
                raise RuntimeError("Invalid incident reference")
            status, data = call(url, f"/api/admin/uploads/{args.upload_id}/quarantine", token, b"", "POST",
                                {"X-Incident-ID": args.incident})
        elif args.command == "events":
            if role != "soc":
                raise RuntimeError("Only assigned SOC can inspect this raw event export")
            status, data = call(url, "/api/soc/events", token)
            if status == 200:
                events = data.get("events", [])[-20:]
                data = {"pod_id": data.get("pod_id"), "events": events,
                        "total_events_in_response": len(data.get("events", [])),
                        "note": "Synthetic raw events; not proof of Wazuh alert indexing."}
        else:
            raise RuntimeError("Unknown command")
        print(json.dumps({"http_status": status, "result": data}, indent=2))
        if status >= 500:
            raise RuntimeError("Lab service not ready")
    except (ValueError, KeyError, OSError, RuntimeError, URLError, json.JSONDecodeError) as exc:
        raise SystemExit(f"STOP: {exc}") from None


if __name__ == "__main__":
    main()
