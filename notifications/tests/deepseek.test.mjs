import test from 'node:test';
import assert from 'node:assert/strict';
import { AuditObserver, apply } from '../adapters/deepseek/index.mjs';

function fixture() {
  const output = [], session = { id: 'root' }, child = { id: 'child' };
  const rootAgent = { id: 'root', session };
  const ctx = { agents: { roots: () => [rootAgent] } };
  return { output, session, child, ctx, observer: new AuditObserver(ctx, record => output.push(record), () => 1000) };
}
test('root turns only; tool, child and failed/interrupted are not done', () => {
  const f = fixture();
  f.observer.observe(f.session, { type: 'tool/result', seq: 1, data: {} });
  f.observer.observe(f.child, { type: 'turn/end', seq: 2, data: { turn: 1, reason: { kind: 'completed' } } });
  for (const [turn, kind] of [[1, 'completed'], [2, 'error'], [3, 'aborted']])
    f.observer.observe(f.session, { type: 'turn/end', seq: turn + 3, data: { turn, reason: { kind } } });
  assert.deepEqual(f.output.map(x => [x.kind, x.detail]), [
    ['done', 'Turn completed'], ['failed', 'Turn failed'], ['failed', 'Turn interrupted']]);
});
test('native audit identity and outcome, resolution keeps scope and never enables decisions', () => {
  const f = fixture();
  f.observer.observe(f.session, { type: 'turn/start', seq: 1, data: { turn: 7 } });
  f.observer.observe(f.session, { type: 'approval/asked', seq: 2, data: { id: 'native-id', toolName: 'bash', callId: 'tool-id', reason: 'sensitive reason' } });
  f.observer.heartbeat();
  f.observer.observe(f.session, { type: 'approval/decided', seq: 3, data: { id: 'native-id', outcome: 'allowed-once' } });
  assert.equal(f.output.length, 3);
  assert.ok(f.output.every(x => x.requestId === 'native-id' && x.canDecide === false));
  assert.equal(f.output[2].outcome, 'allowed');
  assert.equal(f.output[0].detail, f.output[2].detail);
  assert.ok(!JSON.stringify(f.output).includes('sensitive reason'));
});
test('unknown resolution, missing turn and child audits cannot create a pending record', () => {
  const f = fixture();
  f.observer.observe(f.session, { type: 'approval/asked', seq: 2, data: { id: 'unknown', toolName: 'bash' } });
  f.observer.observe(f.session, { type: 'approval/decided', seq: 3, data: { id: 'unknown', outcome: 'allowed-once' } });
  assert.equal(f.output.length, 0);
});
test('multiple roots are isolated and withdrawal is authoritative cancelled', () => {
  const f = fixture(); const second = { id: 'other' };
  f.ctx.agents.roots = () => [{ id: 'root', session: f.session }, { id: 'other', session: second }];
  for (const session of [f.session, second]) {
    f.observer.observe(session, { type: 'turn/start', seq: 1, data: { turn: 1 } });
    f.observer.observe(session, { type: 'approval/asked', seq: 2, data: { id: 'same-native-id', toolName: 'bash' } });
  }
  f.observer.observe(f.session, { type: 'approval/decided', seq: 3, data: { id: 'same-native-id', outcome: 'cancelled' } });
  assert.equal(f.output.filter(x => x.state === 'resolved').length, 1);
  assert.equal(f.output.at(-1).outcome, 'cancelled');
  assert.equal(f.observer.pending.size, 1);
});
test('native userQuestions projection retains continued inputs until native settlement', () => {
  const f = fixture(); let active = [], settled = [];
  f.ctx.sessionProjections = { stateOf: () => ({ questions: { active, settled } }) };
  f.observer.observe(f.session, { type: 'turn/start', seq: 1, data: { turn: 1 } });
  active = [{ callId: 'question-call', state: 'open', questions: [{ id: 'q', question: 'private question' }] }];
  f.observer.observe(f.session, { type: 'tool/call', seq: 2, data: { turn: 1 } });
  active[0].state = 'continued';
  f.observer.observe(f.session, { type: 'tool/result', seq: 3, data: {} });
  assert.equal(f.output.filter(x => x.kind === 'input' && x.state === 'resolved').length, 0);
  active = []; settled = [{ callId: 'question-call', answers: [{ id: 'q', selected: ['private answer'] }] }];
  f.observer.observe(f.session, { type: 'user/message', seq: 4, data: {} });
  assert.equal(f.output.at(-1).kind, 'input');
  assert.equal(f.output.at(-1).state, 'resolved');
  assert.equal(f.output.at(-1).outcome, 'answered');
  assert.ok(!JSON.stringify(f.output).includes('private'));
});
test('unavailable optional input projection cannot suppress native completion', () => {
  const f = fixture();
  f.ctx.sessionProjections = { stateOf() { throw new Error('projection unavailable'); } };
  f.observer.observe(f.session, { type: 'turn/end', seq: 1, data: { turn: 1, reason: { kind: 'completed' } } });
  assert.equal(f.output[0].kind, 'done');
});
test('terminal native turn withdraws unresolved audit observations without accepted verdict', () => {
  const f = fixture();
  f.observer.observe(f.session, { type: 'turn/start', seq: 1, data: { turn: 1 } });
  f.observer.observe(f.session, { type: 'approval/asked', seq: 2, data: { id: 'native', toolName: 'bash' } });
  f.observer.observe(f.session, { type: 'turn/end', seq: 3, data: { turn: 2, reason: { kind: 'completed' } } });
  assert.equal(f.observer.pending.size, 1);
  f.observer.observe(f.session, { type: 'turn/end', seq: 4, data: { turn: 1, reason: { kind: 'error' } } });
  const cleared = f.output.filter(x => x.kind === 'approval' && x.state === 'resolved');
  assert.equal(cleared.length, 1);
  assert.equal(cleared[0].requestId, 'native');
  assert.ok(!('outcome' in cleared[0]));
  assert.equal(f.observer.pending.size, 0);
});

