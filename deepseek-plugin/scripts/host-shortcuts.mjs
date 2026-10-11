// Read-only execution of the inspected host's REAL registration implementation.
// Only snapshot publication is a test double; no host boot, storage or DOM runs.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';
import vm from 'node:vm';

export function loadHostShortcuts(modules) {
  const path = resolve(modules, '@deepseek-ai/dsh-client-shortcuts/lib/client.js');
  const source = readFileSync(path, 'utf8');
  function section(start, end) {
    const a = source.indexOf(start), b = source.indexOf(end, a);
    if (a < 0 || b <= a || source.indexOf(start, a + start.length) !== -1) {
      throw new Error('Unsupported inspected shortcut source structure; inspect the new host before testing.');
    }
    return source.slice(a, b);
  }
  const policy = section('const keyNames =', '//#region ../../util/crypto/lib/index.js');
  const registry = section('var ShortcutRegistry = class', '//#region lib/types/client/dom.js');
  const store = { createSnapshotStore(initial) {
    let value = initial;
    return { getSnapshot: () => value, set: next => { value = next; }, subscribe: () => () => {} };
  } };
  const host = vm.runInNewContext(`(() => { ${policy}\n${registry}\nreturn { ShortcutRegistry, bindingIssue, normalizeBinding }; })()`, {
    _deepseek_ai_dsh_client_store: store,
  }, { filename: 'inspected-host-shortcut-registry.js', timeout: 1000 });
  return {
    ...host, source, sha256: createHash('sha256').update(source).digest('hex'),
    createRegistry(runtime, platform) {
      return new host.ShortcutRegistry(runtime, platform, {
        revision: 'contract-test', sequence: 0, document: { schemaVersion: 1, profiles: {} },
        status: 'ready', error: null, usingDefaults: true,
      });
    },
  };
}
