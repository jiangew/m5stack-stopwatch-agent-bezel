"""Codex notify callback with exact read-only lineage lookup or explicit root fallback."""
import argparse
import json
from pathlib import Path
import sys
import os
import selectors
import subprocess
import time
import re
import unicodedata

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from notifications.adapters.runtime import Publisher, target


CODEX_CLI = '/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex'


def metadata_root(session, codex=CODEX_CLI, timeout=3, display=False):
    """Read one exact thread's lineage metadata, never resume or request turn history.

    App Server metadata includes a preview; it stays transient and is never logged,
    displayed or persisted. Strict deployments can disable this query entirely.
    """
    target(session)
    proc = None
    selector = selectors.DefaultSelector()
    try:
        proc = subprocess.Popen([codex, 'app-server', '--listen', 'stdio://'], stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
        selector.register(proc.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + timeout
        buffered = bytearray()
        budget = 0
        def send(frame):
            proc.stdin.write(json.dumps(frame, separators=(',', ':')).encode() + b'\n')
            proc.stdin.flush()
        def reply(request_id):
            nonlocal budget
            while time.monotonic() < deadline:
                if b'\n' not in buffered:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0 or not selector.select(remaining): return None
                    part = os.read(proc.stdout.fileno(), 8192)
                    if not part: return None
                    budget += len(part)
                    if budget > 1024 * 1024: return None
                    buffered.extend(part)
                    continue
                line, _, rest = buffered.partition(b'\n')
                buffered[:] = rest
                frame = json.loads(line)
                if isinstance(frame, dict) and type(frame.get('id')) is int and frame['id'] == request_id:
                    return frame.get('result') if 'error' not in frame else None
            return None
        send({'id': 1, 'method': 'initialize', 'params': {'clientInfo': {
            'name': 'agentbezel_notifications', 'title': 'AgentBezel notifications', 'version': '0.1.0'}}})
        if reply(1) is None: return None
        send({'method': 'initialized', 'params': {}})
        send({'id': 2, 'method': 'thread/read', 'params': {'threadId': session, 'includeTurns': False}})
        response = reply(2)
        thread = response.get('thread') if isinstance(response, dict) else None
        if not isinstance(thread, dict) or thread.get('id') != session or thread.get('turns') != []: return None
        source = thread.get('source')
        if thread.get('parentThreadId') is not None or isinstance(source, dict) and 'subAgent' in source: return False
        root = True if isinstance(source, str) and source in {'cli', 'vscode', 'exec', 'appServer'} else None
        if display: return dict(root=root, name=thread.get('name'), cwd=thread.get('cwd'), configuredModel=thread.get('model'))
        return root
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        return None
    finally:
        selector.close()
        if proc is not None:
            if proc.poll() is None: proc.terminate()
            try: proc.wait(timeout=1)
            except subprocess.TimeoutExpired:
                proc.kill(); proc.wait(timeout=1)
            proc.stdin.close(); proc.stdout.close()


def plain_text(value, limit):
    if not isinstance(value, str): return '', False
    cleaned = '\n'.join(re.sub(r'^\s*(?:#{1,6}\s+|[-*]\s+)', '', line) for line in value.splitlines())
    cleaned = ' '.join(''.join(c for c in cleaned if not unicodedata.category(c).startswith('C') or c.isspace()).split())
    encoded = cleaned.encode('utf-8')
    return encoded[:limit].decode('utf-8', errors='ignore'), len(encoded)>limit


def handle_notify(record, publisher, roots, root_resolver=None, rich_content=False):
    if not isinstance(record, dict) or record.get('type') != 'agent-turn-complete': return False
    session, turn = record.get('thread-id'), record.get('turn-id')
    target(session); target(turn)
    metadata = root_resolver(session) if root_resolver is not None else None
    info = metadata if isinstance(metadata, dict) else {}
    native_root = info.get('root') if isinstance(metadata, dict) else metadata
    if native_root is False or native_root is not True and session not in roots: return False
    if rich_content:
        title, _ = plain_text(info.get('name'), 512)
        detail, clipped = plain_text(record.get('last-assistant-message'), 4096)
        cwd = info.get('cwd')
        project = Path(cwd).name if isinstance(cwd, str) and cwd.startswith('/') and Path(cwd) != Path.home() else ''
        project, _ = plain_text(project, 64)
        # Thread.model is native per-thread configuration, not execution telemetry.
        configured = info.get('configuredModel')
        model = configured if isinstance(configured, str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._:/+\-]{0,127}', configured) else ''
        provenance = {'model_configured': True} if model else {}
        publisher.publish('codex', session, turn, 'turn-complete', 'done', title, detail or 'Reply available on Mac',
                          state='resolved', stored_session=session, project=project, excerpted=clipped, fit_excerpt=True, model=model, **provenance)
    else:
        publisher.publish('codex', session, turn, 'turn-complete', 'done', 'Codex completed', 'Turn completed',
                          stored_session=session)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True)
    parser.add_argument('--root-session', action='append', default=[], help='fallback verified root id on metadata failure')
    parser.add_argument('--rich-content', action='store_true', help='opt in to native name, project basename and last-reply excerpt')
    parser.add_argument('--no-metadata-query', action='store_true', help='strict privacy: require explicit roots')
    parser.add_argument('--codex', default=CODEX_CLI)
    parser.add_argument('notification', help='JSON argument supplied by native Codex notify')
    args = parser.parse_args()
    if len(args.notification.encode()) > 1024 * 1024: raise ValueError('native callback too large')
    resolver = None if args.no_metadata_query else lambda session: metadata_root(session, codex=args.codex, display=args.rich_content)
    handle_notify(json.loads(args.notification), Publisher(args.directory), set(args.root_session), resolver, rich_content=args.rich_content)


if __name__ == '__main__':
    try: main()
    except (ValueError, OSError, TypeError):
        print('Codex notification rejected; check adapter setup', file=sys.stderr)
        sys.exit(1)