// These fail if native admission, full scope, lease/identity or one-shot ownership is weakened.
async function ownerFixture() {
  const { ApprovalOwner } = await import('../adapters/deepseek/index.mjs');
  assert.equal(typeof ApprovalOwner, 'function', 'missing native approval owner');
  const f = fixture(); let clock=1000;
  f.observer.now=()=>clock;
  const transport={ready:true, send:record=>f.output.push(record), open:record=>transport.opened=record};
  const owner=new ApprovalOwner(f.observer,transport,()=>clock);
  const freeze=value=>{if(value && typeof value==='object'){Object.values(value).forEach(freeze);Object.freeze(value);}return value;};
  const request=(requestId='11111111-1111-4111-8111-111111111111',change={})=>{
    f.observer.observe(f.session,{seq:1,type:'turn/start',data:{turn:1}});
    f.observer.observe(f.session,{seq:2,type:'approval/asked',data:{id:requestId}});
    const policy={mode:'read-only',workspaceRoot:'/',sessionId:'root'};
    return freeze({requestId,agent:f.ctx.agents.roots()[0],signal:new AbortController().signal,
      nativeApprovalScope:{protocol:'stopwatch.dsh.native-approval.v1',implementation:'dsh-tool-bash@0.2.0-rc.2',
        arguments:{command:'pwd',description:'x',workdir:'/',timeoutMs:1,sandbox_permissions:'danger-full-access',justification:'x'},
        standingPolicy:policy,execution:{command:'pwd',workdir:'/',timeoutMs:1,onExpiry:'kill',stdoutMaxBytes:1,
          sandboxPolicy:{...policy,mode:'danger-full-access'}},...change}});
  };
  return {...f,owner,transport,request,setClock:n=>clock=n};
}
test('native owner renders complete scope at new revision and submits only once until committed audit',async()=>{
  const f=await ownerFixture(), req=f.request(); let delegated=0;
  const answer=f.owner.request(req,()=>{delegated++;return 'rejected';});
  const record=f.output.at(-1);f.setClock(1005);
  assert.equal(record.revision,2); assert.equal(record.canDecide,true);
  assert.equal(record.detail,'["bash",{"cmd":"pwd","desc":"x","cwd":"/","ms":1,"mode":"danger-full-access","why":"x"},{"from":"read-only","root":"/","expiry":"kill","out":1}]');
  f.observer.heartbeat(); assert.equal(f.output.at(-1).detail,record.detail);assert.equal(f.output.at(-1).revision,2);
  assert.equal(f.owner.decide({...record,action:'allow_once',decisionId:'d',revision:1}),false);
  assert.equal(f.owner.decide({...record,action:'allow_once',decisionId:'d'}),true);
  assert.equal(await answer,'allowed-once');assert.equal(delegated,0);
  assert.equal(f.owner.decide({...record,action:'decline',decisionId:'d2'}),false);
  assert.equal(f.output.filter(x=>x.state==='resolved').length,0);
  f.observer.observe(f.session,{seq:3,type:'approval/decided',data:{id:req.requestId,outcome:'cancelled'}});
  assert.equal(f.output.at(-1).outcome,'cancelled');assert.equal(f.output.at(-1).revision,2);assert.equal(f.output.at(-1).detail,record.detail);
});
test('missing stock context and unrepresentable scopes delegate immediately',async()=>{
  for(const change of [null,{arguments:{command:'x'.repeat(193)}},{standingPolicy:{mode:'read-only',workspaceRoot:'/',sessionId:'other'}},
    {standingPolicy:{mode:'read-only',workspaceRoot:'/',sessionId:'root',unknown:true}},
    {arguments:{command:'echo 中文'}},{arguments:{command:'Authorization: Bearer synthetic'}}]){
    const f=await ownerFixture();let req=f.request('11111111-1111-4111-8111-111111111111',change??{});
    if(change===null) req=Object.freeze({...req,nativeApprovalScope:undefined});
    let calls=0; assert.equal(await f.owner.request(req,()=>{calls++;return 'rejected';}),'rejected');assert.equal(calls,1);
    assert.equal(f.output.some(x=>x.canDecide),false);
  }
});
test('OPEN, expiry, readiness loss and unload release callback once without a verdict',async()=>{
  for(const action of ['open','expiry','failure','unload','not-ready']){
    const f=await ownerFixture(),req=f.request();let calls=0;
    if(action==='not-ready')f.transport.ready=false;
    const result=f.owner.request(req,()=>{calls++;return 'rejected';});const record=f.output.at(-1);f.setClock(1005);
    if(action==='open')f.owner.decide({...record,action:'open',decisionId:'o'});
    if(action==='expiry'){f.setClock(61001);f.owner.heartbeat();}
    if(action==='failure'||action==='unload')f.owner.disable();
    assert.equal(await result,'rejected');f.owner.disable();assert.equal(calls,1);
    assert.equal(f.output.filter(x=>x.state==='resolved').length,0);
    assert.equal(f.output.at(-1).canDecide,false);
    if(action==='open')assert.ok(f.transport.opened);
    assert.equal(f.owner.decide({...record,action:'allow_once',decisionId:'late'}),false);
  }
});

