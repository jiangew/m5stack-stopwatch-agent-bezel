// Project-owned policy floor; native request() rechecks this before its committed audit.
import {ApprovalService} from './approval.js';
import {symbols} from "@deepseek-ai/cordis";
export default class CanaryApprovalService extends ApprovalService {
  effectivePolicy(session) {
    try {
      const root=this.ctx.root.get('approval');
      const original=value=>value?.[symbols.original]??value;
      if(!root || original(root)===original(this) || typeof root.effectivePolicy!=='function')return 'never';
      if(root.effectivePolicy(session)!=='ask')return 'never';
      const own=super.effectivePolicy(session);
      return own==='ask'?'ask':'never';
    } catch { return 'never'; }
  }
}
