#!/usr/bin/env python3
"""Conservative, bounded updater for normal student Git clones."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def git(*args: str, timeout: int = 12) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True, timeout=timeout, check=False)


def main() -> int:
    if not (ROOT / ".git").exists() or git("remote", "get-url", "origin").returncode:
        print("[OK] Toolkit compatibility will be checked with the broker (managed/no-remote checkout).")
        return 0
    status = git("status", "--porcelain", "--untracked-files=normal")
    if status.returncode or status.stdout.strip():
        print("[WARN] Toolkit has local changes; automatic update skipped. Your files were not overwritten. Commit/stash your work, then update safely.", file=sys.stderr)
        return 0
    try:
        fetched = git("fetch", "--quiet", "origin", "main", timeout=int(os.environ.get("NEOLABS_UPDATE_TIMEOUT", "12")))
    except (subprocess.TimeoutExpired, ValueError):
        print("[WARN] Toolkit update check timed out; continuing with the installed compatible client.", file=sys.stderr)
        return 0
    if fetched.returncode:
        print("[WARN] Toolkit update check could not reach origin; continuing with the installed compatible client.", file=sys.stderr)
        return 0
    ancestor = git("merge-base", "--is-ancestor", "HEAD", "origin/main")
    if ancestor.returncode:
        print("[WARN] Toolkit branch cannot be safely fast-forwarded; no files were changed.", file=sys.stderr)
        return 0
    if git("diff", "--quiet", "HEAD", "origin/main").returncode == 0:
        print("[OK] Toolkit version compatible/current")
        return 0
    updated = git("merge", "--ff-only", "origin/main")
    if updated.returncode:
        print("[WARN] Safe fast-forward failed; no destructive recovery was attempted.", file=sys.stderr)
        return 0
    print("[OK] Toolkit safely fast-forwarded to current origin/main.")
    return 10


if __name__ == "__main__":
    raise SystemExit(main())
