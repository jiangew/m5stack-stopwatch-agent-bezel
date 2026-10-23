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
