"""Synthetic native callbacks only; never inspect user sessions or launch apps."""
import json
import multiprocessing
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
import time

from notifications.adapters.runtime import Publisher, RouteStore, consume_open
from notifications.adapters.codex_notify import handle_notify, metadata_root
from notifications.adapters.hermes_plugin import Observer
from notifications.adapters.super_collector import decode_event, UnsupportedContract, SuperObserver


def route_capacity_writer(directory, event, paused, release, result, hold_snapshot=False):
    """Pause after the pre-publication capacity snapshot in a real child process."""
    import notifications.adapters.runtime as runtime
    original = runtime.os.listdir
    calls = 0
    def listdir(fd):
        nonlocal calls
        names = original(fd)
        calls += 1
        if hold_snapshot and calls == 2:
            paused.set()
            if not release.wait(10): raise RuntimeError('capacity test synchronization timed out')
        return names
    runtime.os.listdir = listdir
    try:
        runtime.RouteStore(directory).save(event)
        result.put('saved')
    except ValueError as error:
        result.put(str(error))
    finally:
        runtime.os.listdir = original


def generic_open_after_snapshot(directory, paused, release, result, now):
    """Freeze the real consumer immediately after its inventory snapshot."""
    import notifications.adapters.runtime as runtime
    original = runtime.RouteStore.records
    def snapshot(store):
        records = list(original(store))
        paused.set()
        if not release.wait(5): raise RuntimeError('snapshot synchronization timed out')
        yield from records
    runtime.RouteStore.records = snapshot
    calls = []
    try:
        result.put((runtime.consume_open(directory, runner=calls.append, now=now), calls))
    finally:
        runtime.RouteStore.records = original


def generic_open_paused_during_claim(directory, paused, release, result, now):
    import notifications.adapters.runtime as runtime
    original = runtime.bridge.decisions
    def claim(*args, **kwargs):
        paused.set()
        if not release.wait(5): raise RuntimeError('claim synchronization timed out')
        return original(*args, **kwargs)
    runtime.bridge.decisions = claim
    try:
        result.put(runtime.consume_open(directory, runner=lambda _: None, now=now))
    finally:
        runtime.bridge.decisions = original


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
  print(json.dumps({'id':2,'result':{'thread':{'id':request['params']['threadId'],'source':'appServer','parentThreadId':None,'turns':[],'model':'native-configured-model','preview':'synthetic private prompt'}}}),flush=True)
""")
        fake.chmod(0o700)
        self.assertTrue(metadata_root('future-root', codex=str(fake)))
        self.assertEqual(metadata_root('future-root', codex=str(fake), display=True),dict(root=True,name=None,cwd=None,configuredModel='native-configured-model'))
        text = calls.read_text().replace('\\n', '\n')
        frames = [json.loads(x) for x in text.splitlines()]
        self.assertEqual([x['method'] for x in frames], ['initialize','initialized','thread/read']*2)
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

    def test_inventory_lock_is_private_single_link_and_never_follows_symlinks(self):
        event = self.pub.publish('codex', 'root', 't', 'r', 'done', 'Done', 'Turn completed')
        lock = self.directory / 'adapter-routes' / '.inventory.lock'
        self.assertEqual(lock.stat().st_mode & 0o777, 0o600)
        lock.chmod(0o644)
        self.assertRaises(ValueError, RouteStore(self.directory).save, event)
        self.assertRaises(ValueError, list, RouteStore(self.directory).records())
        lock.chmod(0o600)
        alias = Path(self.temp.name) / 'lock-hardlink'
        os.link(lock, alias)
        self.assertRaises(ValueError, RouteStore(self.directory).save, event)
        alias.unlink(); lock.unlink()
        os.symlink('/private/tmp', lock)
        self.assertRaises(OSError, RouteStore(self.directory).save, event)
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

    def test_native_sc_batch_delivers_before_subscription_eof(self):
        fake = Path(self.temp.name).resolve() / 'synthetic-live-sc'
        fake.write_text("""#!/usr/bin/env python3
import json,os,sys,time
if 'list' in sys.argv:
 print(json.dumps({'kind':'agents','response':{'agents':[{'stable_target_id':'terminal:root','ui':'terminal'}]}}))
else:
 frames=[{'kind':'ready','sequence':1,'targets':['terminal:root']},
 {'sequence':2,'stable_target_id':'terminal:root','type':'task_complete','timestamp_ms':1000,'worktree_path':'/private/tmp/synthetic'}]
 os.write(sys.stdout.fileno(), ('\\n'.join(json.dumps(x) for x in frames)+'\\n').encode())
 time.sleep(30)
