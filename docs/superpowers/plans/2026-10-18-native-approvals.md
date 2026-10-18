# Native Approval Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development task-by-task. The user already approved request-bound watch allow-once/decline and authorized continued implementation.

**Goal:** Extend the approved notification design with a provable DSH request owner and a reviewable native scope extension, preserving fail-closed behavior on stock harnesses.

**Architecture:** A pinned native source patch supplies a service-minted approval UUID and immutable operation scope from the actual Bash body. The independent Host plugin owns only those extended requests, exchanges bounded decisions with its private Python relay, and reports success only from the native audit result. The patch is built and tested in a temporary module tree; it is never applied to the installed application here.

**Tech Stack:** Node22 ESM/Cordis/AsyncLocalStorage only if needed for observation, Python3 private file bridge, existing Swift/C++ notification contract.

## Global Constraints

- C152 only. No install, profile mutation, app-bundle patch, model call, flash, merge or push in this source phase. Keep the frozen b101926 candidate and installed baseline intact.
- The approved design at docs/superpowers/specs/2026-10-17-task-notifications-design.md remains binding: exact pending source/session/run/request/revision, current lease, fully displayable scope, and authoritative native outcome. Read/dismiss/open never decides; no permanent/session authorization or keyboard approvals.
- Stock DSH0.2.0-rc.2 lacks body-bound scope and callback audit UUID. Stock Codex, SUPER and Hermes native deciding capabilities remain false. A project extension is not claimed as an installed or official native capability.
- Only printable ASCII operation context fitting the existing detail192/title48/model32/wire512 limits can enable watch decisions; never truncate, redact or silently omit executable arguments, cwd or permission scope. Otherwise use OPEN ON MAC.
- Runtime data stays outside the checkout in owner0700/files0600 storage using existing no-follow validation. Tracked examples/probes use synthetic data. Do not copy native bundles or dependencies into Git, record secrets, account/task/device identifiers, or environment values.
- Native routing IDs stay on the Mac. Policy sessionId is validated against the live session and retained for binding, never rendered; it is routing metadata, not permission scope. All executable arguments, effective cwd/defaults and permission fields must still be fully displayed. Unknown policy fields fail closed.
- Native decision choices are allowed-once/rejected only. Cancel, lease expiry, disconnect, process exit, unload and deadline relinquish ownership safely; no local ACK or callback return may be labeled a native allowed result. Only matching committed approval/decided supplies allowed/declined/cancelled.
- Existing HID/quota/audio/firmware behavior remains unchanged. Existing notification-only modes keep working; native mode is explicit opt-in and bounded.

### Task 1: Pinned native approval context extension

**Files:** Create notifications/native-patches/deepseek-0.2.0-rc.2-approval-context.patch, a hash/protocol manifest and README in that directory; create notifications/tests/deepseek-native.test.mjs and a temporary-tree test runner under scripts/. Update capability evidence documentation as needed.

**Interfaces:** Patch the exact extracted @deepseek-ai/dsh-user-approval, dsh-sandbox and dsh-tool-bash modules. The service passes its own immutable requestId (identical to approval/asked and approval/decided UUID) to composed answerers. A versioned immutable operation scope reaches that callback from the actual Bash invocation, containing the exact execution arguments, effective working directory and requested effective sandbox policy. Document exact field names in the patch manifest. Neither observer audit JSON nor a mutable registry execution object is accepted as execution-scope authority.

- [ ] Write native-module tests first, importing byte-verified installed modules from an explicit external test path, with real Cordis, Registry, Bash, ApprovalService and SessionStore and an inert shell sink. Confirm stock fails for missing minted request ID/body-bound scope, and reproduces the audit/ALS mismatch.
- [ ] Implement the minimal reviewable unified patch. Capture a detached immutable argument snapshot at the Bash body entry and use that same snapshot for validation, approval and actual shell request. Compute effective workdir and final requested policy before approval and reuse them for execution. Native policy never and strict-widening validation must still precede answerers; no grants are broadened or persisted. Forward scope through native escalation and add the UUID at the service boundary without mutating caller request objects.
- [ ] Apply only to a temporary copy after exact input SHA256 verification; reject changed native files and partial patch applications. Keep upstream attribution. Do not vendor generated native source.
- [ ] Verify patched callback scope equals the actual inert execution under an adversarial wrapper that sets arguments A, dispatches, then restores audit arguments B. Cover concurrent sessions, exact UUID, abort after submitted allow, never policy, decline, and unchanged nonextended requests. Test immutable nested scope and mutation attempts. Ensure tests exercise production patched modules, not a separately reimplemented approval service.
- [ ] Record protocol, hashes, commands, RED/GREEN results, source-only limitations, and commit only this task's files.

