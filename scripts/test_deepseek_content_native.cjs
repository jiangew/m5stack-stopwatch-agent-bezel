// Run with the installed DSH Electron (ELECTRON_RUN_AS_NODE=1 --expose-internals).
// Arguments: explicit ASAR dsh/node_modules path. No real profile or sessions read.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = process.argv[2];
if (!root || !path.isAbsolute(root)) throw Error('explicit absolute native node_modules required');
const native = name => require(path.join(root, '@deepseek-ai', name, 'lib/index.js'));
const pins = {};
for (const name of ['cordis', 'dsh-session', 'dsh-session-projection', 'dsh-session-title']) {
  const dir = path.join(root, '@deepseek-ai', name);
  const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'package.json')));
  assert.equal(manifest.version, name === 'cordis' ? '4.0.5' : '0.2.1-rc.2');
  pins[name] = {version: manifest.version, sha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(dir, 'lib/index.js'))).digest('hex')};
}
const {Context} = native('cordis');
const {SessionStore} = native('dsh-session');
const {SessionProjectionRegistry} = native('dsh-session-projection');
const {titleProjectionDefinition} = native('dsh-session-title');
const {AuditObserver} = require('../notifications/adapters/deepseek/index.mjs');
(async () => {
  const ctx = new Context();
  ctx.plugin(SessionStore);ctx.plugin(SessionProjectionRegistry);
  await new Promise(resolve => setImmediate(resolve));
  // Register the exact native pure definition without loading title generation.
  ctx.sessionProjections.register(titleProjectionDefinition);
  const output = [], roots = [];
  const observer = new AuditObserver({agents:{roots:()=>roots},sessionProjections:ctx.sessionProjections}, e=>output.push(e),()=>1000,{richContent:true});
  ctx.on('session/event',(session,event)=>observer.observe(session,event));
  const session = ctx.sessions.create('synthetic-root',{meta:{cwd:'/synthetic/桌面助手'}});
  roots.push({id:session.id,session});
  session.append('session/title',{title:'优化通知页布局'});
  session.append('turn/start',{turn:1});
  session.append('assistant/message',{turn:1,step:1,message:{role:'assistant',source:{provider:'synthetic',model:'deepseek-v4-pro'},content:[{type:'text',text:'已完成布局调整。'}]}},{surfaceOp:'append'});
  session.append('turn/end',{turn:1,reason:{kind:'completed'}});
  const ended=output.at(-1);assert.equal(ended.model,'deepseek-v4-pro');
  assert.equal(ended.title,'优化通知页布局');assert.equal(ended.project,'桌面助手');assert.equal(ended.detail,'已完成布局调整。');assert.equal(ended.terminalReason,'completed');assert.equal(ended.state,'resolved');assert.equal(ended.canDecide,false);
  session.append('turn/start',{turn:2});
  session.append('request/header',{header:{config:{provider:'synthetic',model:'deepseek-v4-pro'}},reason:'initial'});
  session.append('approval/asked',{id:'synthetic-audit',toolName:'bash',reason:'Synthetic ignored reason'});
  const waiting=output.at(-1);assert.equal(waiting.kind,'approval');assert.equal(waiting.canDecide,false);assert.equal(waiting.model,'deepseek-v4-pro');
  session.append('session/title',{title:'Renamed'});observer.heartbeat();
  session.append('approval/decided',{id:'synthetic-audit',outcome:'rejected'});
  assert.equal(output.at(-1).outcome,'declined');assert.equal(output.at(-1).title,waiting.title);
  if (process.argv[3]) fs.writeFileSync(process.argv[3], output.map(event=>JSON.stringify(event)).join('\n')+'\n',{mode:0o600});
  await ctx.fiber.dispose();
  console.log(JSON.stringify({result:'PASS native DSH content contracts',pins,checks:['real Session/header','real title projection','committed assistant message','native turn reason','audit-only approval resolution'],modelsInvoked:0,profileModified:false}));
})().catch(error=>{console.error(error);process.exitCode=1;});
