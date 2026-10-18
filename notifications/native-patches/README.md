# Pinned DSH approval context extension

This source-only project extension targets DeepSeek Harness `0.2.0-rc.2`, upstream [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness). The package manifests identify the upstream code as MIT licensed. The zero-context unified patch (protected by exact full input hashes) preserves upstream source attribution and changes three extracted `lib/index.js` files. It does not install or enable an application capability.

`manifest.json` pins the patch, seven directly exercised native module entries, and the complete 1,558-file extracted dependency tree. Input and output SHA256 values identify the exact tested bytes. No native package or dependency is vendored here.

Run from the repository root with an explicit, previously extracted `node_modules` directory:

```sh
node scripts/test_deepseek_native.mjs /private/tmp/dsh-native-approval-probe/native/dsh/node_modules stock
node scripts/test_deepseek_native.mjs /private/tmp/dsh-native-approval-probe/native/dsh/node_modules patched
```

`stock` deliberately runs the extension acceptance tests against unchanged upstream bytes and exits nonzero (expected RED). `patched` must exit zero. The runner verifies the entire dependency tree before copying, copies only into a private temporary tree, checks patch bytes/targets, dry-runs the complete patch, applies it only in that tree, verifies every output and the dependency tree, then runs the native tests. It verifies unchanged external input afterward and discards the temporary tree on success or failure. Changed inputs, symlinks, special files, partial/changed patches and changed outputs fail closed. It never writes to the supplied source, an installed app or a profile. Test children receive only PATH and explicit synthetic test configuration.

## Public protocol

The ApprovalService callback receives a frozen shallow copy of the caller request, with `requestId` replaced by the service-minted UUID. The caller object is not mutated. This UUID equals the committed `approval/asked.data.id` and `approval/decided.data.id`. Agent/session/signal references remain native live references. Nonextended requests also receive the UUID but have no operation descriptor.

An eligible ordinary Bash request additionally carries:

```ts
nativeApprovalScope: Readonly<{
  protocol: 'stopwatch.dsh.native-approval.v1';
  implementation: 'dsh-tool-bash@0.2.0-rc.2';
  arguments: Readonly<JsonObject>;
  standingPolicy: Readonly<JsonObject>;
  execution: Readonly<{
    command: string;
    workdir: string;
    timeoutMs: number;
    onExpiry: 'kill';
    stdoutMaxBytes: number;
    sandboxPolicy: Readonly<JsonObject>;
  }>;
}>;
```

Every nested descriptor value is frozen. `arguments` is the detached snapshot created at the actual Bash body entry and reused for argument validation, escalation parameters, command and execution-mode selection. `standingPolicy` is the complete policy captured before awaiting approval. `execution.sandboxPolicy` is the complete final requested policy. All policy fields are retained. Native policy `sessionId` is routing metadata: validate and bind it locally against the exact live session; never render native identifiers on the watch. Render all operation/permission fields losslessly, and fail closed on unknown policy fields. The execution spec is resolved before approval and reused after allow; defaults cannot be recomputed after the user decides. Effective cwd includes the native policy/session fallback and relative-path resolution.

Only foreground calls without a job registry receive a descriptor, and only when the shell spec has an absolute cwd, positive resolved timeout/output budget, kill expiry, and exactly the known spec keys. Background/job/promotion paths and unresolved or unknown executor specs retain native approval without this descriptor. Explicit executor `env`, `stdin`, or unknown fields disable the extension rather than exposing or omitting them. Managed `dshEnv` is captured privately and reused, never included in the public descriptor. Ambient process environment and provider internals are outside this command-scope protocol. No claim is made that spill limits, grace timing, filesystem contents or ambient process environment are immutable.

Native strict-widening validation, never policy, normalization, cancellation race and audit append remain authoritative. A callback return or local ACK is not a native resolution. Consumers accept only the matching committed `approval/decided`, including cancellation after locally submitted allow. No grant is persisted or widened beyond the one native request.

This protocol assumes a trusted composition of the pinned ordinary Bash tool, sandbox helper, approval service and shell provider. A protocol string is not attestation against malicious same-process plugins. Audit text, a mutable registry execution object, and AsyncLocalStorage are not scope authority. Persistent Bash and other implementations are unsupported.

## Adapter handoff

Bind ownership to the live root agent/session/current turn, minted `requestId`, frozen descriptor reference and live signal. Independently enforce native pending state, revision, lease, bounds and the complete displayable scope. Read/open/dismiss must not decide. Missing/unknown/oversize/non-ASCII scope delegates to the ordinary native answerer.

The verbose descriptor is not watch display text. A tiny synthetic descriptor with `pwd`, description/reason `x`, cwd/root `/`, read-only standing mode, danger-full-access requested mode, timeout/output budget 1 is **449 JSON bytes**. A documented lossless compact example for precisely those values is **191 ASCII bytes**:

```json
["bash",{"command":"pwd","description":"x","workdir":"/","timeoutMs":1,"sandbox_permissions":"danger-full-access","justification":"x"},{"from":"read-only","root":"/","expiry":"kill","out":1}]
```

This encoding reconstructs the fixed protocol/implementation and duplicate effective values from complete arguments plus standing mode/root, expiry and output budget; the protocol's eligibility means foreground without jobs. It is not an implemented renderer. Additional operation/permission fields, changed effective defaults, a relative cwd or longer arguments require additional lossless display context and often exceed the 192-byte detail limit. Native sessionId remains private routing metadata, validated locally rather than displayed; unknown policy fields fail closed. Never truncate, redact, omit fields or replace scope with a digest to fit. Installed stock support remains false until a separate reviewed deployment and runtime acceptance.
