# Week 3 arena — Blue detection

Use this pack only while the central assignment explicitly opens `w03-credential-storm`.

1. Read [`arena-contract.yaml`](arena-contract.yaml) and the current Rules of Engagement.
2. Pull the current toolkit and run `START-NEOLABS-SOC.cmd arena` on Windows or `bash start-neolabs-soc.sh arena` on Linux. Enter the facilitator-issued arena URL and hidden Blue telemetry access code. Existing Wazuh data and credentials are reused.
3. Wait for `WEEK 3 BLUE WORKSTATION READY`, then open [`../../docs/week-03/credential-storm-blue-detection-guide.md`](../../docs/week-03/credential-storm-blue-detection-guide.md).
4. Open **NeoLabs — Week 3 Arena Operations** in Wazuh. It shows live HTTPS traffic and attacker IPs, synthetic usernames/account IDs, confirmed hijack alerts, arena runtime health and blacklisted-IP hits.
5. Record facts in `templates/week-03-blue-evidence-ledger.csv` without passwords, tokens or session material.
6. Hand confirmed containment requests to the IT Security Support responder, using the alert/event ID and account ID.
7. Validate a copied ledger offline with `python scripts/validate-week03-blue-ledger.py PATH.csv`.

To raise a local Wazuh alert whenever one exact source IP makes an arena HTTPS request:

```text
neolabs ip-blacklist add 198.51.100.8
neolabs ip-blacklist list
neolabs ip-blacklist remove 198.51.100.8
```

This is a detection-only local watchlist. It does not block traffic. CIDRs, ranges and hostnames are rejected.

Every matching HTTPS request creates a separate rule `100160` alert. A successful login to one of the 15 arena accounts creates rule `100122`, with the synthetic username, account ID and source IP. The account is considered protected only after the approved dashboard containment action succeeds.

The dedicated arena is pod-less. Do not use an old pod URL. A Blue point requires an observed failed attempt and approved containment before a successful login for that same synthetic account.
