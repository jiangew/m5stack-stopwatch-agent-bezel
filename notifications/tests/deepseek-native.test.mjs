import test from 'node:test';
import assert from 'node:assert/strict';
import { AsyncLocalStorage } from 'node:async_hooks';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// All sessions/commands are synthetic. Only the external shell execution seam is inert.
// Removing the body snapshot, pre-await resolution, service UUID or native gates
// must break the corresponding behavioral test below.
const root = process.env.DSH_NATIVE_MODULES;
if (!root) throw new Error('Set DSH_NATIVE_MODULES to an explicit extracted node_modules path; use scripts/test_deepseek_native.mjs');
const stock = process.env.DSH_NATIVE_VARIANT !== 'patched';
const manifest = JSON.parse(await readFile(new URL('../native-patches/manifest.json', import.meta.url)));
const expected = Object.fromEntries(manifest.files.map(f => [f.package, stock ? f.inputSha256 : (f.outputSha256 ?? f.inputSha256)]));
for (const [pkg, hash] of Object.entries(expected)) {
  const bytes = await readFile(resolve(root, '@deepseek-ai', pkg, 'lib/index.js'));
  assert.equal(createHash('sha256').update(bytes).digest('hex'), hash, `unverified native ${pkg}`);
}
const native = name => import(pathToFileURL(resolve(root, '@deepseek-ai', name, 'lib/index.js')));
const [{ Context, Service }, { SessionStore }, { ApprovalService }, { ToolRuntime }, { apply: bash }] =
  await Promise.all(['cordis', 'dsh-session', 'dsh-user-approval', 'dsh-tools', 'dsh-tool-bash'].map(native));
class Prompt extends Service {
  constructor(ctx) { super(ctx, 'systemPrompt'); }
  tools() {} section() {} context() {} getSectionOrder() { return 1; } getContextOrder() { return 1; }
}
const tick = () => new Promise(r => setImmediate(r));
const args = extra => Object.fromEntries(Object.entries({command:'pwd', description:'x', workdir:'sub', timeoutMs:7,
  sandbox_permissions:'danger-full-access', justification:'x', ...extra}).filter(([,v])=>v!==undefined));
async function fixture(t, {policy='ask', background=false, jobs, noCwd=false, realResolver=false} = {}) {
  const ctx = new Context();
  ctx.plugin(Prompt); ctx.plugin(SessionStore); ctx.plugin(ApprovalService, {policy});
  ctx.plugin(ToolRuntime, {mode:'native'}); await tick();
  t.after(() => ctx.fiber.dispose());
  const requests=[], executions=[], audits=[], als = new AsyncLocalStorage();
  let defaults={workdir:'/synthetic/default', timeoutMs:11, stdoutMaxBytes:99};
  let standing={mode:'workspace-write', workspaceRoot:'/synthetic/root', extra:{roots:['/synthetic/root']}};
  const env={SYNTHETIC:'initial'};
  const liveConfig={cwd:'/synthetic/executor',timeoutMs:11,maxTimeoutMs:20,maxOutputBytes:99,maxSpillBytes:100,graceMs:1};
  const {LocalBashExecutor}=await native('dsh-bash-local');
  const nativeConfig=Object.fromEntries(Object.keys(liveConfig).map(key=>[key,{get:()=>liveConfig[key]}]));
  const shell={sandboxMode:'workspace-write',
    resolve(r) { return realResolver ? LocalBashExecutor.prototype.resolve.call({config:nativeConfig},r) : {...defaults, onExpiry:'kill', ...r}; },
    async execute(r) { executions.push(r); return {result:async()=>({exitCode:0,signal:null,timedOut:false,
      aborted:false, timeoutMs:r.timeoutMs, stdout:{text:'synthetic',truncated:false}, stderr:{text:'',truncated:false}})}; }};
  bash({shell, shellEnv:{collect:()=>env}, systemPrompt:ctx.systemPrompt, tools:ctx.tools,
    get(name) { return name==='approval'?ctx.approval:name==='sandboxPolicy'?{resolve:()=>standing}:name==='jobs'?jobs:undefined; },
    inject(_keys,callback) {if(jobs) callback({jobs,tools:ctx.tools,effect(){}});}, logger:{warn() {}}}, {enableRunInBackground:background});
  ctx.on('session/event', (session,event)=>audits.push({session,event}));
  ctx.on('tools/execute', (exec,next)=>als.run(exec,()=>next()), {prepend:true});
  ctx.on('approval/request', req=>{const gate=Promise.withResolvers(); requests.push({req,gate,exec:als.getStore()}); return gate.promise;}, {prepend:true});
  let serial=0;
  function start(input=args(), controller=new AbortController()) {
    const session=ctx.sessions.create('synthetic-'+(++serial), noCwd?{}:{meta:{cwd:'/synthetic/header'}});
    session.append('turn/start',{turn:1});
    session.append('tool/call',{turn:1,step:1,callId:'same-call',name:'bash',arguments:JSON.stringify(input)});
    const agent={id:session.id,session,ctx};
    return {session,agent,controller,promise:ctx.tools.execute({agent,name:'bash',callId:'same-call',arguments:input,signal:controller.signal})};
  }
  return {ctx,requests,executions,audits,als,start,env,liveConfig,
    setDefaults(value){defaults=value;}, setStanding(value){standing=value;}, standing};
}
function assertScope(req, execution, command='pwd') {
  const scope=req.nativeApprovalScope;
  assert.ok(scope, 'missing body-bound nativeApprovalScope');
  assert.equal(scope.protocol,'stopwatch.dsh.native-approval.v1');
  assert.equal(scope.implementation,'dsh-tool-bash@0.2.0-rc.2');
  assert.equal(scope.arguments.command,command);
  const {signal,dshEnv,...publicSpec}=execution;
  assert.deepEqual(scope.execution,publicSpec);
  assert.equal(scope.execution.command,command);
}
function auditPair(f, session) {
  return f.audits.filter(x=>x.session===session && x.event.type.startsWith('approval/')).map(x=>x.event);
}

