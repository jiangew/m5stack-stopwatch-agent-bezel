#!/usr/bin/env python3
"""Private Stopwatch adapter bridge; no native app automation or keyboard approvals.

Native adapters MUST resolve the exact pending source/session/run/request/revision
and recheck its scope/capability before acting on a consumed decision. Only emit
state=resolved after an authoritative native response, never after file/ATT ACK.
"""
import argparse
import json
import os
from pathlib import Path
import stat
import time
import uuid

MAX_EVENT = 8192
SOURCES = {'codex', 'deepseek', 'super', 'hermes'}
IDENTITY = ('source', 'sessionId', 'runId', 'requestId', 'revision')


def _string(value, maximum, nonempty=False):
    return isinstance(value, str) and (value != '' or not nonempty) and '\0' not in value and len(value.encode('utf-8')) <= maximum


def _integer(value, maximum=2**63 - 1):
    return type(value) is int and 0 <= value <= maximum


def validate_event(event):
    data = dict(event)
    data.setdefault('canDecide', False)
    required = {'v', 'eventId', 'source', 'sessionId', 'runId', 'requestId', 'revision', 'createdAt', 'leaseDeadline', 'kind', 'title', 'model', 'detail', 'canDecide', 'state'}
    if not required.issubset(data) or set(data) - required - {'options', 'optionIds', 'outcome'}:
        raise ValueError('invalid event fields')
    if (type(data['v']) is not int or data['v'] != 1 or data['source'] not in SOURCES
            or data['kind'] not in {'done', 'approval', 'input', 'failed'} or data['state'] not in {'pending', 'resolved'}
            or not _integer(data['revision'], 2**32 - 1) or data['revision'] == 0
            or not _integer(data['createdAt'], 2**63 - 120001) or not _integer(data['leaseDeadline']) or type(data['canDecide']) is not bool
            or not all(_string(data[k], 256, True) for k in ('eventId', 'sessionId', 'runId', 'requestId'))
            or not all(_string(data[k], 4096) for k in ('title', 'model', 'detail'))):
        raise ValueError('invalid event')
    if 'outcome' in data and (data['state'] != 'resolved' or data['outcome'] not in {'allowed', 'declined', 'answered', 'cancelled'}):
        raise ValueError('outcome requires authoritative resolution')
    if 'options' in data or 'optionIds' in data:
        labels, ids = data.get('options'), data.get('optionIds')
        if (data['kind'] != 'input' or not isinstance(labels, list) or not isinstance(ids, list)
                or not 2 <= len(labels) <= 3 or len(labels) != len(ids)
                or not all(_string(x, 24, True) and all(32 <= ord(c) <= 126 for c in x) for x in labels)
                or not all(_string(x, 256, True) for x in ids) or len(set(ids)) != len(ids)):
            raise ValueError('invalid finite input options')
    if len(_encode(data)) > MAX_EVENT:
        raise ValueError('event exceeds 8192 bytes')
    return data


def _encode(data):
    return json.dumps(data, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode('utf-8')


def _check(fd, directory):
    info = os.fstat(fd)
    if (info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != (0o700 if directory else 0o600)
            or not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode) and info.st_nlink == 1)):
        raise ValueError('unsafe bridge object')


def _directories(directory):
    path = Path(directory)
    if not path.is_absolute() or '..' in path.parts or len(path.parts) < 2:
        raise ValueError('absolute private directory required')
    opened = []
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for i, component in enumerate(path.parts[1:]):
            try:
                next_fd = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            except FileNotFoundError:
                if i != len(path.parts) - 2:
                    raise
                os.mkdir(component, 0o700, dir_fd=fd)
                next_fd = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd); fd = next_fd
        _check(fd, True)
        opened.append(fd)
        result = {'root': fd}
        for name in ('inbox', 'processing', 'decisions', 'consumed'):
            try: os.mkdir(name, 0o700, dir_fd=fd)
            except FileExistsError: pass
            sub = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            opened.append(sub); _check(sub, True); result[name] = sub
        return result
    except BaseException:
        if not opened: os.close(fd)
        for item in opened: os.close(item)
        raise


