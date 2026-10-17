# Opt-in native task notifications

These adapters feed the companion's [private file bridge](../companion/TASK_NOTIFICATIONS.md). They are separate from quota, HID, voice and the existing DeepSeek navigation plugin. Nothing here installs hooks, changes provider configuration, launches models, or flashes a device automatically.

Every native adapter emits `canDecide:false`. Native approval/choice responses are **unsupported**: no adapter owns a proven exact pending request, full displayable scope, source control channel and authoritative response together. The device can read, dismiss and request OPEN ON MAC. Those actions never approve, decline or answer a native request. Generic bridge fixtures that exercise decisions do not establish a native integration.

## Capability and evidence

| Source | Native event entry point | Request/resolution identity | OPEN | Evidence / remaining limit |
| --- | --- | --- | --- | --- |
| Codex | `notify` JSON argument, `agent-turn-complete` only | Exact thread + turn; exact read-only native metadata verifies roots, explicit allowlist fallback | `codex://threads/<thread-id>` | CLI 0.163.0-alpha.10.2 / desktop 26.1013.40934 source + fixtures; notify not installed or observed live. Failure, input and approval events unsupported. |
| DeepSeek | Independent Host Cordis `session/event`; native userQuestions projection | Exact root Session + turn + approval audit UUID; `approval/decided` supplies allowed/declined/cancelled; input projection supplies cleared/answered | App activation only | 0.2.0-rc.2 installed source + fixtures; Host plugin not installed/live tested. Never claims or races the native approval waterfall. |
| SUPER | Native `sc agent subscribe` for explicitly selected root stable target IDs | Native lifecycle sequence identifies observed attention; no native approval request ID/control API | `sc chat select` only with explicit verified Chat UI session binding; otherwise activation | ac45e7aa actual ready/target_closed envelopes captured using isolated no-model QA terminal. Other event variants are source-backed fixtures, not live model-run acceptance. |
| Hermes | Agent plugin `on_session_end`, `subagent_start`, approval observer hooks | Completion session/turn; approval observer-local ID, matched only on unique native session/turn/tool-call tuple; cleared without an accepted verdict | `hermes://open/<stored-session-id>`; never infer a stored ID from runtime sid | Desktop 0.17.6, source 74f726c17675642c2eff3033632e812f5f0e6614 + fixtures; plugin not installed/live tested; built ASAR/source equality unproven. Gateway hooks do not cover Desktop. |

The collector receives genuine native callbacks or native CLI streams; manually sending JSON to `relay.py` is only a developer ingress. Existing desktop sessions are covered only **after** the corresponding opt-in callback/plugin/collector is loaded. No transcript scanning, terminal-output guessing, keystroke approval, duplicate app-server, or replacement Hermes backend is used.

## Shared private runtime

Build/run the companion with its explicit device binding, `--watch` and `--notifications-dir /ABSOLUTE/PRIVATE/notifications`. The directory must be outside this checkout, with canonical non-symlink ancestors. The bridge creates 0700 directories and 0600 files. Use `/private/tmp`, not macOS's `/tmp` symlink, for temporary testing. See the bridge guide for the complete source/run/request/revision and lease contract.

Run the OPEN consumer separately, from the checkout root:

```sh
python3 notifications/adapters/relay.py --directory /ABSOLUTE/PRIVATE/notifications --watch-open
```

Only identity-bound `open` decisions are consumed. Approval/choice decisions are never claimed by these notification-only adapters. Routing records live in private `adapter-routes/`, use the same no-follow owner/mode checks, and are bounded to 256 records. Full inventory causes a content-free error and stops publication; it never evicts a live native request. Stop adapters and companion before explicitly archiving/resetting an old runtime directory. Real events, routing IDs and logs must stay outside the repository.

OPEN reports `exact-session-open-requested`, `application-activation-requested`, or `open-failed`. A successful OS/CLI dispatch is not proof that the user saw the session. DSH fallback and unbound SUPER/Hermes fallback **never** report exact-session navigation. Opening does not emit a resolved native approval.

## Codex native notify

After explicitly choosing to enable it, merge a native `notify` entry into the applicable local Codex configuration without replacing existing settings:

```toml
notify = ["python3", "/ABSOLUTE/CHECKOUT/notifications/adapters/codex_notify.py", "--directory", "/ABSOLUTE/PRIVATE/notifications"]
```

Codex appends the JSON callback argument. Each callback queries only that exact thread through a short local App Server metadata connection: `initialize`, `initialized`, then `thread/read {threadId,includeTurns:false}`. Known root sources (`cli`, `vscode`, `exec`, `appServer`) with no parent and no turns are accepted automatically, so future simultaneous root tasks do not need permanent per-task IDs. Native subAgent sources are rejected. This read neither resumes/starts a thread nor subscribes to/controls the desktop runtime; it issues no account or model request.

The native metadata response also contains a preview (usually the first user message). It is transiently received and immediately discarded; no preview/title/cwd is logged, displayed or persisted. For environments that prohibit even that local metadata transfer, add `--no-metadata-query` and repeat `--root-session NATIVE_ROOT_THREAD_ID` for independently verified roots instead. Unknown sources, query failure, unsupported schema or absent persisted thread metadata require an explicit root fallback; otherwise that completion is skipped. A known child cannot be overridden by the allowlist. The metadata route is source/schema and fixture verified, not yet observed on an installed notify hook.

