// Opt-in, bounded native metadata. Never reads a transcript or invokes a model.
import { basename } from 'node:path';
import { homedir } from 'node:os';

export function clip(value, bytes) {
  let result = '', used = 0;
  for (const character of value) {
    const size = Buffer.byteLength(character);
    if (used + size > bytes) break;
    result += character; used += size;
  }
  return result;
}
export function plain(value, bytes) {
  if (typeof value !== 'string') return '';
  // Bound work before formatting; keep only visible text and plain spacing.
  return clip(value, bytes * 4).replace(/[\p{Cc}\p{Cf}]/gu, c => /[\r\n\t]/.test(c) ? ' ' : '')
    .replace(/(?:^|\s)#{1,6}\s+/g, ' ').replace(/\s+/g, ' ').trim();
}
export function metadata(ctx, session) {
  let title = '';
  try { title = clip(plain(ctx.sessionProjections?.stateOf(session, 'title'), 512), 512); } catch { /* optional projection */ }
  const cwd = session.header?.cwd;
  const project = typeof cwd === 'string' && cwd !== '/' && cwd !== homedir()
    ? clip(plain(basename(cwd), 64), 64) : '';
  return { title, project };
}
export function visibleReply(message) {
  if (message?.role !== 'assistant' || !Array.isArray(message.content) || message.content.some(x => x?.type === 'tool-call')) return null;
  let text = '', clipped = false;
  for (const block of message.content) {
    if (block?.type !== 'text' || typeof block.text !== 'string') continue;
    const remaining = 16384 - Buffer.byteLength(text);
    if (remaining <= 0) { clipped = true; break; }
    const part = clip(block.text, remaining);
    text += (text ? ' ' : '') + part;
    clipped ||= part !== block.text;
  }
  const normalized = plain(text, 4096);
  const detail = clip(normalized, 4096);
  return detail ? { detail, excerpted: clipped || detail !== normalized } : null;
}
export function fit(event) {
  // Foundation escapes '/' and the route wrapper is persisted with the event.
  const size = () => { const json = JSON.stringify({ event, storedSession: null }); return Buffer.byteLength(json) + (json.match(/\//g)?.length ?? 0); };
  while (size() > 8192 && event.detail) {
    event.detail = clip(event.detail, Math.max(0, Buffer.byteLength(event.detail) - 128));
    event.excerpted = true;
  }
  return event;
}

export function modelVersion(value) {
  return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:/+\-]{0,127}$/.test(value) ? value : '';
}

export function replyModel(message) {
  if (!Array.isArray(message?.content) || message.content.some(x => x?.type === 'tool-call')) return '';
  let text = '';
  for (const block of message.content) {
    if (block?.type !== 'text' || typeof block.text !== 'string') continue;
    if (text.length + block.text.length > 1024 * 1024) return '';
    text += '\n' + block.text;
  }
  const models = new Set(); let fence = null;
  for (const line of text.split(/\r?\n/)) {
    let stripped = line.trim();const marker = stripped.match(/^(`{3,}|~{3,})(.*)$/);
    if (marker) {
      if (fence === null) fence = marker[1];
      else if (marker[1][0] === fence[0] && marker[1].length >= fence.length && !marker[2].trim()) fence = null;
      continue;
    }
    if (fence || /^(?: {4}|\t)/.test(line)) continue;
    stripped = stripped.replace(/^[-*]\s+/, '');
    const match = stripped.match(/^(?:\*\*|__)?(?:model(?: version| used)?|(?:本次(?:使用的?)?)?模型(?:版本)?)(?:\*\*|__)?\s*[:：]\s*(.+)$/i);
    if (!match) continue;
    let model = match[1].trim();
    for (const wrapper of ['`', '**', '__']) {
      if (model.length > 2 * wrapper.length && model.startsWith(wrapper) && model.endsWith(wrapper)) {model = model.slice(wrapper.length,-wrapper.length);break;}
    }
    if (modelVersion(model)) models.add(model);
  }
  return models.size === 1 ? [...models][0] : '';
}