def _close(directories):
    for fd in directories.values(): os.close(fd)


def emit(directory, event):
    payload = _encode(validate_event(event))
    dirs = _directories(directory)
    fd = dirs['inbox']
    name = str(uuid.uuid4())
    temporary = '.' + name
    try:
        if len(os.listdir(fd)) >= 1024: raise ValueError('inbox full')
        record = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
        try:
            with os.fdopen(record, 'wb') as output:
                output.write(payload); output.flush(); os.fsync(output.fileno())
            os.link(temporary, name + '.json', src_dir_fd=fd, dst_dir_fd=fd, follow_symlinks=False)
            os.unlink(temporary, dir_fd=fd); os.fsync(fd)
        finally:
            try: os.unlink(temporary, dir_fd=fd)
            except FileNotFoundError: pass
    finally: _close(dirs)


def _read(fd, name):
    record = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
    with os.fdopen(record, 'rb') as source:
        _check(source.fileno(), False)
        payload = source.read(MAX_EVENT + 1)
        if len(payload) > MAX_EVENT: raise ValueError('record too large')
        return json.loads(payload)


def decisions(directory, pending, now=None):
    """Consume once, only for the adapter's currently pending exact native record.

    This is transport validation, not proof of current native capability. Adapter
    must revalidate immediately before native dispatch. Crash after claim loses
    delivery rather than replaying approval; broker reconciles UNKNOWN.
    """
    pending = validate_event(pending)
    now = int(time.time() * 1000) if now is None else now
    dirs = _directories(directory)
    result = []
    try:
        names = os.listdir(dirs['decisions'])
        if len(names) > 1024: raise ValueError('decision directory full')
        for name in sorted(names):
            if not name.endswith('.json'): continue
            try: record = _read(dirs['decisions'], name)
            except (ValueError, OSError, json.JSONDecodeError): continue
            if (record.get('v') != 1 or any(record.get(k) != pending[k] for k in IDENTITY)
                    or not _string(record.get('decisionId'), 256, True)
                    or record.get('action') not in {'open', 'allow_once', 'decline', 'choose'}): continue
            if record['action'] != 'open':
                if (pending['state'] != 'pending' or not pending['canDecide']
                        or not _integer(record.get('createdAt')) or not _integer(record.get('leaseDeadline'))
                        or not record['createdAt'] <= now < min(record['leaseDeadline'], pending['leaseDeadline'])
                        or record['leaseDeadline'] > record['createdAt'] + 15000): continue
                if record['action'] == 'choose':
                    if pending['kind'] != 'input' or record.get('optionId') not in pending.get('optionIds', []): continue
                elif pending['kind'] != 'approval': continue
            # Atomic exclusive claim across competing adapter processes. Do not retry
            # existing consumed names, even after a process crash.
            try:
                os.link(name, name, src_dir_fd=dirs['decisions'], dst_dir_fd=dirs['consumed'], follow_symlinks=False)
            except (FileExistsError, FileNotFoundError): continue
            os.unlink(name, dir_fd=dirs['decisions'])
            os.fsync(dirs['consumed']); os.fsync(dirs['decisions'])
            result.append(record)
            os.unlink(name, dir_fd=dirs['consumed'])
            os.fsync(dirs['consumed'])
        return result
    finally: _close(dirs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path)
    parser.add_argument('operation', choices=('emit', 'decisions'))
    parser.add_argument('--record', type=Path, required=True, help='adapter event JSON; native IDs stay local')
    args = parser.parse_args()
    with args.record.open('rb') as source:
        payload = source.read(MAX_EVENT + 1)
    if len(payload) > MAX_EVENT: raise ValueError('record too large')
    event = json.loads(payload)
    if args.operation == 'emit': emit(args.directory, event)
    else:
        for record in decisions(args.directory, event): print(json.dumps(record, separators=(',', ':')))

if __name__ == '__main__': main()
