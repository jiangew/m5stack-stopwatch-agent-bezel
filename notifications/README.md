# Opt-in native task notifications

These adapters feed the companion's [private file bridge](../companion/TASK_NOTIFICATIONS.md). They are separate from quota, HID, voice and the existing DeepSeek navigation plugin. Nothing here installs hooks, changes provider configuration, launches models, or flashes a device automatically.

Installed stock native approval/choice support remains **false**. Default adapters emit `canDecide:false`. A source-only DSH project extension now has an explicit `nativeApprovals:true` owner for the narrow complete-scope subset described below; it is not installed or physically accepted. The device can read, dismiss and request OPEN ON MAC. Those actions never approve, decline or answer a native request. Generic bridge fixtures that exercise decisions do not establish a native integration.

## Capability and evidence

| Source | Native event entry point | Request/resolution identity | OPEN | Evidence / remaining limit |
| --- | --- | --- | --- | --- |
| Codex | `notify` JSON argument, `agent-turn-complete` only | Exact thread + turn; exact read-only native metadata verifies roots, explicit allowlist fallback | `codex://threads/<thread-id>` | CLI 0.163.0-alpha.10.2 / desktop 26.1013.40934 source + fixtures; notify not installed or observed live. Failure, input and approval events unsupported. |
| DeepSeek | Independent Host Cordis `session/event`; native userQuestions projection | Exact root Session + turn + approval audit UUID; `approval/decided` supplies allowed/declined/cancelled; input projection supplies cleared/answered | App activation only | 0.2.1-rc.2 rich content native-contract fixture; this content candidate is not installed/live tested. Default observer does not own approvals; explicit patched extension is separately module-tested. |
| SUPER | Native `sc agent subscribe` for explicitly selected root stable target IDs | Native lifecycle sequence identifies observed attention; no native approval request ID; current ordinary-question API explicitly forbids approvals | `sc chat select` only with explicit verified Chat UI session binding; otherwise activation | ac45e7aa actual ready/target_closed envelopes captured using isolated no-model QA terminal. Other event variants are source-backed fixtures, not live model-run acceptance. |

The collector receives genuine native callbacks or native CLI streams; manually sending JSON to `relay.py` is only a developer ingress. Existing desktop sessions are covered only **after** the corresponding opt-in callback/plugin/collector is loaded. No transcript scanning, terminal-output guessing, keystroke approval, duplicate app-server, or replacement backend is used.

## Shared private runtime

Build/run the companion with its explicit device binding, `--watch` and `--notifications-dir /ABSOLUTE/PRIVATE/notifications`. The directory must be outside this checkout, with canonical non-symlink ancestors. The bridge creates 0700 directories and 0600 files. Use `/private/tmp`, not macOS's `/tmp` symlink, for temporary testing. See the bridge guide for the complete source/run/request/revision and lease contract.

Run the OPEN consumer separately, from the checkout root:

```sh
python3 notifications/adapters/relay.py --directory /ABSOLUTE/PRIVATE/notifications --watch-open
```

Only identity-bound `open` decisions are consumed. Approval/choice decisions are never claimed by these notification-only adapters. Routing records live in private `adapter-routes/`, use the same no-follow owner/mode checks, and are bounded to 256 records. Full inventory causes a content-free error and stops publication; it never evicts a live native request. Stop adapters and companion before explicitly archiving/resetting an old runtime directory. Real events, routing IDs and logs must stay outside the repository.

OPEN reports `exact-session-open-requested`, `application-activation-requested`, or `open-failed`. A successful OS/CLI dispatch is not proof that the user saw the session. DSH fallback and unbound SUPER fallback **never** report exact-session navigation. Opening does not emit a resolved native approval.

## Codex native notify

After explicitly choosing to enable it, merge a native `notify` entry into the applicable local Codex configuration without replacing existing settings:

