import test from 'node:test';
import assert from 'node:assert/strict';
import {AuditObserver,apply} from '../adapters/deepseek/index.mjs';
function fixture(richContent=true){
 const output=[],session={id:'root',header:{cwd:'/synthetic/桌面助手'},snapshotEvents(){throw Error('history forbidden');},requestHeader(){throw Error('request header forbidden');}};
 let title='优化通知页布局';const agent={id:session.id,session};
 const ctx={agents:{roots:()=>[agent]},sessionProjections:{stateOf(_s,key){return key==='title'?title:undefined;}}};
 const observer=new AuditObserver(ctx,x=>output.push(x),()=>1000,{richContent});
 const send=(type,data,seq=1,s=session)=>observer.observe(s,{type,data,seq});
 const start=()=>send('turn/start',{turn:1});
 const message=(text,extra=[])=>send('assistant/message',{turn:1,message:{role:'assistant',content:[{type:'text',text},...extra]}});
 return {session,ctx,observer,output,send,start,message,rename:s=>title=s};
}
test('opted-in native title/cwd and committed visible reply only, no history/model calls',()=>{
 const f=fixture();f.start();f.message('## Result\n\n已完成布局调整。',[{type:'thinking',text:'PRIVATE THOUGHT'},{type:'image',data:'PRIVATE IMAGE'}]);
 f.send('turn/end',{turn:1,reason:{kind:'completed'}});const e=f.output.at(-1);
 assert.equal(e.title,'优化通知页布局');assert.equal(e.project,'桌面助手');assert.equal(e.detail,'Result 已完成布局调整。');assert.equal(e.state,'resolved');assert.equal(e.terminalReason,'completed');assert.equal(e.canDecide,false);assert.equal(e.model,'');
 assert.ok(!JSON.stringify(e).includes('PRIVATE'));assert.ok(!JSON.stringify(e).includes('/synthetic'));
});
test('default-off keeps legacy privacy and event contract',()=>{
 const f=fixture(false);f.start();f.message('PRIVATE REPLY');f.send('turn/end',{turn:1,reason:{kind:'completed'}});
 const e=f.output.at(-1);assert.equal(e.title,'DeepSeek task');assert.equal(e.detail,'Turn completed');assert.ok(!('project' in e));assert.ok(!('terminalReason' in e));
});
test('child, stale turn, tool-call-bearing message and missing turn start cannot supply final reply',()=>{
 for(const kind of ['child','stale','tool','no-start']){
  const f=fixture();if(kind!=='no-start')f.start();
  if(kind==='child')f.send('assistant/message',{turn:1,message:{content:[{type:'text',text:'PRIVATE'}]}},2,{id:'child'});
  if(kind==='stale')f.send('assistant/message',{turn:2,message:{content:[{type:'text',text:'PRIVATE'}]}},2);
  if(kind==='tool')f.message('PRIVATE',[{type:'tool-call',id:'tool',name:'bash',arguments:{}}]);
  if(kind==='no-start')f.message('PRIVATE');
  f.send('turn/end',{turn:1,reason:{kind:'completed'}});assert.equal(f.output.at(-1).detail,'Reply available on Mac',kind);
 }
});
test('native terminal reasons stay distinct and only actual completion uses the reply',()=>{
 for(const reason of ['completed','error','aborted','blocked','max-tokens']){
  const f=fixture();f.start();f.message('Visible reply');f.send('turn/end',{turn:1,reason:{kind:reason}});const e=f.output.at(-1);
  assert.equal(e.terminalReason,reason);assert.equal(e.state,'resolved');assert.equal(e.kind,reason==='completed'?'done':'failed');
  if(reason!=='completed')assert.notEqual(e.detail,'Visible reply');
 }
});
test('pending metadata freezes across title changes, heartbeat and authoritative native resolution',()=>{
 const f=fixture();f.start();f.send('approval/asked',{id:'approval',toolName:'bash',reason:'PRIVATE REQUEST'});const first=f.output.at(-1);assert.equal(first.title,'优化通知页布局');
 f.rename('Changed title');f.session.header={cwd:'/other/project'};f.observer.heartbeat();f.send('approval/decided',{id:'approval',outcome:'allowed-once'});
 for(const e of f.output){assert.equal(e.title,first.title);assert.equal(e.project,first.project);assert.equal(e.detail,first.detail);assert.equal(e.canDecide,false);}
 assert.equal(f.output.at(-1).outcome,'allowed');assert.ok(!JSON.stringify(f.output).includes('PRIVATE'));
});
test('Unicode/JSON fitting reserves route and Swift slash expansion; missing title stays missing',()=>{
 for(const text of ['中'.repeat(3000),'"'.repeat(5000),'/'.repeat(5000),'\\'.repeat(5000)]){
  const f=fixture();f.rename('中'.repeat(400));f.start();f.message(text+'\u202e\0');f.send('turn/end',{turn:1,reason:{kind:'completed'}});const e=f.output.at(-1);
  assert.ok(Buffer.byteLength(e.title)<=512);assert.ok(Buffer.byteLength(e.detail)<=4096);assert.equal(e.excerpted,true);
  const route=JSON.stringify({event:e,storedSession:null});assert.ok(Buffer.byteLength(route)+[...route].filter(x=>x==='/').length<=8192);assert.ok(!/[\u202e\0]/.test(e.detail));
 }
 const f=fixture();f.rename(null);f.start();f.send('turn/end',{turn:1,reason:{kind:'completed'}});assert.equal(f.output.at(-1).title,'');
});
test('rich capture cannot enable the separate native decision owner',()=>{
 assert.throws(()=>apply({}, {directory:'/synthetic',relayScript:'/synthetic/relay.py',richContent:true,nativeApprovals:true}),/rich|read.only/i);
});

