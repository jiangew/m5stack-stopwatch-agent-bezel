"""Native content-free sc subscriptions, pinned to the observed flat ac45e7aa envelope."""
import argparse
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys

if __package__ in (None, ''): sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from notifications.adapters.runtime import Publisher, SUPER_CLI


class UnsupportedContract(ValueError):
    pass


EVENTS = {'turn_started', 'task_complete', 'errored', 'cancelled', 'approval_needed',
          'user_input_needed', 'target_closed', 'message_available'}
FIELDS = {'sequence', 'stable_target_id', 'type', 'timestamp_ms', 'worktree_path'}


def decode_event(record):
    if not isinstance(record, dict): raise UnsupportedContract('invalid native envelope')
    if set(record) == {'kind', 'sequence', 'targets'} and record['kind'] == 'ready':
        if (type(record['sequence']) is not int or record['sequence'] < 0
                or not isinstance(record['targets'], list)
                or not all(isinstance(x, str) and 0 < len(x) <= 256 for x in record['targets'])):
            raise UnsupportedContract('invalid native ready envelope')
        return None
    # Deliberately reject unverified extensions (including optional run_id) rather than guessing.
    if (set(record) != FIELDS or record.get('type') not in EVENTS
            or type(record.get('sequence')) is not int or record['sequence'] < 0
            or type(record.get('timestamp_ms')) is not int or record['timestamp_ms'] < 0
            or not isinstance(record.get('stable_target_id'), str) or not 0 < len(record['stable_target_id']) <= 256
            or not isinstance(record.get('worktree_path'), str) or not Path(record['worktree_path']).is_absolute()):
        raise UnsupportedContract('unsupported native lifecycle envelope')
    return record


class SuperObserver:
    def __init__(self, publisher, roots, worktree=None):
        self.publisher = publisher
        self.roots = dict(roots)  # stable target -> verified Chat UI session id, or activation fallback
        self.worktree = worktree
        self.last = {}
        self.pending = {}

    def observe(self, record):
        packet = decode_event(record)
        if packet is None: return
        sid, seq, kind = packet['stable_target_id'], packet['sequence'], packet['type']
        if sid not in self.roots or seq <= self.last.get(sid, -1): return
        if self.worktree and packet['worktree_path'] != self.worktree: return
        self.last[sid] = seq
        if kind in {'task_complete', 'errored', 'cancelled', 'target_closed'}:
            pending = self.pending.pop(sid, None)
            if pending:
                self.publisher.publish('super', sid, pending['runId'], pending['requestId'], pending['kind'],
                                       pending['title'], pending['detail'], state='resolved', stored_session=self.roots[sid])
        if kind in {'approval_needed', 'user_input_needed'}:
            if sid in self.pending or len(self.pending) >= 64: return
            attention = 'approval' if kind == 'approval_needed' else 'input'
            event = self.publisher.publish('super', sid, 'lifecycle-' + str(seq), 'attention-' + str(seq), attention,
                                           'SUPER needs input', 'Open on Mac: native attention event', stored_session=self.roots[sid])
            self.pending[sid] = event
        elif kind in {'task_complete', 'errored', 'cancelled'}:
            detail = {'task_complete': 'Turn completed', 'errored': 'Turn failed', 'cancelled': 'Turn interrupted'}[kind]
            self.publisher.publish('super', sid, 'lifecycle-' + str(seq), 'turn-complete',
                                   'done' if kind == 'task_complete' else 'failed', 'SUPER task', detail,
                                   stored_session=self.roots[sid])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True)
    parser.add_argument('--worktree', required=True)
    parser.add_argument('--target', action='append', required=True, help='exact stable target id; repeat for roots')
    parser.add_argument('--chat-session', action='append', default=[], help='stable-target=verified-chat-session-id')
    parser.add_argument('--sc', default=SUPER_CLI)
    args = parser.parse_args()
    if not Path(args.worktree).is_absolute(): raise ValueError('absolute native worktree required')
    # Establish root ownership from native metadata; never use model names or volatile pane indexes.
    response = subprocess.run([args.sc, 'agents', 'list', '--worktree', args.worktree, '--output', 'json'],
                              check=True, capture_output=True, timeout=10)
    if len(response.stdout) > 1024 * 1024: raise ValueError('native metadata too large')
    envelope = json.loads(response.stdout)
    if envelope.get('kind') != 'agents' or set(envelope) != {'kind', 'response'}: raise UnsupportedContract('native agent discovery failed')
    rows = envelope['response'].get('agents')
    if not isinstance(rows, list) or not all(isinstance(x, dict) for x in rows): raise UnsupportedContract('invalid native agents envelope')
    roots = {x['stable_target_id']: None for x in rows if isinstance(x, dict) and not x.get('parent_stable_target_id')
             and x.get('stable_target_id') in args.target}
    if set(roots) != set(args.target): raise ValueError('requested target is missing or is a child')
    for binding in args.chat_session:
        stable, sep, session = binding.partition('=')
        row = next((x for x in rows if x.get('stable_target_id') == stable), {})
        if not sep or not session or stable not in roots or row.get('ui') != 'chat': raise ValueError('invalid Chat UI binding')
        roots[stable] = session
    observer = SuperObserver(Publisher(args.directory), roots, args.worktree)
    streams = []
    selector = selectors.DefaultSelector()
    try:
        for stable in roots:
            proc = subprocess.Popen([args.sc, 'agent', 'subscribe', '--to', 'id:' + stable, '--worktree', args.worktree,
                                     '--live-only', '--output', 'json'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
            streams.append(proc)
            os.set_blocking(proc.stdout.fileno(), False)
            selector.register(proc.stdout, selectors.EVENT_READ, bytearray())
        while selector.get_map():
            for item, _ in selector.select(timeout=1):
                try: chunk = os.read(item.fd, 4096)
                except BlockingIOError: continue
                pending = item.data
                if not chunk:
                    if pending: raise UnsupportedContract('incomplete native lifecycle frame')
                    selector.unregister(item.fileobj); continue
                pending.extend(chunk)
                while True:
                    end = pending.find(b'\n')
                    if end < 0:
                        if len(pending) > 8192: raise UnsupportedContract('native lifecycle frame too large')
                        break
                    if end > 8192: raise UnsupportedContract('native lifecycle frame too large')
                    line = bytes(pending[:end]); del pending[:end + 1]
                    observer.observe(json.loads(line))
    finally:
        selector.close()
        for proc in streams:
            if proc.poll() is None: proc.terminate()
        for proc in streams:
            try: proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill(); proc.wait(timeout=5)


if __name__ == '__main__':
    try: main()
    except (ValueError, OSError, TypeError, KeyError, subprocess.SubprocessError):
        print('SUPER adapter disconnected or unsupported native contract; inspect adapter setup', file=sys.stderr)
        sys.exit(1)
