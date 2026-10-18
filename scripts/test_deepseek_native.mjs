#!/usr/bin/env node
// Source-only acceptance runner. Native packages are never installed or edited in place.
import {createHash} from 'node:crypto';
import {cp,lstat,mkdtemp,readFile,readdir,realpath,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {dirname,relative,resolve,sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const manifestPath=resolve(repo,'notifications/native-patches/manifest.json');
const patchPath=resolve(repo,'notifications/native-patches/deepseek-0.2.0-rc.2-approval-context.patch');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');

export async function verifyNativeTree(root,manifest,variant='input') {
  const absolute=await realpath(root);
  for (const file of manifest.files) {
    const target=resolve(absolute,file.path);
    if (!target.startsWith(absolute+sep)) throw new Error('invalid manifest path');
    const info=await lstat(target);
    if (!info.isFile() || info.isSymbolicLink()) throw new Error('native inputs must be regular files');
    const expected=variant==='output'?(file.outputSha256 ?? file.inputSha256):file.inputSha256;
    if (sha(await readFile(target))!==expected) throw new Error(`SHA256 mismatch: ${file.package}`);
  }
}
export function validatePatch(patch,manifest) {
  if (sha(patch)!==manifest.patchSha256) throw new Error('patch SHA256 mismatch');
  const paths=[...patch.toString().matchAll(/^--- a\/(.+)$/gm)].map(m=>m[1]);
  const expected=manifest.files.filter(f=>f.patched).map(f=>f.path);
  if (JSON.stringify(paths)!==JSON.stringify(expected)) throw new Error('unexpected patch targets');
}
export async function verifyDependencyTree(root,manifest,variant='input') {
  const records=[];
  const walk=async path=>{
    const info=await lstat(path);
    if (info.isSymbolicLink()) throw new Error('symlink in external native tree');
    if (info.isDirectory()) {
      for (const name of (await readdir(path)).sort()) await walk(resolve(path,name));
    } else if (info.isFile()) {
      records.push(`${relative(root,path).split(sep).join('/')}\0${sha(await readFile(path))}\n`);
    } else throw new Error('special file in external native tree');
  };
  await walk(root);
  const expected=variant==='output'?manifest.dependencyTree.outputSha256:manifest.dependencyTree.inputSha256;
  if (sha(records.sort().join(''))!==expected || records.length!==manifest.dependencyTree.fileCount) throw new Error('dependency tree SHA256 mismatch');
}

function run(command,args,options={}) {
  const result=spawnSync(command,args,{encoding:'utf8',maxBuffer:1024*1024,...options});
  if (result.error) throw result.error;
  return result;
}
export async function testTemporaryNative(source,variant='patched') {
  if (!['patched','stock'].includes(variant)) throw new Error('variant must be stock or patched');
  const manifest=JSON.parse(await readFile(manifestPath));
  const patch=await readFile(patchPath); validatePatch(patch,manifest);
  await verifyDependencyTree(source,manifest); await verifyNativeTree(source,manifest);
  const temporary=await mkdtemp(resolve(tmpdir(),'stopwatch-dsh-native-'));
  try {
    const target=resolve(temporary,'node_modules');
    await cp(source,target,{recursive:true,errorOnExist:true,force:false});
    await verifyNativeTree(target,manifest);
    await verifyDependencyTree(target,manifest);
    if (variant==='patched') {
      for (const dry of [true,false]) {
        const result=run('patch',['-p1','--batch','--forward',...(dry?['--dry-run']:[]),'-i',patchPath],{cwd:target});
        if (result.status!==0) throw new Error(`patch ${dry?'preflight':'apply'} failed; temporary tree discarded`);
      }
      await verifyNativeTree(target,manifest,'output');
      await verifyDependencyTree(target,manifest,'output');
    }
    const result=run(process.execPath,['--test',resolve(repo,'notifications/tests/deepseek-native.test.mjs')],{
      // Do not copy credentials, proxy or provider variables into the test process.
      env:{PATH:process.env.PATH,DSH_NATIVE_MODULES:target,DSH_NATIVE_VARIANT:variant},
    });
    process.stdout.write(result.stdout); process.stderr.write(result.stderr);
    await verifyNativeTree(source,manifest); await verifyDependencyTree(source,manifest); // The external stock tree stayed untouched.
    return result.status ?? 1;
  } finally { await rm(temporary,{recursive:true,force:true}); }
}
if (process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  const [source,variant='patched',...extra]=process.argv.slice(2);
  if (!source || extra.length) {
    process.stderr.write('Usage: node scripts/test_deepseek_native.mjs /explicit/extracted/node_modules [stock|patched]\n');
    process.exitCode=2;
  } else {
    try {process.exitCode=await testTemporaryNative(resolve(source),variant);}
    catch(error) {process.stderr.write(`${error.message}\n`);process.exitCode=1;}
  }
}