test('body descriptor defeats restored audit/ALS argument counterexample', async t=>{
  const f=await fixture(t);
  f.ctx.on('tools/execute',(exec,next)=>{
    const logged=exec.arguments;
    const actual={...logged,command:'echo ACTUAL', extra:{nested:['before']}};
    exec.arguments=actual;
    const pending=next();
    actual.command='echo MUTATED'; actual.extra.nested[0]='after';
    exec.arguments=logged;
    return pending;
  });
  const call=f.start(); await tick(); const {req,gate,exec}=f.requests[0];
  assert.equal(exec.arguments.command,'pwd'); assert(Object.isFrozen(exec.arguments));
  assert.equal(JSON.parse(call.session.eventAt(1).data.arguments).command,'pwd');
  gate.resolve('allowed-once'); await call.promise;
  if (stock) {
    assert.equal(req.nativeApprovalScope,undefined);
    assert.equal(f.executions[0].command,'echo MUTATED'); // stock counterexample characterization
  }
  assertScope(req,f.executions[0],'echo ACTUAL');
  assert.equal(req.nativeApprovalScope.arguments.extra.nested[0],'before');
});

test('callback receives immutable service UUID matching committed audit pair', async t=>{
  const f=await fixture(t); const call=f.start(); await tick(); const {req,gate}=f.requests[0];
  gate.resolve('allowed-once'); await call.promise;
  const [asked,decided]=auditPair(f,call.session);
  assert.match(req.requestId ?? '',/^[0-9a-f-]{36}$/);
  assert.equal(req.requestId,asked.data.id); assert.equal(req.requestId,decided.data.id);
  assert.equal(decided.data.outcome,'allowed-once'); assert(Object.isFrozen(req));
  assert.throws(()=>{req.requestId='changed';},TypeError);
  assertScope(req,f.executions[0]);
});

test('deep scope cannot be mutated and execution reuses captured policy/defaults/cwd/environment', async t=>{
  const f=await fixture(t); const call=f.start(args({workdir:undefined,timeoutMs:undefined})); await tick();
  const {req,gate}=f.requests[0]; const scope=req.nativeApprovalScope;
  assert.ok(scope,'missing immutable captured scope');
  assert.throws(()=>{scope.arguments.command='changed';},TypeError);
  assert.throws(()=>{scope.standingPolicy.extra.roots.push('/changed');},TypeError);
  assert.throws(()=>{scope.execution.sandboxPolicy.mode='read-only';},TypeError);
  assert.equal(scope.execution.workdir,'/synthetic/root'); assert.equal(scope.execution.timeoutMs,11);
  f.standing.extra.roots[0]='/changed'; f.standing.workspaceRoot='/changed';
  f.setStanding({mode:'read-only',workspaceRoot:'/other'});
  f.setDefaults({workdir:'/changed',timeoutMs:900,stdoutMaxBytes:900}); f.env.SYNTHETIC='changed';
  gate.resolve('allowed-once'); await call.promise;
  assertScope(req,f.executions[0]);
  assert.equal(f.executions[0].dshEnv.SYNTHETIC,'initial');
  assert.equal(f.executions[0].sandboxPolicy.workspaceRoot,'/synthetic/root');
  assert.equal(f.executions[0].stdoutMaxBytes,99);
});