```toml
notify = ["python3", "/ABSOLUTE/CHECKOUT/notifications/adapters/codex_notify.py", "--directory", "/ABSOLUTE/PRIVATE/notifications"]
```

Codex appends the JSON callback argument. Each callback queries only that exact thread through a short local App Server metadata connection: `initialize`, `initialized`, then `thread/read {threadId,includeTurns:false}`. Known root sources (`cli`, `vscode`, `exec`, `appServer`) with no parent and no turns are accepted automatically, so future simultaneous root tasks do not need permanent per-task IDs. Native subAgent sources are rejected. This read neither resumes/starts a thread nor subscribes to/controls the desktop runtime; it issues no account or model request.

The native metadata response also contains a preview (usually the first user message). It is transiently received and immediately discarded; without the rich-content opt-in, no preview/title/cwd is logged, displayed or persisted. For environments that prohibit even that local metadata transfer, add `--no-metadata-query` and repeat `--root-session NATIVE_ROOT_THREAD_ID` for independently verified roots instead. Unknown sources, query failure, unsupported schema or absent persisted thread metadata require an explicit root fallback; otherwise that completion is skipped. A known child cannot be overridden by the allowlist. The metadata route is source/schema and fixture verified, not yet observed on an installed notify hook.

Loading/reloading notify into already open desktop threads still needs live acceptance. There is no wrapper that starts a new task. Once opting into this native Codex route, start Companion with `--native-codex-notifications` as well as `--watch --notifications-dir ...`: the dedicated fresh channel then suppresses duplicate legacy vendor-HID Codex completion alerts while preserving status LEDs. The option defaults off; stale/disconnected dedicated delivery falls back after 15 seconds. Source/build tests do not establish physical duplicate-alert acceptance.

