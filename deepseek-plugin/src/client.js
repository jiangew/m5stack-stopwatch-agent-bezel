import { planAction } from './dom-adapter.js';

const inject = ['shortcuts', 'slots', 'configForms', 'layout', 'sessions', 'workspaces'];
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
  try { console.error(message); } catch { /* Logging must not break host boot/disposal. */ }
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
      try { releases.pop()(); } catch { failed = true; }
    }
    if (failed) diagnostic(RELEASE_FAILURE);
  };
  const plan = (context, action) => {
    if (disposed) return null;
    if (pending) {
      const { element, kind, owner, count } = pending;
      const acknowledged = !element.isConnected || (kind === 'expand'
        ? element.getAttribute('aria-expanded') === 'true' || owner.querySelectorAll('[data-row-key]').length !== count
        : element.getAttribute('aria-selected') === 'true');
      if (!acknowledged) return null;
      if (kind === 'thread' && element.isConnected) {
        const bodies = document.querySelectorAll('[data-conversation-content]');
        if (bodies.length !== 1 || bodies[0].getAttribute('data-conversation-session') !== element.getAttribute('data-row-key').slice(8) || bodies[0].getAttribute('data-content-phase') === 'settling') return null;
      }
      pending = null;
    }
    try { return planAction(document, context, factsFrom(ctx), action); }
    catch { return null; }
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
          if (!initial) return { status: 'blocked', reason: 'AgentBezel: focused, unambiguous ready main view required (or list boundary).' };
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
  } catch {
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
  } catch {
    // Also contain effect setup errors, including errors after its callback ran.
    dispose?.();
    diagnostic(REGISTRATION_FAILURE);
  }
}
export { inject, apply, registerCommands, factsFrom };
