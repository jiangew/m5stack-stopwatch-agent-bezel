#!/usr/bin/env node
// Separate code-only fixture: never extend or mutate the Task 1 native tree.
import {createHash} from 'node:crypto';
import {lstat,mkdir,mkdtemp,readFile,readdir,writeFile,rm,realpath} from 'node:fs/promises';
import {resolve,dirname,relative,sep,basename} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'..');
export const fixturePin=JSON.parse(await readFile(new URL('../notifications/native-patches/deployment/fixture-manifest.json',import.meta.url)));
export const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function noLinks(path){
  let current=resolve(path);
  while(true){const info=await lstat(current);if(info.isSymbolicLink())throw Error('symlink path forbidden');const parent=dirname(current);if(parent===current)break;current=parent;}
}
export async function hashTree(root){
  await noLinks(root);const records=[];
  async function walk(path){const st=await lstat(path);if(st.isSymbolicLink())throw Error('symlink forbidden');
    if(st.isDirectory())for(const name of (await readdir(path)).sort())await walk(resolve(path,name));
    else if(st.isFile())records.push(`${relative(root,path).split(sep).join('/')}\0${sha(await readFile(path))}\n`);
    else throw Error('special file forbidden');
  }
  await walk(root);return {fileCount:records.length,sha256:sha(records.sort().join(''))};
}
export async function verifyLoaderFixture(root){
  if(JSON.stringify(await hashTree(root))!==JSON.stringify(fixturePin.fixture))throw Error('loader fixture SHA256 mismatch');
}
export function archiveEntries(bytes){
  const headerSize=bytes.readUInt32LE(4),jsonSize=bytes.readUInt32LE(12);
  if(jsonSize>headerSize || headerSize+8>bytes.length)throw Error('invalid ASAR header');
  const tree=JSON.parse(bytes.subarray(16,16+jsonSize));const entries=[];
  function walk(node,prefix=''){for(const [name,value] of Object.entries(node.files??{})){
    if(!name || ['.','..'].includes(name) || /[\\/\x00]/.test(name))throw Error('invalid archive path');
    const path=prefix+name;if(value.files)walk(value,path+'/');else entries.push({path,value});
  }}walk(tree);return {entries,base:8+headerSize};
}
export async function readArchiveCode(archive){
  await noLinks(archive);if(!(await lstat(archive)).isFile())throw Error('ASAR must be regular');
  const bytes=await readFile(archive);if(sha(bytes)!==fixturePin.asarSha256)throw Error('ASAR SHA256 mismatch');
  return {bytes,...archiveEntries(bytes)};
}
export async function archiveFile(archive,parsed,path){
  const entry=parsed.entries.find(e=>e.path===path)?.value;
  if(!entry || entry.link)throw Error('missing or linked archive entry');
  let bytes;
  if(entry.unpacked){const file=resolve(archive+'.unpacked',path);await noLinks(file);if(!(await lstat(file)).isFile())throw Error('unpacked input not regular');bytes=await readFile(file);}
  else {const offset=Number(entry.offset);if(!Number.isSafeInteger(offset)||offset<0||!Number.isSafeInteger(entry.size)||entry.size<0||parsed.base+offset+entry.size>parsed.bytes.length)throw Error('invalid archive range');bytes=parsed.bytes.subarray(parsed.base+offset,parsed.base+offset+entry.size);}
  if(bytes.length!==entry.size || entry.integrity?.algorithm!=='SHA256' || sha(bytes)!==entry.integrity.hash)throw Error('archive entry SHA256 mismatch');return bytes;
}
export async function extractLoaderFixture(archive,destination){
  const parsed=await readArchiveCode(archive);await noLinks(dirname(destination));await mkdir(destination,{mode:0o700});
  try{
    for(const {path} of parsed.entries){
      const selected=path==='dsh/package.json'||path===fixturePin.addon.manifest||path===fixturePin.addon.binary||
        path.startsWith('dsh/node_modules/')&&(/\.(js|mjs|cjs)$/.test(path)||path.endsWith('/package.json')||/^(license|licence|notice)/i.test(basename(path)));
      if(!selected)continue;const bytes=await archiveFile(archive,parsed,path);const out=resolve(destination,path);
      await mkdir(dirname(out),{recursive:true,mode:0o700});await writeFile(out,bytes,{flag:'wx',mode:0o600});
    }
    const addon=await readFile(resolve(destination,fixturePin.addon.binary));
    if(process.platform!==fixturePin.addon.platform || process.arch!==fixturePin.addon.arch || addon.readUInt32LE(0)!==0xfeedfacf || addon.readUInt32LE(4)!==0x100000c)throw Error('unsupported addon architecture/platform');
    if(sha(addon)!==fixturePin.addon.binarySha256||sha(await readFile(resolve(destination,fixturePin.addon.manifest)))!==fixturePin.addon.manifestSha256)throw Error('addon pin mismatch');
    await verifyLoaderFixture(destination);return destination;
  }catch(error){await rm(destination,{recursive:true,force:true});throw error;}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
  const args=process.argv.slice(2),historical=args.at(-1)==='--historical-source-fixture';if(historical)args.pop();
  const [source,fixture,...extra]=args;
  if(!source||!fixture||extra.length){process.stderr.write('Usage: node scripts/test_deepseek_native_loader.mjs STOCK_NODE_MODULES VERIFIED_FIXTURE_OR_APP_ASAR [--historical-source-fixture]\n');process.exitCode=2;}
  else {let temporary;try{
    let fixtureRoot=await realpath(fixture);
    if((await lstat(fixtureRoot)).isFile()){temporary=await mkdtemp('/private/tmp/stopwatch-dsh-loader-');fixtureRoot=await extractLoaderFixture(fixtureRoot,resolve(temporary,'fixture'));}
    await verifyLoaderFixture(fixtureRoot);
    if(!historical)await readArchiveCode('/Applications/DeepSeek Harness.app/Contents/Resources/app.asar');
    process.stdout.write(historical?'Historical source fixture tests only; no current runtime/install acceptance.\n':'Pinned installed archive verified; source-only tests follow.\n');
    const result=spawnSync(process.execPath,['--expose-internals','--test','--test-timeout=60000',resolve(repo,'notifications/tests/deepseek-loader.test.mjs')],{encoding:'utf8',timeout:120000,maxBuffer:4*1024*1024,env:{PATH:process.env.PATH,DSH_NATIVE_MODULES:resolve(source),DSH_LOADER_FIXTURE:fixtureRoot,DSH_VERIFICATION_MODE:historical?'historical-source-fixture':'installed-archive'}});
    process.stdout.write(result.stdout??'');process.stderr.write(result.stderr??'');if(result.error)throw result.error;process.exitCode=result.status??1;
  }catch(error){process.stderr.write(error.message+'\n');process.exitCode=1;}finally{if(temporary)await rm(temporary,{recursive:true,force:true});}}
}
