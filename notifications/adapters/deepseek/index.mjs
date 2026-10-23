// Independent Host plugin. Native ownership requires explicit patched-protocol opt-in.
export { ApprovalOwner } from './approval.mjs';
import { ApprovalOwner } from './approval.mjs';
import { randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import { isAbsolute } from 'node:path';
import { metadata, visibleReply, fit } from './content.mjs';

const id = value => typeof value === 'string' && value.length > 0 && Buffer.byteLength(value) <= 256 && !value.includes('\0');
const key = (session, request) => JSON.stringify([session, request]);
const outcome = { 'allowed-once': 'allowed', rejected: 'declined', cancelled: 'cancelled' };

export class AuditObserver {
  constructor(ctx, send, now = Date.now, { richContent = false } = {}) {
    this.ctx = ctx; this.send = send; this.now = now;
    this.richContent = richContent; this.replies = new Map();
    this.turns = new Map(); this.pending = new Map(); this.inputs = new Map();
  }
  root(session) {
    return this.ctx.agents.roots().find(agent => agent.session === session && agent.id === session.id);
  }
  frame(sessionId, runId, requestId, kind, title, detail, previous = null, resolution = null) {
    const createdAt = Math.max(this.now(), previous ? previous.createdAt + 1 : 0);
    const event = { v: 1, eventId: randomUUID(), source: 'deepseek', sessionId, runId, requestId,
      revision: previous?.revision ?? 1, createdAt, leaseDeadline: createdAt + 15000, kind, title, model: '', detail,
      state: resolution ? 'resolved' : 'pending', canDecide: resolution ? false : (previous?.canDecide ?? false) };
    if (resolution && outcome[resolution]) event.outcome = outcome[resolution];
    if (this.richContent) {
      if (previous) {
        event.title = previous.title; event.project = previous.project;
        event.excerpted = previous.excerpted ?? false;
      } else {
        const session = this.ctx.agents.roots().find(agent => agent.id === sessionId && agent.session.id === sessionId)?.session;
        if (session) Object.assign(event, metadata(this.ctx, session));
        event.excerpted = false;
      }
    }
    return this.richContent ? fit(event) : event;
  }
  observe(session, event) {
    if (!session || !id(session.id) || !this.root(session) || !event || !Number.isSafeInteger(event.seq)) return;
    this.syncInputs(session);
    const data = event.data;
    if (!data || typeof data !== 'object') return;
    if (event.type === 'turn/start') {
      if (Number.isSafeInteger(data.turn) && data.turn > 0 && (this.turns.has(session.id) || this.turns.size < 64)) {
        this.turns.set(session.id, String(data.turn)); this.replies.delete(session.id);
      }
      return;
    }
    if (this.richContent && event.type === 'assistant/message') {
      if (this.turns.get(session.id) === String(data.turn)) {
        const reply = visibleReply(data.message);
        // A tool-bearing step supersedes earlier visible text; never reuse it as the final reply.
        if (reply) this.replies.set(session.id, reply); else this.replies.delete(session.id);
      }
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
      const record = this.frame(session.id, String(data.turn), 'turn-complete', reason === 'completed' ? 'done' : 'failed', 'DeepSeek task', detail);
      if (this.richContent) {
        const reply = this.turns.get(session.id) === String(data.turn) && reason === 'completed' ? this.replies.get(session.id) : null;
        record.detail = reply?.detail ?? (reason === 'completed' ? 'Reply available on Mac' : detail);
        record.excerpted = reply?.excerpted ?? false;
        record.state = 'resolved'; record.terminalReason = reason;
        fit(record);
      }
      this.send(record);
      if (this.turns.get(session.id)===String(data.turn)) { this.turns.delete(session.id); this.replies.delete(session.id); }
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
    for (const sessionId of this.turns.keys()) {
      if (!this.ctx.agents.roots().some(agent => agent.id === sessionId && agent.session.id === sessionId)) {
        this.turns.delete(sessionId); this.replies.delete(sessionId);
      }
    }
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

const decisionFields = ['v','decisionId','source','sessionId','runId','requestId','revision','action','createdAt','leaseDeadline'];
function validDecision(value) {
  return value && typeof value === 'object' && Object.keys(value).length === decisionFields.length &&
    decisionFields.every(key => Object.hasOwn(value,key)) && value.v === 1 && value.source === 'deepseek' &&
    ['decisionId','sessionId','runId','requestId'].every(key => id(value[key])) &&
    ['revision','createdAt','leaseDeadline'].every(key => Number.isSafeInteger(value[key]) && value[key] >= 0) &&
    value.revision > 0 && ['open','allow_once','decline'].includes(value.action);
}

export const inject = ['agents', 'sessionProjections'];
export function apply(ctx, config = {}) {
  if (!isAbsolute(config.directory ?? '') || !isAbsolute(config.relayScript ?? ''))
    throw new Error('absolute private directory and relayScript are required');
  const native = config.nativeApprovals === true;
  if (native && config.richContent === true) throw new Error('rich content is read-only; native approval ownership must remain disabled');
  const child = spawn(config.python ?? 'python3', [config.relayScript, '--directory', config.directory, ...(native ? ['--native'] : [])],
    { stdio: ['pipe', native ? 'pipe' : 'ignore', 'ignore'] });
  let failed = false, owner, timer, buffered = Buffer.alloc(0);
  const fail = () => {
    if (failed) return;
    failed = true; transport.ready = false; owner?.disable();
    child.stdin.destroy(); child.kill();
    ctx.logger?.warn('Stopwatch adapter unavailable');
  };
  const send = message => {
    const payload = Buffer.from(JSON.stringify(message) + '\n');
    if (failed || child.stdin.destroyed || payload.length > 8193 || child.stdin.writableLength + payload.length > 65536) {
      fail(); return false;
    }
    try { child.stdin.write(payload); return true; } catch {fail();return false;}
  };
  const transport = {
    ready: false,
    send: record => send(native ? {type:'event', event:record} : record),
    open: record => send({type:'open', event:record})
  };
  const observer = new AuditObserver(ctx, record => transport.send(record), Date.now, {richContent: config.richContent === true});
  if (native) owner = new ApprovalOwner(observer, transport);
  child.on('error', fail); child.on('exit', fail); child.stdin.on('error', fail);
  if (native) {
    child.stdout.on('error', fail);
    child.stdout.on('data', data => {
      if (failed) return;
      buffered=Buffer.concat([buffered,data]);
      let newline;
      while ((newline=buffered.indexOf(10))>=0) {
        if (newline>8192) {fail();return;}
        const line=buffered.subarray(0,newline);buffered=buffered.subarray(newline+1);
        try {
          const message=JSON.parse(line.toString('utf8'));
          if (message.type==='ready' && !transport.ready && Object.keys(message).length===2 && message.protocol==='stopwatch.dsh.native-approval.v1') transport.ready=true;
          else if (message.type==='published' && transport.ready && Object.keys(message).length===2 && typeof message.eventId==='string') { /* publication receipt, never native outcome */ }
          else if (message.type==='decision' && transport.ready && Object.keys(message).length===2 && validDecision(message.decision)) owner.decide(message.decision);
          else {fail();return;}
        } catch {fail();return;}
      }
      if (buffered.length>8192) fail();
    });
    child.stdout.on('end', fail);
  }
  const cleanup = () => { clearInterval(timer); owner?.disable(); child.stdin.end(); child.kill(); };
  try {
    ctx.effect(() => cleanup, 'Stopwatch notification observer');
    ctx.on('session/event', (session, event) => {observer.observe(session, event); owner?.heartbeat();}, { global: true });
    if (owner) ctx.on('approval/request', (request,next) => owner.request(request,next), { prepend:true });
    timer = setInterval(() => {owner?.heartbeat();observer.heartbeat();}, 5000);
    timer.unref();
  } catch (error) { cleanup(); throw error; }
}