test('relative cwd is captured before an approval observer changes policy root', async t=>{
  const f=await fixture(t); const call=f.start(); await tick(); const {req,gate}=f.requests[0];
  f.standing.workspaceRoot='/synthetic/changed'; gate.resolve('allowed-once'); await call.promise;
  assertScope(req,f.executions[0]); assert.equal(f.executions[0].workdir,'/synthetic/root/sub');
});

test('concurrent sessions with same call ID bind distinct UUIDs and one-shot outcomes', async t=>{
  const f=await fixture(t); const a=f.start(args({command:'echo A'})), b=f.start(args({command:'echo B'}));
  await tick(); assert.equal(f.requests.length,2);
  assert.ok(f.requests[0].req.requestId,'missing native UUID');
  assert.notEqual(f.requests[0].req.requestId,f.requests[1].req.requestId);
  f.requests[1].gate.resolve('allowed-once'); f.requests[0].gate.resolve('rejected');
  const results=await Promise.all([a.promise,b.promise]);
  assert.equal(results[0].isError,true); assert.equal(results[1].isError,false);
  assert.equal(f.executions.length,1); assertScope(f.requests[1].req,f.executions[0],'echo B');
  assert.equal(auditPair(f,a.session)[1].data.outcome,'rejected');
});

test('native cancellation after submitted allow commits cancelled and never executes', async t=>{
  const f=await fixture(t); const call=f.start(); await tick();
  f.requests[0].gate.resolve('allowed-once'); call.controller.abort(); await call.promise;
  assert.equal(f.executions.length,0); assert.equal(auditPair(f,call.session)[1].data.outcome,'cancelled');
});

test('native never and strict widening reject before answerers', async t=>{
  const f=await fixture(t,{policy:'never'}); const call=f.start(); await call.promise;
  assert.equal(f.requests.length,0); assert.equal(f.executions.length,0);
  assert.equal(auditPair(f,call.session)[1].data.outcome,'rejected');
  const bad=f.start(args({sandbox_permissions:'read-only'})); await bad.promise;
  assert.equal(f.requests.length,0); assert.equal(auditPair(f,bad.session).length,0);
});

test('nonextended service requests keep identity/outcomes without mutating caller or forging scope', async t=>{
  const f=await fixture(t); const session=f.ctx.sessions.create('synthetic-service'); session.append('turn/start',{turn:1});
  const req={agent:{id:'synthetic-service',session},toolName:'synthetic',callId:'same-call',requestId:'forged'};
  const promise=f.ctx.approval.request(req); await tick();
  const seen=f.requests[0].req; f.requests[0].gate.resolve('rejected'); assert.equal(await promise,'rejected');
  assert.equal(req.requestId,'forged'); assert.equal(seen.nativeApprovalScope,undefined);
  assert.notEqual(seen.requestId,'forged'); assert.equal(seen.agent,req.agent);
  assert.equal(seen.requestId,auditPair(f,session)[0].data.id);
});

test('background request stays nonextended and decline remains native', async t=>{
  const f=await fixture(t,{background:true}); const call=f.start(args({run_in_background:true})); await tick();
  assert.equal(f.requests[0].req.nativeApprovalScope,undefined);
  f.requests[0].gate.resolve('rejected'); await call.promise; assert.equal(f.executions.length,0);
});

