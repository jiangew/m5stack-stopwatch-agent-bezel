import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import * as source from '../src/client.js';
import { checkRegistrationContract } from '../scripts/check-installed-contract.mjs';

const inspected = process.env.DSH_INSPECTED_NODE_MODULES ?? fileURLToPath(new URL('../../../../outputs/dsh-source-inspection/dsh/node_modules', import.meta.url));
test('real host registration: 3 commands x 6 platforms x source/bundle; rejects old and null defaults', {
  skip: !process.env.DSH_INSPECTED_NODE_MODULES && !existsSync(inspected) ? 'Inspected host absent; set DSH_INSPECTED_NODE_MODULES (required for release validation)' : false,
}, () => {
  assert.match(checkRegistrationContract(inspected), /Real ShortcutRegistry.register contract passed/);
});

const registrationDiagnostic = 'AgentBezel: navigation commands disabled because shortcut registration failed; check plugin/host compatibility.';
const releaseDiagnostic = 'AgentBezel: shortcut cleanup failed; navigation actions disabled; reload or disable this plugin.';
function plugin(kind, logs, t) {
  if (kind === 'source') {
    t.mock.method(console, 'error', (...args) => logs.push(args));
    return source;
  }
  let result;
  vm.runInNewContext(readFileSync(new URL('../lib/client.js', import.meta.url), 'utf8'), {
    window: { __ModuleLoader__: { load: value => { result = value.factory(); } } },
    console: { error: (...args) => logs.push(args) },
  });
  return result;
}
function context(failAt, failRelease = false) {
  const active = new Map(), retained = [], attempts = [];
  let calls = 0, cleanup;
  const ctx = {
    shortcuts: { register(command) {
      if (++calls === failAt) throw new Error('PRIVATE user prompt /workspace/secret');
      active.set(command.id, command); retained.push(command);
      return () => {
        attempts.push(command.id);
        // Leave one stale callback behind to verify the plugin's disabled guard.
        if (failRelease && command.id === retained.at(-1).id) throw new Error('PRIVATE release data');
        active.delete(command.id);
      };
    } },
    effect(callback) { cleanup = callback(); },
  };
  return { ctx, active, retained, attempts, cleanup: () => cleanup, calls: () => calls };
}
for (const kind of ['source', 'bundle']) {
  for (const failAt of [1, 2, 3]) for (const viaApply of [false, true]) for (const failRelease of [false, true]) {
    test(`${kind}: register #${failAt} fails, ${viaApply ? 'apply' : 'registerCommands'} contains error, release throws=${failRelease}`, t => {
      const logs = [], api = plugin(kind, logs, t), state = context(failAt, failRelease);
      let dispose;
      assert.doesNotThrow(() => {
        if (viaApply) { api.apply(state.ctx); dispose = state.cleanup(); }
        else dispose = api.registerCommands(state.ctx, undefined);
      });
      assert.equal(state.calls(), failAt);
      assert.equal(typeof dispose, 'function');
      assert.deepEqual(state.attempts, state.retained.map(row => row.id).reverse());
      assert.equal(state.active.size, failRelease && failAt > 1 ? 1 : 0);
      for (const command of state.retained) assert.equal(command.resolve({}).status, 'blocked');
      assert.deepEqual(logs, [...(failRelease && failAt > 1 ? [[releaseDiagnostic]] : []), [registrationDiagnostic]]);
      assert.doesNotThrow(() => { dispose(); dispose(); });
      assert.equal(state.attempts.length, failAt - 1);
    });
  }
  test(`${kind}: normal teardown attempts every release once despite a release exception`, t => {
    const logs = [], api = plugin(kind, logs, t), state = context(0, true);
    api.apply(state.ctx);
    assert.equal(state.active.size, 3);
    assert.doesNotThrow(() => { state.cleanup()(); state.cleanup()(); });
    assert.deepEqual(state.attempts, state.retained.map(row => row.id).reverse());
    for (const command of state.retained) assert.equal(command.resolve({}).status, 'blocked');
    assert.deepEqual(logs, [[releaseDiagnostic]]);
  });
  for (const afterCallback of [false, true]) test(`${kind}: effect setup failure (${afterCallback ? 'after' : 'before'} callback) never escapes apply`, t => {
    const logs = [], api = plugin(kind, logs, t), state = context(0);
    state.ctx.effect = callback => {
      if (afterCallback) callback();
      throw new Error('PRIVATE effect data');
    };
    assert.doesNotThrow(() => api.apply(state.ctx));
    assert.equal(state.active.size, 0);
    assert.equal(state.attempts.length, afterCallback ? 3 : 0);
    assert.deepEqual(logs, [[registrationDiagnostic]]);
  });
}
test('a failing diagnostic sink never escapes registration or apply', t => {
  t.mock.method(console, 'error', () => { throw new Error('PRIVATE logger'); });
  const state = context(3, true);
  assert.doesNotThrow(() => source.apply(state.ctx));
  assert.equal(state.attempts.length, 2);
});
