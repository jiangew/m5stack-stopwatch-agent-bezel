"""Shared native-adapter publication and OPEN routing. No approval transport."""
import hashlib
import fcntl
from contextlib import contextmanager
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid

REPO = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location('stopwatch_notification_bridge', REPO / 'scripts/stopwatch_notify.py')
bridge = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bridge)
SAFE_TARGET = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}\Z')
SUPER_CLI = '/Applications/super.engineering.app/Contents/Resources/bin/sc-macos-aarch64'
BUNDLES = {'codex': 'com.openai.codex', 'deepseek': 'com.deepseek.dsh',
           'super': 'engineering.super.app', 'hermes': 'com.nousresearch.hermes'}


def target(value):
    if not isinstance(value, str) or not SAFE_TARGET.fullmatch(value):
        raise ValueError('invalid native navigation target')
    return value


def _key(event):
    return hashlib.sha256(json.dumps([event[k] for k in bridge.IDENTITY], separators=(',', ':')).encode()).hexdigest() + '.json'


class RouteStore:
    """Bounded private routing records. Reuse the bridge's no-follow fd policy."""
    def __init__(self, directory):
        self.directory = Path(directory)
        if not self.directory.is_absolute() or self.directory.resolve().is_relative_to(REPO):
            raise ValueError('adapter runtime directory must be absolute and outside repository')

    def _open(self):
        dirs = bridge._directories(self.directory)
        try:
            try: os.mkdir('adapter-routes', 0o700, dir_fd=dirs['root'])
            except FileExistsError: pass
            fd = os.open('adapter-routes', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=dirs['root'])
            try:
                bridge._check(fd, True)
                return fd
            except BaseException:
                os.close(fd)
                raise
        finally:
            bridge._close(dirs)

    @contextmanager
    def _locked(self, fd, exclusive):
        lock = os.open('.inventory.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=fd)
        try:
            bridge._check(lock, False)
            fcntl.flock(lock, fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
            bridge._check(lock, False)
            yield
        finally:
            os.close(lock)

    @staticmethod
    def _names(fd):
        # The persistent lock and in-progress atomic files never consume route capacity.
        return [name for name in os.listdir(fd) if re.fullmatch(r'[0-9a-f]{64}\.json', name)]

    def save(self, event, stored_session=None):
        event = bridge.validate_event(event)
        if stored_session is not None: target(stored_session)
        if event['source'] == 'codex': target(event['sessionId'])
        record = {'event': event, 'storedSession': stored_session}
        payload = bridge._encode(record)
        if len(payload) > bridge.MAX_EVENT: raise ValueError('route record too large')
        fd = self._open(); name = _key(event); temporary = '.' + str(uuid.uuid4())
        try:
            with self._locked(fd, True):
                if name not in self._names(fd) and len(self._names(fd)) >= 256:
                    raise ValueError('adapter route inventory full')
                out = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
                with os.fdopen(out, 'wb') as stream:
                    stream.write(payload); stream.flush(); os.fsync(stream.fileno())
                os.replace(temporary, name, src_dir_fd=fd, dst_dir_fd=fd)
                os.fsync(fd)
        finally:
            try: os.unlink(temporary, dir_fd=fd)
            except FileNotFoundError: pass
            os.close(fd)

    @staticmethod
    def _owner_fd(fd, event):
        # Keep the inode stable after release; unlinking would permit two locks
        # for the same identity. At most one lock file per bounded route exists.
        name = '.owner-' + _key(event)
        owners = [item for item in os.listdir(fd) if re.fullmatch(r'\.owner-[0-9a-f]{64}\.json', item)]
        if name not in owners and len(owners) >= 256:
            raise ValueError('owner lock inventory full')
        lock = os.open(name, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=fd)
        try:
            bridge._check(lock, False)
            return lock
        except BaseException:
            os.close(lock)
            raise

    def acquire_owner(self, event):
        """Hold a kernel liveness lock until native continuation release/exit."""
        event = bridge.validate_event(event)
        fd = self._open()
        try:
            with self._locked(fd, True):
                if _key(event) not in self._names(fd) and len(self._names(fd)) >= 256:
                    raise ValueError('adapter route inventory full')
                lock = self._owner_fd(fd, event)
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    bridge._check(lock, False)
                    return lock
                except BaseException:
                    os.close(lock)
                    raise
        finally:
            os.close(fd)

    def claim_open(self, snapshot, now=None):
        """Re-read and claim under the same lock used by every route renewal.

        The lease grants decision authority, not proof that its owner is dead.
        A live native lock excludes generic OPEN even after the lease expires.
        """
        fd = self._open()
        try:
            with self._locked(fd, True):
                record = bridge._read(fd, _key(snapshot))
                if set(record) != {'event', 'storedSession'}: raise ValueError('invalid route record')
                event = bridge.validate_event(record['event'])
                if _key(event) != _key(snapshot): raise ValueError('route identity mismatch')
                lock = self._owner_fd(fd, event)
                try:
                    try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    except BlockingIOError: return None
                    bridge._check(lock, False)
                    current = int(time.time() * 1000) if now is None else now
                    if event['canDecide'] and current < event['leaseDeadline']: return None
                    decisions = bridge.decisions(self.directory, event, now=current)
                    if any(decision['action'] != 'open' for decision in decisions):
                        raise ValueError('native decisions unsupported')
                    return event, record['storedSession'], decisions
                finally:
                    os.close(lock)
        finally:
            os.close(fd)

    def records(self):
        fd = self._open()
        try:
            records = []
            with self._locked(fd, False):
                names = self._names(fd)
                if len(names) > 256: raise ValueError('adapter route inventory full')
                for name in sorted(names):
                    record = bridge._read(fd, name)
                    if set(record) != {'event', 'storedSession'}: raise ValueError('invalid route record')
                    event = bridge.validate_event(record['event'])
                    if _key(event) != name: raise ValueError('route identity mismatch')
                    records.append((event, record['storedSession']))
        finally:
            os.close(fd)
        yield from records

    def command(self, event, stored_session=None):
        source = event['source']
        if stored_session is None:
            for saved, native in self.records():
                if _key(saved) == _key(event):
                    stored_session = native
                    break
        if source == 'codex':
            return ['open', 'codex://threads/' + target(event['sessionId'])], 'exact-session-open-requested'
        if source == 'super' and stored_session:
            return [SUPER_CLI, 'chat', 'select', target(stored_session)], 'exact-session-open-requested'
        if source == 'hermes' and stored_session:
            from urllib.parse import quote
            return ['open', 'hermes://open/' + quote(target(stored_session), safe='')], 'exact-session-open-requested'
        return ['open', '-b', BUNDLES[source]], 'application-activation-requested'


class Publisher:
    def __init__(self, directory, now=None):
        self.directory = Path(directory)
        self.routes = RouteStore(directory)
        self.now = now or (lambda: int(time.time() * 1000))
        self._times = {}

    def publish(self, source, session, run, request, kind, title, detail, *, model='', state='pending',
                revision=1, outcome=None, stored_session=None):
        identity = (source, session, run, request, revision)
        timestamp = max(self.now(), self._times.get(identity, -1) + 1)
        event = dict(v=1, eventId=str(uuid.uuid4()), source=source, sessionId=session, runId=run,
                     requestId=request, revision=revision, createdAt=timestamp, leaseDeadline=timestamp + 15000,
                     kind=kind, title=title, model=model, detail=detail, canDecide=False, state=state)
        if outcome is not None: event['outcome'] = outcome
        result = self.forward(event, stored_session=stored_session)
        if len(self._times) < 256 or identity in self._times: self._times[identity] = timestamp
        return result

    def forward(self, event, *, stored_session=None):
        event = bridge.validate_event(event)
        # Generic ingress cannot assert native decision support.
        if event['canDecide']: raise ValueError('native decisions unsupported')
        self.routes.save(event, stored_session)
        bridge.emit(self.directory, event)
        return event


def _run_open(command):
    result = subprocess.run(command, check=True, timeout=10, stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if command[0] == SUPER_CLI:
        if len(result.stdout) > 65536: raise subprocess.SubprocessError('native open result too large')
        try: native = json.loads(result.stdout)
        except (ValueError, TypeError): raise subprocess.SubprocessError('invalid native open result') from None
        if not isinstance(native, dict) or native.get('kind') in (None, 'cli_error') or 'error' in native:
            raise subprocess.SubprocessError('native open rejected')


def consume_open(directory, runner=None, now=None):
    """Consume identity-bound OPEN only. Never synthesize native approval resolution."""
    store = RouteStore(directory)
    runner = runner or _run_open
    result = []
    for snapshot, _stored in store.records():
        claimed = store.claim_open(snapshot, now=now)
        if claimed is None: continue
        event, stored, decisions = claimed
        for decision in decisions:
            command, status = store.command(event, stored)
            try:
                runner(command)
            except (OSError, subprocess.SubprocessError):
                status = 'open-failed'
            result.append({'decisionId': decision['decisionId'], 'status': status})
    return result