test('temporary-tree applier rejects native source drift and partial/changed patches', async()=>{
  const {verifyNativeTree, validatePatch} = await import('../../scripts/test_deepseek_native.mjs');
  const {mkdtemp,mkdir,writeFile,rm} = await import('node:fs/promises');
  const {tmpdir} = await import('node:os');
  const manifest=JSON.parse(await readFile(new URL('../native-patches/manifest.json',import.meta.url)));
  const dir=await mkdtemp(resolve(tmpdir(),'synthetic-dsh-hash-'));
  try {
    for (const file of manifest.files) {
      const dest=resolve(dir,file.path); await mkdir(resolve(dest,'..'),{recursive:true});
      await writeFile(dest,await readFile(resolve(root,file.path)));
    }
    await verifyNativeTree(dir,manifest,stock?'input':'output');
    await writeFile(resolve(dir,manifest.files[0].path),'synthetic changed bytes');
    await assert.rejects(verifyNativeTree(dir,manifest,stock?'input':'output'),/SHA256 mismatch/);
    const patch=await readFile(new URL('../native-patches/deepseek-0.2.0-rc.2-approval-context.patch',import.meta.url));
    validatePatch(patch,manifest);
    assert.throws(()=>validatePatch(Buffer.from(patch.toString().replace('@@','@x')),manifest),/patch SHA256 mismatch/);
    assert.throws(()=>validatePatch(Buffer.from(patch.toString().split('--- a/')[1]),manifest),/patch SHA256 mismatch/);
  } finally {await rm(dir,{recursive:true,force:true});}
});

test('external dependency tree must match pin before native imports', async()=>{
  const {verifyDependencyTree}=await import('../../scripts/test_deepseek_native.mjs');
  const {mkdtemp,writeFile,rm}=await import('node:fs/promises');
  const {tmpdir}=await import('node:os');
  const manifest=JSON.parse(await readFile(new URL('../native-patches/manifest.json',import.meta.url)));
  const dir=await mkdtemp(resolve(tmpdir(),'synthetic-dsh-dependency-'));
  try {await writeFile(resolve(dir,'unexpected.js'),'synthetic'); await assert.rejects(verifyDependencyTree(dir,manifest),/dependency tree SHA256 mismatch/);}
  finally {await rm(dir,{recursive:true,force:true});}
});


test('real LocalBashExecutor resolves and caps once before approval; live config cannot drift', async t=>{
  const f=await fixture(t,{realResolver:true}); const call=f.start(args({timeoutMs:90})); await tick();
  const {req,gate}=f.requests[0];
  assert.ok(req.nativeApprovalScope,'missing captured real resolver scope');
  assert.equal(req.nativeApprovalScope.execution.timeoutMs,20);
  f.liveConfig.maxTimeoutMs=200; f.liveConfig.maxOutputBytes=999;
  gate.resolve('allowed-once'); await call.promise;
  assertScope(req,f.executions[0]);
  assert.equal(f.executions[0].timeoutMs,20); assert.equal(f.executions[0].stdoutMaxBytes,99);
});


test('unresolved executor defaults omit descriptor and preserve ordinary native answerer', async t=>{
  const f=await fixture(t); f.setDefaults({});
  const call=f.start(args({timeoutMs:undefined})); await tick();
  assert.equal(f.requests[0].req.nativeApprovalScope,undefined);
  f.requests[0].gate.resolve('allowed-once'); await call.promise;
  assert.equal(auditPair(f,call.session)[1].data.outcome,'allowed-once');
  assert.equal(f.executions[0].command,'pwd');
});

test('job-capable foreground path omits descriptor and keeps native decline', async t=>{
  const f=await fixture(t,{background:true,jobs:{}}); const call=f.start(); await tick();
  assert.equal(f.requests[0].req.nativeApprovalScope,undefined);
  f.requests[0].gate.resolve('rejected'); await call.promise;
  assert.equal(f.executions.length,0); assert.equal(auditPair(f,call.session)[1].data.outcome,'rejected');
});

test('throwing answerer retains native unavailable outcome and never executes', async t=>{
  const f=await fixture(t); const call=f.start(); await tick();
  f.requests[0].gate.reject(new Error('synthetic answerer failure')); await call.promise;
  assert.equal(f.executions.length,0); assert.equal(auditPair(f,call.session)[1].data.outcome,'unavailable');
});


test('unknown executor spec fields or explicit environment never enter public descriptor', async t=>{
  const f=await fixture(t);
  f.setDefaults({workdir:'/synthetic/default',timeoutMs:11,stdoutMaxBytes:99,env:{SYNTHETIC:'private'}});
  const call=f.start(); await tick();
  const {req,gate}=f.requests[0]; gate.resolve('rejected'); await call.promise;
  assert.equal(req.nativeApprovalScope,undefined);
});
