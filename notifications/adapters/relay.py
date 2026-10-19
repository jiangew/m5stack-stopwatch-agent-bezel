"""Private NDJSON ingress for the separate DSH Host plugin; not a manual live-support claim."""
import argparse
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from notifications.adapters.runtime import Publisher, consume_open


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--open-once', action='store_true')
    mode.add_argument('--watch-open', action='store_true')
    mode.add_argument('--native', action='store_true')
    args = parser.parse_args()
    if args.native:
        from notifications.adapters.deepseek.native_relay import serve
        return serve(args.directory)
    if args.open_once or args.watch_open:
        while True:
            for result in consume_open(args.directory): print(json.dumps(result), flush=True)
            if not args.watch_open: return
            time.sleep(0.25)
    publisher = Publisher(args.directory)
    while True:
        line = sys.stdin.buffer.readline(8194)
        if not line: break
        if len(line) > 8193 or not line.endswith(b'\n'): raise ValueError('oversize or partial adapter frame')
        record = json.loads(line)
        if not isinstance(record, dict) or record.get('source') != 'deepseek': raise ValueError('unexpected adapter source')
        publisher.forward(record)


if __name__ == '__main__':
    try: main()
    except (ValueError, OSError, TypeError, KeyError):
        print('Native adapter bridge rejected a frame; check setup', file=sys.stderr)
        sys.exit(1)
