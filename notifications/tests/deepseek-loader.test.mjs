import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,readFile,writeFile,chmod,symlink,rm,lstat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const builder=await import('../../scripts/build_deepseek_native_candidate.mjs').catch(()=>({}));
const sha=b=>createHash('sha256').update(b).digest('hex');
const fixture=process.env.DSH_LOADER_FIXTURE;
const source=process.env.DSH_NATIVE_MODULES;
const input=()=>({kind:'synthetic',presetEntryId:'standard-row',approvalEntryId:'approval',canaryId:'stopwatch-canary',canaryEntryId:'stopwatch-canary-row',entries:[
  {id:'approval',name:'@deepseek-ai/dsh-user-approval',config:{policy:{__jsExpr:"'ask'"}}},
  {id:'registry',name:'@deepseek-ai/dsh-agent-preset-registry',config:{default:'standard'}},
  {id:'standard-row',name:'@deepseek-ai/dsh-agent-preset',config:{id:'standard',name:'Standard',description:'synthetic fixture',plugins:[
    {id:'ordinary-bash',name:'@deepseek-ai/dsh-tool-bash',disabled:{__jsExpr:"process.platform === 'win32'"},config:{enableRunInBackground:true}},
    {id:'unrelated',name:'cordis:group',group:true,config:[]}
  ]}}
]});
async function setup(t){const dir=await mkdtemp('/private/tmp/synthetic-dsh-candidate-');t.after(()=>rm(dir,{recursive:true,force:true}));const profile=resolve(dir,'profile');await mkdir(profile,{mode:0o700});return {profile,output:resolve(profile,'extension'),source,fixture};}
function options(f,configuration=input()){return {...f,configuration,configurationSha256:sha(JSON.stringify(configuration)),verificationMode:process.env.DSH_VERIFICATION_MODE??'installed-archive'};}
test('builder contract exists',()=>assert.equal(typeof builder.buildCandidate,'function'));
test('candidate preserves baseline/config expressions, isolates only clone, pins exact peers and destination bytes',async t=>{
  const f=await setup(t),config=input(),before=JSON.stringify(config);const result=await builder.buildCandidate(options(f,config));
  assert.equal(JSON.stringify(config),before);assert.deepEqual(result.overlay[0].insert[0].config.plugins[1],config.entries[2].config.plugins[1]);
  const clone=result.overlay[0].insert[0];assert.equal(clone.config.id,'stopwatch-canary');const group=clone.config.plugins[0];
  assert.equal(group.name,'cordis:group');assert.deepEqual(group.isolate,{approval:true});assert.equal(group.config[1].config.enableRunInBackground,false);
  assert.deepEqual(group.config[1].disabled,config.entries[2].config.plugins[0].disabled);assert.deepEqual(group.config[0].config,config.entries[0].config);
  assert.equal(group.config[0].name,pathToFileURL(resolve(f.output,'lib/approval-floor.mjs')).href);
  const pkg=JSON.parse(await readFile(resolve(f.output,'package.json')));assert.equal(pkg.private,true);assert.equal(pkg.type,'module');assert.equal(pkg.scripts,undefined);assert.equal(pkg.dependencies,undefined);assert.equal(pkg.peerDependencies['@deepseek-ai/cordis'],'4.0.4');assert.equal(pkg.peerDependencies['@deepseek-ai/schemastery'],'3.18.4');
  assert.equal((await lstat(f.output)).mode&0o777,0o700);assert.equal((await lstat(resolve(f.output,'lib/bash.js'))).mode&0o777,0o600);
  await builder.verifyCandidate(f.output,options(f,config));
  const provenance=JSON.parse(await readFile(resolve(f.output,'provenance.json')));assert.equal(provenance.destination,pathToFileURL(f.output+'/').href);assert.notEqual(provenance.transform.beforeSha256,provenance.transform.afterSha256);
  assert.equal(provenance.verificationMode,process.env.DSH_VERIFICATION_MODE??'installed-archive');assert.equal(provenance.installedArchiveVerified,provenance.verificationMode==='installed-archive');assert.match(provenance.status,/historical source-only/);assert.equal(provenance.sourceContentHashes['scripts/build_deepseek_native_candidate.mjs'],sha(await readFile(new URL('../../scripts/build_deepseek_native_candidate.mjs',import.meta.url))));
  await assert.rejects(builder.buildCandidate(options(f,config)),/exist|overwrite/);
  await writeFile(resolve(f.output,'lib/bash.js'),'changed',{mode:0o600});await assert.rejects(builder.verifyCandidate(f.output,options(f,config)),/hash|SHA256/);
});
test('unknown shapes, missing/duplicate Bash, duplicate preset IDs and stale verified configuration fail closed',async t=>{
  const f=await setup(t);
  for(const mutate of [c=>c.entries[2].config.plugins.push({...c.entries[2].config.plugins[0]}),c=>c.entries[2].config.plugins.shift(),c=>c.entries[2].config.plugins={},c=>c.entries[2].config.unknown=true,c=>c.canaryId='standard',c=>c.entries[2].config.plugins[0].name='@deepseek-ai/dsh-tool-bash-persistent']){
    const c=input();mutate(c);await assert.rejects(builder.buildCandidate(options(f,c)),/preset|Bash|shape|unknown|duplicate/i);
  }
  await assert.rejects(builder.buildCandidate({...options(f),configurationSha256:'0'.repeat(64)}),/configuration.*hash/);
});
test('nonprivate output ancestors, symlinks, unignored checkout destinations and local native shadows are refused without mutation',async t=>{
  const f=await setup(t);await chmod(f.profile,0o755);await assert.rejects(builder.buildCandidate(options(f)),/private/);await chmod(f.profile,0o700);
  await symlink(f.profile,resolve(f.profile,'link'));await assert.rejects(builder.buildCandidate(options({...f,output:resolve(f.profile,'link/extension')})),/symlink/);
  await assert.rejects(builder.buildCandidate(options({...f,profile:resolve('.'),output:resolve('unignored-candidate')})),/ignored/);
  const shadow=resolve(f.profile,'node_modules/@deepseek-ai/cordis');await mkdir(shadow,{recursive:true,mode:0o700});await writeFile(resolve(shadow,'package.json'),'{}');
  await assert.rejects(builder.buildCandidate(options(f)),/shadow/);assert.equal(await readFile(resolve(shadow,'package.json'),'utf8'),'{}');
});
test('wrong peers, scripts, local runtime dependencies, unexpected output and changed provenance cannot validate',async t=>{
  const f=await setup(t);await builder.buildCandidate(options(f));const pkgPath=resolve(f.output,'package.json'),original=await readFile(pkgPath,'utf8');
  for(const mutate of [p=>p.peerDependencies['@deepseek-ai/cordis']='*',p=>p.dependencies={x:'1'},p=>p.scripts={install:'false'},p=>p.private=false]){
    const p=JSON.parse(original);mutate(p);await writeFile(pkgPath,JSON.stringify(p));await assert.rejects(builder.verifyCandidate(f.output,options(f)),/package|hash|SHA256/);
  }
  await writeFile(pkgPath,original);await mkdir(resolve(f.output,'node_modules'));await assert.rejects(builder.verifyCandidate(f.output,options(f)),/unexpected|shadow/);await rm(resolve(f.output,'node_modules'),{recursive:true});
  const p=JSON.parse(await readFile(resolve(f.output,'provenance.json')));p.destination='file:///different/';await writeFile(resolve(f.output,'provenance.json'),JSON.stringify(p));await assert.rejects(builder.verifyCandidate(f.output,options(f)),/provenance|destination/);
});

