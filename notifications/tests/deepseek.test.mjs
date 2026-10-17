import test from 'node:test';
import assert from 'node:assert/strict';
import { AuditObserver, apply } from '../adapters/deepseek/index.mjs';

function fixture() {
  const output = [], session = { id: 'root' }, child = { id: 'child' };
  const rootAgent = { id: 'root', session };
  const ctx = { agents: { roots: () => [rootAgent] } };
  return { output, session, child, ctx, observer: new AuditObserver(ctx, record => output.push(record), () => 1000) };
}
test('root turns only; tool, child and failed/interrupted are not done', () => {
  const f = fixture();
  f.observer.observe(f.session, { type: 'tool/result', seq: 1, data: {} });
  f.observer.observe(f.child, { type: 'turn/end', seq: 2, data: { turn: 1, reason: { kind: 'completed' } } });
  for (const [turn, kind] of [[1, 'completed'], [2, 'error'], [3, 'aborted']])
    f.observer.observe(f.session, { type: 'turn/end', seq: turn + 3, data: { turn, reason: { kind } } });
  assert.deepEqual(f.output.map(x => [x.kind, x.detail]), [
    ['done', 'Turn completed'], ['failed', 'Turn failed'], ['failed', 'Turn interrupted']]);
});
test('native audit identity and outcome, resolution keeps scope and never enables decisions', () => {
  const f = fixture();
  f.observer.observe(f.session, { type: 'turn/start', seq: 1, data: { turn: 7 } });
  f.observer.observe(f.session, { type: 'approval/asked', seq: 2, data: { id: 'native-id', toolName: 'bash', callId: 'tool-id', reason: 'sensitive reason' } });
  f.observer.heartbeat();
  f.observer.observe(f.session, { type: 'approval/decided', seq: 3, data: { id: 'native-id', outcome: 'allowed-once' } });
  assert.equal(f.output.length, 3);
  assert.ok(f.output.every(x => x.requestId === 'native-id' && x.canDecide === false));
  assert.equal(f.output[2].outcome, 'allowed');
  assert.equal(f.output[0].detail, f.output[2].detail);
  assert.ok(!JSON.stringify(f.output).includes('sensitive reason'));
});
test('unknown resolution, missing turn and child audits cannot create a pending record', () => {
  const f = fixture();
  f.observer.observe(f.session, { type: 'approval/asked', seq: 2, data: { id: 'unknown', toolName: 'bash' } });
  f.observer.observe(f.session, { type: 'approval/decided', seq: 3, data: { id: 'unknown', outcome: 'allowed-once' } });
  assert.equal(f.output.length, 0);
});
test('multiple roots are isolated and withdrawal is authoritative cancelled', () => {
  const f = fixture(); const second = { id: 'other' };
  f.ctx.agents.roots = () => [{ id: 'root', session: f.session }, { id: 'other', session: second }];
  for (const session of [f.session, second]) {
    f.observer.observe(session, { type: 'turn/start', seq: 1, data: { turn: 1 } });
    f.observer.observe(session, { type: 'approval/asked', seq: 2, data: { id: 'same-native-id', toolName: 'bash' } });
  }
  f.observer.observe(f.session, { type: 'approval/decided', seq: 3, data: { id: 'same-native-id', outcome: 'cancelled' } });
  assert.equal(f.output.filter(x => x.state === 'resolved').length, 1);
  assert.equal(f.output.at(-1).outcome, 'cancelled');
  assert.equal(f.observer.pending.size, 1);
});
test('native userQuestions projection retains continued inputs until native settlement', () => {
  const f = fixture(); let active = [], settled = [];
  f.ctx.sessionProjections = { stateOf: () => ({ questions: { active, settled } }) };
  f.observer.observe(f.session, { type: 'turn/start', seq: 1, data: { turn: 1 } });
  active = [{ callId: 'question-call', state: 'open', questions: [{ id: 'q', question: 'private question' }] }];
  f.observer.observe(f.session, { type: 'tool/call', seq: 2, data: { turn: 1 } });
  active[0].state = 'continued';
  f.observer.observe(f.session, { type: 'tool/result', seq: 3, data: {} });
  assert.equal(f.output.filter(x => x.kind === 'input' && x.state === 'resolved').length, 0);
  active = []; settled = [{ callId: 'question-call', answers: [{ id: 'q', selected: ['private answer'] }] }];
  f.observer.observe(f.session, { type: 'user/message', seq: 4, data: {} });
  assert.equal(f.output.at(-1).kind, 'input');
  assert.equal(f.output.at(-1).state, 'resolved');
  assert.equal(f.output.at(-1).outcome, 'answered');
  assert.ok(!JSON.stringify(f.output).includes('private'));
});
test('unavailable optional input projection cannot suppress native completion', () => {
  const f = fixture();
  f.ctx.sessionProjections = { stateOf() { throw new Error('projection unavailable'); } };
  f.observer.observe(f.session, { type: 'turn/end', seq: 1, data: { turn: 1, reason: { kind: 'completed' } } });
  assert.equal(f.output[0].kind, 'done');
});
test('terminal native turn withdraws unresolved audit observations without accepted verdict', () => {
  const f = fixture();
  f.observer.observe(f.session, { type: 'turn/start', seq: 1, data: { turn: 1 } });
  f.observer.observe(f.session, { type: 'approval/asked', seq: 2, data: { id: 'native', toolName: 'bash' } });
  f.observer.observe(f.session, { type: 'turn/end', seq: 3, data: { turn: 2, reason: { kind: 'completed' } } });
  assert.equal(f.observer.pending.size, 1);
  f.observer.observe(f.session, { type: 'turn/end', seq: 4, data: { turn: 1, reason: { kind: 'error' } } });
  const cleared = f.output.filter(x => x.kind === 'approval' && x.state === 'resolved');
  assert.equal(cleared.length, 1);
  assert.equal(cleared[0].requestId, 'native');
  assert.ok(!('outcome' in cleared[0]));
  assert.equal(f.observer.pending.size, 0);
});
