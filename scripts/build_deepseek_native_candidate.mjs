#!/usr/bin/env node
import {mkdir,readFile,writeFile,lstat,readdir,rm} from 'node:fs/promises';
import {resolve,dirname,relative,sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import {withTemporaryNative,verifyDependencyTree,verifyNativeTree,validatePatch} from './test_deepseek_native.mjs';
import {sha,noLinks,verifyLoaderFixture,fixturePin,readArchiveCode} from './test_deepseek_native_loader.mjs';
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const patchDir=resolve(repo,'notifications/native-patches');
const json=value=>JSON.stringify(value,null,2)+'\n';
const plain=value=>value!==null&&typeof value==='object'&&!Array.isArray(value)&&Object.getPrototypeOf(value)===Object.prototype;
const within=(child,parent)=>child.startsWith(parent+sep);
function requireShape(value,keys,label){if(!plain(value)||Object.keys(value).some(k=>!keys.includes(k)))throw Error('unknown '+label+' shape');}
function declaration(configuration,output){
  requireShape(configuration,['kind','entries','presetEntryId','approvalEntryId','canaryId','canaryEntryId'],'configuration');
  if(!['synthetic','synthetic-shipped-base','inventoried'].includes(configuration.kind)||!Array.isArray(configuration.entries))throw Error('unknown preset inventory');
  const c=structuredClone(configuration),entries=c.entries;
  const presets=entries.filter(e=>e.name==='@deepseek-ai/dsh-agent-preset');
  if(!/^[a-z][a-z0-9-]{1,63}$/.test(c.canaryId)||!/^[a-z][a-z0-9-]{1,63}$/.test(c.canaryEntryId)||entries.some(e=>e.id===c.canaryEntryId)||presets.some(e=>e.config?.id===c.canaryId))throw Error('duplicate or invalid canary preset identity');
  const matches=presets.filter(e=>e.id===c.presetEntryId),approvals=entries.filter(e=>e.id===c.approvalEntryId&&e.name==='@deepseek-ai/dsh-user-approval');
  if(matches.length!==1||approvals.length!==1)throw Error('missing or duplicate preset/approval declaration');
  const preset=matches[0];requireShape(preset,['id','name','config','disabled'],'preset declaration');requireShape(preset.config,['id','name','description','order','plugins'],'preset config');
  if(typeof preset.config.id!=='string'||!Array.isArray(preset.config.plugins))throw Error('unknown preset shape');
  requireShape(approvals[0].config,['policy'],'approval config');const policy=approvals[0].config.policy;
  if(!['ask','never'].includes(policy)&&!(plain(policy)&&Object.keys(policy).length===1&&typeof policy.__jsExpr==='string'))throw Error('unknown explicit approval policy');
  const bashRows=[];
  function inspect(rows,top=true){for(const row of rows){
    if(!plain(row)||typeof row.name!=='string'||row.name.startsWith('.')||row.name.startsWith('/'))throw Error('unknown preset row shape or unanchored module');
    if(row.name.includes('bash')&&row.name!=='@deepseek-ai/dsh-tool-bash')throw Error('unsupported Bash preset');
    if(row.name==='@deepseek-ai/dsh-tool-bash'){if(!top)throw Error('unknown nested Bash preset shape');bashRows.push(row);}
    if(row.group===true){if(!Array.isArray(row.config))throw Error('unknown preset group shape');inspect(row.config,false);}
    else if(row.config?.plugins)throw Error('unknown nested preset shape');
  }}inspect(preset.config.plugins);
  if(bashRows.length!==1)throw Error('exactly one ordinary Bash row required');
  const bash=bashRows[0];requireShape(bash,['id','name','config','disabled','inject'],'Bash row');
  if(bash.config!==undefined)requireShape(bash.config,['enableRunInBackground'],'Bash config');
  const clone=structuredClone(preset);clone.id=c.canaryEntryId;clone.config.id=c.canaryId;clone.config.name=(clone.config.name??clone.config.id)+' (Stopwatch canary)';
  const index=preset.config.plugins.indexOf(bash);
  clone.config.plugins[index]={id:c.canaryEntryId+'-scope',name:'cordis:group',group:true,isolate:{approval:true},config:[
    {id:c.canaryEntryId+'-approval',name:pathToFileURL(resolve(output,'lib/approval-floor.mjs')).href,config:approvals[0].config},
    {...bash,name:pathToFileURL(resolve(output,'lib/bash.js')).href,config:{...bash.config,enableRunInBackground:false}}
  ]};
  return [{insert:[clone]}];
}
async function destination(options,create){
  const output=resolve(options.output),profile=resolve(options.profile);
  if(!within(output,profile))throw Error('output must be inside explicit profile');
  if(!within(output,repo)&&!within(output,'/private/tmp')&&!within(output,'/private/var/folders'))throw Error('source-only output must use private temporary or ignored checkout staging');
  if(within(output,repo)){
    const check=spawnSync('git',['check-ignore','-q','--',relative(repo,output)],{cwd:repo});
    if(check.status!==0)throw Error('checkout output must be ignored');
  }
  await noLinks(profile);await noLinks(dirname(output));
  for(const dir of [profile,dirname(output)]){const st=await lstat(dir);if(!st.isDirectory()||st.uid!==process.getuid()||(st.mode&0o777)!==0o700)throw Error('output parent/profile must be owner-private 0700');}
  let cursor=dirname(output);
  while(true){
    // Reject local native/framework packages anywhere Node could find before installation.
    const modules=resolve(cursor,'node_modules');
    try{await lstat(modules);throw Error('local shadow dependencies forbidden');}catch(error){if(error.code!=='ENOENT')throw error;}
    if(cursor===profile)break;cursor=dirname(cursor);
  }
  if(create){try{await lstat(output);throw Error('output exists; refusing overwrite');}catch(error){if(error.code!=='ENOENT')throw error;}}
  else await noLinks(output);
  return output;
}
async function contents(options){
  const {source,fixture,configuration,configurationSha256}=options;
  if(sha(JSON.stringify(configuration))!==configurationSha256)throw Error('configuration hash mismatch');
  const overlay=declaration(configuration,resolve(options.output));
  const verificationMode=options.verificationMode??'installed-archive';
  if(!['installed-archive','historical-source-fixture'].includes(verificationMode))throw Error('unknown verification mode');
  if(verificationMode==='historical-source-fixture'){
    if(options.archive!==undefined)throw Error('historical source fixture mode cannot validate an archive');
  }else await readArchiveCode(options.archive??'/Applications/DeepSeek Harness.app/Contents/Resources/app.asar');
  await verifyLoaderFixture(fixture);
  const manifest=JSON.parse(await readFile(resolve(patchDir,'manifest.json')));
  const patch=await readFile(resolve(patchDir,'deepseek-0.2.0-rc.2-approval-context.patch'));validatePatch(patch,manifest);
  await verifyNativeTree(source,manifest);await verifyDependencyTree(source,manifest);
  return withTemporaryNative(source,async patched=>{
    const files={};const modules=[['dsh-user-approval','approval'],['dsh-sandbox','sandbox'],['dsh-tool-bash','bash']];
    for(const [pkg,file] of modules)files[`lib/${file}.js`]=await readFile(resolve(patched,'@deepseek-ai',pkg,'lib/index.js'),'utf8');
    const before=files['lib/bash.js'];const token='from "@deepseek-ai/dsh-sandbox";';
    if(before.split(token).length!==2||before.split('"@deepseek-ai/dsh-sandbox"').length!==2)throw Error('unexpected sandbox import transform');
    files['lib/bash.js']=before.replace(token,'from "./sandbox.js";');
    files['lib/approval-floor.mjs']=await readFile(resolve(patchDir,'deployment/approval-floor.mjs'),'utf8');
    const peerNames=[...new Set(Object.values(files).flatMap(code=>[...code.matchAll(/from "(@deepseek-ai\/[^"/]+)"/g)].map(m=>m[1])))].sort();
    const expected=['cordis','dsh-llm','dsh-scope','dsh-session','dsh-shell','dsh-tools','dsh-util-values','schemastery'].map(n=>'@deepseek-ai/'+n).sort();
    if(JSON.stringify(peerNames)!==JSON.stringify(expected))throw Error('unexpected native peers');
    const peers={},peerManifests={};for(const name of peerNames){const bytes=await readFile(resolve(source,name,'package.json'));const pkg=JSON.parse(bytes);if(pkg.name!==name||typeof pkg.version!=='string')throw Error('native peer manifest mismatch');peers[name]=pkg.version;peerManifests[name]=sha(bytes);}
    files['package.json']=json({name:'@stopwatch-project/dsh-native-approval-canary',version:'0.0.0',private:true,type:'module',peerDependencies:peers});
    files['canary.patch.yml']=json(overlay); // JSON is accepted by the native YAML entry-list schema; __jsExpr objects stay intact.
    files['LICENSE.upstream']=(await Promise.all(modules.map(async([pkg])=>`@deepseek-ai/${pkg}\n${await readFile(resolve(fixture,'dsh/node_modules/@deepseek-ai',pkg,'LICENSE'),'utf8')}\n`))).join('\n');
    const sourceContentHashes={};for(const name of ['scripts/build_deepseek_native_candidate.mjs','scripts/test_deepseek_native.mjs','scripts/test_deepseek_native_loader.mjs','notifications/native-patches/manifest.json','notifications/native-patches/deployment/fixture-manifest.json','notifications/native-patches/deployment/approval-floor.mjs'])sourceContentHashes[name]=sha(await readFile(resolve(repo,name)));
    const provenance={schemaVersion:1,status:'historical source-only candidate; not installable or accepted on the current runtime',verificationMode,installedArchiveVerified:verificationMode==='installed-archive',sourceContentHashes,kind:configuration.kind,destination:pathToFileURL(resolve(options.output)+'/').href,
      asarSha256:fixturePin.asarSha256,loaderFixture:fixturePin.fixture,addon:fixturePin.addon,nativeInputTree:manifest.dependencyTree.inputSha256,nativePatchedTree:manifest.dependencyTree.outputSha256,patchSha256:manifest.patchSha256,
      configurationSha256,peerManifests,peerConfigurationSha256:sha(json(peers)),transform:{description:'one static sandbox import to ./sandbox.js in generated Bash only',beforeSha256:sha(before),afterSha256:sha(files['lib/bash.js'])},files:Object.fromEntries(Object.entries(files).map(([name,bytes])=>[name,sha(bytes)]))};
    files['provenance.json']=json(provenance);return {files,overlay,provenance};
  });
}
export async function buildCandidate(options){
  const output=await destination(options,true);const result=await contents(options);await mkdir(output,{mode:0o700});
  try{await mkdir(resolve(output,'lib'),{mode:0o700});for(const [name,bytes]of Object.entries(result.files))await writeFile(resolve(output,name),bytes,{flag:'wx',mode:0o600});return result;}
  catch(error){await rm(output,{recursive:true,force:true});throw error;}
}
export async function verifyCandidate(output,options){
  await destination({...options,output},false);const expected=await contents({...options,output});const names=[];
  async function walk(path){const st=await lstat(path);if(st.isSymbolicLink()||st.uid!==process.getuid())throw Error('nonprivate/symlink candidate');if(st.isDirectory()){if((st.mode&0o777)!==0o700)throw Error('nonprivate candidate directory');for(const name of await readdir(path)){const child=resolve(path,name);if(name==='node_modules')throw Error('unexpected shadow dependency');await walk(child);}}else if(st.isFile()){if((st.mode&0o777)!==0o600)throw Error('nonprivate candidate file');names.push(relative(output,path));}else throw Error('unexpected special output');}
  await walk(output);if(JSON.stringify(names.sort())!==JSON.stringify(Object.keys(expected.files).sort()))throw Error('unexpected output files');
  for(const [name,bytes]of Object.entries(expected.files))if(sha(await readFile(resolve(output,name)))!==sha(bytes))throw Error(`${name==='provenance.json'?'provenance destination':'package/output'} SHA256 mismatch`);
  return expected.provenance;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
  const args=process.argv.slice(2),historical=args.at(-1)==='--historical-source-fixture';if(historical)args.pop();
  const [source,fixture,profile,output,configurationFile,configurationSha256,...extra]=args;
  if(!configurationSha256||extra.length){process.stderr.write('Usage: node scripts/build_deepseek_native_candidate.mjs STOCK_NODE_MODULES VERIFIED_FIXTURE PRIVATE_SYNTHETIC_PROFILE NEW_OUTPUT CONFIG_JSON CONFIG_SHA256 [--historical-source-fixture]\n');process.exitCode=2;}
  else try{const configuration=JSON.parse(await readFile(configurationFile));await buildCandidate({source,fixture,profile,output,configuration,configurationSha256,...(historical?{verificationMode:'historical-source-fixture'}:{})});process.stdout.write('Created historical source-only private candidate; not installable/current-runtime accepted.\n');}catch(error){process.stderr.write(error.message+'\n');process.exitCode=1;}
}
