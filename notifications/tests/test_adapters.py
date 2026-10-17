"""Synthetic native callbacks only; never inspect user sessions or launch apps."""
import json
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest

from notifications.adapters.runtime import Publisher, RouteStore, consume_open
from notifications.adapters.codex_notify import handle_notify, metadata_root
from notifications.adapters.hermes_plugin import Observer
from notifications.adapters.super_collector import decode_event, UnsupportedContract, SuperObserver


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='stopwatch-adapter-')
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name).resolve() / 'bridge'
        self.clock = 1000
        self.pub = Publisher(self.directory, now=lambda: self.clock)

    def records(self):
        return [json.loads(p.read_text()) for p in sorted((self.directory / 'inbox').glob('*.json'))]

    def test_codex_native_notify_filters_children_tools_and_content(self):
        record = {'type': 'agent-turn-complete', 'thread-id': 'root-a', 'turn-id': 'turn-1',
                  'input-messages': ['synthetic private prompt'], 'last-assistant-message': 'private answer'}
        self.assertTrue(handle_notify(record, self.pub, {'root-a'}))
        self.assertFalse(handle_notify(dict(record, **{'thread-id': 'child'}), self.pub, {'root-a'}))
        self.assertFalse(handle_notify(dict(record, type='tool-complete'), self.pub, {'root-a'}))
        self.assertFalse(handle_notify(record, self.pub, set()))
        event = self.records()[0]
        self.assertEqual((event['sessionId'], event['runId'], event['kind']), ('root-a', 'turn-1', 'done'))
        self.assertNotIn('private', json.dumps(event))
        self.assertFalse(event['canDecide'])

    def test_codex_automatic_metadata_roots_and_unknown_fallback(self):
        record = {'type':'agent-turn-complete','thread-id':'future-root','turn-id':'t'}
        self.assertTrue(handle_notify(record, self.pub, set(), root_resolver=lambda _: True))
        self.assertFalse(handle_notify(dict(record, **{'thread-id':'child'}), self.pub, {'child'}, root_resolver=lambda _: False))
        self.assertFalse(handle_notify(dict(record, **{'thread-id':'unknown'}), self.pub, set(), root_resolver=lambda _: None))
        self.assertTrue(handle_notify(dict(record, **{'thread-id':'manual'}), self.pub, {'manual'}, root_resolver=lambda _: None))

    def test_codex_metadata_query_is_exact_read_only_and_discards_preview(self):
        fake = Path(self.temp.name).resolve() / 'synthetic-codex'
        calls = Path(self.temp.name).resolve() / 'metadata-requests'
        fake.write_text("""#!/usr/bin/env python3
import json,sys
for line in sys.stdin:
 request=json.loads(line)
 with open(""" + repr(str(calls)) + """,'a') as output: output.write(json.dumps(request)+'\\n')
 if request.get('method')=='initialize': print(json.dumps({'id':1,'result':{}}),flush=True)
 if request.get('method')=='thread/read':
  print(json.dumps({'id':2,'result':{'thread':{'id':request['params']['threadId'],'source':'appServer','parentThreadId':None,'turns':[],'preview':'synthetic private prompt'}}}),flush=True)
""")
        fake.chmod(0o700)
        self.assertTrue(metadata_root('future-root', codex=str(fake)))
        text = calls.read_text().replace('\\n', '\n')
        frames = [json.loads(x) for x in text.splitlines()]
        self.assertEqual([x['method'] for x in frames], ['initialize','initialized','thread/read'])
        self.assertEqual(frames[-1]['params'], {'threadId':'future-root','includeTurns':False})
        original = fake.read_text()
        fake.write_text(original.replace("'source':'appServer'", "'source':{'subAgent':'review'}"))
        self.assertFalse(metadata_root('future-root', codex=str(fake)))
        fake.write_text(original.replace("'parentThreadId':None", "'parentThreadId':'parent'"))
        self.assertFalse(metadata_root('future-root', codex=str(fake)))
        fake.write_text(original.replace("'source':'appServer'", "'source':'unknown'"))
        self.assertIsNone(metadata_root('future-root', codex=str(fake)))
        self.assertEqual(metadata_root('future-root', codex='/nonexistent/synthetic-codex'), None)

    def test_codex_two_sessions_never_merge_on_model(self):
        for session in ['a', 'b']:
            handle_notify({'type': 'agent-turn-complete', 'thread-id': session, 'turn-id': 't'}, self.pub, {'a', 'b'})
        self.assertEqual({x['sessionId'] for x in self.records()}, {'a', 'b'})

    def test_hermes_turn_hook_and_children(self):
        observer = Observer(self.pub)
        observer.subagent_start(child_session_id='child')
        observer.on_session_end(session_id='child', turn_id='t', completed=True, failed=False, interrupted=False)
        observer.on_session_end(session_id='root', turn_id='t', completed=True, failed=False, interrupted=False, model='model')
        observer.on_session_end(session_id='root', turn_id='t2', completed=False, failed=True, interrupted=False)
        observer.on_session_end(session_id='root2', turn_id='t', completed=False, failed=False, interrupted=True)
        events = self.records()
        self.assertEqual(len(events), 3)
        self.assertEqual(sum(x['kind'] == 'done' for x in events), 1)
        self.assertEqual(sum(x['detail'] == 'Turn interrupted' for x in events), 1)
        self.assertEqual(sum(x['detail'] == 'Turn failed' for x in events), 1)

    def test_hermes_observer_request_resolution_never_claims_accept(self):
        observer = Observer(self.pub)
        context = dict(session_id='root', session_key='routing', turn_id='turn', tool_call_id='call')
        observer.pre_approval_request(**context, command='synthetic secret command')
        observer.post_approval_response(**context, choice='once')
        events = self.records()
        self.assertEqual({x['state'] for x in events}, {'pending', 'resolved'})
        self.assertEqual(len({x['requestId'] for x in events}), 1)
        self.assertTrue(all(not x['canDecide'] and 'outcome' not in x for x in events))
        self.assertNotIn('secret command', json.dumps(events))

    def test_hermes_ambiguous_or_missing_correlation_fails_closed(self):
        observer = Observer(self.pub)
        observer.pre_approval_request(session_id='s', turn_id='t')
        context = dict(session_id='s', turn_id='t', tool_call_id='c')
        observer.pre_approval_request(**context)
        observer.pre_approval_request(**context)
        observer.post_approval_response(**context, choice='once')
        self.assertEqual(len(self.records()), 2)
        self.assertTrue(all(x['state'] == 'pending' for x in self.records()))

    def test_hermes_exact_terminal_turn_clears_ambiguous_observers_without_verdict(self):
        observer = Observer(self.pub)
        context = dict(session_id='s', turn_id='t', tool_call_id='c')
        observer.pre_approval_request(**context)
        observer.pre_approval_request(**context)
        observer.post_approval_response(**context, choice='once')
        observer.on_session_end(session_id='s', turn_id='other', completed=True, failed=False, interrupted=False)
        self.assertEqual(sum(x['state'] == 'resolved' for x in self.records()), 0)
        observer.on_session_end(session_id='s', turn_id='t', completed=False, failed=False, interrupted=True)
        cleared = [x for x in self.records() if x['state'] == 'resolved']
        self.assertEqual(len(cleared), 2)
        self.assertTrue(all('outcome' not in x for x in cleared))
        self.assertEqual({x['requestId'] for x in cleared}, {x['requestId'] for x in self.records() if x['kind'] == 'approval'})

    def test_routes_open_exact_sessions_without_approving(self):
        calls = []
        for source, session, target in [('codex', 'root', 'root'), ('super', 'chat', 'chat'), ('hermes', 'stored', 'stored')]:
            event = self.pub.publish(source, session, 't', 'r', 'done', 'Done', 'Turn completed', stored_session=target)
            decision = {'v': 1, 'decisionId': 'decision-' + source, 'source': source, 'sessionId': session,
                        'runId': 't', 'requestId': 'r', 'revision': 1, 'action': 'open',
                        'createdAt': 1000, 'leaseDeadline': 16000}
            (self.directory / 'decisions' / (source + '.json')).write_text(json.dumps(decision))
            (self.directory / 'decisions' / (source + '.json')).chmod(0o600)
        results = consume_open(self.directory, runner=lambda command: calls.append(command), now=1000)
        self.assertEqual([x['status'] for x in results], ['exact-session-open-requested'] * 3)
        self.assertEqual(len(calls), 3)
        self.assertIn(['open', 'codex://threads/root'], calls)
        self.assertIn(['open', 'hermes://open/stored'], calls)
        self.assertTrue(any(x[-3:] == ['chat', 'select', 'chat'] for x in calls))
        self.assertEqual(consume_open(self.directory, runner=lambda x: self.fail('replayed'), now=1001), [])

    def test_fallback_never_claims_exact_open_and_decline_not_consumed(self):
        event = self.pub.publish('deepseek', 's', 't', 'r', 'approval', 'Approval', 'Open on Mac')
        decision = dict(v=1, decisionId='o', source='deepseek', sessionId='s', runId='t', requestId='r', revision=1,
                        action='open', createdAt=1000, leaseDeadline=16000)
        path = self.directory / 'decisions' / 'open.json'
        path.write_text(json.dumps(decision)); path.chmod(0o600)
        results = consume_open(self.directory, runner=lambda _: None, now=1000)
        self.assertEqual(results[0]['status'], 'application-activation-requested')
        decision.update(decisionId='deny', action='decline')
        path.write_text(json.dumps(decision)); path.chmod(0o600)
        self.assertEqual(consume_open(self.directory, runner=lambda _: self.fail('decided'), now=1000), [])
        self.assertTrue(path.exists())

    def test_unsafe_routes_and_missing_stored_id_do_not_open(self):
        self.assertRaises(ValueError, self.pub.publish, 'codex', 'bad/id', 't', 'r', 'done', 'Done', 'Done')
        calls = []
        event = self.pub.publish('hermes', 'runtime', 't', 'r', 'done', 'Done', 'Done')
        command, status = RouteStore(self.directory).command(event)
        self.assertEqual(status, 'application-activation-requested')
        self.assertNotIn('hermes://open/runtime', command)

    def test_open_native_failure_is_reported_without_resolving_request(self):
        import subprocess
        event = self.pub.publish('deepseek', 's', 't', 'r', 'approval', 'Approval', 'Open on Mac')
        decision = dict(v=1, decisionId='open-failure', source='deepseek', sessionId='s', runId='t', requestId='r',
                        revision=1, action='open', createdAt=1000, leaseDeadline=16000)
        path = self.directory / 'decisions' / 'open-failure.json'
        path.write_text(json.dumps(decision)); path.chmod(0o600)
        def fail(_): raise subprocess.CalledProcessError(1, ['synthetic-open'])
        self.assertEqual(consume_open(self.directory, runner=fail, now=1000)[0]['status'], 'open-failed')
        self.assertEqual(self.records()[0]['state'], 'pending')

    def test_private_route_objects_reject_symlinks_and_public_modes(self):
        import os
        self.pub.publish('deepseek', 's', 't', 'r', 'done', 'Done', 'Turn completed')
        routes = self.directory / 'adapter-routes'
        path = next(routes.glob('*.json'))
        path.chmod(0o644)
        self.assertRaises(ValueError, list, RouteStore(self.directory).records())
        path.chmod(0o600)
        path.unlink(); os.symlink('/private/tmp', path)
        self.assertRaises(OSError, list, RouteStore(self.directory).records())

    def test_native_resolution_timestamp_is_strictly_later(self):
        observer = Observer(self.pub)
        context = dict(session_id='s', turn_id='t', tool_call_id='c')
        observer.pre_approval_request(**context)
        observer.post_approval_response(**context, choice='deny')
        events = self.records()
        pending = next(x for x in events if x['state'] == 'pending')
        resolved = next(x for x in events if x['state'] == 'resolved')
        self.assertGreater(resolved['createdAt'], pending['createdAt'])

    def test_super_captured_native_envelope_and_multisession_terminal_outcomes(self):
        observer = SuperObserver(self.pub, {'terminal:root': None, 'chat:other': 'chat-id'})
        def packet(seq, type_, sid='terminal:root'):
            return dict(sequence=seq, stable_target_id=sid, type=type_, timestamp_ms=1000, worktree_path='/private/tmp/synthetic')
        self.assertIsNone(decode_event(dict(kind='ready', sequence=1, targets=['terminal:root'])))
        self.assertEqual(decode_event(packet(2, 'target_closed'))['type'], 'target_closed')
        observer.observe(packet(3, 'approval_needed'))
        observer.observe(packet(4, 'task_complete'))
        observer.observe(packet(5, 'errored', 'chat:other'))
        observer.observe(packet(6, 'cancelled', 'chat:other'))
        observer.observe(packet(7, 'task_complete', 'terminal:child'))
        events = self.records()
        self.assertEqual(sum(x['kind'] == 'done' for x in events), 1)
        self.assertEqual(sum(x['kind'] == 'failed' for x in events), 2)
        self.assertEqual(sum(x['state'] == 'resolved' for x in events), 1)
        self.assertTrue(all(x['canDecide'] is False and 'outcome' not in x for x in events))
        self.assertRaises(UnsupportedContract, decode_event, dict(packet(8, 'task_complete'), unexpected='data'))
        self.assertRaises(UnsupportedContract, decode_event, dict(packet(8, 'task_complete'), sequence=True))

    def test_native_sc_transport_not_a_manual_event_emitter(self):
        fake = Path(self.temp.name).resolve() / 'synthetic-sc'
        fake.write_text("""#!/usr/bin/env python3
import json,sys
if 'list' in sys.argv:
 print(json.dumps({'kind':'agents','response':{'agents':[{'stable_target_id':'terminal:root','ui':'terminal'}]}}))
else:
 print(json.dumps({'kind':'ready','sequence':1,'targets':['terminal:root']}))
 print(json.dumps({'sequence':2,'stable_target_id':'terminal:root','type':'task_complete','timestamp_ms':1000,'worktree_path':'/private/tmp/synthetic'}))
""")
        fake.chmod(0o700)
        subprocess.run([sys.executable, '-m', 'notifications.adapters.super_collector', '--directory', str(self.directory),
                        '--sc', str(fake), '--worktree', '/private/tmp/synthetic', '--target', 'terminal:root'],
                       check=True, capture_output=True)
        self.assertEqual(self.records()[0]['kind'], 'done')
        self.assertFalse(self.records()[0]['canDecide'])

    @unittest.skipUnless(os.environ.get('TASK_NOTIFICATION_TEST_BINARY'), 'run notifications/test.sh for Swift bridge')
    def test_codex_callback_through_real_swift_queue(self):
        handle_notify({'type':'agent-turn-complete','thread-id':'root','turn-id':'t'}, self.pub, {'root'})
        result = subprocess.run([os.environ['TASK_NOTIFICATION_TEST_BINARY'], '--bridge', str(self.directory)],
                                check=True, capture_output=True, text=True)
        card = json.loads(result.stdout)
        self.assertEqual((card['src'], card['kind'], card['decide']), ('codex', 'done', False))
        self.assertEqual(list((self.directory / 'decisions').glob('*.json')), [])

    @unittest.skipUnless(os.environ.get('TASK_NOTIFICATION_TEST_BINARY'), 'run notifications/test.sh for Swift bridge')
    def test_dsh_native_audit_relay_to_real_swift_queue(self):
        code = """import {AuditObserver} from './notifications/adapters/deepseek/index.mjs';
const session={id:'root'};
const ctx={agents:{roots:()=>[{id:'root',session}]}};
const observer=new AuditObserver(ctx,x=>console.log(JSON.stringify(x)),()=>1000);
observer.observe(session,{type:'turn/start',seq:1,data:{turn:1}});
observer.observe(session,{type:'approval/asked',seq:2,data:{id:'native',toolName:'bash'}});
observer.observe(session,{type:'approval/decided',seq:3,data:{id:'native',outcome:'allowed-once'}});
"""
        native = subprocess.run(['node', '--input-type=module', '-e', code], check=True, capture_output=True)
        subprocess.run([sys.executable, '-m', 'notifications.adapters.relay', '--directory', str(self.directory)],
                       input=native.stdout, check=True, capture_output=True)
        result = subprocess.run([os.environ['TASK_NOTIFICATION_TEST_BINARY'], '--bridge', str(self.directory)],
                                check=True, capture_output=True, text=True)
        card = json.loads(result.stdout)
        self.assertEqual((card['src'], card['state'], card['outcome'], card['decide']), ('deepseek','resolved','allowed',False))
        self.assertEqual(list((self.directory / 'decisions').glob('*.json')), [])

    def test_super_unknown_envelopes_are_explicitly_unsupported(self):
        for packet in [{'kind': 'task_complete', 'session_id': 's'}, {'type': 'event', 'event': {'kind': 'task_complete'}}]:
            self.assertRaises(UnsupportedContract, decode_event, packet)


if __name__ == '__main__':
    unittest.main()
