# Task Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. User has already authorized execution; do not ask again between tasks.

**Goal:** Implement a local multi-harness notification inbox and request-bound allow-once/decline flow, exposing verified native capabilities honestly.

**Architecture:** A Swift queue and private file bridge run in Mac Companion. A persistent CoreBluetooth notification transport writes bounded cards and reads opaque watch actions on dedicated private GATT characteristics. Harness adapters publish native events and consume exact decisions; firmware displays bounded cards and prevents implicit or stale approval.

**Tech Stack:** Swift5.10/macOS14, Foundation/AppKit/CoreBluetooth; Arduino C++17/ArduinoJson6/M5Unified; dependency-free Python/Node adapter clients and tests.

## Global Constraints

- C152 only; no build or mock proves physical acceptance. No flash/install/provider configuration mutation in this implementation phase.
- Preserve existing HID, quota, navigation, IMU, power and USB input-only audio behavior.
- Source enum is codex, deepseek, super, hermes; models never identify a task.
- Mac owns durable queue; local notifications directory0700, files0600, bounded payloads, no symlink following; synthetic tracked samples only.
- Native allow-once/decline requires pending source/request/revision, current lease, fully displayable scope, and adapter capability. Read/dismiss/open never decides. No keystroke approvals.
- Notification GATT service7F0D4E66-2AC2-4A71-BFBE-4EF61A0E5C11, card-write characteristic ending5C12, action read/notify ending5C13. Dedicated encrypted read/write, independent of quota/HID.
- Wire card JSON maximum512 bytes, ASCII display fields; opaque id/revision/generation are uint32; v=1. Keys: v,g,id,r,src,kind,title,model,detail,state,count,ttl,alert,decide; optional options array2..3 ASCII labels<=24 bytes; optional muteLegacyCodex boolean defaultsfalse and explicitly owns legacy completion presentation for15s channel lease; optional ack uint32 echoes a processed action sequence, optional outcome allowed/declined/answered/cancelled only when resolved. src uses source enum; kind done/approval/input/failed; state pending/submitting/resolved/unknown/expired; ttl milliseconds <=15000; alert0..3; decide boolean. Actions: v,g,id,r,action; action next/previous/read/close/dismiss/open/allow_once/decline/choose0/choose1/choose2; firmware always sends seq uint32 and holds one action until ack. Notifications are hints; read recovers full action. Snapshot id0 is empty inbox. Invalid or oversize payloads fail closed, never silently truncate approval detail.
- Local bridge input options uses options labels and equally sized distinct optionIds (opaque native IDs<=256 bytes); choice dispatch includes action choose and optionId. Local event max8192 bytes. Queue max64; refuse new pending overflow, evict only dismissed/resolved entries.
- Confirm holding800ms, movement<20px. Toast5000ms, lease15000ms. New events do not replace an open detail/confirmation. Haptic candidate176/30ms, gap120ms, no audio during active microphone.
- Before Swift commands use CLANG_MODULE_CACHE_PATH=/private/tmp/stopwatch-swift-module-cache and SWIFTPM_MODULECACHE_OVERRIDE same; swift test/build --disable-sandbox --cache-path /private/tmp/stopwatch-swift-cache. Native C++ tests use c++ -std=c++17 -Iinclude; firmware build via existing canonical .pio toolchain without changing baseline source.

### Task 1: Mac broker, private adapter bridge and notification transport

**Files:** Create companion/Sources/CodexWatchCompanion/TaskNotification*.swift and corresponding Tests; modify main.swift option/lifecycle only as needed; create scripts/stopwatch_notify.py plus tests.

**Interfaces:** Produces documented bridge event schema and exact wire cards per Global Constraints. Notification broker ingests versioned source/session/run/request records with stable ID, revision, created time, native lease deadline, kind, title/model/detail and canDecide defaultfalse. It persists queue to private local storage and accepts opaque watch actions. Decisions are atomic files bound to native request and revision, consumed by adapter; resolved alone means cleared; only explicit authoritative outcome allowed/declined/answered/cancelled confirms the native result. A Python helper emits events and reads decisions with private filesystem permissions.

- [x] Write Swift tests for duplicate events, multiple sessions/request IDs, stale revisions, absent/expired capability, decision idempotency, resolution-before-click, restart disabling approval until refreshed, lost receipt UNKNOWN, queue browsing and bounds. Run failing tests before production code.
- [x] Implement broker/model/store with exact-identity equality and bounded inputs; validation failure leaves state unchanged. Expose source-native IDs only to the local adapter bridge; wire IDs are opaque uint32. Save pending dispatch state before publishing decision; on restart never re-emit an approval. Maintain at most one120s reminder and reconnect alert suppression.
- [x] Implement owner-only file inbox with atomic publication and consume-once processing, reject unsafe path/symlink records, keep real task content outside repository. Add Python client with bounded event encoding and identity-bound decision reads.
- [x] Implement persistent CoreBluetooth transport pinned to existing --device-id; discover only new service, require card-write withResponse and action read/notify, bounded frames. Never infer approval success from ATT ACK. Reconnect clears stale actions and resends current card without alert.
- [x] Add --notifications-dir option to real --watch mode; opt-in starts runtime/timer even when Codex quota read fails. Defaults retain existing behavior. No silent app installation/config mutation.
- [x] Run production-core/transport standalone Swift regression suites and Python helper tests; debug/release build. Full XCTest package execution is unavailable in this command-line SDK; this is recorded as a verification limitation. Record commands/results/concerns and commit only this task's files.

