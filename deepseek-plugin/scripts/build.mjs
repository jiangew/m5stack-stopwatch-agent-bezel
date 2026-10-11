import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';
import vm from 'node:vm';

const root = fileURLToPath(new URL('../', import.meta.url));
const require = createRequire(import.meta.url);
// No downloads. Pin output to the locally inspected compiler version.
const candidates = [process.env.DSH_PLUGIN_TYPESCRIPT, 'typescript', '/opt/homebrew/lib/node_modules/typescript', '/usr/local/lib/node_modules/typescript'].filter(Boolean);
let ts;
for (const candidate of candidates) {
  try { ts = require(candidate); break; } catch {}
}
if (!ts) throw new Error('Local TypeScript 5.9.2 is required for rebuild; set DSH_PLUGIN_TYPESCRIPT to its package directory. No dependency is downloaded.');
if (ts.version !== '5.9.2') throw new Error(`Reproducible build requires TypeScript 5.9.2, found ${ts.version}`);
const manifest = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
const names = ['dom-adapter', 'client'];
const factories = names.map(name => {
  const source = readFileSync(resolve(root, `src/${name}.js`), 'utf8');
  const result = ts.transpileModule(source, {
    fileName: `${name}.js`, reportDiagnostics: true,
    compilerOptions: { allowJs: true, target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS, newLine: ts.NewLineKind.LineFeed, removeComments: false },
  });
  if (result.diagnostics?.some(d => d.category === ts.DiagnosticCategory.Error)) throw new Error(`Compile diagnostics in ${name}`);
  new vm.Script(result.outputText);
  return `${JSON.stringify(`./${name}.js`)}: function(module, exports, require) {\n${result.outputText}\n}`;
});
const bundle = `// Generated with TypeScript ${ts.version}; run node scripts/build.mjs.\nwindow.__ModuleLoader__.load({\n  id: ${JSON.stringify(manifest.name)},\n  factory: function() {\n    const factories = {\n${factories.join(',\n')}\n    };\n    const cache = Object.create(null);\n    function require(id) {\n      if (cache[id]) return cache[id].exports;\n      if (!Object.hasOwn(factories, id)) throw new Error('Unexpected bundled import');\n      const module = { exports: {} };\n      cache[id] = module;\n      factories[id](module, module.exports, require);\n      return module.exports;\n    }\n    return require('./client.js');\n  }\n});\n`;
new vm.Script(bundle);
const outputs = { 'lib/client.js': bundle, 'lib/index.js': readFileSync(resolve(root, 'src/index.js'), 'utf8') };
for (const [relative, content] of Object.entries(outputs)) {
  const path = resolve(root, relative);
  if (process.argv.includes('--check')) {
    if (!existsSync(path) || readFileSync(path, 'utf8') !== content) throw new Error(`Stale generated artifact: ${relative}`);
  } else {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, content);
  }
}
console.log(process.argv.includes('--check') ? 'Generated artifacts match sources.' : 'Built host ESM and lazy-CJS browser factory (not raw ESM / System.register).');
