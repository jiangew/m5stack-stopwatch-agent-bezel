// Minimal structural DOM fixture. Deliberately throws on all content reads.
class Element {
  constructor(tag = 'div', attrs = {}) {
    this.tagName = tag.toUpperCase(); this.attrs = { ...attrs }; this.children = [];
    this.parentElement = null; this.ownerDocument = null; this.clicks = 0; this.onClick = null;
    this.style = { display: 'block', visibility: 'visible', opacity: '1' };
  }
  get textContent() { throw new Error('Forbidden content read'); }
  get innerText() { throw new Error('Forbidden content read'); }
  get innerHTML() { throw new Error('Forbidden content read'); }
  get value() { throw new Error('Forbidden draft read'); }
  get dataset() { throw new Error('Use allowlisted attributes only'); }
  get isConnected() { return !!this.ownerDocument && (this === this.ownerDocument.documentElement || !!this.parentElement?.isConnected); }
  getAttribute(name) {
    if (!['class', 'role', 'data-row-key', 'data-content-phase', 'data-conversation-session', 'aria-selected', 'aria-expanded', 'aria-disabled', 'type'].includes(name)) throw new Error(`Forbidden attribute read: ${name}`);
    return this.attrs[name] ?? null;
  }
  hasAttribute(name) { return Object.hasOwn(this.attrs, name); }
  setAttribute(name, value) { this.attrs[name] = value; }
  removeAttribute(name) { delete this.attrs[name]; }
  append(...elements) {
    for (const element of elements) {
      element.parentElement = this; this.children.push(element);
      const connect = node => { node.ownerDocument = this.ownerDocument; node.children.forEach(connect); };
      connect(element);
    }
    return elements.at(-1);
  }
  remove() { this.parentElement.children = this.parentElement.children.filter(child => child !== this); this.parentElement = null; }
  matches(selector) {
    return selector.split(',').some(part => {
      let rest = part.trim();
      const tag = rest.match(/^[a-z]+/i)?.[0];
      if (tag) { if (this.tagName !== tag.toUpperCase()) return false; rest = rest.slice(tag.length); }
      while (rest) {
        let match;
        if ((match = rest.match(/^\.([\w-]+)/))) {
          if (!(this.attrs.class ?? '').split(' ').includes(match[1])) return false;
        } else if ((match = rest.match(/^\[([\w-]+)(?:="([^"]*)")?\]/))) {
          if (!this.hasAttribute(match[1]) || (match[2] !== undefined && this.attrs[match[1]] !== match[2])) return false;
        } else throw new Error(`Unsupported fixture selector: ${rest}`);
        rest = rest.slice(match[0].length);
      }
      return true;
    });
  }
  querySelectorAll(selector) {
    return this.children.flatMap(child => [...(child.matches(selector) ? [child] : []), ...child.querySelectorAll(selector)]);
  }
  closest(selector) { for (let node = this; node; node = node.parentElement) if (node.matches(selector)) return node; return null; }
  contains(element) { for (let node = element; node; node = node.parentElement) if (node === this) return true; return false; }
  getClientRects() { return this.style.display === 'none' ? [] : [{}]; }
  click() { this.clicks++; this.onClick?.(); }
}
class Document {
  constructor() {
    this.documentElement = new Element('html'); this.documentElement.ownerDocument = this;
    this.body = this.documentElement.append(new Element('body'));
    this.visibilityState = 'visible'; this.focused = true;
    this.defaultView = { frameElement: null, getComputedStyle: node => node.style };
    this.defaultView.top = this.defaultView;
  }
  querySelectorAll(selector) { return this.documentElement.querySelectorAll(selector); }
  hasFocus() { return this.focused; }
  get localStorage() { throw new Error('Forbidden storage access'); }
}
const e = (tag, attrs) => new Element(tag, attrs);
function fixture() {
  const document = new Document();
  const frame = document.body.append(e('div', { class: '_6Qf49G_frame' }));
  const sidebar = frame.append(e('div', { class: '_6Qf49G_sidebarCol' }));
  const browser = sidebar.append(e('div', { class: '_7514NG_root' }));
  const tree = browser.append(e('div', { class: '_7514NG_list', role: 'tree' }));
  const center = frame.append(e('div', { class: '_6Qf49G_centerCol' }));
  const conversation = center.append(e('div', { class: 'ST7X_W_root', 'data-phase': 'active' }));
  const header = conversation.append(e('header'));
  const tabs = header.append(e('div', { role: 'tablist', 'data-conversation-tabs': '' }));
  const chat = tabs.append(e('button', { role: 'tab', type: 'button', 'aria-selected': 'true' }));
  const trajectory = tabs.append(e('button', { role: 'tab', type: 'button', 'aria-selected': 'false' }));
  const content = conversation.append(e('div', { 'data-conversation-content': '', 'data-content-phase': 'active', 'data-conversation-session': 's1' }));
  const editor = content.append(e('div', { contenteditable: 'true' }));
  document.activeElement = editor;
  const context = { region: 'editable', modal: null, target: editor };
  const facts = { mainPanel: null, sessionsPhase: 'ready', workspacesPhase: 'ready', developerTools: true, viewIds: ['chat', 'trajectory'] };
  function group(id, parent = tree, expanded = true) {
    const section = parent.append(e('div', { class: '_7514NG_groupSection' }));
    const row = section.append(e('div', { class: 'jJkEga_projectRow', role: 'treeitem', 'data-row-key': `workspace:${id}`, 'aria-expanded': String(expanded) }));
    row.append(e('span')).append(e('button', { type: 'button' })); // new-thread action must never receive clicks
    return { section, row };
  }
  function session(id, parent = tree, selected = id === 's1') {
    return parent.append(e('div', { class: 'jJkEga_sessionRow', role: 'treeitem', 'data-row-key': `session:${id}`, 'aria-selected': String(selected) }));
  }
  function overflow(id, parent, expanded = false) {
    return parent.append(e('button', { class: '_7514NG_sessionOverflowButton', type: 'button', 'data-row-key': `overflow:${id}`, 'aria-expanded': String(expanded) }));
  }
  return { document, frame, sidebar, browser, tree, center, conversation, header, tabs, chat, trajectory, content, editor, context, facts, group, session, overflow };
}
export { Element, Document, e, fixture };
