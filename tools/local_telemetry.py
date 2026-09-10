"""Bounded, read-only local NDJSON analysis; no network or runtime dependencies."""
import gzip
import json
from pathlib import Path

MAX_BYTES = 32 * 1024 * 1024
MAX_EVENTS = 100000


def load_events(path):
    path = Path(path)
    opener = gzip.open if path.suffix.lower() == '.gz' else open
    with opener(path, 'rb') as stream:
        raw = stream.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError('Telemetry exceeds the 32 MiB expanded-size limit')
    events = []
    for number, line in enumerate(raw.decode('utf-8-sig').splitlines(), 1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValueError(f'Invalid JSON on line {number}') from exc
        if not isinstance(event, dict):
            raise ValueError(f'Expected an event object on line {number}')
        events.append(event)
        if len(events) > MAX_EVENTS:
            raise ValueError('Telemetry exceeds the 100000-event limit')
    if not events:
        raise ValueError('Telemetry file contains no events')
    return events


def analyze(args):
    try:
        events = load_events(args.file)
    except (OSError, ValueError, EOFError) as exc:
        raise SystemExit(f'ERROR: {exc}') from exc
    # ASCII JSON escapes terminal control characters and preserves original values.
    lines = [json.dumps(event, ensure_ascii=True, sort_keys=True) for event in events]
    matches = [line for line in lines if not args.contains or args.contains.casefold() in line.casefold()]
    if args.limit < 1:
        raise SystemExit('ERROR: --limit must be positive')
    print(f'LOCAL FILE ANALYSIS ONLY — {len(events)} events; {len(matches)} matching; showing up to {args.limit}.')
    print('These are source records, not Wazuh alerts. Local file contents are not authenticated.')
    for line in matches[:args.limit]:
        print(line)
