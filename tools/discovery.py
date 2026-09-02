"""Resolve only explicitly promoted NeoLabs deployments over verified HTTPS."""
from __future__ import annotations
import json, os, ssl, urllib.parse, urllib.request
from pathlib import Path

def resolve_gateway(configured: str, state_dir: Path, channel: str = "ril-current", discovery_url: str | None = None) -> tuple[str, str | None]:
    discovery = (discovery_url or os.environ.get("NEOLABS_DISCOVERY_URL", "")).strip()
    if not discovery:
        return configured.rstrip("/"), None
    parsed=urllib.parse.urlsplit(discovery)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        raise ValueError("NEOLABS_DISCOVERY_URL must be verified HTTPS")
    endpoint=urllib.parse.urljoin(discovery.rstrip("/")+"/", f"api/v1/discovery/channels/{channel}")
    cache=state_dir/"discovery.json"
    try:
        with urllib.request.urlopen(endpoint, context=ssl.create_default_context(), timeout=15) as response:
            record=json.load(response)
        if record.get("state")!="STUDENT_READY" or record.get("healthy") is not True or record.get("protocol_version")!="2.0" or record.get("deployment_channel")!=channel or record.get("promoted") is not True:
            raise ValueError("discovery did not return a promoted compatible STUDENT_READY deployment")
        gateway=str(record.get("gateway_url", "")); target=urllib.parse.urlsplit(gateway)
        if target.scheme!="https" or not target.netloc or target.username or target.password: raise ValueError("discovery gateway URL is invalid")
        state_dir.mkdir(parents=True,exist_ok=True); cache.write_text(json.dumps(record,sort_keys=True),encoding="utf-8"); os.chmod(cache,0o600)
        return gateway.rstrip("/"), discovery.rstrip("/")
    except Exception as error:
        try: record=json.loads(cache.read_text(encoding="utf-8"))
        except Exception: raise ValueError("stable discovery is unavailable and no last-known-good deployment exists") from error
        if record.get("state")!="STUDENT_READY" or record.get("healthy") is not True or record.get("protocol_version")!="2.0" or record.get("deployment_channel")!=channel or record.get("promoted") is not True:
            raise ValueError("cached discovery record is not eligible") from error
        return str(record["gateway_url"]).rstrip("/"), discovery.rstrip("/")