// This integration exercises generated bytes and the original public runtime APIs.
// Only the external shell/OS-open boundaries are inert; no model or device is used.
const tick=()=>new Promise(r=>setImmediate(r));
test('actual generated package through native Loader, resolver, registry and production owner',async t=>{
  const f=await setup(t);const built=await builder.buildCandidate(options(f));
  const native=name=>import(pathToFileURL(resolve(fixture,'dsh/node_modules/@deepseek-ai',name,'lib/index.js')));
  const [{Context,Service,symbols},{Loader,Group},{PluginPackages,createRuntimeResolution,prepareProfileEntries},{AgentPresetRegistry,livePresetMounts},{SessionStore},{SessionProjectionRegistry},{SystemPrompt},{ToolRuntime},{createScope},{ApprovalService},{applyEntryPatches}]=await Promise.all(['cordis','cordis-plugin-loader','dsh-app-boot','dsh-agent-preset-registry','dsh-session','dsh-session-projection','dsh-system-prompt','dsh-tools','dsh-scope','dsh-user-approval','cordis-plugin-include'].map(native));
  const {AuditObserver,ApprovalOwner}=await import('../adapters/deepseek/index.mjs');
  const original=x=>x?.[symbols.original]??x;
  const baseline=input().entries.filter(e=>e.id==='standard-row');
  const composed=applyEntryPatches(baseline,built.overlay,()=>assert.fail('unexpected patch warning'));
  assert.deepEqual(composed[0],baseline[0]);assert.equal(composed.length,2);
  let serial=0;
  async function host(t){
    const ctx=new Context();ctx.baseUrl=pathToFileURL(resolve(f.profile,'cordis.yml')).href;ctx.provide('profileContext',{dir:f.profile});
    t.after(()=>ctx.fiber.dispose());
    ctx.plugin(Loader,{baseUrl:pathToFileURL(resolve(f.profile,'cordis.yml')).href});await ctx.fiber.await();ctx.loader.builtins.group=Group;
    const resolution=await createRuntimeResolution({installAnchor:resolve(fixture,'dsh/package.json'),profile:{dir:f.profile,skippedBundles:[],layers:[]},home:resolve(f.profile,'synthetic-home')});
    const pp=ctx.plugin(PluginPackages,{resolution});await pp.await();
    ctx.plugin(SystemPrompt);ctx.plugin(SessionStore);ctx.plugin(SessionProjectionRegistry);ctx.plugin(AgentPresetRegistry,{default:'standard'});ctx.plugin(ToolRuntime,{mode:'native'});
    const executions=[],roots=[],requests=[],records=[],audits=[],jobStarts=[];
    class Shell extends Service{constructor(ctx){super(ctx,'shell');}get sandboxMode(){return 'read-only';}resolve(r){return {workdir:'/',timeoutMs:1,stdoutMaxBytes:1,onExpiry:'kill',...r};}async execute(r){executions.push(r);return {result:async()=>({exitCode:0,signal:null,timedOut:false,aborted:false,timeoutMs:1,stdout:{text:'synthetic',truncated:false},stderr:{text:'',truncated:false}})};}}
    class Env extends Service{constructor(ctx){super(ctx,'shellEnv');}collect(){return {};}}
    class Policy extends Service{constructor(ctx){super(ctx,'sandboxPolicy');}resolve({session}){return {mode:'read-only',workspaceRoot:'/',sessionId:session.id};}}
    class Jobs extends Service{constructor(ctx){super(ctx,'jobs');}start(spec){jobStarts.push(spec);throw Error('inert background boundary');}}
    ctx.plugin(Shell);ctx.plugin(Env);ctx.plugin(Policy);ctx.plugin(Jobs);let rootFiber=ctx.plugin(ApprovalService,{policy:'ask'});await tick();await rootFiber.await();
    const root=original(ctx.get('approval'));assert.ok(root,'root approval mounted');ctx.agents={roots:()=>roots};
    let clock=Date.now();const observer=new AuditObserver(ctx,r=>records.push(r),()=>clock);
    const transport={ready:true,send:r=>records.push(r),open:()=>{assert.ok(requests.length);}};
    const owner=new ApprovalOwner(observer,transport,()=>clock);
    ctx.on('session/event',(session,event)=>{audits.push({session,event});observer.observe(session,event);});
    ctx.on('approval/request',req=>{const gate=Promise.withResolvers();requests.push({req,gate});return gate.promise;});
    ctx.on('approval/request',(req,next)=>owner.request(req,next),{prepend:true});
    await ctx.loader.root.update(prepareProfileEntries(ctx,composed,ctx.baseUrl));await ctx.loader.await();
    assert.deepEqual((await ctx.agentPresets.list()).map(p=>p.id).sort(),['standard','stopwatch-canary']);
    const scopes=[];
    async function agent(preset='stopwatch-canary'){
      const session=ctx.sessions.create('synthetic-loader-'+(++serial),{meta:{cwd:'/'}});const agent={id:session.id,session};
      const scope=createScope(ctx,agent);agent.ctx=scope.ctx;scopes.push(scope);await ctx.agentPresets.mount(scope.ctx,preset);roots.push(agent);session.append('turn/start',{turn:1});return agent;
    }
    function start(agent,{descriptor=true,extra={}}={}){
      const controller=new AbortController(),args={command:'pwd',description:'x',workdir:'/',timeoutMs:1,sandbox_permissions:'danger-full-access',justification:'x',...extra};
      for(const key of Object.keys(args))if(args[key]===undefined)delete args[key];
      if(descriptor){agent.session.append('tool/call',{turn:1,step:1,callId:'same-call',name:'bash',arguments:JSON.stringify(args)});return {agent,controller,promise:ctx.tools.execute({agent,name:'bash',callId:'same-call',arguments:args,signal:controller.signal})};}
      return {agent,controller,promise:ctx.get('approval').request({agent,toolName:'synthetic-root-gate',signal:controller.signal})};
    }
    function answer(record,action='allow_once'){clock=Math.max(clock+10,record.createdAt+10);return owner.decide({...record,action,decisionId:'synthetic-choice',createdAt:clock,leaseDeadline:clock+15000});}
    const decided=agent=>audits.filter(a=>a.session===agent.session&&a.event.type==='approval/decided').at(-1)?.event.data;
    t.after(async()=>{owner.disable();for(const r of requests)r.gate.resolve('rejected');for(const scope of scopes)await scope.dispose();await ctx.fiber.dispose();});
    return {ctx,root,rootFiber,owner,transport,executions,jobStarts,records,requests,agent,start,answer,decided,scopes,advance(ms){clock+=ms;},async removeRoot(){await rootFiber.dispose();},async replaceRoot(policy){await rootFiber.dispose();rootFiber=ctx.plugin(ApprovalService,{policy});await rootFiber.await();}};
  }
  await t.test('all native peers share Host module identity; isolated provider and foreground scope leave stock/default intact',async t=>{
    const h=await host(t),a=await h.agent(),s=await h.agent('standard');const canary=h.ctx.agentPresets.serviceFor(a,'approval');
    assert.notEqual(canary,h.root);assert.equal(original(h.ctx.get('approval')),h.root);assert.equal(original(canary.ctx.root.get('approval')),h.root);assert.equal(h.ctx.agentPresets.defaultId,'standard');
    const pkg=JSON.parse(await readFile(resolve(f.output,'package.json')));
    const probe=resolve(f.profile,'identity.mjs');await writeFile(probe,Object.keys(pkg.peerDependencies).map((name,i)=>`export * as p${i} from '${name}';`).join('\n'),{mode:0o600});
    const identities=await import(pathToFileURL(probe));
    for(const [i,name]of Object.keys(pkg.peerDependencies).entries()){
      assert.equal(h.ctx.pluginPackages.packageOf(name,pathToFileURL(resolve(f.output,'lib/bash.js')).href).dir,resolve(fixture,'dsh/node_modules',name));
      assert.equal(identities['p'+i],name==='@deepseek-ai/schemastery'?await import(pathToFileURL(resolve(fixture,'dsh/node_modules/@deepseek-ai/schemastery/lib/index.mjs'))):await native(name.slice('@deepseek-ai/'.length)));
    }
    assert.equal(canary instanceof Service,true);assert.equal(canary.constructor.Config, (await import(pathToFileURL(resolve(f.output,'lib/approval.js')))).ApprovalService.Config);
    assert.ok(JSON.stringify(h.ctx.tools.get('bash',s).parameters).includes('run_in_background'));
    assert.ok(!JSON.stringify(h.ctx.tools.get('bash',a).parameters).includes('run_in_background'));
    const call=h.start(a);await tick();assert.equal(h.requests.length,0);const owned=h.records.find(r=>r.canDecide);assert.ok(owned);assert.ok(!owned.detail.includes(a.session.id));
    assert.equal(h.answer(owned),true);assert.equal(h.records.some(r=>r.state==='resolved'),false);await call.promise;
    assert.equal(h.executions.length,1);assert.equal(h.decided(a).id,owned.requestId);assert.equal(h.records.at(-1).outcome,'allowed');
    assert.equal(original(h.ctx.get('approval')),h.root);
    const blocked=await h.start(a,{extra:{run_in_background:true,sandbox_permissions:undefined,justification:undefined}}).promise;assert.equal(blocked.isError,true);assert.match(blocked.error.message,/run_in_background is disabled/);assert.equal(h.jobStarts.length,0);
    const background=await h.start(s,{extra:{run_in_background:true,sandbox_permissions:undefined,justification:undefined}}).promise;assert.equal(background.isError,true);assert.equal(h.jobStarts.length,1,JSON.stringify(background));assert.equal(h.executions.length,1);
  });
  await t.test('live root never/missing/throwing/unknown/self fail closed; explicit session override retains native semantics',async t=>{
    const h=await host(t),a=await h.agent(),canary=h.ctx.agentPresets.serviceFor(a,'approval');
    h.root.config.policy='never';assert.equal(canary.effectivePolicy(a.session),'never');
    let call=h.start(a);await call.promise;assert.equal(h.records.some(r=>r.canDecide),false);assert.equal(h.decided(a).outcome,'rejected');
    a.session.append('approval/policy',{policy:'ask'});assert.equal(canary.effectivePolicy(a.session),'ask');
    a.session.append('approval/policy',{policy:'never'});assert.equal(canary.effectivePolicy(a.session),'never');
    const b=await h.agent();h.root.config.policy='ask';canary.config.policy='never';assert.equal(canary.effectivePolicy(b.session),'never');canary.config.policy='ask';
    const policy=h.root.effectivePolicy;h.root.effectivePolicy=()=>{throw Error('synthetic');};assert.equal(canary.effectivePolicy(b.session),'never');h.root.effectivePolicy=()=> 'unknown';assert.equal(canary.effectivePolicy(b.session),'never');h.root.effectivePolicy=policy;
    h.root.ctx.set('approval',canary);assert.equal(canary.effectivePolicy(b.session),'never');h.root.ctx.set('approval',h.root);
    await h.removeRoot();assert.equal(canary.effectivePolicy(b.session),'never');
  });
  await t.test('pending watch and delegated UI allow cannot outlive root policy drift or replacement',async t=>{
    const h=await host(t);
    for(const mode of ['watch','delegate','replacement']){
      h.root.config.policy='ask';const a=await h.agent(),call=h.start(a,{extra:mode==='delegate'?{command:'x'.repeat(250)}:{}});await tick();
      const owned=h.records.findLast(r=>r.sessionId===a.session.id&&r.canDecide);
      if(mode==='replacement')await h.replaceRoot('never');else h.root.config.policy='never';
      if(owned)assert.equal(h.answer(owned),true);else h.requests.at(-1).gate.resolve('allowed-once');
      await call.promise;assert.equal(h.decided(a).outcome,'rejected',mode);assert.equal(h.records.at(-1).outcome,'declined');
    }
    assert.equal(h.executions.length,0);
  });
  await t.test('concurrent UUIDs, cancellation and descriptorless root gates use exact committed outcomes',async t=>{
    const h=await host(t),a=await h.agent(),b=await h.agent(),ca=h.start(a),cb=h.start(b);await tick();const owned=h.records.filter(r=>r.canDecide);assert.equal(owned.length,2);assert.notEqual(owned[0].requestId,owned[1].requestId);
    h.answer(owned[0]);ca.controller.abort();h.answer(owned[1],'decline');await Promise.all([ca.promise,cb.promise]);assert.equal(h.decided(a).outcome,'cancelled');assert.equal(h.decided(b).outcome,'rejected');assert.equal(h.executions.length,0);
    const gateAgent=await h.agent(),gate=h.start(gateAgent,{descriptor:false});await tick();assert.equal(h.requests.at(-1).req.nativeApprovalScope,undefined);assert.equal(h.records.filter(r=>r.canDecide).length,2);h.requests.at(-1).gate.resolve('rejected');await gate.promise;assert.equal(h.decided(gateAgent).outcome,'rejected');
  });
  await t.test('lease expiry, disconnect and owner disposal delegate; overlay removal retains live revision then baseline recovers',async t=>{
    const h=await host(t);
    for(const mode of ['expiry','disconnect','dispose']){
      const a=await h.agent(),call=h.start(a);await tick();const owned=h.records.findLast(r=>r.canDecide&&r.sessionId===a.session.id);assert.ok(owned);
      if(mode==='expiry'){h.advance(16000);h.owner.heartbeat();}else if(mode==='disconnect'){h.transport.ready=false;h.owner.heartbeat();h.transport.ready=true;}else h.owner.disable();
      assert.equal(h.requests.at(-1).req.requestId,owned.requestId);assert.equal(h.answer(owned),false);h.requests.at(-1).gate.resolve('rejected');await call.promise;assert.equal(h.decided(a).outcome,'rejected');
    }
    const live=await h.agent();await h.ctx.loader.root.update(baseline);await h.ctx.loader.await();assert.deepEqual((await h.ctx.agentPresets.list()).map(p=>p.id),['standard']);
    assert.ok(h.ctx.agentPresets.serviceFor(live,'approval'),'existing agents retain old revision until disposed');
    assert.equal(original(h.ctx.get('approval')),h.root);assert.equal(h.ctx.agentPresets.defaultId,'standard');assert.equal(h.executions.length,0);
    for(const scope of h.scopes)await scope.dispose();assert.deepEqual(livePresetMounts(h.ctx.fiber).map(m=>m.presetId),['standard']);
    const stock=await h.agent('standard'),gate=h.start(stock,{descriptor:false});await tick();h.requests.at(-1).gate.resolve('rejected');await gate.promise;assert.equal(h.decided(stock).outcome,'rejected');
  });
});

