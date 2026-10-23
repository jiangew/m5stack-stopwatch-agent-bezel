# DSH notification content parity

User approved: finish DSH content collection and the read-only attention layout
so they use the existing Codex notification design. Confirmation stays on Mac.
Reuse the existing isolated worktree; preserve the installed accepted V2 baseline
until reviewed candidates and coordinated installation are ready.

## Native contract

The installed desktop bundle is DSH0.2.1-rc.2. Its original Host observer is
loaded by an absolute file URI from the old private release. The unrelated
navigation package and globally installed CLI are separate installations.

- Read task name through `ctx.sessionProjections.stateOf(session, 'title')` only;
  missing projection/name stays empty for the existing stable local serial.
- Read project basename from immutable `session.header.cwd`; omit home/root or
  absent paths. Never store a complete working directory.
- Observe only committed `assistant/message` events for an exact live root and
  observed current turn. Keep one bounded visible text excerpt per root; reject
  thinking/tool/image blocks and tool-call-bearing intermediate messages. Consume
  it only on matching completed `turn/end`, then release the bounded cache.
- Do not scan transcripts, call title generation, invoke models, create tasks,
  infer child completion or reconstruct requests that predate plugin loading.
- Capture is explicit `richContent:true`, default off. `nativeApprovals` stays
  false; rich observation and the source-only native decision owner cannot be
  enabled together. Existing capability/scope behavior stays separate.

## Event and display contract

Optional project/excerpted fields use the accepted V2 bounds. An optional
`terminalReason` carries only native completed/error/aborted/blocked/max-tokens
for done/failed records and must agree with kind. Native completed/failed records
are resolved, rather than pending. Fit UTF-8 and the encoded route envelope,
including Foundation slash escaping, before publication; never fit native scope.

Shared read-only presentation adds layout3 for approval/input cards; layout2
remains the completed/failed path. Both display canonical DSH source, n/N,
project/time, two-line task name and centered bounded body. Read-only approval
shows WAITING ON MAC, input WAITING FOR INPUT; native settled outcomes alone
show ALLOWED/DECLINED/ANSWERED/CANCELLED, otherwise CLEARED. DSH round completion
says TURN ENDED; interruptions and limits retain their native meaning.

Keep header/body/fonts, footer x88/264 y378/395, BACK430 and all gestures/hit
regions from accepted V2. Attention has OPEN ON MAC only. Never render deciding
controls or truncate a capable scope. Original durable events remain unchanged;
freeze task metadata for the same pending identity. Reserve count/ack/TTL and
attention state/outcome JSON widths so heartbeat or resolution cannot alter the
same card's excerpt and break firmware context checks.

The shared read-only attention layout also applies to other sources; their
collectors and approval authority remain unchanged. Update compatible generic
OPEN relay alongside the new optional fields. No automatic old-event backfill.

## Acceptance

Failing regressions precede code: root/turn isolation, native fields and visible
text only, Unicode/escaped bounds, immutable heartbeats/outcomes, new read-only
layout/status, stable wire text and untouched capable scope. Exercise installed
native Session/projection contracts with synthetic events and inert generation.
Build native, standard, selected USB-mic+IMU and Companion candidates; inspect
native DSH completed/waiting/resolved previews and review the fixed patch.
Installation, exact-port app-only flash and physical/native live acceptance are
separate steps; do not edit running profile or restart DSH during development.
