import unittest
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

    def test_optional_metadata_has_strict_types(self):
        base=dict(v=1,eventId='event',source='codex',sessionId='s',runId='r',requestId='q',revision=1,createdAt=1,leaseDeadline=2,kind='done',title='中文',model='',detail='摘录',canDecide=False,state='resolved')
        self.assertEqual(validate_event(dict(base,project='project',excerpted=True))['project'],'project')
        for changes in [dict(project=12),dict(excerpted='yes'),dict(project='a'*65)]:
            with self.assertRaises(ValueError):validate_event(dict(base,**changes))

if __name__=='__main__':unittest.main()
