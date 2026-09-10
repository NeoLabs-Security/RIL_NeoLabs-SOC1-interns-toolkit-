"""Import validated local synthetic telemetry into the existing Wazuh pipeline."""
import hashlib
import json
from tools.local_telemetry import load_events


def run(args):
    from tools import neolabs as core
    # Authorization comes from the gateway, never from a user-selected pod.
    manifest = core.refresh(core.read_session())
    if not core.student_is_ready(manifest) or manifest.get('runtime_mode') != 'offline-fallback':
        core.fail('import requires a ready Offline Fallback assignment')
    try:
        events = load_events(args.file)
    except (OSError, ValueError, EOFError) as exc:
        core.fail(str(exc))
    for event in events:
        if (event.get('synthetic') is not True or
                event.get('pod_id') != manifest.get('pod_id') or
                event.get('scenario_id') != manifest.get('scenario_id') or
                not isinstance(event.get('schema_version'), str) or
                not event['schema_version'].startswith('1.') or
                not isinstance(event.get('event_time'), str) or not event['event_time'] or
                not isinstance(event.get('event_id'), str) or not event['event_id']):
            core.fail('local telemetry failed synthetic/pod/scenario/event validation; nothing imported')
    canonical = '\n'.join(json.dumps(e, sort_keys=True, separators=(',', ':')) for e in events) + '\n'
    scope = str(manifest.get('release_generation', '')) + ':' + str(manifest['pod_id'])
    key = 'local:' + hashlib.sha256((scope + canonical).encode()).hexdigest()
    # A separate exclusive lock prevents concurrent CLI imports racing the ledger.
    lock = core.HOME_STATE / 'local-import.lock'
    lock.parent.mkdir(parents=True, exist_ok=True)
    try:
        handle = lock.open('x')
    except FileExistsError:
        core.fail('another local import is active; if interrupted, inspect local-import.lock before recovery')
    try:
        with handle:
            seen = core.replayed_keys()
            pending = core.replay_pending()
            stack = core.start_wazuh_stack()
            if key not in seen and key not in pending:
                # Persist intent BEFORE append: an interrupted append is ambiguous,
                # so subsequent runs verify only, never blindly append again.
                pending[key] = events[0]['event_id']
                core.save_replay_pending(pending)
                core.append_to_wazuh(stack, canonical)
            if not core.verify_replay_indexed(stack, manifest, events[0]['event_id']):
                core.fail('import is pending: representative event is not searchable. Run doctor; retry verifies without appending again')
            seen.add(key)
            for event_id in dict.fromkeys(event['event_id'] for event in events[1:]):
                if not core.verify_replay_indexed(stack, manifest, event_id, wait=1):
                    core.fail('import remains pending: not all event IDs are searchable in wazuh-alerts-*. Retry verifies without appending again')
            pending.pop(key, None)
            core.save_replayed_keys(seen)
            core.save_replay_pending(pending)
            print(f'Threat Hunting ready: all {len(set(e["event_id"] for e in events))} distinct event IDs found in wazuh-alerts-*.')
            print('Open Threat Intelligence > Threat Hunting. Select the ingestion time range; filter data.pod_id and data.scenario_id.')
            print('Source timestamps remain in data.event_time. Baseline training alerts are not necessarily malicious activity.')
    finally:
        lock.unlink(missing_ok=True)
