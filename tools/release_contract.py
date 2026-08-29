"""NeoLabs student manifest protocol v2 validation and generation transitions."""
from __future__ import annotations
from typing import Any

PROTOCOL_VERSION = "2.0"
TRACKS = {"SOC", "PENTEST", "SUPPORT"}
RESOURCE_TYPES = {"SOC": "soc_enrolment.v1", "PENTEST": "pentest_targets.v1", "SUPPORT": "support_ticket_queue.v1"}

def validate_manifest(manifest: dict[str, Any], expected_track: str) -> dict[str, Any]:
    required = ("deployment_id", "deployment_channel", "scenario_id", "scenario_release",
                "release_generation", "student_ready", "lab_state", "runtime_mode",
                "pod_id", "track", "assignment_id", "resources")
    missing = [key for key in required if key not in manifest]
    if missing:
        raise ValueError("manifest missing required protocol fields: " + ", ".join(missing))
    if manifest.get("protocol_version") != PROTOCOL_VERSION:
        raise ValueError("unsupported NeoLabs protocol version")
    if manifest["track"] != expected_track or expected_track not in TRACKS:
        raise ValueError("manifest track does not match this toolkit")
    if manifest["student_ready"] is not True or manifest["lab_state"] != "STUDENT_READY":
        raise ValueError("deployment is not STUDENT_READY")
    if not isinstance(manifest["release_generation"], str) or not manifest["release_generation"]:
        raise ValueError("manifest release generation is invalid")
    if not isinstance(manifest["resources"], dict):
        raise ValueError("manifest resources are invalid")
    if not compatible_resource(manifest["resources"], RESOURCE_TYPES[expected_track]):
        raise ValueError("manifest resource contract is unsupported")
    return manifest

def generation_changed(previous: dict[str, Any] | None, current: dict[str, Any]) -> bool:
    return bool(previous) and (
        previous.get("deployment_id") != current.get("deployment_id")
        or previous.get("release_generation") != current.get("release_generation")
    )

def compatible_resource(resource: dict[str, Any], expected_type: str, versions=(1,)) -> bool:
    return resource.get("resource_type") == expected_type and resource.get("schema_version") in versions
