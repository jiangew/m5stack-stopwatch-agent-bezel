import unittest
import json
import tempfile
from pathlib import Path
from notifications.adapters.runtime import Publisher
from notifications.adapters.codex_notify import handle_notify
from scripts.stopwatch_notify import validate_event

class Capture:
    def __init__(self): self.calls=[]
    def publish(self,*args,**kwargs): self.calls.append((args,kwargs))

class RichCodexTests(unittest.TestCase):
    def test_actual_name_and_reply_only_with_opt_in(self):
        record={'type':'agent-turn-complete','thread-id':'root','turn-id':'turn',
                'last-assistant-message':'## Result\n\n调整完成。\n\nTests passed.', 'input-messages':['PRIVATE PROMPT']}
        metadata=lambda _:dict(root=True,name='优化通知布局',cwd='/synthetic/project')
        p=Capture();self.assertTrue(handle_notify(record,p,set(),metadata,rich_content=True))
        args,kw=p.calls[0]
        self.assertEqual(args[5],'优化通知布局');self.assertEqual(args[6],'Result 调整完成。 Tests passed.')
        self.assertEqual(kw['project'],'project');self.assertEqual(kw['state'],'resolved')
        self.assertNotIn('PRIVATE PROMPT',str(p.calls));self.assertNotIn('/synthetic',str(p.calls))
        p=Capture();handle_notify(record,p,{'root'})
        self.assertEqual(p.calls[0][0][5:7],('Codex completed','Turn completed'))
        self.assertNotIn('project',p.calls[0][1])

    def test_missing_name_does_not_use_private_preview(self):
        p=Capture();handle_notify({'type':'agent-turn-complete','thread-id':'root','turn-id':'turn'},p,{'root'},lambda _:dict(root=None,preview='PRIVATE PROMPT'),rich_content=True)
        args,kw=p.calls[0];self.assertEqual(args[5],'');self.assertEqual(args[6],'Reply available on Mac')
        self.assertNotIn('PRIVATE PROMPT',str(p.calls))

    def test_child_and_unknown_root_are_rejected(self):
        r={'type':'agent-turn-complete','thread-id':'child','turn-id':'turn'}
        for metadata,roots in [(dict(root=False,name='秘密'),{'child'}),(dict(root=None),set())]:
            p=Capture();self.assertFalse(handle_notify(r,p,roots,lambda _:metadata,rich_content=True));self.assertEqual(p.calls,[])

    def test_long_reply_utf8_and_untrusted_control_characters(self):
        p=Capture();r={'type':'agent-turn-complete','thread-id':'root','turn-id':'turn','last-assistant-message':'中'*3000+'\x00\u202e'}
        handle_notify(r,p,{'root'},rich_content=True)
        args,kw=p.calls[0];self.assertLessEqual(len(args[6].encode()),4096);self.assertTrue(kw['excerpted']);self.assertNotIn('\x00',args[6]);self.assertNotIn('\u202e',args[6])

    def test_escaped_reply_fits_real_event_and_route_envelopes(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as directory:
            publisher=Publisher(directory,now=lambda:1000)
            record={'type':'agent-turn-complete','thread-id':'r'*128,'turn-id':'t'*128,'last-assistant-message':'"'*4096}
            metadata=lambda _:dict(root=True,name='"'*512,cwd='/synthetic/'+('\\'*64))
            self.assertTrue(handle_notify(record,publisher,set(),metadata,rich_content=True))
            routes=list(publisher.routes.records());self.assertEqual(len(routes),1)
            event,_=routes[0];self.assertTrue(event['excerpted']);self.assertLess(len(event['detail'].encode()),4096)
            inbox=list((Path(directory)/'inbox').glob('*.json'));self.assertEqual(len(inbox),1)
            self.assertEqual(json.loads(inbox[0].read_text())['detail'],event['detail'])
            for path in (Path(directory)/'adapter-routes').glob('*.json'):self.assertLessEqual(path.stat().st_size,8192)

    def test_model_is_exact_thread_configuration_and_explicitly_qualified(self):
        p=Capture();metadata=lambda _:dict(root=True,name='任务',cwd='/synthetic/project',configuredModel='gpt-6.1-sol')
        handle_notify({'type':'agent-turn-complete','thread-id':'root','turn-id':'turn','model':'UNVERIFIED CALLBACK'},p,set(),metadata,rich_content=True)
        _,kw=p.calls[0];self.assertEqual(kw['model'],'gpt-6.1-sol');self.assertIs(kw['model_configured'],True)
        for value in [None,123,'invalid\nmodel','x'*129]:
            p=Capture();handle_notify({'type':'agent-turn-complete','thread-id':'root','turn-id':'turn'},p,{'root'},lambda _:dict(root=True,configuredModel=value),rich_content=True)
            self.assertEqual(p.calls[0][1]['model'],'');self.assertNotIn('model_configured',p.calls[0][1])

    def test_latest_reply_model_marker_wins_without_guessing_from_mentions(self):
        base={'type':'agent-turn-complete','thread-id':'root','turn-id':'turn'}
        metadata=lambda _:dict(root=True,configuredModel='configured-model')
        for text,expected in [('Result\n模型：gpt-6.1-sol','gpt-6.1-sol'),('Done\n- **Model version**: `deepseek-v4-pro`','deepseek-v4-pro'),('Compare gpt-6.1-sol and deepseek-v4-pro.','configured-model'),('```yaml\nmodel: example-model\n```','configured-model'),('模型：first-model\n模型：second-model','configured-model')]:
            p=Capture();handle_notify(dict(base,**{'last-assistant-message':text}),p,set(),metadata,rich_content=True)
            kw=p.calls[0][1];self.assertEqual(kw['model'],expected)
            self.assertEqual(kw.get('model_configured',False),expected=='configured-model')

    def test_optional_metadata_has_strict_types(self):
        base=dict(v=1,eventId='event',source='codex',sessionId='s',runId='r',requestId='q',revision=1,createdAt=1,leaseDeadline=2,kind='done',title='中文',model='',detail='摘录',canDecide=False,state='resolved')
        self.assertEqual(validate_event(dict(base,project='project',excerpted=True))['project'],'project')
        self.assertTrue(validate_event(dict(base,model='native-model',modelConfigured=True))['modelConfigured'])
        for changes in [dict(project=12),dict(excerpted='yes'),dict(project='a'*65),dict(modelConfigured='yes'),dict(modelConfigured=True),dict(modelConfigured=True,source='deepseek',model='x')]:
            with self.assertRaises(ValueError):validate_event(dict(base,**changes))

    def test_terminal_reason_is_strict_and_agrees_with_completion(self):
        base=dict(v=1,eventId='event',source='deepseek',sessionId='s',runId='r',requestId='q',revision=1,createdAt=1,leaseDeadline=2,kind='done',title='中文',model='',detail='摘录',canDecide=False,state='resolved')
        self.assertEqual(validate_event(dict(base,terminalReason='completed'))['terminalReason'],'completed')
        for changes in [dict(terminalReason='unknown'),dict(terminalReason=12),dict(terminalReason='error'),dict(terminalReason='completed',kind='approval'),dict(terminalReason='completed',canDecide=True),dict(terminalReason='completed',state='pending')]:
            with self.assertRaises(ValueError):validate_event(dict(base,**changes))

if __name__=='__main__' :unittest.main()
