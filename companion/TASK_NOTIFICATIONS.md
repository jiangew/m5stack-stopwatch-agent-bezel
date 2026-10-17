# Private task notification bridge (v1)

This opt-in bridge has no native approval integrations yet. Source adapters must
be explicitly connected in a later step. `canDecide` defaults to false. Display,
read, dismiss, open and transport acknowledgments never approve a native request.

Start the source-built companion with `--watch --device-id UUID
--notifications-dir ABSOLUTE_PRIVATE_DIRECTORY`. The directory must have a real
(non-symlink) parent and be outside the repository. The companion creates its
final directory and subdirectories with0700 permissions; all files are0600.
Existing objects with other owners/modes are rejected. Use canonical paths:
macOS `/var` and `/tmp` aliases are symlinks; use `/private/var` or `/private/tmp`.
One companion owns each directory using a nonblocking advisory lock. Other
companion functionality is unchanged when this option is omitted. The runtime
and250ms polling start before the first quota/App Server read, so quota failure
does not prevent notifications.

## Local adapter events

Python API: `emit(directory, event)` and `decisions(directory, pending, now=None)`
in `scripts/stopwatch_notify.py`. CLI accepts `--directory ABSOLUTE_PATH emit
--record EVENT_JSON` (or `decisions`). Keep real JSON outside the repository.
`now` and all timestamps are Unix milliseconds; default `now` is wall clock.

Required event keys: `v:1`, `eventId:string`, `source:codex|deepseek|super|hermes`,
`sessionId:string`, `runId:string`, `requestId:string`, `revision:uint32>0`,
`createdAt:int64`, `leaseDeadline:int64`, `kind:done|approval|input|failed`,
`title:string`, `model:string`, `detail:string`, `state:pending|resolved`.
`canDecide:boolean` is optional (defaultfalse). Identity strings/eventId are
nonempty and at most256 UTF8 bytes each. Display content is at most4096 UTF8
bytes per field; entire local event is at most8192 bytes. NUL is rejected.

Decision capability also requires nonempty, readable title and detail.
Optional `options` and `optionIds` arrays are supplied together for `kind:input`:
2–3 nonempty ASCII labels of at most24 bytes and equally many distinct opaque
native IDs of at most256 UTF8 bytes. Arbitrary text entry is unsupported.

Native identity is the exact tuple `(source,sessionId,runId,requestId)`; model
names never identify tasks. Each revision's kind/title/model/detail/options and
native option IDs are immutable. Scope changes require a higher revision.
Heartbeats use a new eventId, strictly later createdAt and refreshed
leaseDeadline, preserving revision and scope. They neither rearm initial alerts
nor reset FIFO/120-second reminder time. A decidable lease must be current,
created within15seconds and end no later than createdAt+15000ms. Native adapters
refresh only while the exact request remains pending and retains capability.
Older revisions, duplicate events and terminal-to-pending updates are ignored.
Malformed events do not alter queue state.

The durable queue holds64 records. No live pending approval is evicted. At
capacity only a dismissed resolved record, or dismissed done/failed record, can
be removed. Other overflow records remain in private processing for retry,
bounded by the1024-file inbox/processing inventory limits. Adapter callers must
handle full directories explicitly. Pending approval/input comes first, then
failures, then completions in original per-revision FIFO order. Read/browsing
pins selection until `close` or `dismiss`; arrivals cannot steal that selection.
Only pending approval/input gets at most one reminder at120seconds. Reconnect
suppresses all old alerts.

Inbox emission uses same-directory atomic publication. The companion exclusively
claims each file, persists queue changes before removal and recovers processing
files after restart. Unsafe/malformed records are removed with a content-free
error log. Every path component is opened with no symlink following; objects
must be regular owner-only files with one link. Filesystem permission checks
protect local privacy; an already-compromised same-user adapter is trusted code.

## Decisions and authority

A local decision includes `v:1`, `decisionId`, the complete native identity,
`revision`, `action:allow_once|decline|choose|open`, `createdAt`, `leaseDeadline`,
and optional native `optionId` for `choose`. Watch `choose0/1/2` maps to exact
optionIds at that revision; native IDs never appear on BLE.

