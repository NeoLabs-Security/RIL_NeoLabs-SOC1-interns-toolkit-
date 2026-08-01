from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from collector import Collector, Config


class CollectorValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        self.config = Config(
            endpoint="https://telemetry.example.invalid/api/v1/soc/telemetry",
            certificate=root / "client.crt",
            private_key=root / "client.key",
            ca_certificate=root / "ca.crt",
            installation_id_path=root / "installation-id",
            cursor_path=root / "cursor",
            assigned_pod_path=root / "assigned-pod",
            output_path=root / "events.ndjson",
            health_path=root / "health.json",
            poll_interval=15,
        )
        self.collector = Collector(self.config)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    @staticmethod
    def event(**overrides: object) -> dict[str, object]:
        event: dict[str, object] = {
            "schema_version": "1.0",
            "event_id": "evt-001",
            "event_time": "2026-08-01T09:14:21Z",
            "pod_id": "pod-03",
            "event_type": "authentication",
            "synthetic": True,
        }
        event.update(overrides)
        return event

    def encode(self, *events: dict[str, object]) -> bytes:
        return "\n".join(json.dumps(event) for event in events).encode("utf-8")

    def test_valid_event_is_accepted(self) -> None:
        events = list(self.collector.parse_ndjson(self.encode(self.event()), "pod-03"))
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["event_id"], "evt-001")

    def test_cross_pod_event_is_rejected(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "issued pod scope"):
            list(
                self.collector.parse_ndjson(
                    self.encode(self.event(pod_id="pod-04")),
                    "pod-03",
                )
            )

    def test_non_synthetic_event_is_rejected(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "not marked synthetic"):
            list(
                self.collector.parse_ndjson(
                    self.encode(self.event(synthetic=False)),
                    "pod-03",
                )
            )

    def test_missing_required_field_is_rejected(self) -> None:
        event = self.event()
        event.pop("event_time")
        with self.assertRaisesRegex(RuntimeError, "missing required fields"):
            list(self.collector.parse_ndjson(self.encode(event), "pod-03"))

    def test_server_issued_pod_cannot_change_silently(self) -> None:
        self.collector.verify_assigned_pod("pod-03")
        with self.assertRaisesRegex(RuntimeError, "changed without local credential reset"):
            self.collector.verify_assigned_pod("pod-04")

    def test_poll_url_never_adds_a_pod_selector(self) -> None:
        url = self.collector.build_url("cursor-123")
        self.assertIn("cursor=cursor-123", url)
        self.assertIn("limit=1000", url)
        self.assertNotIn("pod", url.lower())


if __name__ == "__main__":
    unittest.main()