test('read-only input freezes metadata through continued and native answered projection',()=>{
 const f=fixture();let active=[],settled=[];
 const titleProjection=f.ctx.sessionProjections.stateOf;
 f.ctx.sessionProjections.stateOf=(session,key)=>key==='userQuestions'?{questions:{active,settled}}:titleProjection(session,key);
 f.start();active=[{callId:'question',state:'open',questions:[{question:'PRIVATE QUESTION'}]}];
 f.send('tool/call',{turn:1});const first=f.output.at(-1);assert.equal(first.kind,'input');assert.equal(first.title,'优化通知页布局');assert.equal(first.project,'桌面助手');
 f.rename('New name');active[0].state='continued';f.send('tool/result',{});assert.equal(f.output.length,1);
 active=[];settled=[{callId:'question',answers:[{answer:'PRIVATE ANSWER'}]}];f.send('user/message',{});
 const final=f.output.at(-1);assert.equal(final.outcome,'answered');assert.equal(final.title,first.title);assert.equal(final.detail,first.detail);assert.equal(final.canDecide,false);assert.ok(!JSON.stringify(f.output).includes('PRIVATE'));
});

test('execution model comes from exact current native request/message and freezes on attention',()=>{
 const f=fixture();f.start();f.send('request/header',{header:{config:{provider:'synthetic',model:'deepseek-v4-pro'}}});
 f.send('assistant/message',{turn:1,message:{role:'assistant',source:{model:'deepseek-v4-pro-202610'},content:[{type:'tool-call',id:'tool'}]}});
 f.send('approval/asked',{id:'request'});const initial=f.output.at(-1);assert.equal(initial.model,'deepseek-v4-pro-202610');
 f.send('request/header',{header:{config:{model:'different-model'}}});f.observer.heartbeat();assert.equal(f.output.at(-1).model,initial.model);
 f.send('approval/decided',{id:'request',outcome:'rejected'});assert.equal(f.output.at(-1).model,initial.model);
 f.send('assistant/message',{turn:1,message:{role:'assistant',source:{model:'deepseek-v4-pro-final'},content:[{type:'text',text:'Done'}]}});
 f.send('turn/end',{turn:1,reason:{kind:'completed'}});assert.equal(f.output.at(-1).model,'deepseek-v4-pro-final');
 f.send('turn/start',{turn:2});f.send('approval/asked',{id:'second'});assert.equal(f.output.at(-1).model,'');
});
test('unobserved, stale and child model events cannot supply a model; legacy stays empty',()=>{
 for(const kind of ['unobserved','stale','child','legacy']){
  const f=fixture(kind!=='legacy');if(kind!=='unobserved')f.start();
  f.send('assistant/message',{turn:kind==='stale'?2:1,message:{role:'assistant',source:{model:'PRIVATE-MODEL'},content:[]}},2,kind==='child'?{id:'child'}:f.session);
  f.send('turn/end',{turn:1,reason:{kind:'completed'}});assert.equal(f.output.at(-1).model,'',kind);
 }
});