### Task 2: Opt-in DSH owning adapter and duplex bridge

**Files:** Create notifications/adapters/deepseek/approval.mjs and a dedicated native relay module if needed; modify notifications/adapters/deepseek/index.mjs, notifications/adapters/relay.py and runtime.py narrowly; extend notifications/tests/deepseek.test.mjs, deepseek-native.test.mjs and test_adapters.py; update notifications/test.sh, capabilities.json, notifications/README.md and docs/TASK_NOTIFICATIONS.md.

**Interfaces:** Consume only Task1's implemented versioned native descriptor and minted requestId. The plugin opt-in configuration is nativeApprovals:true (default false). Register an approval/request owner before native UI with prepend:true. Bound maps64, NDJSON frames8192 bytes, bridge write backlog65536 bytes, refresh5000ms, current decision lease15000ms and maximum ownership window60000ms. A dedicated bidirectional child relay validates private files and exact identity before delivering decisions back to the owner. Decide only after child readiness; on child/process/backpressure/parse failure, safely delegate once and disable capability. No arbitrary source can claim native support through generic Publisher.forward.

- [ ] Read Task1's protocol manifest and report. Write failing tests for opt-in ownership, stock/missing context fallback, complete ASCII scope and oversize/unknown fields, concurrency, decision revalidation, stale ID/revision, duplicated answer, native abort and native result correlation. Add process-level tests of the actual duplex relay with private files.
- [ ] Implement the owner with root/session/current observed turn validation, exact native requestId and descriptor binding, bounded state and scope equality. Render all operation and permission fields without truncation; bind native routing metadata privately as specified above. Unrepresentable operations immediately call next(). Ignore pre-load requests and child agents. Registering an observer never bypasses native policy.
- [ ] Own the callback exclusively while watch deciding is enabled. On OPEN, timeout, unload, bridge failure, scope change or invalidation, remove capability and delegate exactly once to the normal native answerer. Abort follows native cancellation. Late watch answers cannot settle a delegated/native-resolved request. Refreshes must not overwrite owned detail with generic audit observations.
- [ ] Claim private-file decisions once, forward full exact identity with action, and recheck native pending status, descriptor, revision and current lease immediately before settlement. Only allow_once/decline map to native outcomes. OPEN must release ownership then request application activation, not leave a hidden native prompt. The notification-only OPEN consumer must not steal native-owned decisions.
- [ ] Only committed matching native approval/decided emits a resolved outcome, including cancellation racing an allowed-once callback return. Preserve audit-only fallback and input/completion behavior. No replay after process restart, no optimistic accepted result.
- [ ] Run focused tests followed by notifications/test.sh and scripts/test_task_notifications.sh. Run git diff --check. Document current installed stock support separately from patched native-module acceptance, leave firmware candidate untouched, and commit the independently testable adapter.

## Final verification and review

- [ ] Independent task review after each task: spec compliance and code quality; fix actionable findings with covering tests.
- [ ] Broad final review of this native-integration delta, including the existing private bridge call sites affected by native mode. Review the rest of the original candidate only where a concrete new contract risk requires it.
- [ ] Verify clean branch and exact commits, source/tests versus installed runtime/hardware status. Preserve original candidate provenance; a new adapter patch is not a newly installed/physically accepted candidate.
- [ ] Record Hermes exact-ID/ABA/final-outcome blockers and current SUPER CLI approval restriction with source evidence. Mark unimplemented native capabilities explicitly rather than checking off product acceptance.