Loading/reloading notify into already open desktop threads still needs live acceptance. There is no wrapper that starts a new task. Once opting into this native Codex route, start Companion with `--native-codex-notifications` as well as `--watch --notifications-dir ...`: the dedicated fresh channel then suppresses duplicate legacy vendor-HID Codex completion alerts while preserving status LEDs. The option defaults off; stale/disconnected dedicated delivery falls back after 15 seconds. Source/build tests do not establish physical duplicate-alert acceptance.

The handler discards `input-messages`, `last-assistant-message`, metadata preview, working directory and other task content. It emits only generic completion display text and exact native IDs. `Stop` is not used as final completion because other Stop hooks can continue a turn. `notify` does not provide approvals, input, failed or interrupted outcomes. See [official notify configuration](https://learn.chatgpt.com/docs/config-file/config-advanced).

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

Native input projection entries stay pending when their tool continues after a timeout; only the native projection dropping/settling the exact call clears them. Question text/options/answers are not copied. Requests whose start was missed at plugin load are not reconstructed from task text; pending approval before loading is unsupported. No approval answerer is registered, so desktop UI ownership and ordering remain unchanged. See [native approval subsystem](https://deepseek-harness.github.io/deepseek-harness/en/reference/subsystems/approval).

## SUPER native collector

Use the installed bundled CLI. Discover exact root stable IDs using native `sc agents list --worktree /ABSOLUTE/WORKTREE --output json`; the collector repeats this metadata check and rejects known child targets. Run from the checkout root:

```sh
python3 notifications/adapters/super_collector.py \
  --directory /ABSOLUTE/PRIVATE/notifications \
  --worktree /ABSOLUTE/WORKTREE --target NATIVE_STABLE_TARGET_ID
```

Repeat `--target` for multiple roots in that worktree. Optional `--chat-session NATIVE_STABLE_TARGET_ID=NATIVE_CHAT_SESSION_ID` enables exact Chat UI OPEN only after verifying the native binding; terminal targets use app activation. Models never identify a task. No session, prompt or workspace is created by the collector.

The validated ac45e7aa stream is a flat event with exactly `sequence`, `stable_target_id`, `type`, `timestamp_ms`, `worktree_path`; its initial ready frame is `{kind:"ready",sequence,targets}`. Unknown wrappers, extra fields (including unverified `run_id` extensions), malformed records and CLI errors stop ingestion with a content-free diagnostic. It does not guess a newer schema or continue under a stale contract. Completion/error/cancel are distinct, another target is ignored, and pending attention is cleared only by a terminal native lifecycle outcome for that exact target. Attention has no native approval identity, so no decision or invented accepted outcome is exposed.

The collector starts live. If it disconnects, stop/reinspect native state and restart; it does not fabricate events missed while offline or treat idle as completion. The app must already run and native provider lifecycle hooks must support that target. The actual QA observed ready and target_closed from a temporary `sleep; true` terminal; no model task was submitted. `task_complete` and provider-specific approval/input coverage still need a synthetic native model-run acceptance test. See [native CLI automation](https://super.engineering/docs/cli-local-api/).

## Hermes agent plugin

Use `adapters/hermes/` as a local agent plugin, not the gateway `hooks/` directory. Once installation is separately authorized, link the plugin directory into the active profile's plugins directory, enable only `agentbezel-notifications` through native plugin controls, and ensure `STOPWATCH_NOTIFICATIONS_DIR=/ABSOLUTE/PRIVATE/notifications` reaches the **existing Desktop owner backend**. The plugin symlink must continue pointing into this checkout; do not copy its `__init__.py` in isolation. No install/enable/restart is performed by these files.

`on_session_end` is a native per-finalized-turn plugin callback, distinct from memory-provider session cleanup. It requires native session/turn IDs and explicit completed/failed/interrupted booleans. `subagent_start` records child IDs; child callbacks do not complete a parent. No tool or raw output hook is used to infer completion.

Approval pre/post hooks do not carry the native queue request ID and cannot decide. An exact unique session/turn/tool-call tuple receives an explicitly observer-local card ID; its matching post callback clears that same ID without claiming allowed/declined. Duplicate ambiguous tuples remain unknown until an exact native finalized-turn callback clears all observed requests of that session/turn; they are never selected by FIFO or command text. These observations do not renew native decision leases. Secret commands and reason text are discarded. Arbitrary clarify input is unsupported. See [official hooks scope](https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks).

## Verification and release boundary

From the checkout root:

```sh
sh notifications/test.sh
sh scripts/test_task_notifications.sh
```

The adapter suite runs Python/native Node fixture tests plus callback→private filesystem→real Swift broker tests, including cleared native audit outcomes, monotonic resolution timestamps, child/tool exclusion, multiple sessions, no false acceptance, OPEN routing, and symlink/mode rejection. It never installs plugins or calls a model. The source protocol and installed artifact pins are documented above; current private inspection notes stay in the ignored task work area.

No C152 build/flash/pairing/encrypted GATT/button/haptic/physical notification acceptance is established by these tests. Native plugin installation, exact session opening in each app, existing-session coverage after reload, and end-to-end physical delivery require separate observed acceptance.
