// Generated with TypeScript 5.9.2; run node scripts/build.mjs.
window.__ModuleLoader__.load({
  id: "dsh-agentbezel-navigation",
  factory: function() {
    const factories = {
"./dom-adapter.js": function(module, exports, require) {
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SELECTORS = void 0;
exports.planAction = planAction;
// DOM contract pinned to inspected DSH 0.2.0-rc.2. No labels or user content.
const SELECTORS = Object.freeze({
    frame: '._6Qf49G_frame', sidebar: '._6Qf49G_sidebarCol', center: '._6Qf49G_centerCol',
    browser: '._7514NG_root', group: '._7514NG_groupSection',
    tree: '[role="tree"]', row: '[data-row-key]',
    conversation: '.ST7X_W_root', tabs: '[data-conversation-tabs]',
    content: '[data-conversation-content]',
    obstruction: '[role="dialog"], [role="alertdialog"], [aria-modal="true"], dialog[open], [role="menu"]',
});
exports.SELECTORS = SELECTORS;
const all = (node, selector) => Array.from(node.querySelectorAll(selector));
const one = (node, selector) => {
    const matches = all(node, selector);
    return matches.length === 1 ? matches[0] : null;
};
const attr = (node, name) => node.getAttribute(name);
const bool = (node, name) => ['true', 'false'].includes(attr(node, name));
function visible(node) {
    if (!node?.isConnected || node.closest('[hidden], [inert], [aria-hidden="true"]'))
        return false;
    const view = node.ownerDocument.defaultView;
    for (let current = node; current; current = current.parentElement) {
        const style = view.getComputedStyle(current);
        if (style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse' || style.opacity === '0')
            return false;
    }
    return node.getClientRects().length > 0;
}
function enabled(node) {
    return visible(node) && !node.hasAttribute('disabled') && attr(node, 'aria-disabled') !== 'true';
}
function baseScope(document, context, facts) {
    if (!document || document.visibilityState !== 'visible' || !document.hasFocus())
        return null;
    const view = document.defaultView;
    if (!view || view.top !== view || view.frameElement !== null)
        return null;
    if (!context || context.modal !== null || !['page', 'editable'].includes(context.region))
        return null;
    if (all(document, SELECTORS.obstruction).length || all(document, 'iframe').some(visible))
        return null;
    if (facts.mainPanel !== null || facts.sessionsPhase !== 'ready' || facts.workspacesPhase !== 'ready')
        return null;
    const frame = one(document, SELECTORS.frame);
    if (!frame || !visible(frame) || frame.hasAttribute('data-dragging') || frame.hasAttribute('data-animating') || frame.hasAttribute('data-rightbar-fullscreen'))
        return null;
    const sidebar = one(frame, SELECTORS.sidebar);
    const center = one(frame, SELECTORS.center);
    const conversation = one(document, SELECTORS.conversation);
    const content = one(document, SELECTORS.content);
    if (!sidebar || !center || !conversation || !content || !center.contains(conversation) || !conversation.contains(content) || !visible(conversation))
        return null;
    const phase = attr(content, 'data-content-phase');
    if (!['active', 'hero'].includes(phase))
        return null;
    const target = document.activeElement;
    const inPage = node => node === document.body || frame.contains(node);
    if (!target || !inPage(target) || target.closest('.xterm, [inert]'))
        return null;
    if (context.target && (!inPage(context.target) || context.target.closest('.xterm, [inert]')))
        return null;
    return { frame, sidebar, center, conversation, content };
}
function treeScope(scope) {
    if (scope.frame.hasAttribute('data-sidebar-collapsed'))
        return null;
    const browser = one(scope.sidebar, SELECTORS.browser);
    const tree = browser && one(browser, SELECTORS.tree);
    if (!tree || !visible(tree) || !tree.matches('._7514NG_list, ._7514NG_flatList'))
        return null;
    const rows = all(tree, SELECTORS.row);
    if (!rows.length || all(tree, '[role="treeitem"]').length !== rows.filter(row => attr(row, 'role') === 'treeitem').length)
        return null;
    const keys = new Set();
    const tokens = [];
    for (const element of rows) {
        const key = attr(element, 'data-row-key');
        if (keys.has(key) || !visible(element) || element.closest(SELECTORS.tree) !== tree)
            return null;
        keys.add(key);
        const group = element.closest(SELECTORS.group);
        let kind;
        if (key.startsWith('session:') && key.length > 8 && element.matches('div.jJkEga_sessionRow[role="treeitem"]') && bool(element, 'aria-selected'))
            kind = 'session';
        else if (key.startsWith('workspace:') && element.matches('div.jJkEga_projectRow[role="treeitem"]') && bool(element, 'aria-expanded') && group)
            kind = 'workspace';
        else if (key.startsWith('overflow:') && element.matches('button._7514NG_sessionOverflowButton') && attr(element, 'type') === 'button' && bool(element, 'aria-expanded') && group)
            kind = 'overflow';
        else
            return null;
        if (!enabled(element))
            return null;
        tokens.push({ kind, element, group, key });
    }
    // Every grouped row must have exactly one matching project owner. No guessed nesting.
    for (const group of all(tree, SELECTORS.group)) {
        const owned = tokens.filter(token => token.group === group);
        const headers = owned.filter(token => token.kind === 'workspace');
        const overflow = owned.filter(token => token.kind === 'overflow');
        if (headers.length !== 1 || overflow.length > 1 || (overflow.length && overflow[0].key.slice(9) !== headers[0].key.slice(10)))
            return null;
        if (attr(headers[0].element, 'aria-expanded') === 'false' && (owned.length !== 1 || all(group, SELECTORS.group).length))
            return null;
    }
    if (tokens.some(token => token.kind === 'session' && token.group === null) && tokens.some(token => token.group !== null))
        return null;
    const selected = tokens.filter(token => token.kind === 'session' && attr(token.element, 'aria-selected') === 'true');
    if (selected.length !== 1 || selected[0].key.slice(8) !== attr(scope.content, 'data-conversation-session'))
        return null;
    return { tree, tokens, selected: selected[0] };
}
function preparation(tree, group) {
    // Hidden idle rows can interleave with visible running rows: fully reveal the
    // owning group BEFORE treating two visible sessions as adjacent.
    return tree.tokens.find(token => token.group === group && token.kind === 'overflow' && attr(token.element, 'aria-expanded') === 'false');
}
function threadPlan(scope, direction) {
    const tree = treeScope(scope);
    if (!tree)
        return null;
    const pending = preparation(tree, tree.selected.group);
    if (pending)
        return { element: pending.element, kind: 'expand' };
    const index = tree.tokens.indexOf(tree.selected);
    for (let i = index + direction; i >= 0 && i < tree.tokens.length; i += direction) {
        const token = tree.tokens[i];
        if (token.kind === 'workspace') {
            if (attr(token.element, 'aria-expanded') === 'false')
                return { element: token.element, kind: 'expand' };
            continue;
        }
        if (token.kind === 'overflow') {
            if (attr(token.element, 'aria-expanded') === 'false')
                return { element: token.element, kind: 'expand' };
            continue; // true means this button would collapse: never click it.
        }
        const reveal = preparation(tree, token.group);
        if (reveal)
            return { element: reveal.element, kind: 'expand' };
        // Archived rows stay in sidebar order but are not openable; do not jump them.
        if (token.element.hasAttribute('aria-description') || token.element.matches('.jJkEga_archived'))
            return null;
        return { element: token.element, kind: 'thread' };
    }
    return null; // no wrap
}
function viewPlan(scope, facts) {
    if (facts.developerTools !== true || facts.viewIds.length !== 2 || new Set(facts.viewIds).size !== 2 || !facts.viewIds.includes('chat') || !facts.viewIds.includes('trajectory'))
        return null;
    const tabs = one(scope.conversation, SELECTORS.tabs);
    if (!tabs || attr(tabs, 'role') !== 'tablist' || !visible(tabs))
        return null;
    const buttons = Array.from(tabs.children);
    if (buttons.length !== 2 || all(tabs, '[role="tab"]').length !== 2 || buttons.some(button => !button.matches('button[role="tab"]') || attr(button, 'type') !== 'button' || !bool(button, 'aria-selected') || !enabled(button)))
        return null;
    const selected = buttons.filter(button => attr(button, 'aria-selected') === 'true');
    if (selected.length !== 1)
        return null;
    // Rendered order is the registry order. Labels are never inspected.
    return { element: buttons[1 - buttons.indexOf(selected[0])], kind: 'view' };
}
function planAction(document, context, facts, action) {
    try {
        const scope = baseScope(document, context, facts);
        if (!scope)
            return null;
        if (action === 'previousThread')
            return threadPlan(scope, -1);
        if (action === 'nextThread')
            return threadPlan(scope, 1);
        if (action === 'toggleView')
            return viewPlan(scope, facts);
        return null;
    }
    catch {
        return null;
    } // incompatible DOM/service shape is always inert
}

},
"./client.js": function(module, exports, require) {
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.inject = void 0;
exports.apply = apply;
exports.registerCommands = registerCommands;
exports.factsFrom = factsFrom;
const dom_adapter_js_1 = require("./dom-adapter.js");
const inject = ['shortcuts', 'slots', 'configForms', 'layout', 'sessions', 'workspaces'];
exports.inject = inject;
const COMMANDS = Object.freeze([
    ['previousThread', 'Previous existing thread', 'ArrowUp'],
    ['nextThread', 'Next existing thread', 'ArrowDown'],
    ['toggleView', 'Toggle Chat / Trajectory', 'ArrowRight'],
]);
function factsFrom(ctx) {
    // Only readiness booleans/phase and registry IDs; never session/workspace data.
    return {
        mainPanel: ctx.layout.panelInfo.getSnapshot().activePanelId,
        sessionsPhase: ctx.sessions.list.getSnapshot().phase,
        workspacesPhase: ctx.workspaces.list.getSnapshot().phase,
        developerTools: ctx.configForms.developerTools.enabled.getSnapshot(),
        viewIds: ctx.slots.entries('conversation.view').map(entry => entry.options.id),
    };
}
// Fixed diagnostics only: never include host exceptions, IDs, or user data.
const REGISTRATION_FAILURE = 'AgentBezel: navigation commands disabled because shortcut registration failed; check plugin/host compatibility.';
const RELEASE_FAILURE = 'AgentBezel: shortcut cleanup failed; navigation actions disabled; reload or disable this plugin.';
function diagnostic(message) {
    try {
        console.error(message);
    }
    catch { /* Logging must not break host boot/disposal. */ }
}
function registerCommands(ctx, document) {
    let disposed = false;
    let pending = null;
    const releases = [];
    const dispose = () => {
        disposed = true;
        pending = null;
        let failed = false;
        while (releases.length) {
            try {
                releases.pop()();
            }
            catch {
                failed = true;
            }
        }
        if (failed)
            diagnostic(RELEASE_FAILURE);
    };
    const plan = (context, action) => {
        if (disposed)
            return null;
        if (pending) {
            const { element, kind, owner, count } = pending;
            const acknowledged = !element.isConnected || (kind === 'expand'
                ? element.getAttribute('aria-expanded') === 'true' || owner.querySelectorAll('[data-row-key]').length !== count
                : element.getAttribute('aria-selected') === 'true');
            if (!acknowledged)
                return null;
            if (kind === 'thread' && element.isConnected) {
                const bodies = document.querySelectorAll('[data-conversation-content]');
                if (bodies.length !== 1 || bodies[0].getAttribute('data-conversation-session') !== element.getAttribute('data-row-key').slice(8) || bodies[0].getAttribute('data-content-phase') === 'settling')
                    return null;
            }
            pending = null;
        }
        try {
            return (0, dom_adapter_js_1.planAction)(document, context, factsFrom(ctx), action);
        }
        catch {
            return null;
        }
    };
    try {
        for (const [action, label, code] of COMMANDS) {
            // Real ShortcutRegistry.register validates ALL profiles, not only this device.
            // Omit unsupported profiles: this host accepts undefined, NOT null defaults.
            const defaults = Object.fromEntries(['desktop:macos', 'desktop:windows', 'web:windows'].map(profile => [
                profile, { code, modifiers: ['control', 'alt'] },
            ]));
            releases.push(ctx.shortcuts.register({
                id: `agentbezel.${action}`, label: () => label, aliases: [], defaults,
                regions: ['page', 'editable'], modals: [],
                resolve(context) {
                    const initial = plan(context, action);
                    if (!initial)
                        return { status: 'blocked', reason: 'AgentBezel: focused, unambiguous ready main view required (or list boundary).' };
                    return {
                        status: 'handled',
                        run() {
                            // Re-read ALL guards and recompute the target immediately before click.
                            // A changed row/tab target invalidates the action instead of retargeting.
                            const current = plan(context, action);
                            if (current && current.element === initial.element && current.kind === initial.kind) {
                                const owner = current.element.closest('[role="tree"]') ?? current.element.parentElement;
                                pending = { ...current, owner, count: owner.querySelectorAll('[data-row-key]').length };
                                current.element.click();
                            }
                        },
                    };
                },
            }));
        }
    }
    catch {
        dispose();
        diagnostic(REGISTRATION_FAILURE);
    }
    return dispose;
}
function apply(ctx) {
    let dispose;
    try {
        ctx.effect(() => {
            dispose = registerCommands(ctx, globalThis.document);
            return dispose;
        }, 'agentbezel: three navigation commands');
    }
    catch {
        // Also contain effect setup errors, including errors after its callback ran.
        dispose?.();
        diagnostic(REGISTRATION_FAILURE);
    }
}

}
    };
    const cache = Object.create(null);
    function require(id) {
      if (cache[id]) return cache[id].exports;
      if (!Object.hasOwn(factories, id)) throw new Error('Unexpected bundled import');
      const module = { exports: {} };
      cache[id] = module;
      factories[id](module, module.exports, require);
      return module.exports;
    }
    return require('./client.js');
  }
});