test('valid-looking secret literals and differing effective execution values cannot enable ownership',async()=>{
  for(const change of ['Authorization: Bearer synthetic','API_KEY=synthetic','x'.repeat(193),'nonascii','different-cwd','unknown-argument','unknown-execution','unknown-policy']) {
    const f=await ownerFixture(),base=f.request();const scope=structuredClone(base.nativeApprovalScope);
    if(change==='nonascii')scope.arguments.description='中文';
    else if(change==='different-cwd')scope.execution.workdir='/other';
    else if(change==='unknown-argument')scope.arguments.extra='hidden';
    else if(change==='unknown-execution')scope.execution.stdin='hidden';
    else if(change==='unknown-policy')scope.execution.sandboxPolicy.extra='hidden';
    else scope.arguments.command=scope.execution.command=change;
    const freeze=x=>{if(x&&typeof x==='object'){Object.values(x).forEach(freeze);Object.freeze(x);}return x;};
    const req=Object.freeze({...base,nativeApprovalScope:freeze(scope)});
    const result=f.owner.request(req,()=> 'rejected'),capable=f.output.some(x=>x.canDecide);
    f.owner.disable();assert.equal(await result,'rejected');
    assert.equal(capable,false,change);
  }
});

test('terminal turn invalidation delegates without republishing a cleared native card',async()=>{
  const f=await ownerFixture(),req=f.request();let calls=0;
  const result=f.owner.request(req,()=>{calls++;return 'rejected';});
  f.observer.observe(f.session,{seq:3,type:'turn/end',data:{turn:1,reason:{kind:'aborted'}}});
  const count=f.output.length;f.owner.heartbeat();
  assert.equal(await result,'rejected');assert.equal(calls,1);
  assert.equal(f.output.length,count,'cleared card cannot be resurrected');
});
test('current root removal, expired decision and unknown action cannot settle native approval',async()=>{
  const f=await ownerFixture(),req=f.request();let calls=0;
  const result=f.owner.request(req,()=>{calls++;return 'rejected';});const record=f.output.at(-1);f.setClock(1005);
  assert.equal(f.owner.decide({...record,action:'choose',decisionId:'d'}),false);
  assert.equal(f.owner.decide({...record,action:'allow_once',decisionId:'d',leaseDeadline:1004}),false);
  f.ctx.agents.roots=()=>[];
  assert.equal(f.owner.decide({...record,action:'allow_once',decisionId:'d'}),false);
  assert.equal(await result,'rejected');assert.equal(calls,1);
});

