// Read-only check: node scripts/check-installed-contract.mjs PATH_TO_DSH_NODE_MODULES
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { registerCommands } from '../src/client.js';
import { loadHostShortcuts } from './host-shortcuts.mjs';
export function checkRegistrationContract(modules) {
  const host = loadHostShortcuts(modules);
  let bundle;
  vm.runInNewContext(readFileSync(new URL('../lib/client.js', import.meta.url), 'utf8'), {
    window: { __ModuleLoader__: { load: value => { bundle = value.factory(); } } },
    console: { error() { throw new Error('Unexpected bundle diagnostic'); } },
  });
  const rows = [];
  const profiles = ['desktop:macos', 'desktop:windows', 'desktop:linux', 'web:macos', 'web:windows', 'web:linux'];
  const allowed = ['desktop:macos', 'desktop:windows', 'web:windows'];
  for (const [name, register] of [['source', registerCommands], ['bundle', bundle.registerCommands]]) {
    for (const profile of profiles) {
      const [runtime, platform] = profile.split(':');
      const registry = host.createRegistry(runtime, platform);
      const dispose = register({ shortcuts: registry }, undefined);
      assert.equal(registry.commands.size, 3, `${name} ${profile}: all commands must register`);
      const definitions = [...registry.commands.values()];
      assert.deepEqual(definitions.map(row => row.id), ['agentbezel.previousThread', 'agentbezel.nextThread', 'agentbezel.toggleView']);
      for (const [index, command] of definitions.entries()) {
        const code = ['ArrowUp', 'ArrowDown', 'ArrowRight'][index];
        assert.deepEqual(Object.keys(command.defaults).sort(), [...allowed].sort());
        for (const target of profiles) {
          const [rt, os] = target.split(':');
          const issue = host.bindingIssue(host.normalizeBinding({ code, modifiers: ['control', 'alt'] }, os), rt, os);
          assert.equal(issue, allowed.includes(target) ? null : 'reserved');
          if (allowed.includes(target)) {
            assert.equal(command.defaults[target].code, code);
            assert.deepEqual(Array.from(command.defaults[target].modifiers), ['control', 'alt']);
          } else assert.equal(command.defaults[target], undefined);
        }
        // Reproduce 0.1.0: real register rejects ALL-six-default definitions even
        // when the receiving runtime itself accepts Control+Alt+Arrow.
        const old = { ...command, defaults: Object.fromEntries(profiles.map(key => [key, { code, modifiers: ['control', 'alt'] }])) };
        const rejected = host.createRegistry(runtime, platform);
        assert.throws(() => rejected.register(old), /Reserved shortcut default/);
        assert.equal(rejected.commands.size, 0);
        // null is valid in preference overrides, but NOT this registration schema.
        const explicitNull = { ...command, defaults: { ...command.defaults, 'desktop:linux': null } };
        assert.throws(() => rejected.register(explicitNull), /null/);
        assert.equal(rejected.commands.size, 0);
      }
      const catalog = registry.catalog.getSnapshot();
      assert.equal(catalog.length, 3);
      for (const row of catalog) {
        assert.equal(row.issue, null);
        assert.equal(row.conflicts.length, 0);
        assert.equal(row.binding === null, !allowed.includes(profile));
      }
      assert.equal(registry.bindings.size, allowed.includes(profile) ? 3 : 0);
      dispose(); dispose();
      assert.equal(registry.commands.size, 0);
      assert.equal(registry.catalog.getSnapshot().length, 0);
      rows.push(`${name} ${profile}: 3 registered, ${allowed.includes(profile) ? '3 bound' : 'unbound (catalog null)'}, old definitions rejected`);
    }
  }
  // Actual host validation failure after earlier successful registrations.
  // Unlike a throwing fake, this executes the same reserved-default rejection
  // that caused 0.1.0 activation to fail, then observes the real registry cleanup.
  for (const register of [registerCommands, bundle.registerCommands]) for (const failAt of [2, 3]) {
    const registry = host.createRegistry('desktop', 'macos');
    let calls = 0;
    const dispose = register({ shortcuts: { register(command) {
      calls++;
      if (calls === failAt) command = {
        ...command, defaults: { ...command.defaults, 'desktop:linux': command.defaults['desktop:macos'] },
      };
      return registry.register(command);
    } } }, undefined);
    assert.equal(calls, failAt);
    assert.equal(registry.commands.size, 0);
    assert.equal(registry.catalog.getSnapshot().length, 0);
    assert.equal(registry.bindings.size, 0);
    assert.doesNotThrow(dispose);
  }
  assert.match(host.source, /if \(!gesture\.repeat\) resolution\.run\(\)/);
  const workspace = readFileSync(resolve(modules, '@deepseek-ai/dsh-client-ui-workspace/lib/client.js'), 'utf8');
  for (const marker of ['_7514NG_groupSection', 'jJkEga_sessionRow', 'jJkEga_projectRow', '"data-row-key": `overflow:${group.key}`', '"aria-selected": selected']) assert.ok(workspace.includes(marker), marker);
  const conversation = readFileSync(resolve(modules, '@deepseek-ai/dsh-client-ui-conversation/lib/client.js'), 'utf8');
  for (const marker of ['ST7X_W_root', '"data-conversation-tabs": ""', 'slots.entries("conversation.view")', 'ctx.configForms.developerTools.enabled.getSnapshot()']) assert.ok(conversation.includes(marker), marker);
  return `Real ShortcutRegistry.register contract passed (no validateDefinition exists in this host).\nHost SHA-256: ${host.sha256}\n${rows.join('\n')}\nSnapshot store stub only; no live activation/UI or OS delivery tested.`;
}
if (process.argv[1] && resolve(process.argv[1]) === new URL(import.meta.url).pathname) {
  if (!process.argv[2]) throw new Error('Pass inspected DSH node_modules directory (no installation performed).');
  console.log(checkRegistrationContract(process.argv[2]));
}
