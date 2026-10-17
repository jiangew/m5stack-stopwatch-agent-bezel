// Independent Host plugin. Observes committed audit events; never owns an approval waterfall.
import { randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import { isAbsolute } from 'node:path';

const id = value => typeof value === 'string' && value.length > 0 && Buffer.byteLength(value) <= 256 && !value.includes('\0');
const key = (session, request) => JSON.stringify([session, request]);
const outcome = { 'allowed-once': 'allowed', rejected: 'declined', cancelled: 'cancelled' };

export class AuditObserver {
  constructor(ctx, send, now = Date.now) {
    this.ctx = ctx; this.send = send; this.now = now;
    this.turns = new Map(); this.pending = new Map(); this.inputs = new Map();
  }
  root(session) {
    return this.ctx.agents.roots().find(agent => agent.session === session && agent.id === session.id);
  }
  frame(sessionId, runId, requestId, kind, title, detail, previous = null, resolution = null) {
    const createdAt = Math.max(this.now(), previous ? previous.createdAt + 1 : 0);
    const event = { v: 1, eventId: randomUUID(), source: 'deepseek', sessionId, runId, requestId,
      revision: 1, createdAt, leaseDeadline: createdAt + 15000, kind, title, model: '', detail,
      state: resolution ? 'resolved' : 'pending', canDecide: false };
    if (resolution && outcome[resolution]) event.outcome = outcome[resolution];
    return event;
  }
  observe(session, event) {
    if (!session || !id(session.id) || !this.root(session) || !event || !Number.isSafeInteger(event.seq)) return;
    this.syncInputs(session);
    const data = event.data;
    if (!data || typeof data !== 'object') return;
    if (event.type === 'turn/start') {
      if (Number.isSafeInteger(data.turn) && data.turn > 0) this.turns.set(session.id, String(data.turn));
      return;
    }
    if (event.type === 'turn/end') {
      if (!Number.isSafeInteger(data.turn) || data.turn <= 0) return;
      const reason = data.reason?.kind;
      if (!['completed', 'error', 'aborted', 'blocked', 'max-tokens'].includes(reason)) return;
      const detail = reason === 'completed' ? 'Turn completed' : reason === 'aborted' ? 'Turn interrupted' : reason === 'error' ? 'Turn failed' : 'Turn stopped';
      for (const [identity, entry] of this.pending) {
        const p = entry.record;
        if (p.sessionId !== session.id || p.runId !== String(data.turn)) continue;
        this.pending.delete(identity);
        this.send(this.frame(p.sessionId, p.runId, p.requestId, p.kind, p.title, p.detail, p, 'cleared'));
      }
      this.send(this.frame(session.id, String(data.turn), 'turn-complete', reason === 'completed' ? 'done' : 'failed', 'DeepSeek task', detail));
      this.turns.delete(session.id);
      return;
    }
    if (event.type === 'approval/asked') {
      const run = this.turns.get(session.id);
      if (!run || !id(data.id) || this.pending.size >= 64 || this.pending.has(key(session.id, data.id))) return;
      const record = this.frame(session.id, run, data.id, 'approval', 'DeepSeek approval', 'Open on Mac: native approval pending');
      this.pending.set(key(session.id, data.id), { session, record });
      this.send(record);
    } else if (event.type === 'approval/decided') {
      const found = this.pending.get(key(session.id, data.id));
      if (!found || !['allowed-once', 'rejected', 'cancelled', 'unavailable'].includes(data.outcome)) return;
      this.pending.delete(key(session.id, data.id));
      const p = found.record;
      this.send(this.frame(p.sessionId, p.runId, p.requestId, p.kind, p.title, p.detail, p, data.outcome));
    }
  }
  syncInputs(session) {
    let questions;
    try { questions = this.ctx.sessionProjections?.stateOf(session, 'userQuestions')?.questions; }
    catch { return; } // Optional projection unavailable: other native events remain usable.
    if (!questions || !Array.isArray(questions.active) || !Array.isArray(questions.settled)) return;
    const run = this.turns.get(session.id);
    for (const question of questions.active) {
      const identity = key(session.id, question.callId);
      if (!run || !id(question.callId) || this.inputs.has(identity) || this.inputs.size >= 64) continue;
      const record = this.frame(session.id, run, question.callId, 'input', 'DeepSeek input', 'Open on Mac: native question pending');
      this.inputs.set(identity, { session, record }); this.send(record);
    }
    for (const [identity, entry] of this.inputs) {
      if (entry.session !== session || questions.active.some(x => x.callId === entry.record.requestId)) continue;
      const p = entry.record;
      const settled = questions.settled.some(x => x.callId === p.requestId && Array.isArray(x.answers) && x.answers.length > 0);
      const record = this.frame(p.sessionId, p.runId, p.requestId, p.kind, p.title, p.detail, p, 'cleared');
      if (settled) record.outcome = 'answered';
      this.inputs.delete(identity); this.send(record);
    }
  }
  heartbeat() {
    for (const session of new Set([...this.inputs.values()].map(x => x.session))) {
      if (this.root(session)) this.syncInputs(session);
    }
    for (const [identity, entry] of this.pending) {
      if (!this.root(entry.session)) { this.pending.delete(identity); continue; }
      const p = entry.record;
      entry.record = this.frame(p.sessionId, p.runId, p.requestId, p.kind, p.title, p.detail, p);
      this.send(entry.record);
    }
  }
}

export const inject = ['agents', 'sessionProjections'];
export function apply(ctx, config = {}) {
  if (!isAbsolute(config.directory ?? '') || !isAbsolute(config.relayScript ?? ''))
    throw new Error('absolute private directory and relayScript are required');
  const process = spawn(config.python ?? 'python3', [config.relayScript, '--directory', config.directory],
    { stdio: ['pipe', 'ignore', 'ignore'] });
  let failed = false;
  process.on('error', () => { failed = true; ctx.logger?.warn('Stopwatch adapter unavailable'); });
  process.on('exit', () => { failed = true; });
  process.stdin.on('error', () => { failed = true; });
  const observer = new AuditObserver(ctx, record => {
    if (failed || process.stdin.writableLength > 65536) return;
    const payload = JSON.stringify(record) + '\n';
    if (Buffer.byteLength(payload) <= 8193) process.stdin.write(payload);
  });
  let timer;
  const cleanup = () => { clearInterval(timer); process.stdin.end(); process.kill(); };
  try {
    ctx.effect(() => cleanup, 'Stopwatch notification observer');
    ctx.on('session/event', (session, event) => observer.observe(session, event), { global: true });
    timer = setInterval(() => observer.heartbeat(), 5000);
    timer.unref();
  } catch (error) { cleanup(); throw error; }
}
