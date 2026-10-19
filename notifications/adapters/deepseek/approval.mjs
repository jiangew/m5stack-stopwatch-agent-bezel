// Opt-in owner for the pinned, body-bound project extension. Native audit remains final.
import { isAbsolute } from 'node:path';
const identity = ['source','sessionId','runId','requestId','revision'];
const exact = (value, keys) => value && Object.getPrototypeOf(value) === Object.prototype &&
  Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value,key));
const ascii = value => typeof value === 'string' && /^[\x20-\x7e]+$/.test(value);
const positive = value => Number.isSafeInteger(value) && value > 0;
const frozen = value => !value || typeof value !== 'object' || (Object.isFrozen(value) && Object.values(value).every(frozen));
const modes = ['read-only','workspace-write','danger-full-access'];
function policy(value, session) {
  return exact(value,['mode','workspaceRoot','sessionId']) && modes.includes(value.mode) &&
    ascii(value.workspaceRoot) && isAbsolute(value.workspaceRoot) && value.sessionId === session;
}
export function renderScope(scope, session) {
  if (!exact(scope,['protocol','implementation','arguments','standingPolicy','execution']) || !frozen(scope) ||
      scope.protocol !== 'stopwatch.dsh.native-approval.v1' || scope.implementation !== 'dsh-tool-bash@0.2.0-rc.2') return null;
  const a=scope.arguments, p=scope.standingPolicy, e=scope.execution;
  if (!exact(a,['command','description','workdir','timeoutMs','sandbox_permissions','justification']) ||
      !exact(e,['command','workdir','timeoutMs','onExpiry','stdoutMaxBytes','sandboxPolicy']) ||
      !['command','description','workdir','justification'].every(k=>ascii(a[k])) ||
      !isAbsolute(a.workdir) || !positive(a.timeoutMs) || !positive(e.stdoutMaxBytes) ||
      !policy(p,session) || !policy(e.sandboxPolicy,session) ||
      e.command!==a.command || e.workdir!==a.workdir || e.timeoutMs!==a.timeoutMs || e.onExpiry!=='kill' ||
      e.sandboxPolicy.mode!==a.sandbox_permissions || e.sandboxPolicy.workspaceRoot!==p.workspaceRoot ||
      modes.indexOf(a.sandbox_permissions)<=modes.indexOf(p.mode)) return null;
  // Never redact credentials and then claim that the resulting display is complete.
  if (/authorization|bearer\s|(?:api[ _-]?key|token|secret|password)\s*[:=]/i.test(JSON.stringify(a))) return null;
  const displayed={cmd:a.command,desc:a.description,cwd:a.workdir,ms:a.timeoutMs,mode:a.sandbox_permissions,why:a.justification};
  const detail=JSON.stringify(['bash',displayed,{from:p.mode,root:p.workspaceRoot,expiry:e.onExpiry,out:e.stdoutMaxBytes}]);
  return detail.length<=192 && ascii(detail) ? detail : null;
}
export class ApprovalOwner {
  constructor(observer, transport, now=Date.now) {
    this.observer=observer; this.transport=transport; this.now=now; this.entries=new Map(); this.disabled=false;
  }
  request(req,next) {
    const session=req.agent?.session, pending=this.observer.pending.get(JSON.stringify([session?.id,req.requestId]));
    const detail=renderScope(req.nativeApprovalScope,session?.id);
    if (this.disabled || !this.transport.ready || !Object.isFrozen(req) || !session ||
        this.observer.root(session)!==req.agent || req.agent.id!==session.id || req.signal?.aborted ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(req.requestId??'') ||
        !pending || this.observer.turns.get(session.id)!==pending.record.runId || !detail ||
        this.entries.size>=64 || this.entries.has(req.requestId)) return next();
    const entry={req,next,pending,scope:req.nativeApprovalScope,detail,start:this.now(),status:'owned'};
    const promise=new Promise((resolve,reject)=>{entry.resolve=resolve;entry.reject=reject;});
    this.entries.set(req.requestId,entry);
    pending.record={...this.observer.frame(session.id,pending.record.runId,req.requestId,'approval','DeepSeek approval',detail,pending.record),
      revision:pending.record.revision+1,canDecide:true};
    entry.abort=()=>this.release(entry,false,'cancelled');
    req.signal?.addEventListener('abort',entry.abort,{once:true});
    if (!this.publish(entry)) this.disable();
    return promise;
  }
  publish(entry) {
    try { return this.transport.send(entry.pending.record)!==false; } catch { return false; }
  }
  current(entry) {
    const {req,pending}=entry, session=req.agent.session;
    return session && pending.session===session && this.observer.pending.get(JSON.stringify([session.id,req.requestId]))===pending &&
      this.observer.root(session)===req.agent && req.agent.id===session.id &&
      this.observer.turns.get(session.id)===pending.record.runId && !req.signal?.aborted &&
      req.nativeApprovalScope===entry.scope && renderScope(entry.scope,session.id)===entry.detail;
  }
  release(entry,delegate=true,result) {
    if (entry.status!=='owned') return;
    entry.status='released';this.entries.delete(entry.req.requestId);
    entry.req.signal?.removeEventListener('abort',entry.abort);
    entry.pending.record={...entry.pending.record,canDecide:false,createdAt:Math.max(this.now(),entry.pending.record.createdAt+1)};
    if (this.observer.pending.get(JSON.stringify([entry.pending.session.id,entry.req.requestId]))===entry.pending) this.publish(entry);
    if (delegate) { try {entry.resolve(entry.next());}catch(error){entry.reject(error);} }
    else entry.resolve(result);
  }
  decide(decision) {
    const entry=this.entries.get(decision.requestId);
    if (!entry || entry.status!=='owned') return false;
    const record=entry.pending.record,now=this.now();
    if (!this.current(entry) || !this.transport.ready || now>=entry.start+60000 || now>=record.leaseDeadline) {
      this.release(entry);return false;
    }
    if (!identity.every(k=>decision[k]===record[k]) || !['open','allow_once','decline'].includes(decision.action) ||
        !Number.isSafeInteger(decision.createdAt) || !Number.isSafeInteger(decision.leaseDeadline) ||
        decision.createdAt>now || now>=decision.leaseDeadline || decision.leaseDeadline>decision.createdAt+15000) return false;
    if (decision.action==='open') {
      this.release(entry);
      try {this.transport.open(entry.pending.record);}catch{this.disable();}
    } else {
      entry.status='submitted';entry.req.signal?.removeEventListener('abort',entry.abort);
      entry.pending.record={...record,canDecide:false,createdAt:Math.max(now,record.createdAt+1)};
      if (!this.publish(entry)) {entry.status='owned';this.disable();return false;}
      entry.resolve(decision.action==='allow_once'?'allowed-once':'rejected');
    }
    return true;
  }
  heartbeat() {
    for (const entry of this.entries.values()) {
      if (entry.status==='submitted') {if(!this.current(entry))this.entries.delete(entry.req.requestId);continue;}
      if (!this.current(entry) || !this.transport.ready || this.now()>=entry.start+60000 || this.now()>=entry.pending.record.leaseDeadline) this.release(entry);
    }
  }
  disable() {this.disabled=true;for(const entry of this.entries.values())this.release(entry);}
}
