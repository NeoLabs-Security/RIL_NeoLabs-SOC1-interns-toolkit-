# NeoLabs SOC Query Journal Template

> Record searches as they are performed so another analyst can reproduce the investigation. Replace secrets and private endpoints with approved references; never paste enrolment tokens or private keys.

## Case information

| Field | Entry |
|---|---|
| Case / assignment ID | |
| Analyst | |
| Assigned pod | |
| Investigation date | |
| Primary alert | |

## Query register

| Query ID | Time run (UTC) | Platform / source | Exact query or filter | Event-time range | Result count | Important result or negative finding | Evidence IDs | Next pivot |
|---|---|---|---|---|---|---|---|---|
| Q-001 | | Wazuh / OpenSearch / local tool | | | | | | |

## Detailed query record

### Q-___

**Question being tested:**  

**Data source and index/view:**  

**Exact query/filter/command:**

```text

```

**Time field used:** Event time / ingest time / other  
**Time range:**  
**Fields displayed or exported:**  
**Result summary:**  
**Relevant evidence IDs:**  
**Limitations:**  
**Decision / next query:**  

## Query-quality checks

- [ ] The query uses the intended field rather than only free-text search.
- [ ] Exact and analysed fields are distinguished where applicable.
- [ ] The event-time field and time zone are recorded.
- [ ] A zero-result search was checked against source health and retention.
- [ ] Filters inherited from a dashboard or saved view are recorded.
- [ ] Wildcards and broad searches are narrowed before drawing conclusions.
- [ ] Commands were run only against synthetic data or explicitly authorised systems.
- [ ] Output containing sensitive values was redacted before submission.

## Investigation summary

**Most useful query:**  

**Most important negative finding:**  

**Visibility gap discovered:**  

**Queries recommended for higher-tier review:**  
