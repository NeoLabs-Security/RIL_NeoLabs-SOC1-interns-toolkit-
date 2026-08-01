# Authoritative Source Register

**Programme:** NeoLabs / RIL SOC Level 1 Internship  
**Review baseline:** 1 August 2026  
**Purpose:** Record the primary public literature used to research, verify and maintain student-facing material in this repository.

## Source hierarchy

1. Official standards, government publications and product documentation.
2. Official project specifications and release repositories.
3. Vendor-neutral technical standards and recognised professional guidance.
4. Community material only when it identifies a practical issue that is independently verified against a primary source.

A source being listed here does not mean its wording may be copied. NeoLabs material must explain concepts in original language, provide attribution where required and comply with the source licence.

## Security operations, incident response and logging

| ID | Authority | Source | Use in toolkit | Status / caution |
|---|---|---|---|---|
| NIST-IR-01 | NIST | [SP 800-61 Rev. 3 — Incident Response Recommendations and Considerations for Cybersecurity Risk Management](https://csrc.nist.gov/pubs/sp/800/61/r3/final) | Current incident-response governance, preparation, detection, response, recovery and improvement | Final, published April 2025; supersedes Rev. 2 |
| NIST-LOG-01 | NIST | [SP 800-92 — Guide to Computer Security Log Management](https://csrc.nist.gov/pubs/sp/800/92/final) | Enduring log-management concepts, operational responsibilities, retention and protection | Final 2006 publication; use with modern supplementary guidance |
| NIST-LOG-02 | NIST | [SP 800-92 Rev. 1 Initial Public Draft — Cybersecurity Log Management Planning Guide](https://csrc.nist.gov/pubs/sp/800/92/r1/ipd) | Modern planning language and log-management improvement playbook | Draft published October 2023; label as draft when cited |
| ACSC-LOG-01 | Australian Signals Directorate and international partners | [Best practices for event logging and threat detection](https://www.cyber.gov.au/business-government/secure-design/secure-by-design/best-practices-for-event-logging-and-threat-detection) | High-quality security events, central collection, baseline-aware monitoring and secure storage | Re-check publication date and revisions during annual review |
| CISA-IR-01 | CISA | [Federal Government Cybersecurity Incident and Vulnerability Response Playbooks](https://www.cisa.gov/news-events/news/federal-government-cybersecurity-incident-and-vulnerability-response-playbooks) | Playbook structure, coordination and response workflow examples | Adapt concepts; do not imply VCC is a federal environment |

## Wazuh

| ID | Authority | Source | Use in toolkit | Status / caution |
|---|---|---|---|---|
| WAZUH-DOC-01 | Wazuh | [Current documentation](https://documentation.wazuh.com/current/) | Primary source for architecture, configuration, dashboard, WQL, decoders, rules and troubleshooting | Version-sensitive; every tutorial must state tested release |
| WAZUH-DOCKER-01 | Wazuh | [wazuh-docker repository](https://github.com/wazuh/wazuh-docker) | Official container topology and certificate-generation files | NeoLabs baseline currently pins `v4.14.6`; upgrades require testing |
| WAZUH-JSON-01 | Wazuh | [JSON decoder](https://documentation.wazuh.com/current/user-manual/ruleset/decoders/json-decoder.html) | Parsing VCC synthetic JSON telemetry and teaching dynamic fields | Test nested arrays and null handling with supplied datasets |
| WAZUH-RULE-01 | Wazuh | [Custom rules](https://documentation.wazuh.com/current/user-manual/ruleset/rules/custom.html) | Safe local rule authoring, identifiers and validation | Custom IDs must remain within approved local ranges |
| WAZUH-TEST-01 | Wazuh | [Testing decoders and rules](https://documentation.wazuh.com/current/user-manual/ruleset/testing.html) | `wazuh-logtest` workflow and rule validation | Students test synthetic records only |
| WAZUH-DASH-01 | Wazuh | [Navigating the Wazuh dashboard](https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/navigating-the-wazuh-dashboard.html) | Dashboard tutorials and terminology | Screenshots and menu labels can change by release |
| WAZUH-WQL-01 | Wazuh | [Filtering data using Wazuh Query Language](https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/filtering-data.html) | Dashboard and API filtering reference | Do not confuse WQL with Microsoft KQL or OpenSearch DSL |
| WAZUH-API-01 | Wazuh | [Securing the Wazuh server API](https://documentation.wazuh.com/current/user-manual/api/securing-api.html) | API exposure and RBAC principles | Student deployment keeps the API non-public by default |

## Threat behaviour, detection and analytic rules

| ID | Authority | Source | Use in toolkit | Status / caution |
|---|---|---|---|---|
| MITRE-ATTACK-01 | MITRE | [ATT&CK current site](https://attack.mitre.org/) | Adversary behaviour, tactics, techniques and defensive mapping | Current site version at review: v19.1, 28 April 2026 |
| MITRE-DET-01 | MITRE | [Detection Strategies](https://attack.mitre.org/detectionstrategies/) | Modern telemetry-first detection design | Prefer Detection Strategies, Analytics and Data Components over deprecated flat data-source teaching |
| SIGMA-01 | SigmaHQ | [Sigma specification](https://sigmahq.io/docs/basics/rules.html) | Vendor-neutral detection-rule structure and metadata | A Sigma example is not automatically executable in Wazuh |
| SIGMA-02 | SigmaHQ | [Sigma rule repository](https://github.com/SigmaHQ/sigma) | Style examples and behavioural coverage | Review licence and avoid copying large rule sets into the toolkit |

## Windows, Linux and endpoint telemetry

| ID | Authority | Source | Use in toolkit | Status / caution |
|---|---|---|---|---|
| MS-SYSMON-01 | Microsoft Sysinternals | [Sysmon documentation](https://learn.microsoft.com/sysinternals/downloads/sysmon) | Sysmon purpose, configuration and event semantics | Event availability depends on Sysmon version and configuration |
| MS-AUDIT-01 | Microsoft Learn | [Windows security auditing](https://learn.microsoft.com/windows/security/threat-protection/auditing/basic-security-audit-policies) | Windows Security log channels and audit-policy dependencies | Use event documentation for each Event ID; avoid memorisation without context |
| MS-EVENT-01 | Microsoft Learn | [4624 successful logon](https://learn.microsoft.com/windows/security/threat-protection/auditing/event-4624) and related event pages | Authentication examples and field interpretation | Logon types require context and do not by themselves prove malicious activity |
| SYSTEMD-01 | freedesktop.org | [journalctl manual](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html) | Linux journal queries and field filtering | Distribution retention and permissions differ |
| RHEL-AUDIT-01 | Red Hat | [Security auditing documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/security_hardening/auditing-the-system_security-hardening) | `auditd`, `ausearch` and audit-key examples | Commands must be tested against the stated distribution/version |

## Cloud, web and data sources

| ID | Authority | Source | Use in toolkit | Status / caution |
|---|---|---|---|---|
| AWS-CT-01 | AWS | [CloudTrail user guide](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html) | Cloud identity, API activity, event structure and coverage limits | Management, data, network and Insights events differ |
| AWS-VPC-01 | AWS | [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html) | Network-flow interpretation and limitations | Flow records show metadata, not application payload or intent |
| AWS-R53-01 | AWS | [Route 53 Resolver query logging](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-query-logs.html) | DNS investigation examples | Collection must be enabled before events exist |
| OWASP-T10-01 | OWASP | [OWASP Top 10:2025](https://owasp.org/Top10/2025/) | Current web-application risk awareness | Current list differs materially from 2021; use 2025 names and order |
| OWASP-API-01 | OWASP | [API Security Top 10](https://owasp.org/API-Security/) | API abuse, authorization and logging examples | Awareness list, not a complete testing methodology |
| NGINX-LOG-01 | NGINX | [HTTP log module](https://nginx.org/en/docs/http/ngx_http_log_module.html) | Access-log fields and format examples | Proxy headers and custom formats affect source interpretation |
| POSTGRES-LOG-01 | PostgreSQL | [Error reporting and logging](https://www.postgresql.org/docs/current/runtime-config-logging.html) | Database error, authentication and statement-context examples | Detailed statement logging may expose sensitive information |

## Search, indexing and containers

| ID | Authority | Source | Use in toolkit | Status / caution |
|---|---|---|---|---|
| OPENSEARCH-01 | OpenSearch | [Query DSL](https://docs.opensearch.org/latest/query-dsl/) | Exact, full-text, Boolean and range-query concepts | Field mappings determine query behaviour |
| OPENSEARCH-02 | OpenSearch | [Dashboards Discover](https://docs.opensearch.org/latest/dashboards/discover/index-discover/) | Investigation pivots and saved searches | Wazuh dashboard packaging may differ from upstream OpenSearch Dashboards |
| DOCKER-01 | Docker | [Docker Compose documentation](https://docs.docker.com/compose/) | Student Wazuh deployment, volumes, health checks and secrets | Host resource and kernel requirements still apply |
| DOCKER-SEC-01 | Docker | [Docker security](https://docs.docker.com/engine/security/) | Least exposure, daemon boundary and container limitations | Docker access is effectively privileged on the learner's own host |

## Maintenance requirements

- Revalidate version-sensitive sources before each cohort.
- Record the tested Wazuh, Docker, browser and operating-system versions in each tutorial.
- Mark draft standards as drafts.
- Do not claim a log proves compromise when it only records an observation.
- Add new sources to this register before relying on them for a published module.