By default the handler discards `input-messages`, `last-assistant-message`, metadata preview, working directory and other task content. It emits only generic completion display text and exact native IDs. `Stop` is not used as final completion because other Stop hooks can continue a turn. `notify` does not provide approvals, input, failed or interrupted outcomes. See [official notify configuration](https://learn.chatgpt.com/docs/config-file/config-advanced).


### Optional rich Codex content (candidate V2)

Add `--rich-content` to the existing native notify command only after installing
matching V2 firmware and a Companion started with `--notification-content-v2`.
Both switches default off. Keep `--native-codex-notifications`, directory binding
and the existing OPEN relay settings. These switches do not install themselves.

The metadata-only `thread/read` (`includeTurns:false`) supplies the exact native
thread `name` and a short `cwd` basename. Installed CLI schema and an exact local
metadata probe confirmed those fields on 2026-10-22; no turn history was read.
Missing names become a stable device-local `未命名任务 #N`, never the thread
preview or the user's prompt. No model name is invented. A callback's last reply
is normalized to plain text and bounded to 4096 UTF-8 bytes in the private bridge;
further encoded event/route fitting can shorten it, and only a smaller wire excerpt reaches the watch. This opt-in therefore allows real
task names, project basenames and reply text into the private runtime and watch.
It sends no inference/translation requests. Full replies remain in the native app.

The display shows source, selected position/count, project/time, a two-line task
name, `TURN ENDED` for a Codex round end, and an excerpt with `MORE ON MAC` when
clipped. DSH round ends also show `TURN ENDED`; its interruptions/blocks/limits retain their native meaning. Other done sources show `COMPLETED`.
This is event reporting, not a claim that all project work succeeded. Existing
queued generic Codex records cannot retroactively recover titles/replies; new
opted-in callback events provide them. DSH has a separately opt-in native content collector described below; the other collectors keep their current ingress.
Chinese glyph coverage is the bundled M5GFX efontCN set, not arbitrary Unicode
or emoji coverage. The existing Latin Space Mono text and gesture controls remain.

A candidate build or fixture pass does not establish live delivery, native OPEN,
or physical C152 acceptance. See the [candidate record](../docs/NOTIFICATION_CONTENT_V2_20261022.md)
for coordinated deployment and rollback boundaries.

## DeepSeek Harness Host plugin

Package `adapters/deepseek/` is independent `dsh-agentbezel-notifications`, not an extension to `deepseek-plugin/`. When installation is separately authorized, install that local package into the verified external Desktop profile using its existing package manager, then add a **Host root** node to that profile's existing patch, preserving all other nodes:

```yaml
- insert:
    - id: agentbezel-notifications
      name: dsh-agentbezel-notifications
      config:
        directory: /ABSOLUTE/PRIVATE/notifications
        relayScript: /ABSOLUTE/CHECKOUT/notifications/adapters/relay.py
        python: /ABSOLUTE/PYTHON
```

No app bundle should be edited. Fully reload the intended Host according to that version's plugin workflow; do not start a separate Host. Disabling/removing only this new node stops its timer/relay process. The existing navigation plugin is untouched.

The plugin requires native `agents` and `sessionProjections` services, accepts only exact runtime roots, and listens to committed `turn/end` and approval audit pairs. A step/tool/child completion is not a parent DONE. Failed, blocked, token-limited and aborted turns are not successes. Pending audit observations refresh every five seconds while that same root remains live; a matching native `approval/decided` withdraws the same immutable card and alone supplies the outcome. A terminal native turn can also clear that turn's unresolved audit observations without supplying an accepted/declined verdict. An unavailable answerer is cleared without an accepted/declined label.

Native input projection entries stay pending when their tool continues after a timeout; only the native projection dropping/settling the exact call clears them. Question text/options/answers are not copied. Requests whose start was missed at plugin load are not reconstructed from task text; pending approval before loading is unsupported. Default configuration registers no approval answerer. Explicit patched ownership is described below. See [native approval subsystem](https://deepseek-harness.github.io/deepseek-harness/en/reference/subsystems/approval).

### DSH content parity candidate (0.2.1-rc.2)

Explicit `richContent: true` on the Host observer reads the native `title`
projection and immutable header cwd basename. It keeps one bounded visible
committed assistant reply per observed live root/turn and consumes it only on a
matching completed turn. Tool-call-bearing messages, reasoning, images, child
agents and unobserved turns cannot supply the reply. Missing text points to Mac;
there is no history scan, title generation or model call. Titles<=512 UTF-8 bytes,
reply<=4096 with encoded event/route fitting; full content remains on Mac.

Keep `nativeApprovals: false`: rich observation and the separate decision owner
cannot be enabled together. Same-request task metadata stays fixed across
heartbeats and native resolution. Approval/input question bodies and answers
remain private. The shared read-only attention layout uses `WAITING ON MAC` /
`WAITING FOR INPUT`, and only native outcomes yield `ALLOWED`, `DECLINED`,
`ANSWERED` or `CANCELLED`; clearing alone shows `CLEARED`.

This candidate requires matching firmware, Companion build17, DSH collector and
generic OPEN relay. A fully reloaded intended desktop Host is required to load
its new module/config; installation and live acceptance have not happened.
The unrelated global CLI and navigation plugin must remain untouched. See
[DSH candidate validation](../docs/DSH_NOTIFICATION_CONTENT_20261023.md).

## Patched DSH approval owner (source-only)

The installed stock app still has no native decision capability. This optional adapter consumes only the [pinned project extension](native-patches/README.md), never audit text, mutable tool execution objects or arbitrary generic ingress. `nativeApprovals: true` is off by default and is eligible only in a separately deployed patched Host. No bundle/profile installation is performed here.

The owner registers `approval/request` with `prepend:true`, after native policy checks. Before ownership it requires the dedicated child relay's private-storage ready handshake, exact live root agent and Session, a turn/start observed since load, current pending audit UUID and the immutable body descriptor. Stock, background, child, pre-load, unknown/missing fields, credentials requiring redaction, non-ASCII, unequal effective values and oversized scope immediately delegate to native UI. Native routing sessionId is matched against the live Session and stays private on the Mac; managed environment is never displayed or transported.

The implemented lossless detail schema is `["bash",{"cmd":command,"desc":description,"cwd":workdir,"ms":timeoutMs,"mode":sandbox_permissions,"why":justification},{"from":standingMode,"root":standingRoot,"expiry":"kill","out":resolvedOutputBudget}]`. The short keys map one-to-one to the complete input arguments: command, description, absolute workdir, timeoutMs, sandbox_permissions and justification; all are displayed. The fixed `bash` schema denotes protocol stopwatch.dsh.native-approval.v1 and implementation dsh-tool-bash@0.2.0-rc.2. Admission requires effective command/cwd/timeout equal those arguments, effective requested mode equal sandbox_permissions, and both policy roots equal the displayed root. Both policies require known mode/workspaceRoot/sessionId fields. This reconstructs every operation/permission field; only validated native session routing metadata is excluded. There is no omission, truncation, digest or secret redaction. The minimal `/` + `pwd` case is 144 ASCII bytes; most ordinary commands exceed detail 192 and delegate.

Ownership upgrades the generic observation to revision 2; heartbeat and committed resolution preserve that full detail and revision. Maps hold at most 64 entries, frame payloads 8192 bytes, write backlog 65536 bytes, refresh 5 seconds, lease 15 seconds, maximum ownership 60 seconds. Exact current identity, descriptor, live signal/root/turn and lease are rechecked before allowed-once/rejected submission. OPEN releases to native UI before requesting application activation. Timeout, unload, child/protocol/backpressure failure and invalidation delegate once. Callback return and publication ACK never resolve a card: only matching committed approval/decided supplies allowed/declined/cancelled, including cancellation after local allow submission.

The dedicated duplex relay claims private-file decisions once; generic Publisher.forward still rejects all canDecide claims. A separate OPEN consumer re-reads the current route and claims under the same inventory lock used by renewal. Per-identity kernel ownership locks protect live native callbacks even after the 15-second decision lease expires; exact OPEN still reaches the owner, invokes the native continuation, and only then releases the routing lock and requests activation. Allow/decline remain forbidden after lease expiry. The original 60-second ownership window cannot renew: a child reaching it disables the channel, withdraws capabilities and releases its locks, and the parent delegates once when scheduled. Graceful exit also withdraws capabilities; a killed child's locks release automatically, allowing generic OPEN after the old decision lease. Routing and stable no-follow owner-lock files are each bounded to256. Relay restart never restores ownership from persisted routes. The actual native tests run real verified Cordis/Registry/Bash/ApprovalService with an inert shell; OS-opening process tests use an inert runner. These establish source/module behavior only.

## SUPER native collector

Use the installed bundled CLI. Discover exact root stable IDs using native `sc agents list --worktree /ABSOLUTE/WORKTREE --output json`; the collector repeats this metadata check and rejects known child targets. Run from the checkout root:

```sh
python3 notifications/adapters/super_collector.py \
  --directory /ABSOLUTE/PRIVATE/notifications \
  --worktree /ABSOLUTE/WORKTREE --target NATIVE_STABLE_TARGET_ID
```

Repeat `--target` for multiple roots in that worktree. Optional `--chat-session NATIVE_STABLE_TARGET_ID=NATIVE_CHAT_SESSION_ID` enables exact Chat UI OPEN only after verifying the native binding; terminal targets use app activation. Models never identify a task. No session, prompt or workspace is created by the collector.

The installed app is now 15aae8f8; its help/static contract supports ordinary question answers but explicitly forbids approval answers. A content-minimized question getter and request closure remain unvalidated. Current lifecycle runtime compatibility needs revalidation; no current 15aae8f8 lifecycle acceptance is claimed.

The validated ac45e7aa stream is a flat event with exactly `sequence`, `stable_target_id`, `type`, `timestamp_ms`, `worktree_path`; its initial ready frame is `{kind:"ready",sequence,targets}`. Unknown wrappers, extra fields (including unverified `run_id` extensions), malformed records and CLI errors stop ingestion with a content-free diagnostic. It does not guess a newer schema or continue under a stale contract. Completion/error/cancel are distinct, another target is ignored, and pending attention is cleared only by a terminal native lifecycle outcome for that exact target. Attention has no native approval identity, so no decision or invented accepted outcome is exposed.

The collector starts live. If it disconnects, stop/reinspect native state and restart; it does not fabricate events missed while offline or treat idle as completion. The app must already run and native provider lifecycle hooks must support that target. The actual QA observed ready and target_closed from a temporary `sleep; true` terminal; no model task was submitted. `task_complete` and provider-specific approval/input coverage still need a synthetic native model-run acceptance test. See [native CLI automation](https://super.engineering/docs/cli-local-api/).

## Retired Hermes source

Hermes notifications are no longer supported. Its adapter/plugin entrypoints and
OPEN routes have been removed. New Hermes events are rejected by the Python
bridge, Companion ingress and firmware. Companion startup migrates old broker
queues by removing Hermes records while retaining all other sources and IDs.
Old Hermes route entries are ignored so they cannot block supported OPEN routes.

## Verification and release boundary

From the checkout root:

```sh
sh notifications/test.sh
sh scripts/test_task_notifications.sh
```

Set DSH_NATIVE_MODULES to an explicit external pinned node_modules tree to include the temporary-tree patched native acceptance in notifications/test.sh (otherwise it reports that acceptance as not run). The adapter suite runs Python/Node tests plus callback→private filesystem→real Swift broker tests, including cleared native audit outcomes, monotonic resolution timestamps, child/tool exclusion, multiple sessions, no false acceptance, OPEN routing, and symlink/mode rejection. Persistent SUPER stream tests deliver batched frames before EOF and isolate partial frames across roots. Routing capacity is serialized across callback processes with an owner-only, single-link, no-follow lock; its file does not consume the 256-record capacity, and existing identities remain writable at capacity. It never installs plugins or calls a model. The source protocol and installed artifact pins are documented above; current private inspection notes stay in the ignored task work area.

No C152 build/flash/pairing/encrypted GATT/button/haptic/physical notification acceptance is established by these tests. Native plugin installation, exact session opening in each app, existing-session coverage after reload, and end-to-end physical delivery require separate observed acceptance.


### Model/time row follow-up

For Codex and DSH rich cards, the context before local time now displays the
native model version instead of project. DSH reads the current observed native
request/header config.model and committed assistant message.source.model, bound
to the exact root Session/turn; pending identity freezes it through resolution.
Codex's metadata-only Thread.model is **current/latest persisted thread
configuration, not per-turn execution telemetry**. The user chose that fallback
as a fallback; internal `modelConfigured:true` retains the provenance. The
latest user preference displays only the model version, without a 配置 prefix. No global default or arbitrary callback model field fills gaps.
Missing model shows `模型未提供`; old events are not backfilled. The original
project remains local metadata; Codex/DSH rich wire omits it. Other source rows
retain project/time. Candidate build18 is not installed or physically accepted.
See [model row evidence](../docs/NOTIFICATION_MODEL_ROW_20261023.md).


The [latest reply-model follow-up](../docs/NOTIFICATION_REPLY_MODEL_20261023.md)
prioritizes the last assistant result before session configuration. DSH uses its
native reply model; when unavailable, an unambiguous standalone model annotation
in reply text is accepted (Codex's callback provides reply text only). Ordinary
mentions, fenced/quoted/indented examples and conflicting model annotations do
not provide a model. Fallback reads only exact session configuration. UI renders
no source prefix. Native scope, queue identity and controls remain unchanged.