""")
        fake.chmod(0o700)
        collector = subprocess.Popen([sys.executable, '-m', 'notifications.adapters.super_collector', '--directory', str(self.directory),
                                      '--sc', str(fake), '--worktree', '/private/tmp/synthetic', '--target', 'terminal:root'],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        try:
            deadline = time.monotonic() + 2
            while not self.records() and collector.poll() is None and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertIsNone(collector.poll(), 'subscription must remain open before EOF')
            self.assertEqual([x['kind'] for x in self.records()], ['done'])
        finally:
            import signal
            os.killpg(collector.pid, signal.SIGTERM)
            collector.wait(timeout=5)

    def test_route_capacity_is_atomic_across_callback_processes(self):
        event = self.pub.publish('codex', 'root', 'turn', 'seed', 'done', 'Done', 'Turn completed')
        routes = RouteStore(self.directory)
        for number in range(254):
            routes.save(dict(event, requestId='seed-' + str(number)))
        ctx = multiprocessing.get_context('fork')
        paused, release, result = ctx.Event(), ctx.Event(), ctx.Queue()
        first = ctx.Process(target=route_capacity_writer,
                            args=(str(self.directory), dict(event, requestId='first'), paused, release, result, True))
        second = ctx.Process(target=route_capacity_writer,
                             args=(str(self.directory), dict(event, requestId='second'), paused, release, result))
        first.start()
        try:
            self.assertTrue(paused.wait(5), 'first callback reached its capacity snapshot')
            second.start()
            # Without an inventory lock the second callback publishes while the first is paused.
            # With the lock it cannot reach publication until the first releases ownership.
            second.join(timeout=0.3)
        finally:
            release.set()
            first.join(timeout=5)
            if second.pid: second.join(timeout=5)
            for proc in (first, second):
                if proc.pid and proc.is_alive(): proc.kill(); proc.join()
        self.assertEqual(first.exitcode, 0)
        self.assertEqual(second.exitcode, 0)
        self.assertEqual(sorted([result.get(timeout=2), result.get(timeout=2)]), ['adapter route inventory full', 'saved'])
        self.assertEqual(len(list(routes.records())), 256)
        routes.save(dict(event, detail='Updated terminal metadata'))
        self.assertEqual(len(list(routes.records())), 256, 'existing identities remain writable at capacity')

    def test_native_sc_partial_frame_does_not_block_another_root(self):
        fake = Path(self.temp.name).resolve() / 'synthetic-partial-sc'
        fake.write_text("""#!/usr/bin/env python3
import json,os,sys,time
if 'list' in sys.argv:
 print(json.dumps({'kind':'agents','response':{'agents':[{'stable_target_id':s,'ui':'terminal'} for s in ['terminal:partial','terminal:complete']]}}))
else:
 sid=sys.argv[sys.argv.index('--to')+1][3:]
 if sid=='terminal:partial': os.write(sys.stdout.fileno(), b'{"sequence":')
 else:
  packet={'sequence':2,'stable_target_id':sid,'type':'task_complete','timestamp_ms':1000,'worktree_path':'/private/tmp/synthetic'}
  os.write(sys.stdout.fileno(), (json.dumps(packet)+'\\n').encode())
 time.sleep(30)
