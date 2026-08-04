# NeoLabs SOC Evidence Log Template

> Record evidence used in an authorised investigation. This template is for training and case discipline; it does not replace organisational forensic procedures or legal chain-of-custody requirements.

## Case information

| Field | Entry |
|---|---|
| Case / assignment ID | |
| Analyst | |
| Assigned pod | |
| Investigation start | YYYY-MM-DD HH:MM UTC |
| Report path / link | |

## Evidence register

| Evidence ID | Date/time collected (UTC) | Event time range | Source system | Evidence type | Collection method / query | Original location | File or record hash, when applicable | Handling / redaction note | Relevance |
|---|---|---|---|---|---|---|---|---|---|
| EV-001 | | | | Alert / raw event / export / screenshot / config / owner confirmation | | | | | |

## Evidence-quality checks

For each important item, consider:

- Was the source operating during the event period?
- Is the timestamp event time, ingest time or alert time?
- Is the time zone known?
- Could the record be duplicated, delayed or truncated?
- Did a decoder or parser alter the displayed fields?
- Is the value source-generated, user-controlled or enrichment data?
- Is the evidence complete enough for the conclusion?
- Was sensitive data redacted without removing necessary meaning?

## Evidence statements

Use one statement per important claim.

### EV-___

**Observed fact:**  

**Source and time:**  

**What this evidence supports:**  

**What this evidence does not prove:**  

**Quality or visibility limitation:**  

**Related evidence:**  

## Transfer or review record

| Date/time UTC | Evidence ID(s) | From | To / reviewer | Purpose | Method | Confirmation |
|---|---|---|---|---|---|---|
| | | | | | | |

## Final checks

- [ ] Every report fact points to an evidence ID or clearly identified source.
- [ ] No credential, private key or enrolment token is included.
- [ ] Personal or cross-pod information is removed or escalated rather than published.
- [ ] Screenshots show the required context and do not replace available raw records.
- [ ] UTC conversions are documented.
- [ ] Negative findings include the source, query and time range.
