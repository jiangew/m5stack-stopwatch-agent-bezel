import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { apply as hostApply } from '../lib/index.js';
const read = name => readFileSync(new URL(`../${name}`, import.meta.url), 'utf8');
test('built browser factory materializes without globals, imports or side effects', () => {
  let registration;
  const sandbox = { window: { __ModuleLoader__: { load: value => { registration = value; } } } };
  vm.runInNewContext(read('lib/client.js'), sandbox);
  assert.equal(registration.id, 'dsh-agentbezel-navigation');
  const plugin = registration.factory(() => { throw new Error('Unexpected host import'); });
  assert.equal(typeof plugin.apply, 'function'); assert.equal(typeof plugin.registerCommands, 'function');
  assert.deepEqual(Array.from(plugin.inject), ['shortcuts', 'slots', 'configForms', 'layout', 'sessions', 'workspaces']);
  // All behavior is delayed until Cordis effect installation.
  let effect;
  plugin.apply({ effect: callback => effect = callback });
  assert.equal(typeof effect, 'function');
});
test('host apply is empty and package declares both installable bundle and client', () => {
  hostApply(new Proxy({}, { get() { throw new Error('Host side effect'); } }));
  const manifest = JSON.parse(read('package.json'));
  assert.equal(manifest.version, '0.1.1');
  assert.equal(manifest.exports['./client'], './lib/client.js');
  assert.equal(manifest.dsh.client.platform, 'web');
  assert.ok(manifest.dsh.client.inject.includes('@deepseek-ai/dsh-client-shortcuts'));
  assert.equal(manifest.dsh.bundle.patch, './cordis.patch.yml');
  assert.match(read('cordis.patch.yml'), /- insert:\n\s+- id: agentbezel-navigation\n\s+name: dsh-agentbezel-navigation/);
  assert.equal(manifest.dependencies, undefined);
});
test('runtime code has no key listeners, storage/network/OS injection or content reads', () => {
  for (const source of ['src/client.js', 'src/dom-adapter.js']) {
    assert.doesNotMatch(read(source), /\b(?:addEventListener|KeyboardEvent|dispatchEvent|localStorage|sessionStorage|fetch|XMLHttpRequest|textContent|innerText|innerHTML|openWorkspace|startSession|setTimeout|setInterval)\b/);
  }
});
