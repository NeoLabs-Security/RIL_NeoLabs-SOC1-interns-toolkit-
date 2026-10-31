#!/usr/bin/env python3
"""Update only known Week 4 VCC URLs in a local SOC collector .env.

Defaults to dry-run. Preserves local secrets, client certs, CA and Wazuh
persistent data. Existing pod assignment and telemetry cursor are untouched.
"""
import argparse
import ipaddress
import os
import pathlib
import shutil
import tempfile
from datetime import datetime, timezone
from urllib.parse import urlsplit

ROOT = pathlib.Path(__file__).resolve().parents[1]
ENV = ROOT / ".env"
OLD = "16.16.110.32"
parser = argparse.ArgumentParser()
parser.add_argument("--public-ip", default="13.53.110.120")
parser.add_argument("--apply", action="store_true")
args = parser.parse_args()
try:
    ip = ipaddress.ip_address(args.public_ip)
except ValueError as exc:
    raise SystemExit("Invalid VCC public IP: " + str(exc))
if ip.version != 4 or not ip.is_global:
    raise SystemExit("Expected globally routable VCC IPv4 address")
if not ENV.is_file() or ENV.is_symlink():
    raise SystemExit("Missing/unsafe wazuh-stack/.env; refusing to create or replace secrets")
old_lines = ENV.read_text().splitlines(keepends=True)
targets = {
    "VCC_ENROLMENT_BASE_URL": "https://" + args.public_ip + ":18443",
    "VCC_TELEMETRY_ENDPOINT": "https://" + args.public_ip + ":18443/api/v1/soc/telemetry",
}
new_lines = list(old_lines)
for key, target in targets.items():
    indexes = [i for i,line in enumerate(new_lines) if line.startswith(key + "=")]
    if len(indexes) != 1:
        raise SystemExit("Missing or duplicate local .env key: " + key)
    idx = indexes[0]
    old_url = new_lines[idx].split("=",1)[1].strip().strip("'\"")
    if old_url:
        parsed = urlsplit(old_url)
        if parsed.scheme != "https" or parsed.hostname not in (OLD, args.public_ip, "localhost", "127.0.0.1") or parsed.port != 18443:
            raise SystemExit("Refusing to overwrite an unrelated endpoint: " + key)
    new_lines[idx] = key + "=" + target + "\n"
    print(key + " -> " + target)
if old_lines == new_lines:
    print("Already current; no file changes required")
    raise SystemExit(0)
if not args.apply:
    print("DRY RUN: rerun with --apply after VCC HTTPS certificate and broker are ready")
    raise SystemExit(0)
backup = ENV.with_name(".env.before-vcc-ip-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
shutil.copy2(ENV, backup)
os.chmod(backup, 0o600)
fd, temp = tempfile.mkstemp(prefix=".env.vcc-ip.", dir=ENV.parent)
try:
    with os.fdopen(fd,"w") as f:
        f.writelines(new_lines)
        f.flush()
        os.fsync(f.fileno())
    st = ENV.stat()
    os.chmod(temp, st.st_mode & 0o777)
    os.chown(temp, st.st_uid, st.st_gid)
    os.replace(temp, ENV)
finally:
    if os.path.exists(temp):
        os.unlink(temp)
print("Only VCC URLs updated; private .env backup stored. No containers restarted.")
print("Recreate only the collector after validating TLS, without deleting its cursor or volume.")
