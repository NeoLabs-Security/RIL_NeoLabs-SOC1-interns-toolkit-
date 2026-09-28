# Week 3 arena — Blue detection

Use this pack only while the central assignment explicitly opens `w03-credential-storm`.

1. Read [`arena-contract.yaml`](arena-contract.yaml) and the current Rules of Engagement.
2. Open [`../../docs/week-03/credential-storm-blue-detection-guide.md`](../../docs/week-03/credential-storm-blue-detection-guide.md).
3. Use the Wazuh query card to locate failed, successful and containment events.
4. Record facts in `templates/week-03-blue-evidence-ledger.csv` without passwords, tokens or session material.
5. Hand confirmed containment requests to the IT Security Support responder, using the alert/event ID and account ID.
6. Validate a copied ledger offline with `python scripts/validate-week03-blue-ledger.py PATH.csv`.

The dedicated arena is pod-less. Do not use an old pod URL. A Blue point requires an observed failed attempt and approved containment before a successful login for that same synthetic account.
