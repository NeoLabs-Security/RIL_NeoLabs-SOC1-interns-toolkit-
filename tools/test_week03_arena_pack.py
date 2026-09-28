from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


class Week03ArenaPackTests(unittest.TestCase):
    def test_validator_accepts_one_valid_row_and_rejects_out_of_scope_account(self):
        script = Path(__file__).parents[1] / "scripts" / "validate-week03-blue-ledger.py"
        header = "case_id,account_id,event_time_utc,event_type,outcome,source_ip,alert_or_event_id,query_time_window_utc,evidence_reference,analyst,notes\n"
        with tempfile.TemporaryDirectory() as directory:
            ledger = Path(directory) / "ledger.csv"
            ledger.write_text(header + "C-1,syn-credential-storm-pod-01-01,2026-09-28T09:30:00Z,login,failure,192.0.2.10,E-1,09:00Z/10:00Z,EV-1,analyst,\n", encoding="utf-8")
            self.assertEqual(subprocess.run(["python3", str(script), str(ledger)], check=False).returncode, 0)
            ledger.write_text(header + "C-1,real-user,2026-09-28T09:30:00Z,login,failure,192.0.2.10,E-1,09:00Z/10:00Z,EV-1,analyst,\n", encoding="utf-8")
            self.assertEqual(subprocess.run(["python3", str(script), str(ledger)], check=False).returncode, 1)


if __name__ == "__main__":
    unittest.main()
