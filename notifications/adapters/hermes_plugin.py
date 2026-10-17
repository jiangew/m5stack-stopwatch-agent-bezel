"""Hermes agent plugin, separate from gateway hooks. Observers never decide."""
import os
from pathlib import Path
import sys
import threading
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from notifications.adapters.runtime import Publisher, target


class Observer:
    def __init__(self, publisher):
        self.publisher = publisher
        self.children = set()
        self.pending = {}
        self.lock = threading.RLock()

    def subagent_start(self, child_session_id=None, **_):
        if isinstance(child_session_id, str):
            with self.lock: self.children.add(child_session_id)

    def on_session_end(self, session_id=None, turn_id=None, completed=None, failed=None, interrupted=None,
                       model='', parent_session_id=None, **_):
        with self.lock:
            if session_id in self.children or parent_session_id: return
            if not all(isinstance(v, str) and v for v in [session_id, turn_id]): return
            if not all(type(v) is bool for v in [completed, failed, interrupted]): return
            # A finalized native turn withdraws all its observed attention, even when a
            # duplicate callback made individual post-response correlation ambiguous.
            for identity in list(self.pending):
                if identity[:2] != (session_id, turn_id): continue
                for request in self.pending.pop(identity):
                    self.publisher.publish('hermes', session_id, turn_id, request, 'approval',
                                           'Hermes approval', 'Open on Mac: native approval observer',
                                           state='resolved', stored_session=session_id)
            if interrupted: kind, detail = 'failed', 'Turn interrupted'
            elif failed: kind, detail = 'failed', 'Turn failed'
            elif completed: kind, detail = 'done', 'Turn completed'
            else: return
            target(session_id)
            if not isinstance(model, str) or len(model.encode()) > 32 or not model.isascii(): model = ''
            self.publisher.publish('hermes', session_id, turn_id, 'turn-complete', kind,
                                   'Hermes completed' if kind == 'done' else 'Hermes stopped', detail,
                                   model=model, stored_session=session_id)

    def _identity(self, context):
        values = tuple(context.get(k) for k in ['session_id', 'turn_id', 'tool_call_id'])
        return values if all(isinstance(x, str) and x for x in values) and values[0] not in self.children else None

    def pre_approval_request(self, **context):
        with self.lock:
            identity = self._identity(context)
            if identity is None: return
            if sum(len(x) for x in self.pending.values()) >= 64: return
            # This is an explicitly observer-local identity, not Hermes's queue request_id.
            request = 'observer-' + str(uuid.uuid4())
            self.pending.setdefault(identity, []).append(request)
            self.publisher.publish('hermes', identity[0], identity[1], request, 'approval',
                                   'Hermes approval', 'Open on Mac: native approval observer', stored_session=identity[0])

    def post_approval_response(self, **context):
        with self.lock:
            identity = self._identity(context)
            if context.get('choice') not in {'once', 'session', 'always', 'deny', 'timeout', 'cancelled', 'notify_failed', 'smart_approve', 'smart_deny'}: return
            requests = self.pending.get(identity, [])
            # Duplicate callbacks lack native request_id: retain until exact turn finalization.
            if len(requests) != 1: return
            self.pending.pop(identity)
            self.publisher.publish('hermes', identity[0], identity[1], requests[0], 'approval',
                                   'Hermes approval', 'Open on Mac: native approval observer', state='resolved',
                                   stored_session=identity[0])


def register(ctx):
    directory = os.environ.get('STOPWATCH_NOTIFICATIONS_DIR')
    if not directory: raise ValueError('STOPWATCH_NOTIFICATIONS_DIR required')
    observer = Observer(Publisher(directory))
    ctx.register_hook('subagent_start', observer.subagent_start)
    ctx.register_hook('on_session_end', observer.on_session_end)
    ctx.register_hook('pre_approval_request', observer.pre_approval_request)
    ctx.register_hook('post_approval_response', observer.post_approval_response)
