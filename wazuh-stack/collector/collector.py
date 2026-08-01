#!/usr/bin/env python3
"""Poll the VCC pod-scoped telemetry API and append validated events to NDJSON.

The VCC control plane determines pod scope. This client never accepts a trusted pod
identifier from the learner. It verifies that the pod returned by the server remains
stable and that every event belongs to that server-issued pod.
"""

from __future__ import annotations

import json
import os
import signal
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

MAX_RESPONSE_BYTES = 5 * 1024 * 1024
MAX_EVENTS_PER_RESPONSE = 1000
REQUIRED_EVENT_FIELDS = {
    "schema_version",
    "event_id",
    "event_time",
    "pod_id",
    "event_type",
    "synthetic",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def atomic_write(path: Path, value: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(value, encoding="utf-8")
    os.chmod(temporary, mode)
    temporary.replace(path)


def read_optional(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return ""


@dataclass(frozen=True)
class Config:
    endpoint: str
    certificate: Path
    private_key: Path
    ca_certificate: Path
    installation_id_path: Path
    cursor_path: Path
    assigned_pod_path: Path
    output_path: Path
    health_path: Path
    poll_interval: int

    @classmethod
    def from_environment(cls) -> "Config":
        interval_text = os.getenv("VCC_POLL_INTERVAL_SECONDS", "15")
        try:
            interval = int(interval_text)
        except ValueError as exc:
            raise ValueError("VCC_POLL_INTERVAL_SECONDS must be an integer") from exc
        if interval < 5 or interval > 3600:
            raise ValueError("VCC_POLL_INTERVAL_SECONDS must be between 5 and 3600")

        return cls(
            endpoint=os.getenv("VCC_TELEMETRY_ENDPOINT", "").strip(),
            certificate=Path(os.getenv("VCC_CLIENT_CERT_PATH", "/run/vcc-secrets/client.crt")),
            private_key=Path(os.getenv("VCC_CLIENT_KEY_PATH", "/run/vcc-secrets/client.key")),
            ca_certificate=Path(os.getenv("VCC_CA_CERT_PATH", "/run/vcc-secrets/ca.crt")),
            installation_id_path=Path(
                os.getenv("VCC_INSTALLATION_ID_PATH", "/run/vcc-secrets/installation-id")
            ),
            cursor_path=Path(os.getenv("VCC_TELEMETRY_CURSOR_PATH", "/state/vcc-telemetry.cursor")),
            assigned_pod_path=Path(os.getenv("VCC_ASSIGNED_POD_PATH", "/state/assigned-pod")),
            output_path=Path(os.getenv("VCC_OUTPUT_PATH", "/data/vcc-events.ndjson")),
            health_path=Path(os.getenv("VCC_HEALTH_PATH", "/state/collector-health.json")),
            poll_interval=interval,
        )


class Collector:
    def __init__(self, config: Config) -> None:
        self.config = config
        self.running = True
        self.failures = 0

    def write_health(self, status: str, detail: str, **extra: Any) -> None:
        payload: dict[str, Any] = {
            "status": status,
            "detail": detail,
            "updated_at": utc_now(),
            "consecutive_failures": self.failures,
        }
        payload.update(extra)
        atomic_write(self.config.health_path, json.dumps(payload, sort_keys=True) + "\n")

    def enrolled(self) -> bool:
        required = (
            self.config.endpoint,
            str(self.config.certificate) if self.config.certificate.is_file() else "",
            str(self.config.private_key) if self.config.private_key.is_file() else "",
            str(self.config.ca_certificate) if self.config.ca_certificate.is_file() else "",
            read_optional(self.config.installation_id_path),
        )
        return all(required)

    def ssl_context(self) -> ssl.SSLContext:
        context = ssl.create_default_context(cafile=str(self.config.ca_certificate))
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(
            certfile=str(self.config.certificate),
            keyfile=str(self.config.private_key),
        )
        context.check_hostname = True
        context.verify_mode = ssl.CERT_REQUIRED
        return context

    def build_url(self, cursor: str) -> str:
        parsed = urllib.parse.urlsplit(self.config.endpoint)
        if parsed.scheme != "https" or not parsed.netloc:
            raise ValueError("VCC_TELEMETRY_ENDPOINT must be an absolute HTTPS URL")
        query = dict(urllib.parse.parse_qsl(parsed.query, keep_blank_values=True))
        if cursor:
            query["cursor"] = cursor
        query["limit"] = str(MAX_EVENTS_PER_RESPONSE)
        return urllib.parse.urlunsplit(
            (parsed.scheme, parsed.netloc, parsed.path, urllib.parse.urlencode(query), parsed.fragment)
        )

    def fetch(self, cursor: str) -> tuple[list[dict[str, Any]], str, str]:
        installation_id = read_optional(self.config.installation_id_path)
        if not installation_id:
            raise RuntimeError("installation identifier is missing")

        request = urllib.request.Request(
            self.build_url(cursor),
            method="GET",
            headers={
                "Accept": "application/x-ndjson",
                "User-Agent": "NeoLabs-VCC-Telemetry-Collector/0.1.0",
                "X-VCC-Installation-ID": installation_id,
            },
        )
        with urllib.request.urlopen(request, context=self.ssl_context(), timeout=30) as response:
            content_length = response.headers.get("Content-Length")
            if content_length and int(content_length) > MAX_RESPONSE_BYTES:
                raise RuntimeError("telemetry response exceeds configured size limit")
            body = response.read(MAX_RESPONSE_BYTES + 1)
            if len(body) > MAX_RESPONSE_BYTES:
                raise RuntimeError("telemetry response exceeds configured size limit")
            assigned_pod = response.headers.get("X-VCC-Pod-ID", "").strip()
            next_cursor = response.headers.get("X-VCC-Next-Cursor", "").strip()

        if not assigned_pod:
            raise RuntimeError("telemetry response omitted X-VCC-Pod-ID")
        return list(self.parse_ndjson(body, assigned_pod)), next_cursor, assigned_pod

    def parse_ndjson(self, body: bytes, assigned_pod: str) -> Iterable[dict[str, Any]]:
        text = body.decode("utf-8")
        event_count = 0
        for line_number, raw_line in enumerate(text.splitlines(), start=1):
            line = raw_line.strip()
            if not line:
                continue
            event_count += 1
            if event_count > MAX_EVENTS_PER_RESPONSE:
                raise RuntimeError("telemetry response contains too many events")
            try:
                event = json.loads(line)
            except json.JSONDecodeError as exc:
                raise RuntimeError(f"invalid JSON on telemetry line {line_number}") from exc
            if not isinstance(event, dict):
                raise RuntimeError(f"telemetry line {line_number} is not a JSON object")
            missing = sorted(REQUIRED_EVENT_FIELDS.difference(event))
            if missing:
                raise RuntimeError(
                    f"telemetry line {line_number} is missing required fields: {', '.join(missing)}"
                )
            if event.get("synthetic") is not True:
                raise RuntimeError(f"telemetry line {line_number} is not marked synthetic")
            if event.get("pod_id") != assigned_pod:
                raise RuntimeError(f"telemetry line {line_number} does not match issued pod scope")
            yield event

    def verify_assigned_pod(self, assigned_pod: str) -> None:
        previous = read_optional(self.config.assigned_pod_path)
        if previous and previous != assigned_pod:
            raise RuntimeError("server-issued pod changed without local credential reset")
        if not previous:
            atomic_write(self.config.assigned_pod_path, assigned_pod + "\n")

    def append_events(self, events: list[dict[str, Any]]) -> None:
        if not events:
            return
        self.config.output_path.parent.mkdir(parents=True, exist_ok=True)
        with self.config.output_path.open("a", encoding="utf-8") as output:
            for event in events:
                output.write(json.dumps(event, separators=(",", ":"), sort_keys=True) + "\n")
            output.flush()
            os.fsync(output.fileno())

    def poll_once(self) -> None:
        cursor = read_optional(self.config.cursor_path)
        events, next_cursor, assigned_pod = self.fetch(cursor)
        self.verify_assigned_pod(assigned_pod)
        self.append_events(events)
        if next_cursor and next_cursor != cursor:
            atomic_write(self.config.cursor_path, next_cursor + "\n")
        self.failures = 0
        self.write_health(
            "healthy",
            "pod-scoped telemetry poll completed",
            assigned_pod=assigned_pod,
            events_received=len(events),
            cursor_present=bool(next_cursor or cursor),
        )

    def run(self) -> None:
        while self.running:
            if not self.enrolled():
                self.failures = 0
                self.write_health(
                    "unenrolled",
                    "waiting for an operator-approved VCC credential and endpoint",
                )
                time.sleep(self.config.poll_interval)
                continue

            try:
                self.poll_once()
            except urllib.error.HTTPError as exc:
                self.failures += 1
                status = "authentication_error" if exc.code in (401, 403) else "remote_error"
                self.write_health(status, f"telemetry service returned HTTP {exc.code}")
            except (urllib.error.URLError, TimeoutError, ssl.SSLError) as exc:
                self.failures += 1
                self.write_health("connection_error", type(exc).__name__)
            except Exception as exc:  # fail closed and expose only the exception type
                self.failures += 1
                self.write_health("validation_error", type(exc).__name__)

            delay = min(self.config.poll_interval * max(1, self.failures), 300)
            time.sleep(delay)


def main() -> int:
    try:
        config = Config.from_environment()
    except ValueError as exc:
        print(f"Configuration error: {exc}", file=sys.stderr)
        return 2

    collector = Collector(config)

    def stop(_signum: int, _frame: Any) -> None:
        collector.running = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    collector.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