test('archive traversal, changed installed ASAR, and changed external fixture are rejected before importing code',async t=>{
  const {archiveEntries,readArchiveCode,verifyLoaderFixture}=await import('../../scripts/test_deepseek_native_loader.mjs');
  const {validatePatch,verifyNativeTree,verifyDependencyTree}=await import('../../scripts/test_deepseek_native.mjs');
  const manifest=JSON.parse(await readFile(new URL('../native-patches/manifest.json',import.meta.url)));
  const patch=await readFile(new URL('../native-patches/deepseek-0.2.0-rc.2-approval-context.patch',import.meta.url));
  assert.throws(()=>validatePatch(Buffer.concat([patch,Buffer.from('\n')]),manifest),/patch SHA256/);
  const header=Buffer.from(JSON.stringify({files:{'..':{files:{escape:{offset:'0',size:0}}}}}));const bytes=Buffer.alloc(header.length+16);bytes.writeUInt32LE(header.length+8,4);bytes.writeUInt32LE(header.length,12);header.copy(bytes,16);
  assert.throws(()=>archiveEntries(bytes),/archive path/);
  const f=await setup(t);const fake=resolve(f.profile,'changed.asar');await writeFile(fake,'synthetic changed archive',{mode:0o600});await assert.rejects(readArchiveCode(fake),/ASAR SHA256/);
  await assert.rejects(verifyDependencyTree(f.profile,manifest),/dependency tree SHA256/);
  await assert.rejects(verifyNativeTree(f.profile,manifest),/ENOENT/);
  await assert.rejects(verifyLoaderFixture(f.profile),/fixture SHA256/);
  await assert.rejects(builder.buildCandidate({...options(f),verificationMode:undefined,archive:fake}),/ASAR SHA256/);
  await assert.rejects(builder.buildCandidate({...options(f),verificationMode:'unknown'}),/unknown verification mode/);
  await assert.rejects(builder.buildCandidate({...options(f),verificationMode:'historical-source-fixture',archive:fake}),/cannot validate an archive/);
});
