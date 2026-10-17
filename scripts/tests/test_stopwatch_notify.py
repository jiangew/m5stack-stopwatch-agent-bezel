import importlib.util
import json
import os
from pathlib import Path
import tempfile
import subprocess
import unittest

spec = importlib.util.spec_from_file_location('stopwatch_notify', Path(__file__).parents[1] / 'stopwatch_notify.py')
notify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notify)

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
            self.assertTrue(target.exists())
            self.assertEqual(notify.decisions(directory, event, now=1001), [record])

    def test_outcome_requires_authoritative_resolution(self):
        event = self.fixture(); event['outcome'] = 'allowed'
        with self.assertRaises(ValueError): notify.validate_event(event)
        event['state'] = 'resolved'
        self.assertEqual(notify.validate_event(event)['outcome'], 'allowed')

    def test_missing_capability_defaults_false(self):
        data = self.fixture(); del data['canDecide']
        self.assertFalse(notify.validate_event(data)['canDecide'])

if __name__ == '__main__': unittest.main()