test('same session and id without the exact live root agent delegates',async()=>{
  const f=await ownerFixture(),base=f.request();
  const req=Object.freeze({...base,agent:{id:base.agent.id,session:base.agent.session}});
  const result=f.owner.request(req,()=> 'rejected');f.owner.disable();
  assert.equal(await result,'rejected');
  assert.equal(f.output.some(x=>x.canDecide),false);
});

test('turn tracking admits only64 live roots and cannot later own an overflow turn',()=>{
  const sessions=Array.from({length:65},(_,i)=>({id:'root-'+i}));
  const roots=sessions.map(session=>({id:session.id,session})), output=[];
  const observer=new AuditObserver({agents:{roots:()=>roots}},record=>output.push(record),()=>1000);
  sessions.forEach(session=>observer.observe(session,{seq:1,type:'turn/start',data:{turn:1}}));
  // No approval backlog exists; the turn bound itself must reject overflow.
  observer.observe(sessions[64],{seq:2,type:'approval/asked',data:{id:'overflow'}});
  assert.equal(output.length,0);
});

// The subprocess only replaces the external relay failure boundary; owner and
// plugin lifecycle/registration/backlog logic are production code.
test('plugin default stays audit-only; malformed child, exit and backlog disable ownership once',async t=>{
  const {mkdtemp,writeFile,readFile,rm}=await import('node:fs/promises');
  const dir=await mkdtemp('/private/tmp/synthetic-dsh-child-');t.after(()=>rm(dir,{recursive:true,force:true}));
  for(const failure of ['default','malformed','bad-decision','exit','oversize','backlog']) {
    const f=await ownerFixture(), handlers=new Map();let cleanup;
    f.ctx.on=(name,handler)=>handlers.set(name,handler);f.ctx.effect=effect=>{cleanup=effect();};
    const script=dir+'/'+failure+'.mjs';
    await writeFile(script,`import {writeFileSync} from 'node:fs';
process.stdout.write(JSON.stringify({type:'ready',protocol:'stopwatch.dsh.native-approval.v1'})+'\\n');
writeFileSync(${JSON.stringify(script+'.ready')},'ready');
setInterval(()=>{},1000);
${failure==='backlog'||failure==='default'?'':`process.stdin.once('data',()=>setTimeout(()=>{${failure==='exit'?'process.exit(1)':failure==='oversize'?"process.stdout.write('x'.repeat(8193)+'\\n')":failure==='bad-decision'?"process.stdout.write(JSON.stringify({type:'decision',decision:{action:'allow_once'}})+'\\n')":"process.stdout.write('invalid-json\\n')"}},100));`}`);
    apply(f.ctx,{python:process.execPath,relayScript:script,directory:dir+'/bridge',nativeApprovals:failure!=='default'});
    try {
      for(let i=0;i<100;i++){try{await readFile(script+'.ready');break;}catch{await new Promise(r=>setTimeout(r,10));}}
      await new Promise(r=>setTimeout(r,20));
      if(failure==='default'){assert.equal(handlers.has('approval/request'),false);continue;}
      const req=f.request();const event=handlers.get('session/event');
      event(f.session,{seq:1,type:'turn/start',data:{turn:1}});
      event(f.session,{seq:2,type:'approval/asked',data:{id:req.requestId}});
      let delegated=0;const answer=handlers.get('approval/request')(req,()=>{delegated++;return 'rejected';});
      assert.equal(delegated,0,'ready child must initially own native callback');
      if(failure==='backlog'){
        event(f.session,{seq:3,type:'turn/end',data:{turn:2,reason:{kind:'completed'}}});
        assert.equal(delegated,0,'another turn cannot release current native owner');
      }
      if(failure==='backlog')for(let i=0;i<1200;i++)event(f.session,{seq:i+3,type:'turn/end',data:{turn:2,reason:{kind:'completed'}}});
      let timeout;
      try {assert.equal(await Promise.race([answer,new Promise((_,reject)=>{timeout=setTimeout(()=>reject(new Error('owner not released after child failure')),700);})]),'rejected');}
      finally{clearTimeout(timeout);}
      assert.equal(delegated,1);
      assert.equal(await handlers.get('approval/request')(req,()=>{delegated++;return 'rejected';}),'rejected');
      assert.equal(delegated,2,'disabled capability delegates new request immediately');
    } finally {cleanup();}
  }
});