For approval/choice the broker persists `submitting` plus its decisionId BEFORE
publishing a0600 decision file atomically. It never retries a persisted dispatch.
An adapter exclusively claims an exact matching decision and consumes it once.
Crash before/after consumption can lose delivery; it must never cause replay.
On restart submitting becomes UNKNOWN and all approval capabilities remain
disabled until a fresh native heartbeat. Already dispatched requests stay
disabled even after heartbeat. After15seconds without authoritative resolution,
submitting becomes UNKNOWN. Only a matching explicit `state:resolved` event clears the native request.
Cleared does not imply accepted: cancellation or interruption can also clear it. A transport/file ACK is insufficient.

An adapter MUST re-resolve current exact source/session/run/request/revision,
recheck pending state, native lease, capability and unchanged full scope just
before native execution. The Python reader validates identity/lease/options but
cannot prove native state. It must emit resolved only after authoritative native
acknowledgment or confirmed cancellation. Optional bridge/card `outcome` is
allowed/declined/answered/cancelled and is valid only with state=resolved.
An absent outcome means unknown/cleared; show RESOLVED. ACCEPTED/DECLINED labels
require explicit corresponding authoritative outcomes. A later native outcome
can enrich a cleared record once, without changing its immutable scope. Open is an identity-bound routing request; unsupported routing
must report unsupported instead of claiming a particular session opened. Open
never changes native approval state. No keyboard approval path exists here.

## BLE wire

Service `7F0D4E66-2AC2-4A71-BFBE-4EF61A0E5C11`; card-write `…5C12` must support
ATT withResponse; action `…5C13` must support read+notify. Firmware must require
encrypted access independently of quota/HID. CoreBluetooth does not expose link
encryption status to this client. Physical pairing/encryption requires device
acceptance testing.

Cards are complete JSON<=512 bytes, with required keys:
`v:1,g:uint32,id:uint32,r:uint32,src,kind,title,model,detail,state,count,ttl,alert,decide`.
`g` changes on reconnect; id is an opaque nonzero queue identifier; id0 means
empty inbox. `r` is native revision. `state` is pending/submitting/resolved/
unknown/expired. `ttl` is conservative remaining milliseconds<=15000;
`alert`0none/1done/2pending approval or input/3failure. Optional `options`
contains only display labels. `ack:uint32` is the highest action sequence
processed in the current generation (default0), **only a transport acknowledgment**.

Display limits are title48, model32, detail192 ASCII bytes, options3×24bytes.
If full scope cannot fit those limits or512-byte JSON, card becomes
`title:"Open on Mac",detail:"Full scope available on Mac",decide:false` with
options omitted. Approval detail is never silently truncated.

Actions are complete JSON<=160 bytes:
`v:1,g:uint32,id:uint32,r:uint32,action:string,seq:uint32`.
Action names: next/previous/read/close/dismiss/open/allow_once/decline/choose0/
choose1/choose2. `seq` is optional for older producers but firmware should always
send a strictly increasing positive seq per connection; duplicates do not repeat
actions. Keep at most one firmware action pending until card.ack acknowledges
its seq. New connection generations reject old action records. Read/notify can
both deliver an action; notify is a hint when MTU truncates JSON, and a complete
read at most once per second recovers it. Unknown or stale actions fail closed.

A card needs a single negotiated ATT write capable of its full length; the
client does not fragment or truncate frames if the link cannot accept them.
It reconnects only to the explicitly pinned device. ATT ACK only advances the
transport write slot. No read, ATT ACK or notification delivery implies that a
user saw the card or that a native action succeeded.

## Verification

`sh scripts/test_task_notifications.sh` compiles/runs the real core standalone
Swift harness, Python unit tests, and a Python→Swift→Python private filesystem
roundtrip including restart UNKNOWN and authoritative resolution. XCTest sources
also live in the normal package tests; a full Xcode XCTest SDK is required.
Synthetic tests/builds establish no physical C152 acceptance.
