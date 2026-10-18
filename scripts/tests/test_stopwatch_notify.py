import importlib.util
import json
import multiprocessing
import os
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('stopwatch_notify', Path(__file__).parents[1] / 'stopwatch_notify.py')
notify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notify)

def inbox_publisher(directory, event, paused, release, results, hold=False):
    original = notify.os.listdir
    def snapshot(fd):
        names = original(fd)
        if hold:
            paused.set()
            if not release.wait(10): raise RuntimeError('publication test timed out')
        return names
    notify.os.listdir = snapshot
    try:
        notify.emit(directory, event)
        results.put('published')
    except ValueError as error:
        results.put(str(error))
    finally:
        notify.os.listdir = original

class NotifyTests(unittest.TestCase):
    def fixture(self):
        return dict(v=1, eventId='synthetic-event', source='codex', sessionId='synthetic-session', runId='synthetic-run', requestId='synthetic-request', revision=1, createdAt=1000, leaseDeadline=16000, kind='approval', title='Synthetic', model='test', detail='Read synthetic fixture', canDecide=True, state='pending')
    def test_private_atomic_emit_and_invalid_unchanged(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            notify.emit(directory, self.fixture())
            self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
            records = list((directory / 'inbox').glob('*.json'))
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0].stat().st_mode & 0o777, 0o600)
            bad = self.fixture(); bad['detail'] = 'x' * 9000
            with self.assertRaises(ValueError): notify.emit(directory, bad)
            self.assertEqual(len(list((directory / 'inbox').glob('*.json'))), 1)
    @unittest.skipUnless(os.environ.get('TASK_NOTIFICATION_TEST_BINARY'), 'standalone Swift bridge binary required')
    def test_consumer_can_claim_immediately_at_publication(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            original_link, original_rename = os.link, os.rename
            def concurrent_publish(operation):
                def publish(*args, **kwargs):
                    result = operation(*args, **kwargs)
                    # Run the real consumer before the publisher can do any further cleanup.
                    subprocess.run([os.environ['TASK_NOTIFICATION_TEST_BINARY'], '--bridge', str(directory)], check=True, capture_output=True)
                    return result
                return publish
            with patch.object(notify.os, 'link', concurrent_publish(original_link)), patch.object(notify.os, 'rename', concurrent_publish(original_rename)):
                notify.emit(directory, self.fixture())
            self.assertEqual(list((directory / 'inbox').glob('*.json')), [])
            self.assertEqual(len(notify.decisions(directory, self.fixture(), now=1002)), 1)
    def test_decision_exact_identity_and_consume_once(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            notify.emit(directory, self.fixture())
            record = dict(v=1, decisionId='synthetic-decision', source='codex', sessionId='synthetic-session', runId='synthetic-run', requestId='synthetic-request', revision=1, action='allow_once', createdAt=1000, leaseDeadline=16000)
            target = directory / 'decisions' / 'synthetic.json'
            target.write_text(json.dumps(record)); target.chmod(0o600)
            wrong = self.fixture(); wrong['revision'] = 2
            self.assertEqual(notify.decisions(directory, wrong, now=1001), [])
            self.assertTrue(target.exists())
            self.assertEqual(notify.decisions(directory, self.fixture(), now=1001), [record])
            self.assertEqual(notify.decisions(directory, self.fixture(), now=1001), [])
    def test_symlink_directory_rejected(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            directory.symlink_to(Path(root) / 'elsewhere')
            with self.assertRaises((ValueError, OSError)): notify.emit(directory, self.fixture())
    @unittest.skipUnless(os.environ.get('TASK_NOTIFICATION_TEST_BINARY'), 'standalone Swift bridge binary required')
    def test_real_swift_bridge_roundtrip(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            notify.emit(directory, self.fixture())
            binary = os.environ['TASK_NOTIFICATION_TEST_BINARY']
            first = subprocess.run([binary, '--bridge', str(directory)], check=True, capture_output=True, text=True)
            card = json.loads(first.stdout)
            self.assertEqual(card['state'], 'submitting')
            self.assertNotIn('sessionId', card)
            consumed = notify.decisions(directory, self.fixture(), now=1002)
            self.assertEqual(len(consumed), 1)
            self.assertEqual(consumed[0]['requestId'], 'synthetic-request')
            self.assertEqual(notify.decisions(directory, self.fixture(), now=1002), [])
            restarted = subprocess.run([binary, '--bridge', str(directory)], check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(restarted.stdout)['state'], 'unknown')
            self.assertEqual(list((directory / 'decisions').glob('*.json')), [])
            resolved = self.fixture(); resolved['state'] = 'resolved'; resolved['eventId'] = 'resolved'
            notify.emit(directory, resolved)
            final = subprocess.run([binary, '--bridge', str(directory)], check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(final.stdout)['state'], 'resolved')

    def test_expired_or_wrong_native_option_cannot_consume(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            event = self.fixture(); event.update(kind='input', options=['A', 'B'], optionIds=['native-a', 'native-b'])
            notify.emit(directory, event)
            record = dict(v=1, decisionId='synthetic-decision', source='codex', sessionId='synthetic-session', runId='synthetic-run', requestId='synthetic-request', revision=1, action='choose', optionId='wrong-native-option', createdAt=1000, leaseDeadline=16000)
            target = directory / 'decisions' / 'synthetic.json'
            target.write_text(json.dumps(record)); target.chmod(0o600)
            self.assertEqual(notify.decisions(directory, event, now=1001), [])
            record['optionId'] = 'native-b'; target.write_text(json.dumps(record))
            self.assertEqual(notify.decisions(directory, event, now=16000), [])
            self.assertFalse(target.exists())
            self.assertEqual(notify.decisions(directory, event, now=1001), [])

    def test_outcome_requires_authoritative_resolution(self):
        event = self.fixture(); event['outcome'] = 'allowed'
        with self.assertRaises(ValueError): notify.validate_event(event)
        event['state'] = 'resolved'
        self.assertEqual(notify.validate_event(event)['outcome'], 'allowed')

    def test_missing_capability_defaults_false(self):
        data = self.fixture(); del data['canDecide']
        self.assertFalse(notify.validate_event(data)['canDecide'])

    @unittest.skipUnless(os.environ.get('TASK_NOTIFICATION_PROBE_BINARY'), 'production Swift Store probe required')
    def test_multiprocess_inbox_admission_and_production_consumer(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            for index in range(1023):
                notify.emit(directory, dict(self.fixture(), eventId='seed-' + str(index)))
            temporary = directory / 'inbox' / '.synthetic-incomplete-write'
            temporary.write_bytes(b'not a published record'); temporary.chmod(0o600)
            ctx = multiprocessing.get_context('fork')
            paused, release, results = ctx.Event(), ctx.Event(), ctx.Queue()
            first = ctx.Process(target=inbox_publisher, args=(directory, dict(self.fixture(), eventId='first'), paused, release, results, True))
            second = ctx.Process(target=inbox_publisher, args=(directory, dict(self.fixture(), eventId='second'), paused, release, results))
            first.start()
            try:
                self.assertTrue(paused.wait(5), 'first callback reached actual capacity snapshot')
                second.start(); second.join(timeout=0.3)
            finally:
                release.set(); first.join(timeout=5)
                if second.pid: second.join(timeout=5)
                for child in (first, second):
                    if child.pid and child.is_alive(): child.kill(); child.join()
            self.assertEqual((first.exitcode, second.exitcode), (0, 0))
            self.assertEqual(sorted([results.get(timeout=2), results.get(timeout=2)]), ['inbox full', 'published'])
            self.assertEqual(len(list((directory / 'inbox').glob('*.json'))), 1024)
            probe = subprocess.run([os.environ['TASK_NOTIFICATION_PROBE_BINARY'], '--consume', str(directory)], check=True, capture_output=True, text=True)
            self.assertEqual([json.loads(line)['consumed'] for line in probe.stdout.splitlines()], [1024, 1024])
            self.assertEqual(list((directory / 'inbox').glob('*.json')), [])
            self.assertTrue(temporary.exists(), 'unknown temporary files are neither capacity nor cleanup targets')

    @unittest.skipUnless(os.environ.get('TASK_NOTIFICATION_PROBE_BINARY'), 'production Swift Store probe required')
    def test_preexisting_overfull_inbox_drains_in_bounded_batches(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            notify.emit(directory, dict(self.fixture(), eventId='seed'))
            for index in range(1024):
                path = directory / 'inbox' / ('existing-' + str(index) + '.json')
                path.write_text(json.dumps(dict(self.fixture(), eventId='existing-' + str(index))))
                path.chmod(0o600)
            self.assertRaises(ValueError, notify.emit, directory, dict(self.fixture(), eventId='must-not-publish'))
            self.assertEqual(len(list((directory / 'inbox').glob('*.json'))), 1025)
            probe = subprocess.run([os.environ['TASK_NOTIFICATION_PROBE_BINARY'], '--consume', str(directory)], check=True, capture_output=True, text=True)
            observations = [json.loads(line) for line in probe.stdout.splitlines()]
            self.assertEqual([x['consumed'] for x in observations], [1024, 1025])
            self.assertTrue(all(x['rejected'] == 0 for x in observations))
            self.assertTrue(all('error' not in x for x in observations))
            self.assertEqual(list((directory / 'inbox').glob('*.json')), [])
            self.assertEqual(list((directory / 'processing').glob('*.json')), [])

    @unittest.skipUnless(os.environ.get('TASK_NOTIFICATION_PROBE_BINARY'), 'production Swift Store probe required')
    def test_full_processing_retains_inbox_without_blocking_poll(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            notify.emit(directory, dict(self.fixture(), eventId='waiting-inbox'))
            for index in range(1024):
                path = directory / 'processing' / ('pending-' + str(index) + '.json')
                path.write_text(json.dumps(dict(self.fixture(), eventId='pending-' + str(index))))
                path.chmod(0o600)
            probe = subprocess.run([os.environ['TASK_NOTIFICATION_PROBE_BINARY'], '--backpressured', str(directory)], check=True, capture_output=True, text=True)
            observations = [json.loads(line) for line in probe.stdout.splitlines()]
            self.assertTrue(all('error' not in x and x['consumed'] == 0 for x in observations))
            self.assertEqual([x['rejected'] for x in observations], [1024, 2048])
            self.assertEqual(len(list((directory / 'inbox').glob('*.json'))), 1)
            self.assertEqual(len(list((directory / 'processing').glob('*.json'))), 1024)
            recovered = subprocess.run([os.environ['TASK_NOTIFICATION_PROBE_BINARY'], '--consume', str(directory)], check=True, capture_output=True, text=True)
            self.assertEqual([json.loads(line)['consumed'] for line in recovered.stdout.splitlines()], [1024, 1025])

    def test_inbox_publication_lock_rejects_unsafe_objects(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as root:
            directory = Path(root) / 'notifications'
            notify.emit(directory, self.fixture())
            lock = directory / 'inbox' / '.publish.lock'
            self.assertEqual(lock.stat().st_mode & 0o777, 0o600)
            lock.chmod(0o644)
            self.assertRaises(ValueError, notify.emit, directory, self.fixture())
            lock.chmod(0o600)
            alias = Path(root) / 'lock-hardlink'; os.link(lock, alias)
            self.assertRaises(ValueError, notify.emit, directory, self.fixture())
            alias.unlink(); lock.unlink(); lock.symlink_to('/private/tmp')
            self.assertRaises(OSError, notify.emit, directory, self.fixture())
            self.assertEqual(len(list((directory / 'inbox').glob('*.json'))), 1)

    @unittest.skipUnless(os.environ.get('TASK_NOTIFICATION_CONTROLLER_BINARY') and os.environ.get('TASK_NOTIFICATION_PROBE_BINARY'), 'coupled production broker/controller required')
    def test_superseded_confirmation_close_unpins_host_and_announces_next(self):
        def exchange(proc, **command):
            proc.stdin.write(json.dumps(command) + '\n'); proc.stdin.flush()
            line = proc.stdout.readline()
            self.assertTrue(line, 'synthetic production process stopped unexpectedly')
            return json.loads(line)
        for screen in ('confirm', 'hold', 'inbox'):
            with self.subTest(superseded_screen=screen), tempfile.TemporaryDirectory(dir='/private/tmp') as root:
                host = subprocess.Popen([os.environ['TASK_NOTIFICATION_PROBE_BINARY'], '--broker', str(Path(root) / 'bridge')], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
                watch = subprocess.Popen([os.environ['TASK_NOTIFICATION_CONTROLLER_BINARY']], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
                try:
                    def host_op(op, now, **data): return exchange(host, op=op, now=now, **data)
                    def watch_op(op, now, **data): return exchange(watch, op=op, now=now, **data)
                    def deliver(card, now): return watch_op('receive', now, card=card)
                    card = host_op('ingest', 1000, request='A')
                    deliver(card, 1000)
                    read = watch_op('open', 1001)['action']
                    deliver(host_op('action', 1001, action=read), 1001)
                    if screen != 'inbox':
                        read = watch_op('detail', 1002)['action']
                        deliver(host_op('action', 1002, action=read), 1002)
                        self.assertEqual(watch_op('confirm', 1003)['view'], 4)
                    revised = host_op('ingest', 1100, request='A', revision=2)
                    preserved = deliver(revised, 1100)
                    host_op('published', 1100)
                    deliver(host_op('ingest', 1101, request='B', kind='done'), 1101)
                    stale = dict(read, action='allow_once'); stale.pop('seq', None)
                    host_op('action', 1102, action=stale)
                    if screen == 'hold': stale_hold = watch_op('hold', 1200)
                    obsolete = watch_op('next' if screen == 'inbox' else 'open-on-mac', 2050)
                    self.assertNotIn('issued', obsolete, 'obsolete nondeciding operations must not cause a send failure')
                    self.assertTrue(obsolete['linked'], 'safe Close must remain reachable after attempted OPEN/Next')
                    close = watch_op('close', 2100)
                    self.assertTrue(close['accepted'], 'Close of superseded display must pass the actual BLE send guard')
                    self.assertEqual((preserved['r'], preserved['detail'], preserved['canDecide']), (1, 'Scope r1', False))
                    if screen == 'hold': self.assertNotIn('issued', stale_hold, 'superseded hold must never issue a native action')
                    self.assertEqual((close['action']['g'], close['action']['id'], close['action']['r']), (revised['g'], revised['id'], 2))
                    next_card = host_op('action', 2100, action=close['action'])
                    self.assertEqual((next_card['title'], next_card['alert'], next_card['ack']), ('B', 1, close['action']['seq']))
                    deliver(next_card, 2100)
                    self.assertEqual(host_op('decisions', 2100)['decisions'], 0)
                    self.assertTrue(watch_op('open', 2101)['accepted'], 'acknowledged Close permits a fresh Read')
                finally:
                    for proc in (host, watch):
                        proc.stdin.close()
                        try: proc.wait(timeout=5)
                        except subprocess.TimeoutExpired: proc.kill(); proc.wait()
                        proc.stdout.close()

if __name__ == '__main__': unittest.main()