test('fresh renewed lease cannot extend ownership past60seconds',async()=>{
  const f=await ownerFixture(),req=f.request();let calls=0;
  const result=f.owner.request(req,()=>{calls++;return 'rejected';});
  f.setClock(60000);f.observer.heartbeat(); // valid lease through75000, but original ownership ends61000.
  f.setClock(61001);f.owner.heartbeat();
  assert.equal(await result,'rejected');assert.equal(calls,1);assert.equal(f.output.at(-1).canDecide,false);
});

test('exact OPEN after decision lease still releases live owner before activation',async()=>{
  const f=await ownerFixture(),req=f.request();const order=[];
  const send=f.transport.send;
  f.transport.send=record=>{if(!record.canDecide)order.push('withdraw');return send(record);};
  f.transport.open=()=>order.push('activate');
  const answer=f.owner.request(req,()=>{order.push('delegate');return 'rejected';});
  const record=f.output.at(-1);f.setClock(17000);
  assert.equal(f.owner.decide({...record,action:'open',decisionId:'expired-open',createdAt:17000,leaseDeadline:32000}),true);
  assert.equal(await answer,'rejected');assert.deepEqual(order,['delegate','withdraw','activate']);
  assert.equal(f.owner.decide({...record,action:'open',decisionId:'duplicate',createdAt:17000,leaseDeadline:32000}),false);
});

test('fresh allow cannot settle a live owner whose current decision lease expired',async()=>{
  const f=await ownerFixture(),req=f.request();let delegated=0;
  const answer=f.owner.request(req,()=>{delegated++;return 'rejected';});
  const record=f.output.at(-1);f.setClock(17000);
  assert.equal(f.owner.decide({...record,action:'allow_once',decisionId:'fresh-late-allow',createdAt:17000,leaseDeadline:32000}),false);
  assert.equal(await answer,'rejected');assert.equal(delegated,1);
  assert.equal(f.output.some(x=>x.state==='resolved'),false);
});
