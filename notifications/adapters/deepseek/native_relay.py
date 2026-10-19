"""Dedicated live DSH owner channel; never restores native authority from disk."""
import json
import os
import selectors
import sys
import time
from notifications.adapters.runtime import RouteStore, bridge, _run_open

PROTOCOL = 'stopwatch.dsh.native-approval.v1'


def _write(frame):
    payload = bridge._encode(frame)
    if len(payload) > 8192: raise ValueError('native reply exceeds bound')
    sys.stdout.buffer.write(payload + b'\n'); sys.stdout.buffer.flush()


def serve(directory):
    # Validate storage before announcing readiness, including the route directory.
    bridge._close(bridge._directories(directory))
    routes = RouteStore(directory)
    list(routes.records())
    pending = {}
    selector = selectors.DefaultSelector()
    selector.register(sys.stdin.buffer, selectors.EVENT_READ)
    buffered = b''
    _write({'type': 'ready', 'protocol': PROTOCOL})
    try:
        while True:
            for _key, _mask in selector.select(0.05):
                data = os.read(sys.stdin.fileno(), 8193)
                if not data:
                    if buffered: raise ValueError('partial native frame')
                    return
                buffered += data
                while b'\n' in buffered:
                    line, buffered = buffered.split(b'\n', 1)
                    if len(line) > 8192: raise ValueError('native frame too large')
                    message = json.loads(line)
                    if not isinstance(message, dict) or set(message) != {'type', 'event'}: raise ValueError('invalid native frame')
                    event = bridge.validate_event(message['event'])
                    if event['source'] != 'deepseek': raise ValueError('unexpected native source')
                    identity = tuple(event[k] for k in bridge.IDENTITY)
                    if message['type'] == 'event':
                        if event['canDecide']:
                            now = int(time.time() * 1000)
                            if (event['state'] != 'pending' or event['kind'] != 'approval'
                                    or not event['createdAt'] <= now < event['leaseDeadline'] <= event['createdAt'] + 15000
                                    or not all(0 < len(event[k]) <= limit and all(32 <= ord(c) <= 126 for c in event[k])
                                               for k, limit in [('title', 48), ('detail', 192)]) or event['model']):
                                raise ValueError('invalid native capability')
                            if identity not in pending and len(pending) >= 64: raise ValueError('native inventory full')
                            if identity not in pending:
                                pending[identity] = {'event': event, 'owner': routes.acquire_owner(event),
                                                     'deadline': event['createdAt'] + 60000}
                            else:
                                pending[identity]['event'] = event
                        else:
                            previous = pending.pop(identity, None)
                            if previous is not None: os.close(previous['owner'])
                        routes.save(event)
                        bridge.emit(directory, event)
                        _write({'type': 'published', 'eventId': event['eventId']})
                    elif message['type'] == 'open':
                        if event['canDecide'] or identity in pending: raise ValueError('OPEN requires ownership release')
                        saved = next((e for e, _ in routes.records() if tuple(e[k] for k in bridge.IDENTITY) == identity), None)
                        if saved != event: raise ValueError('OPEN route mismatch')
                        _run_open(routes.command(event)[0])
                    else: raise ValueError('unknown native frame')
                if len(buffered) > 8192: raise ValueError('partial native frame too large')
            for entry in list(pending.values()):
                event = entry['event']
                now = int(time.time() * 1000)
                # Keep OPEN delivery alive after decision expiry. A stalled parent
                # must still release its exclusive native continuation. The
                # original ownership window cannot renew with incoming leases.
                if now >= entry['deadline']:
                    raise ValueError('native ownership window expired')
                for decision in bridge.decisions(directory, event, now=now):
                    expected = {'v', 'decisionId', *bridge.IDENTITY, 'action', 'createdAt', 'leaseDeadline'}
                    if (set(decision) != expected or decision['action'] not in {'open', 'allow_once', 'decline'}
                            or not all(bridge._integer(decision[k]) for k in ('createdAt', 'leaseDeadline'))):
                        raise ValueError('invalid native decision')
                    _write({'type': 'decision', 'decision': decision})
    finally:
        selector.close()
        # EOF/error/deadline disables the parent capability and relinquishes
        # persisted routes. SIGKILL releases kernel locks automatically; the
        # generic consumer can then use OPEN once the decision lease is old.
        try:
            for entry in pending.values():
                event = entry['event']
                event = dict(event, canDecide=False, createdAt=max(int(time.time()*1000), event['createdAt']+1))
                routes.save(event)
                bridge.emit(directory, event)
        finally:
            for entry in pending.values(): os.close(entry['owner'])
