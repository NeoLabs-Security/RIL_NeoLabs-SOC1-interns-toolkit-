#!/usr/bin/env python3
"""NeoLabs SOC CLI entry point with workstation diagnostics."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

# Support both the installed/module entry point and direct execution from a
# repository checkout. When Python executes `tools/cli.py` directly, sys.path[0]
# is the tools directory, so the repository root must be added before importing
# the `tools` package. The supported launchers use `python -m tools.cli`, but the
# direct path remains safe for diagnostics and regression testing.
if __package__ in {None, ""}:
    repo_root = str(Path(__file__).resolve().parents[1])
    if repo_root not in sys.path:
        sys.path.insert(0, repo_root)

from tools import neolabs as core


def _doctor_help() -> None:
    print("usage: neolabs doctor")
    print()
    print("Verify each local SOC telemetry stage:")
    print("  VCC authentication -> live/replay surface -> raw event file ->")
    print("  Wazuh rule engine -> Filebeat -> indexer -> dashboard")
    print()
    print("The command is read-only with respect to VCC server state and does not change pod scope.")


def do_doctor() -> int:
    try:
        session = core.read_session()
        manifest = core.refresh(session)
    except SystemExit as exc:
        print(f"[FAIL] 1/7 VCC authentication — {exc}", file=sys.stderr)
        return 1

    pod = str(manifest.get("pod_id") or "")
    lab_state = str(manifest.get("lab_state") or "LIVE")
    scenario = str(manifest.get("scenario_id") or "not published")
    print(f"[PASS] 1/7 VCC authentication — session accepted; pod={pod}; scenario={scenario}; state={lab_state}.")

    replay_packs = "unknown"
    if lab_state in {"REPLAY", "CLOUD_LIVE", "ENDPOINT_LIVE"}:
        try:
            replay = core.request_json(
                core.validate_base_url(str(session["base_url"])),
                "/api/v1/lab-access/replay",
                token=str(session["session_token"]),
            )
            packs = replay.get("telemetry_packs", [])
            if isinstance(packs, list):
                replay_packs = str(len(packs))
        except SystemExit:
            # Authentication was already proven. The local doctor will still test
            # raw/indexed data and report the replay surface without mutating it.
            replay_packs = "unknown"

    script = core.ROOT / "wazuh-stack" / "scripts" / "doctor.sh"
    if not script.is_file():
        print("[FAIL] Local doctor script is missing from this toolkit.", file=sys.stderr)
        return 2

    env = os.environ.copy()
    env.update(
        {
            "NEOLABS_DOCTOR_POD": pod,
            "NEOLABS_DOCTOR_LAB_STATE": lab_state,
            "NEOLABS_DOCTOR_REPLAY_PACKS": replay_packs,
        }
    )
    try:
        result = subprocess.run(["bash", str(script)], cwd=script.parent.parent, env=env, check=False)
    except OSError as exc:
        print(f"[FAIL] Could not run local SOC doctor: {exc}", file=sys.stderr)
        return 2
    return int(result.returncode)


def main() -> int:
    args = sys.argv[1:]
    if args and args[0] == "doctor":
        if len(args) > 1 and args[1] in {"-h", "--help"}:
            _doctor_help()
            return 0
        if len(args) != 1:
            print("ERROR: `neolabs doctor` does not accept additional arguments.", file=sys.stderr)
            return 2
        return do_doctor()

    if len(args) == 1 and args[0] in {"-h", "--help"}:
        help_text = core.build_parser().format_help()
        marker = "    disconnect"
        if marker in help_text:
            help_text = help_text.replace(marker, "    doctor              verify VCC-to-Wazuh telemetry health\n" + marker, 1)
        else:
            help_text += "\n  doctor              verify VCC-to-Wazuh telemetry health\n"
        print(help_text, end="" if help_text.endswith("\n") else "\n")
        return 0

    return core.main()


if __name__ == "__main__":
    raise SystemExit(main())
