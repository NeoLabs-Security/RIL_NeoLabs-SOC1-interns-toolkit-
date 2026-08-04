# NeoLabs SOC Level 1 Toolkit — Release Readiness

## Candidate

- Release stage: Version 1 release candidate
- Toolkit branch: `codex/foundation-and-wazuh-scaffold`
- VCC control-plane branch: `codex/soc-enrolment-control-plane`
- Intended use: authorised NeoLabs/RIL synthetic SOC Level 1 internship training
- Deployment status: not merged, not deployed and no real cohort credentials issued

## Repository completion checklist

| Area | Status | Evidence |
|---|---|---|
| SOC curriculum | Passed | Eight progressive modules, guided lab, templates and capstone rubric |
| Wazuh architecture and setup | Passed | Pinned Wazuh 4.14.7 topology, setup scripts and handbook |
| Student access boundaries | Passed | No direct host, EC2, AWS console, database, private network or mentor-dashboard access |
| Credential handling | Passed | Local key generation, single-use bootstrap tokens and ignored credential paths |
| Pod isolation | Passed | Server-derived pod scope and collector cross-pod denial |
| Certificate exchange | Passed | Isolated CSR exchange with an actual training CA and signed client certificates |
| Token replay denial | Passed | Consumed token rejected during the end-to-end rehearsal |
| Client pod selector denial | Passed | Telemetry request containing a pod selector rejected |
| Credential revocation | Passed | Revoked client certificate denied telemetry access |
| Assignment revocation | Passed | Revoked assignment denied the previously issued certificate |
| Synthetic-only telemetry | Passed | Ingestion and collector checks reject events not marked synthetic |
| Backup and restore | Passed | Temporary Docker volume archived, checksummed, deleted, recreated and restored |
| Linux workstation profile | Passed | Automated compatibility check in CI |
| WSL2 and macOS guidance | Documented | Cohort-machine verification remains an operator rollout step |
| Secret scanning | Passed | Repository history and tracked-file boundary checks |
| Compose and source validation | Passed | API tests, Python tests, shell syntax, XML, NDJSON, Compose and Dockerfile checks |
| NeoLabs publication system | Passed | Visual system, print stylesheet and automated PDF build |
| Final publication set | Passed | Analyst handbook, Wazuh guide, templates, lab pack and complete toolkit generated |

## Publication artifacts

The publication workflow produces:

- `NeoLabs_SOC_L1_Analyst_Handbook.pdf`
- `NeoLabs_SOC_L1_Wazuh_Guide.pdf`
- `NeoLabs_SOC_L1_Investigation_Templates.pdf`
- `NeoLabs_SOC_L1_Lab_Pack.pdf`
- `NeoLabs_SOC_L1_Complete_Toolkit.pdf`

The current visual identity uses a repository-contained NeoLabs text wordmark. No external font or unapproved logo asset is distributed.

## Operator-controlled rollout tasks

The following are intentional release operations, not unfinished implementation:

1. review and approve both draft pull requests;
2. merge through the organisation's approved branch-protection process;
3. configure deployment secrets outside Git;
4. deploy the VCC control plane in the isolated training environment;
5. verify DNS, public TLS and private service connectivity;
6. perform a controlled operator smoke test after deployment;
7. test the selected cohort's actual Linux, WSL2 or macOS machines;
8. assign interns to pods and issue individual short-lived enrolment tokens;
9. publish the reviewed PDF artifacts from a tagged commit;
10. record rollout date, reviewers, exceptions and rollback owner.

## Stop conditions

Do not release to students when:

- either required CI workflow is failing;
- the control plane is using example or test secrets;
- public TLS verification is disabled;
- students can select pod scope locally;
- indexer or Wazuh API ports are publicly exposed;
- private keys, tokens or certificates are present in Git;
- the deployed version differs from the reviewed candidate without a new validation run;
- a cohort workstation fails the compatibility check;
- the operator cannot revoke an assignment and credential promptly.

## Approval record

Complete this section during release review:

```text
Toolkit commit:
VCC control-plane commit:
Technical reviewer:
Security reviewer:
Programme owner:
Publication reviewer:
Deployment date:
Rollback owner:
Approved exceptions:
```
