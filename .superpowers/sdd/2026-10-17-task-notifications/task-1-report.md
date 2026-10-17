# Task 1 implementation report

Status: implemented and validated in software; native provider integrations and
physical C152 acceptance are outside this task. No install, flash, native approval,
provider configuration change, or real task ingestion was performed.

## Implemented

- Exact native source/session/run/request/revision identity; opaque uint32 wire
  IDs and connection generation; immutable per-revision decision scope.
- Private0700 directory/0600 files, no-follow descriptor-relative access,
  exclusive broker lock, atomic inbox/decision publication, durable consume-once
  handling, bounded64-record queue with overflow retained for retry rather than
  dropping live approval requests.
- Native capability/lease/display checks for allow-once/decline and finite input
  options; persist-before-publish dispatch, no approval replay after restart,
  UNKNOWN on lost receipt, explicit native resolution only, with resolved-as-cleared distinct from optional
  authoritative allowed/declined/answered/cancelled outcome.
- Pending priority and original per-revision FIFO, browsing/read pins, close to
  unpin, heartbeat alert suppression, one120-second reminder per pending request,
  completion/failure alerts, reconnect suppression.
- Persistent notification-only BLE transport pinned to existing device UUID;
  dedicated GATT service, withResponse complete frames, read+notify actions,
  current-generation seq dedup and card ack. Short-MTU notify can trigger a full
  read; periodic reads recover missed hints. Transport ACK never resolves native
  actions. Device-side encryption still needs physical validation.
- `--notifications-dir` only in real `--watch --device-id` mode, started before
  quota reads and independent of quota failure; default behavior unchanged.
- Python adapter helper, XCTest sources, standalone real Swift behavioral harness
  and a Python→Swift→Python filesystem integration test.

Exact bridge/wire contract and trust boundaries: `companion/TASK_NOTIFICATIONS.md`.

## Red/green evidence

Initial preimplementation tests failed on missing Swift model/broker/store types
and missing Python helper. The standalone invocation was then corrected to use
`-parse-as-library`. Subsequent real behavioral reds caught:

- heartbeat rearming alert;
- concurrent broker allowed;
- queue overflow record removed instead of retained;
- resolved completion missing completion alert.

Each was corrected and the same real-code harness passed afterwards. Expanded
scenarios cover exact request/session equality, duplicate/stale revisions,
immutable scope, absent/expired capability, idempotent dispatch, resolution before
click, restart requiring refresh, no retry of persisted dispatch, lost native
receipt UNKNOWN, stale connection actions, browse pin, finite native option
mapping, reminder firstSeen across heartbeat, wire identity privacy, queue bounds,
symlink rejection, and transport seq acknowledgement.

## Exact commands and outcomes

Run from checkout root:

```sh
sh scripts/test_task_notifications.sh
```

PASS: standalone Swift behavioral executable plus7 Python unittest tests,
including the real private-bridge roundtrip, consume-once, restart UNKNOWN and
explicit resolution. The script sets both Swift module-cache environment
variables, uses `swiftc -parse-as-library` with the model/store/broker and
standalone scenario sources, and keeps binaries/real fixture files in a unique
`/private/tmp/stopwatch-notification-check.XXXXXX` directory removed on exit.

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/stopwatch-swift-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/stopwatch-swift-module-cache \
  swift build --package-path companion --disable-sandbox \
  --cache-path /private/tmp/stopwatch-swift-cache
```

PASS: complete canonical executable debug build, exit0. SwiftPM reports its
pre-existing inaccessible user-level configuration/security cache warnings; no
source/compiler errors.

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/stopwatch-swift-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/stopwatch-swift-module-cache \
  swift build --package-path companion --disable-sandbox \
  --cache-path /private/tmp/stopwatch-swift-cache -c release
```

PASS: complete canonical executable release build, exit0.

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/stopwatch-swift-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/stopwatch-swift-module-cache \
  swift test --package-path companion --disable-sandbox \
  --cache-path /private/tmp/stopwatch-swift-cache
```

BLOCKED by installed CommandLineTools SDK: exit1, `no such module 'XCTest'` in
existing `CompanionRuntimeTests.swift` before any package tests execute. No Xcode
or SDK installation attempted. This is not reported as passing full Swift tests;
the standalone harness executes the new real core without XCTest.

```sh
companion/.build/debug/codex-watch-companion --demo --json-only
companion/.build/debug/codex-watch-companion \
  --notifications-dir /private/tmp/synthetic-notifications --demo --json-only
git diff --check
```

PASS: existing demo JSON remained `{"remaining_percent":59,"reset_in_seconds":3600}`,
exit0. Incompatible notification mode rejected with explicit real-watch-mode
usage error, exit1, before notification runtime starts. Diff whitespace check
passes. No Bluetooth/native application behavior is inferred from these checks.

## Concerns and acceptance boundaries

- This is a generic integration bridge, not live four-harness support. Read-only
  research in `harness-contracts.md` found: Codex has no verified connection to
  the installed desktop's session owner; DeepSeek needs an explicitly installed
  Host plugin plus exact approval/audit correlation and competing UI cancellation
  testing; SUPER has no public exact approval/answer/resolved-verdict contract and
  no live event schema was observed; Hermes requires the same-owner Desktop
  backend connection and authoritative outcomes, with installed/source equality
  unproven. All native-decision capabilities remain off until those gates pass.
- Real adapters must re-resolve exact current native request/revision/capability
  and immutable scope immediately before executing. No native adapter is enabled
  in Task1; unsupported open routing cannot claim an exact session was opened.
- An approval can be lost across an adapter/process crash by design. It becomes
  UNKNOWN and requires native reconciliation; automatic replay is forbidden.
- No build/test establishes C152 pairing/encryption, ATT MTU, rendering, touch,
  confirmation hold, haptics, physical display receipt, or native decision success.
- Full XCTest suite requires full Xcode's XCTest SDK. Existing physical firmware,
  quota, HID/navigation and microphone runtime were not exercised or changed by
  this task except the opt-in companion lifecycle addition.
- Private storage validates ownership/mode/no-follow paths. Same-user adapter
  processes are trusted; it is not a sandbox against a compromised same-user app.