### Task 2: Firmware protocol, notification UI and safe input integration

**Files:** Create include/TaskNotification*.h, simulator/task_notification*_test.cpp or .rb; modify include/CodexMicroBle.h, src/CodexMicroBle.cpp, src/main.cpp and simulator/preview_main.cpp narrowly.

**Interfaces:** Consumes exact wire card/action JSON in Global Constraints. New encrypted GATT characteristics under private notification service. Card updates queued on BLE callback and parsed on main loop; action characteristic contains one bounded opaque action with monotonic local sequence if necessary and can be read after a notify miss. Any protocol extension must be coordinated with Task1 in both languages and documented.

- [x] Write failing native tests for payload validation/oversize, lease/wraparound, stale revision, invalid source/state, first-wake touch, entry gesture isolation,800ms stationary confirmation, arrival while detail open, disconnect during confirmation and multiple pulse scheduling.
- [x] Implement bounded card state and separate presentation/gesture model. Firmware never stores native session/request IDs or credentials. Do not allow a text truncation to enable approval; decide must befalse if full context cannot render.
- [x] Add isolated GATT queue and encrypted characteristics; no changes to existing service UUIDs/report map/GATT revision unless required and documented. Send actions only from validated active card, with exact g/id/r.
- [x] Add five-second toast, global inbox badge and detail/decision views; swallow wake and inherited gestures. Restore previous workspace; block underlying HID, power-touch and IMU feedback interference while modal. Physical power holds remain reachable. Nonblocking haptic sequences use176/30ms and120ms gaps; audio stays optional/off for new path initially.
- [x] Run meaningful main-loop integration regression tests including notification arrival during touch, old completion suppression when new notification owns same event, IMU suppression and USB mic preservation. Produce native framebuffer preview using same renderer.
- [x] Build default/native and explicitly existing USB-mic source candidate (build only, no flash); record build/physical boundary and commit this task's files.

### Task 3: Native harness adapters and capability evidence

**Files:** Create notifications/README.md, notifications/adapters/*, notifications/tests/*; update bilingual README and companion/README.md with opt-in setup and limits.

**Interfaces:** Uses Task1 file bridge. Adapters register only capabilities they actually implement, refresh native pending leases, withdraw resolved requests, validate exact identities before decision, return authoritative native outcome. Existing DSH navigation plugin is untouched.

- [x] Inspect installed/relevant official native sources read-only and record versions/checked contracts for all four harnesses. Do not read credentials or dump real sessions.
- [x] Write failing adapter fixture tests for true run completion versus child/tool completion, failed/interrupted turns, multiple sessions, native pending requests and withdrawal/decision correlation.
- [x] Implement native events via verified hooks/plugins where possible. For unverified private/native APIs provide explicit unsupported capability and OPEN ON MAC, not dummy event generators or inferred success. A generic bridge CLI is a developer integration point, never claimed live support by itself.
- [x] Implement exact-session opening where source supplies a verified deeplink/API. Missing routes fall back to application activation with clear status and no claim of exact navigation.
- [x] Run adapter tests and file-bridge end-to-end tests; document per-harness live-versus-fixture coverage and remaining external blockers. Commit adapters and docs.

### Task 4: End-to-end review, candidate packaging and acceptance record

**Files:** Update docs/superpowers/plans/2026-10-17-task-notifications.md and docs/TASK_NOTIFICATIONS.md; adjust implementation only for review findings.

- [ ] Review complete diff against spec and Global Constraints with an independent reviewer; resolve actionable findings with reproducing tests.
- [x] Run standalone Swift regressions/debug/release, Python/Node adapter tests, native notification/main-loop regressions, current navigation/IMU/haptic regressions and relevant firmware builds. Run git diff --check. Full XCTest SDK is unavailable.
- [ ] Record exact branch/SHA, build outputs and source/native/hardware capability matrix. Preserve known-good installed app and firmware. Freeze candidate only if build checks pass.
- [x] If native support or physical acceptance is blocked, describe exact blocker and continue all independent work; do not call entire feature complete. Prepare concrete candidate for user hardware review; flashing needs exact-port confirmation under AGENTS.md.
