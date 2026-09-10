# Local telemetry analysis

Version 1; reviewed 2026-09-10.

Objective: read downloaded source events, filter records and document findings without Docker, Wazuh or an active session. NDJSON contains one JSON event object per line; it is not an alert index.

From the toolkit directory, using native Python on Windows CMD:

The normal launchers also support local analysis:

Windows CMD or PowerShell (native Python 3.10+; no WSL/Docker required):

```text
.\neolabs.cmd offline analyze --file "C:\path\events.ndjson.gz"
```

Linux (Python 3.10+):

```text
bash neolabs offline analyze --file "/path/events.ndjson.gz"
```

Both preserve the caller's directory for relative file paths and return a nonzero exit code on errors. On Windows, existing login and download commands still use WSL and its existing session; local analysis uses native Python. For an entirely native Windows download, run both login and download with `python -m tools.cli` so they share the native session. The Python commands below also work directly:

```text
python -m tools.cli offline analyze --file "C:\path\events.ndjson.gz"
python -m tools.cli offline analyze --file "C:\path\events.ndjson" --contains "failed" --limit 100
```

On Linux/macOS use `python3` instead of `python`. Plain NDJSON/JSONL and gzip-compressed NDJSON are supported. A JSON array, CSV or ZIP is not supported. Gzip filenames must end in `.gz`.

If telemetry has not yet been downloaded, first log in to your instructor-provided fallback URL using the hidden Access Code prompt, then run:

```text
python -m tools.cli offline download
```

Download requires internet and a ready fallback assignment. It validates synthetic events and server-assigned pod/scenario before saving. Existing files are left unchanged. Analyze needs only the file; it makes no network requests and grants no access to other pods. Untrusted local files are not proof of assignment or authenticity.

Exercise: inspect the first 50 records, filter a relevant identity or action, compare original timestamps, and record event IDs and supporting fields in your evidence journal. Explain what the records establish and what remains uncertain. A text match is not a detection verdict. Keep original evidence unchanged and do not share sensitive records publicly.

The `analyze` command does not inject records into Wazuh. To import a downloaded file, use the separate command below after setting up Wazuh and logging into the fallback:

Windows CMD/PowerShell (existing WSL2/Docker Wazuh setup required):

```text
.\neolabs.cmd offline download
.\neolabs.cmd offline import --file "C:\path\downloaded.ndjson"
```

Linux:

```text
bash neolabs offline download
bash neolabs offline import --file "/path/downloaded.ndjson"
```

Replace the example path with the saved file. Windows import translates native Windows paths into WSL. Import requires internet to refresh assignment authorization; the file supplies the events, not their authorization. It validates every record before ingestion, preserves timestamps, starts the existing Wazuh stack, and verifies a representative event is searchable. This is not proof every source record generated an alert. No pod override is available.

Repeated imports of identical content in the same generation do not append again. Pending imports only retry verification. An interrupted append is deliberately not retried blindly: ask the mentor to inspect the ledger and ingestion state. Do not delete state files to force a retry. Local-file deduplication is separate from online replay history; avoid using both methods for the same events.

After success, open the dashboard with an appropriate time filter. You can return later without importing again while indexed data remains within retention and the stack is running. Do not delete Docker volumes. Existing `connect` behavior remains unchanged; missing dashboard alerts still require ingestion/indexing diagnostics (`neolabs doctor`).

Reference: Python standard-library `json` and `gzip` module documentation: https://docs.python.org/3/library/json.html and https://docs.python.org/3/library/gzip.html.
