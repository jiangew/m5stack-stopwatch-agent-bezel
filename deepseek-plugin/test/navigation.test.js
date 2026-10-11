import test from 'node:test';
import assert from 'node:assert/strict';
import { planAction } from '../src/dom-adapter.js';
import { registerCommands, factsFrom } from '../src/client.js';
import { fixture, e } from './fake-dom.js';
const plan = (f, action = 'nextThread') => planAction(f.document, f.context, f.facts, action);
function pair() { const f = fixture(); f.a = f.session('s1'); f.b = f.session('s2'); return f; }
function mockContext(f) {
  const definitions = new Map();
  const metadata = phase => new Proxy({ phase }, { get(target, key) { if (key !== 'phase') throw new Error(`Forbidden model read ${String(key)}`); return target[key]; } });
  const ctx = {
    shortcuts: { register(command) { definitions.set(command.id, command); return () => definitions.delete(command.id); } },
    layout: { panelInfo: { getSnapshot: () => ({ activePanelId: f.facts.mainPanel }) } },
    sessions: { list: { getSnapshot: () => metadata(f.facts.sessionsPhase) } },
    workspaces: { list: { getSnapshot: () => metadata(f.facts.workspacesPhase) } },
    configForms: { developerTools: { enabled: { getSnapshot: () => f.facts.developerTools } } },
    slots: { entries: name => { assert.equal(name, 'conversation.view'); return f.facts.viewIds.map(id => ({ options: { id, get label() { throw new Error('Forbidden label read'); } } })); } },
  };
  return { ctx, definitions };
}
test('next/previous follow rendered order, no wrap or new session', () => {
  const f = pair(); assert.equal(plan(f).element, f.b);
  assert.equal(plan(f, 'previousThread'), null);
  f.a.attrs['aria-selected'] = 'false'; f.b.attrs['aria-selected'] = 'true'; f.content.attrs['data-conversation-session'] = 's2';
  assert.equal(plan(f), null); assert.equal(plan(f, 'previousThread').element, f.a);
  assert.equal(plan(f, 'center'), null);
});
test('cross project boundary uses actual DOM order including nested projects', () => {
  const f = fixture(); const parent = f.group('p'); const nested = f.group('c', parent.section.append(e('div', { role: 'group' })));
  const child = f.session('child', nested.section); const current = f.session('s1', parent.section);
  const last = f.group('last'); const after = f.session('after', last.section);
  assert.equal(plan(f, 'previousThread').element, child); assert.equal(plan(f).element, after);
  assert.equal(current.clicks, 0);
});
test('collapsed next/previous project prepares only, including nested project', () => {
  const f = fixture(); const before = f.group('before', f.tree, false); const group = f.group('p'); f.session('s1', group.section); const after = f.group('after', f.tree, false);
  assert.equal(plan(f).element, after.row); assert.equal(plan(f).kind, 'expand');
  assert.equal(plan(f, 'previousThread').element, before.row);
  assert.equal(after.row.querySelectorAll('button')[0].clicks, 0);
});
test('expand all owning overflow before adjacent running rows; never collapse', () => {
  const f = fixture(); const g = f.group('p'); f.session('s1', g.section); const b = f.session('s2', g.section); const more = f.overflow('p', g.section);
  assert.equal(plan(f).element, more); assert.equal(plan(f, 'previousThread').element, more);
  more.attrs['aria-expanded'] = 'true'; assert.equal(plan(f).element, b);
});
test('previous across groups reveals predecessor overflow first', () => {
  const f = fixture(); const p = f.group('p'); f.session('p1', p.section); const more = f.overflow('p', p.section);
  const c = f.group('c'); f.session('s1', c.section);
  assert.equal(plan(f, 'previousThread').element, more);
});
test('next across groups reveals candidate group interleaved overflow first', () => {
  const f = fixture(); const p = f.group('p'); f.session('s1', p.section);
  const c = f.group('c'); f.session('c1', c.section); const more = f.overflow('c', c.section);
  assert.equal(plan(f).element, more);
});
test('empty expanded project is safely skipped, boundary is inert', () => {
  const f = fixture(); const p = f.group('p'); f.session('s1', p.section); f.group('empty');
  assert.equal(plan(f), null);
});
test('tabs only switch exactly two known registry entries, arbitrary locale', () => {
  const f = pair(); assert.equal(plan(f, 'toggleView').element, f.trajectory);
  f.chat.attrs['aria-selected'] = 'false'; f.trajectory.attrs['aria-selected'] = 'true';
  assert.equal(plan(f, 'toggleView').element, f.chat);
  f.facts.viewIds = ['trajectory', 'chat']; assert.equal(plan(f, 'toggleView').element, f.chat);
});
for (const [name, mutate] of [
  ['blur', f => f.document.focused = false],
  ['hidden document', f => f.document.visibilityState = 'hidden'],
  ['embedded window', f => f.document.defaultView.top = {}],
  ['terminal context', f => f.context.region = 'terminal'],
  ['modal context', f => f.context.modal = 'other'],
  ['dialog', f => f.document.documentElement.append(e('div', { role: 'dialog' }))],
  ['native dialog', f => f.document.documentElement.append(e('dialog', { open: '' }))],
  ['menu', f => f.document.documentElement.append(e('div', { role: 'menu' }))],
  ['iframe', f => f.document.documentElement.append(e('iframe'))],
  ['second frame', f => f.document.documentElement.append(e('div', { class: '_6Qf49G_frame' }))],
  ['second conversation', f => f.center.append(e('div', { class: 'ST7X_W_root' }))],
  ['embedded content', f => f.center.append(e('div', { 'data-conversation-content': '' }))],
  ['settings main panel', f => f.facts.mainPanel = 'settings'],
  ['sessions pending', f => f.facts.sessionsPhase = 'pending'],
  ['workspaces pending', f => f.facts.workspacesPhase = 'pending'],
  ['settling conversation', f => f.content.attrs['data-content-phase'] = 'settling'],
  ['focus outside app', f => f.document.activeElement = f.document.documentElement],
  ['stale target outside app', f => f.context.target = f.document.documentElement],
  ['dragging', f => f.frame.attrs['data-dragging'] = 'true'],
  ['animating', f => f.frame.attrs['data-animating'] = 'true'],
  ['rightbar fullscreen', f => f.frame.attrs['data-rightbar-fullscreen'] = 'true'],
]) test(`all commands no-op: ${name}`, () => {
  const f = pair(); mutate(f);
  for (const action of ['nextThread', 'previousThread', 'toggleView']) assert.equal(plan(f, action), null);
});
for (const [name, mutate] of [
  ['unknown registry tab', f => f.facts.viewIds = ['chat', 'custom']],
  ['third registry tab', f => f.facts.viewIds.push('custom')],
  ['duplicate registry ids', f => f.facts.viewIds = ['chat', 'chat']],
  ['developer tools disabled', f => f.facts.developerTools = false],
  ['missing trajectory button', f => f.trajectory.remove()],
  ['third button', f => f.tabs.append(e('button', { role: 'tab' }))],
  ['two selected tabs', f => f.trajectory.attrs['aria-selected'] = 'true'],
  ['neither selected', f => f.chat.attrs['aria-selected'] = 'false'],
  ['disabled trajectory', f => f.trajectory.attrs.disabled = ''],
  ['hidden trajectory', f => f.trajectory.style.visibility = 'hidden'],
  ['wrapped buttons', f => { f.trajectory.remove(); f.tabs.append(e('span')).append(f.trajectory); }],
  ['second tablist', f => f.header.append(e('div', { 'data-conversation-tabs': '' }))],
]) test(`toggle fails closed: ${name}`, () => { const f = pair(); mutate(f); assert.equal(plan(f, 'toggleView'), null); });
for (const [name, mutate] of [
  ['duplicate selected', f => f.b.attrs['aria-selected'] = 'true'],
  ['no selected row', f => f.a.attrs['aria-selected'] = 'false'],
  ['selection body mismatch', f => f.content.attrs['data-conversation-session'] = 'other'],
  ['duplicate row key', f => f.b.attrs['data-row-key'] = 'session:s1'],
  ['unknown row', f => f.tree.append(e('div', { 'data-row-key': 'custom:0' }))],
  ['search tree', f => f.tree.attrs.class = '_7514NG_searchTree'],
  ['second tree', f => f.browser.append(e('div', { role: 'tree' }))],
  ['collapsed sidebar', f => f.frame.attrs['data-sidebar-collapsed'] = 'true'],
  ['archived candidate', f => f.b.attrs['aria-description'] = 'redacted'],
  ['disabled candidate', f => f.b.attrs['aria-disabled'] = 'true'],
  ['hidden candidate', f => f.b.attrs.hidden = ''],
  ['changed row class', f => f.b.attrs.class = 'unknown'],
  ['unkeyed treeitem', f => f.tree.append(e('div', { role: 'treeitem' }))],
]) test(`thread fails closed: ${name}`, () => { const f = pair(); mutate(f); assert.equal(plan(f), null); });
test('mismatched overflow owner and collapsed group contents reject', () => {
  const f = fixture(); const g = f.group('g'); f.session('s1', g.section); f.session('s2', g.section); f.overflow('other', g.section);
  assert.equal(plan(f), null);
  const h = fixture(); const p = h.group('g', h.tree, false); h.session('s1', p.section); h.session('s2', p.section); assert.equal(plan(h), null);
});
test('registers exactly approved IDs, six platforms and control (not ctrl)', () => {
  const f = pair(); const { ctx, definitions } = mockContext(f); const dispose = registerCommands(ctx, f.document);
  assert.deepEqual([...definitions.keys()], ['agentbezel.previousThread', 'agentbezel.nextThread', 'agentbezel.toggleView']);
  for (const [id, command] of definitions) {
    assert.deepEqual(command.regions, ['page', 'editable']); assert.deepEqual(command.modals, []);
    assert.deepEqual(Object.keys(command.defaults), ['desktop:macos', 'desktop:windows', 'web:windows']);
    for (const binding of Object.values(command.defaults)) assert.deepEqual(binding.modifiers, ['control', 'alt']);
    for (const profile of ['desktop:linux', 'web:macos', 'web:linux']) assert.equal(command.defaults[profile], undefined);
    assert.ok(id.startsWith('agentbezel.'));
  }
  assert.deepEqual(factsFrom(ctx), f.facts); dispose(); assert.equal(definitions.size, 0);
});
test('run revalidates focus/modal/developerTools/registry/target; no stale clicks', () => {
  for (const mutate of [f => f.document.focused = false, f => f.context.modal = 'other', f => f.facts.sessionsPhase = 'pending', f => f.b.remove()]) {
    const f = pair(); const { ctx, definitions } = mockContext(f); const dispose = registerCommands(ctx, f.document);
    const resolution = definitions.get('agentbezel.nextThread').resolve(f.context); assert.equal(resolution.status, 'handled'); mutate(f); resolution.run(); assert.equal(f.b.clicks, 0); dispose();
  }
  for (const mutate of [f => f.facts.developerTools = false, f => f.facts.viewIds.push('custom')]) {
    const f = pair(); const { ctx, definitions } = mockContext(f); registerCommands(ctx, f.document);
    const r = definitions.get('agentbezel.toggleView').resolve(f.context); mutate(f); r.run(); assert.equal(f.trajectory.clicks, 0);
  }
});
test('unacknowledged thread transition blocks repeated gestures and other commands', () => {
  const f = pair(); const c = f.session('s3'); const { ctx, definitions } = mockContext(f); registerCommands(ctx, f.document);
  const next = definitions.get('agentbezel.nextThread'); next.resolve(f.context).run(); assert.equal(f.b.clicks, 1);
  assert.equal(next.resolve(f.context).status, 'blocked'); assert.equal(definitions.get('agentbezel.toggleView').resolve(f.context).status, 'blocked');
  f.a.attrs['aria-selected'] = 'false'; f.b.attrs['aria-selected'] = 'true';
  assert.equal(next.resolve(f.context).status, 'blocked'); // body has not acknowledged selection
  f.content.attrs['data-conversation-session'] = 's2'; f.content.attrs['data-content-phase'] = 'settling';
  assert.equal(next.resolve(f.context).status, 'blocked');
  f.content.attrs['data-content-phase'] = 'active'; next.resolve(f.context).run(); assert.equal(c.clicks, 1);
});
test('expansion is one click per gesture, pending until actual DOM acknowledgement', () => {
  const f = fixture(); const p = f.group('p'); f.session('s1', p.section); const more = f.overflow('p', p.section);
  const { ctx, definitions } = mockContext(f); registerCommands(ctx, f.document); const next = definitions.get('agentbezel.nextThread');
  next.resolve(f.context).run(); assert.equal(more.clicks, 1); assert.equal(next.resolve(f.context).status, 'blocked');
  more.remove(); const b = f.session('s2', p.section); f.overflow('p', p.section, true);
  next.resolve(f.context).run(); assert.equal(b.clicks, 1); assert.equal(more.clicks, 1);
});
test('page body focus permits commands without requiring editor focus', () => {
  const f = pair(); f.document.activeElement = f.document.body; f.context.target = f.document.body; f.context.region = 'page';
  assert.equal(plan(f).element, f.b); assert.equal(plan(f, 'toggleView').element, f.trajectory);
});
test('disposed previously resolved command cannot click', () => {
  const f = pair(); const { ctx, definitions } = mockContext(f); const dispose = registerCommands(ctx, f.document);
  const resolution = definitions.get('agentbezel.nextThread').resolve(f.context); dispose(); resolution.run(); assert.equal(f.b.clicks, 0);
});