""")
        fake.chmod(0o700)
        collector = subprocess.Popen([sys.executable, '-m', 'notifications.adapters.super_collector', '--directory', str(self.directory),
                                      '--sc', str(fake), '--worktree', '/private/tmp/synthetic',
                                      '--target', 'terminal:partial', '--target', 'terminal:complete'],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        try:
            deadline = time.monotonic() + 2
            while not self.records() and collector.poll() is None and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertIsNone(collector.poll())
            self.assertEqual([(x['sessionId'], x['kind']) for x in self.records()], [('terminal:complete', 'done')])
        finally:
            import signal
            os.killpg(collector.pid, signal.SIGTERM)
            collector.wait(timeout=5)

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

class NativeRelayTests(unittest.TestCase):
    """Exercise the actual subprocess protocol/private bridge, with inert OS activation."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='stopwatch-native-relay-')
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name).resolve() / 'bridge'
        self.event = dict(v=1, eventId='synthetic-event', source='deepseek',sessionId='s',runId='t',requestId='r',revision=2,
                          createdAt=int(time.time()*1000),leaseDeadline=int(time.time()*1000)+15000,
                          kind='approval',title='DeepSeek approval',model='',detail='complete synthetic scope',canDecide=True,state='pending')

    def launch(self, env=None, command=None):
        child = subprocess.Popen(command or [sys.executable,'notifications/adapters/relay.py','--directory',str(self.directory),'--native'],
                                 stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
        def cleanup():
            if child.poll() is None: child.kill()
            child.wait(timeout=5)
            for stream in (child.stdin,child.stdout,child.stderr): stream.close()
        self.addCleanup(cleanup)
        return child

    def send(self, child, message):
        child.stdin.write(json.dumps(message)+'\n');child.stdin.flush()

    def decision(self, action='allow_once'):
        record = dict(self.event, decisionId='synthetic-decision', action=action)
        record = {k:record[k] for k in ('v','decisionId','source','sessionId','runId','requestId','revision','action','createdAt','leaseDeadline')}
        path=self.directory/'decisions'/'synthetic.json';path.write_text(json.dumps(record));path.chmod(0o600)
        return record

    def test_ready_exact_decision_once_and_fresh_open_consumer_cannot_steal(self):
        child=self.launch()
        self.assertEqual(json.loads(child.stdout.readline()),{'type':'ready','protocol':'stopwatch.dsh.native-approval.v1'})
        self.send(child,{'type':'event','event':self.event})
        # published means private route exists before the decision can be read.
        self.assertEqual(json.loads(child.stdout.readline())['type'],'published')
        decision=self.decision()
        self.assertEqual(consume_open(self.directory,runner=lambda _:self.fail('stole owned decision')),[])
        received=json.loads(child.stdout.readline())
        self.assertEqual(received,{'type':'decision','decision':decision})
        child.stdin.close();child.wait(timeout=5)
        records=list(RouteStore(self.directory).records())
        self.assertFalse(records[0][0]['canDecide'])
        self.assertEqual(child.returncode,0)

    def test_generic_publisher_rejects_native_but_aged_owned_open_remains_usable(self):
        pub=Publisher(self.directory)
        with self.assertRaisesRegex(ValueError,'unsupported'):pub.forward(self.event)
        RouteStore(self.directory).save(self.event)
        self.decision('open')
        self.assertEqual(consume_open(self.directory,runner=lambda _:self.fail('fresh route stolen'),now=self.event['createdAt']),[])
        calls=[]
        result=consume_open(self.directory,runner=calls.append,now=self.event['leaseDeadline']+1)
        self.assertEqual(result[0]['status'],'application-activation-requested')
        self.assertEqual(calls,[['open','-b','com.deepseek.dsh']])

    def test_unsafe_storage_and_unknown_frame_terminate_without_capability(self):
        self.directory.mkdir(mode=0o755)
        child=self.launch();child.wait(timeout=5)
        self.assertEqual(child.returncode,1);self.assertEqual(child.stdout.read(),'')
        self.directory.chmod(0o700)
        child=self.launch();self.assertEqual(json.loads(child.stdout.readline())['type'],'ready')
        self.send(child,{'type':'invented'})
        child.wait(timeout=5);self.assertEqual(child.returncode,1)

    def test_owned_open_is_released_before_actual_relay_activates_inert_os_runner(self):
        runner=Path(self.temp.name)/'open';capture=Path(self.temp.name)/'activation'
        runner.write_text('#!'+sys.executable+'\nimport sys\nfrom pathlib import Path\nPath('+repr(str(capture))+').write_text("\\n".join(sys.argv[1:]))\n')
        runner.chmod(0o700)
        child=self.launch(dict(os.environ,PATH=self.temp.name+os.pathsep+os.environ.get('PATH','')))
        self.assertEqual(json.loads(child.stdout.readline())['type'],'ready')
        self.send(child,{'type':'event','event':self.event});self.assertEqual(json.loads(child.stdout.readline())['type'],'published')
        self.decision('open');self.assertEqual(json.loads(child.stdout.readline())['decision']['action'],'open')
        self.assertFalse(capture.exists(),'relay cannot activate before parent releases owner')
        withdrawn=dict(self.event,canDecide=False,createdAt=self.event['createdAt']+1)
        self.send(child,{'type':'event','event':withdrawn});self.assertEqual(json.loads(child.stdout.readline())['type'],'published')
        self.send(child,{'type':'open','event':withdrawn})
        child.stdin.close();child.wait(timeout=5)
        self.assertEqual(child.returncode,0);self.assertEqual(capture.read_text(),'-b\ncom.deepseek.dsh')

    def test_restart_does_not_restore_owned_approval_from_disk(self):
        RouteStore(self.directory).save(self.event)
        self.decision()
        child=self.launch();self.assertEqual(json.loads(child.stdout.readline())['type'],'ready')
        time.sleep(0.1)
        child.stdin.close();child.wait(timeout=5)
        self.assertEqual(child.returncode,0)
        self.assertTrue((self.directory/'decisions'/'synthetic.json').exists(),'restart must not claim old approval')

    def test_65th_owned_request_fails_closed_and_withdraws_live_routes(self):
        child=self.launch();self.assertEqual(json.loads(child.stdout.readline())['type'],'ready')
        for i in range(64):
            self.send(child,{'type':'event','event':dict(self.event,requestId='r-'+str(i))})
            self.assertEqual(json.loads(child.stdout.readline())['type'],'published')
        self.send(child,{'type':'event','event':dict(self.event,requestId='overflow')})
        child.wait(timeout=5);self.assertEqual(child.returncode,1)
        routes=list(RouteStore(self.directory).records())
        self.assertEqual(len(routes),64);self.assertTrue(all(not event['canDecide'] for event,_ in routes))

    def test_oversize_partial_frame_disables_and_withdraws_live_route(self):
        child=self.launch();self.assertEqual(json.loads(child.stdout.readline())['type'],'ready')
        self.send(child,{'type':'event','event':self.event});self.assertEqual(json.loads(child.stdout.readline())['type'],'published')
        child.stdin.write('x'*8193);child.stdin.flush()
        child.wait(timeout=5);self.assertEqual(child.returncode,1)
        self.assertFalse(list(RouteStore(self.directory).records())[0][0]['canDecide'])

    def clock_relay(self):
        """Only time is synthetic; imports and process/private-file operations are real."""
        clock=Path(self.temp.name)/'clock';clock.write_text(str(self.event['createdAt']))
        wrapper=Path(self.temp.name)/'clock_relay.py'
        wrapper.write_text('import sys\nfrom pathlib import Path\nsys.path.insert(0,'+repr(str(Path.cwd()))+')\n'
                           'from notifications.adapters.deepseek import native_relay\n'
                           'native_relay.time.time=lambda: int(Path(sys.argv[2]).read_text())/1000\n'
                           'native_relay.serve(sys.argv[1])\n')
        return self.launch(command=[sys.executable,str(wrapper),str(self.directory),str(clock)]),clock

    def advance_clock(self, clock, now):
        temporary=clock.with_suffix('.next');temporary.write_text(str(now));temporary.replace(clock)

    def test_renewal_between_snapshot_and_claim_cannot_steal_native_open(self):
        now=self.event['createdAt']
        expired=dict(self.event,createdAt=now-16000,leaseDeadline=now-1000)
        RouteStore(self.directory).save(expired)
        self.decision('open')
        paused,release=multiprocessing.Event(),multiprocessing.Event();result=multiprocessing.Queue()
        consumer=multiprocessing.Process(target=generic_open_after_snapshot,args=(str(self.directory),paused,release,result,now))
        consumer.start();self.addCleanup(lambda: consumer.is_alive() and consumer.terminate())
        self.assertTrue(paused.wait(5),'consumer must read expired snapshot')
        # Exact same identity/revision is renewed before the generic atomic claim.
        RouteStore(self.directory).save(self.event)
        release.set();consumer.join(5);self.assertEqual(consumer.exitcode,0)
        received,calls=result.get(timeout=2)
        self.assertEqual(received,[]);self.assertEqual(calls,[])
        self.assertTrue((self.directory/'decisions'/'synthetic.json').exists())

    def test_expired_but_live_native_owner_keeps_open_and_never_accepts_expired_allow(self):
        import selectors
        child,clock=self.clock_relay();self.assertEqual(json.loads(child.stdout.readline())['type'],'ready')
        self.send(child,{'type':'event','event':self.event});self.assertEqual(json.loads(child.stdout.readline())['type'],'published')
        # The lease expires while the native callback still belongs to this live child.
        now=self.event['leaseDeadline']+1;self.advance_clock(clock,now);time.sleep(0.12)
        self.decision('allow_once')
        allow_file=self.directory/'decisions'/'expired-allow.json'
        (self.directory/'decisions'/'synthetic.json').rename(allow_file)
        time.sleep(0.1)
        fresh=dict(self.decision('allow_once'),createdAt=now,leaseDeadline=now+15000)
        fresh_file=self.directory/'decisions'/'fresh-allow.json';fresh_file.write_text(json.dumps(fresh));fresh_file.chmod(0o600)
        self.decision('open')
        self.assertEqual(consume_open(self.directory,runner=lambda _:self.fail('live owner OPEN stolen'),now=now),[])
        selector=selectors.DefaultSelector();selector.register(child.stdout,selectors.EVENT_READ)
        self.addCleanup(selector.close)
        self.assertTrue(selector.select(2),'expired-but-live owner must receive OPEN')
        self.assertEqual(json.loads(child.stdout.readline())['decision']['action'],'open')
        self.assertFalse(allow_file.exists(),'expired allow is discarded without submission')
        self.assertTrue(fresh_file.exists(),'fresh answer to expired native lease must remain unclaimed')

    def test_crashed_owner_releases_private_lock_and_aged_open_falls_back(self):
        child,clock=self.clock_relay();self.assertEqual(json.loads(child.stdout.readline())['type'],'ready')
        self.send(child,{'type':'event','event':self.event});self.assertEqual(json.loads(child.stdout.readline())['type'],'published')
        child.kill();child.wait(timeout=5)
        self.decision('open');calls=[]
        results=consume_open(self.directory,runner=calls.append,now=self.event['leaseDeadline']+1)
        self.assertEqual(results[0]['status'],'application-activation-requested')
        self.assertEqual(calls,[['open','-b','com.deepseek.dsh']])

    def test_native_owner_window_does_not_renew_with_decision_lease(self):
        child,clock=self.clock_relay();self.assertEqual(json.loads(child.stdout.readline())['type'],'ready')
        self.send(child,{'type':'event','event':self.event});self.assertEqual(json.loads(child.stdout.readline())['type'],'published')
        later=self.event['createdAt']+59000;self.advance_clock(clock,later)
        renewed=dict(self.event,createdAt=later,leaseDeadline=later+15000)
        self.send(child,{'type':'event','event':renewed});self.assertEqual(json.loads(child.stdout.readline())['type'],'published')
        self.advance_clock(clock,later+1002)
        child.wait(timeout=3)
        self.assertEqual(child.returncode,1,'ownership must retire by original60swindow')
        self.assertFalse(list(RouteStore(self.directory).records())[0][0]['canDecide'])


    def test_route_renewal_lock_remains_held_through_generic_decision_claim(self):
        import fcntl
        now=self.event['createdAt']
        RouteStore(self.directory).save(dict(self.event,createdAt=now-16000,leaseDeadline=now-1000))
        self.decision('open')
        paused,release=multiprocessing.Event(),multiprocessing.Event();result=multiprocessing.Queue()
        consumer=multiprocessing.Process(target=generic_open_paused_during_claim,args=(str(self.directory),paused,release,result,now))
        consumer.start();self.addCleanup(lambda: consumer.is_alive() and consumer.terminate())
        self.assertTrue(paused.wait(5),'claim must pause inside real private bridge call')
        fd=os.open(self.directory/'adapter-routes'/'.inventory.lock',os.O_RDWR|os.O_NOFOLLOW)
        try:
            # Every native route save/acquire uses this same lock. The latest
            # route cannot renew between generic validation and atomic claim.
            with self.assertRaises(BlockingIOError):fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        finally:
            os.close(fd);release.set()
        consumer.join(5);self.assertEqual(consumer.exitcode,0)
        self.assertEqual(result.get(timeout=2)[0]['status'],'application-activation-requested')

    def test_owner_lock_inventory_is_bounded_even_for_orphaned_lock_files(self):
        RouteStore(self.directory).save(self.event)
        folder=self.directory/'adapter-routes'
        for i in range(256):
            path=folder/('.owner-'+format(i,'064x')+'.json');path.write_text('');path.chmod(0o600)
        self.decision('open')
        with self.assertRaisesRegex(ValueError,'owner lock inventory full'):
            consume_open(self.directory,runner=lambda _:self.fail('unbounded lock inventory'),now=self.event['leaseDeadline']+1)
        self.assertTrue((self.directory/'decisions'/'synthetic.json').exists())
