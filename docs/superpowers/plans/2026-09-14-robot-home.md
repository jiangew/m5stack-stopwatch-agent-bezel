# Robot Home Implementation Plan

> **For agentic workers:** Use executing-plans, serially in the current session.
> No subagents. Each task has a failing test, implementation, verification and
> independent commit. Preserve all installed components until final verification.

**Goal:** Install the approved robot Home as the fourth C152 USB-mic workspace.
**Architecture:** Firmware owns local animation and a Home fallback handshake;
Companion owns explicit workspace selection and app activation. Fixed HID RPCs
carry modes/navigation only. Home suppresses all app-directed inputs except left.
**Tech Stack:** Arduino C++17/M5GFX, ArduinoJson 6, Swift/AppKit/IOKit; macOS 14+.

## Global constraints

- Approved design: `docs/superpowers/specs/2026-09-14-robot-home-design.md`.
- Baseline `f3be5a4`; branch `codex/robot-home`; no merge/push in this request.
- USB-mic only. Preserve default wireless, audio, app identities, permission
  boundaries, launch configuration, targeted key pacing and recoverable backups.
- 5-second heartbeat, 15-second lease, 800ms host action debounce; local animation
  20fps maximum, 2400ms replace-not-queue reaction; short tap less than 500ms.
- Native tests and Swift harness are separate from XCTest; report environmental
  XCTest failures honestly. Fresh exact download-port consent before any flash.

## Task 1: Lease and synchronization

Files: `include/WorkspaceMode.h`, new `simulator/robot_home_lease_test.cpp`.

- [ ] Test strict Home/leased-Codex parsing against the real parser; initial RED:
  `assert(parseParams("{\"mode\":\"home\"}") != Command::Invalid);`.
- [ ] Add Home and CodexLeased commands and optional Home fallback construction:
  `Lease(Mode fallback = Mode::Codex)`; legacy construction remains unchanged.
- [ ] Home-fallback leases start blocked until Home acknowledgment, then allow
  same-owner work commands. Timeout/disconnect blocks old renewals; Home ACK
  unblocks. Expose `needsHomeSync()` and `hostReady()` for integration.
- [ ] Test every invalid key/type/TTL, owner/nonowner renewal, Codex expiry,
  wraparound, Home ACK, repeated reconnect and no dirty-on-renewal behavior.
- [ ] Compile with `clang++ -std=c++17 -Iinclude` and cached ArduinoJson include;
  run new and existing workspace lease tests; commit independently.

## Task 2: Local animation and renderer

Files: new `include/RobotHomeUi.h`, `include/RobotHomeInteraction.h`, matching
`simulator/robot_home_*_test.cpp`; extend `simulator/preview_main.cpp`.

- [ ] Test reaction replacement at 2400ms, time wrap, idle frame limiting and
  no frames while asleep/off-page/overlay. Test a head-bounded tap tracker with
  press/release bounds, maximum movement and consumed wake gesture.
- [ ] Implement deterministic `robot_home::Animation` and `Tap` independent of
  hardware; random choice takes injected entropy and excludes current expression.
- [ ] Port the approved yellow helmet/blue eyes/silver mask into M5GFX primitives;
  state contains only time/expression, link, battery, charging and power overlay.
- [ ] Recording-surface tests assert draw bounds and battery group alignment;
  native preview exports Home idle/happy/surprise/sleep plus unknown/low/charging
  battery scenes to private temporary files. Commit renderer and tests.

## Task 3: Device integration and input isolation

Files: `include/CodexMicroBle.h`, `src/CodexMicroBle.cpp`, `src/main.cpp`,
`include/WorkspaceNavigation.h`, `include/WorkspaceInputPolicy.h` and native tests.

- [ ] Tests: Home only emits dedicated left press/release; all other Home gestures
  produce no RPC; default native navigation stays unchanged.
- [ ] USB-mic state/lease start at Home; disconnect/expiry update snapshot to
  actual lease mode. Publish fixed `host.workspace_action` / `show_home` at most
  once per second while synchronization is required; ACK is Home mode output.
- [ ] Render Home separately; head tap and up/down/right act locally; left only
  sends when hostReady, otherwise shows CONNECT MAC. No success haptics for Home.
- [ ] Release old input on transitions, consume first-wake gesture, preserve
  power hold, suppress physical app buttons and stale Agent completion alerts.
- [ ] Gate animation redraws by visibility and 50ms minimum interval; never call
  noteActivity from animation. Run native suite and USB-mic build; commit.

## Task 4: Companion selection, writer and router

Files: workspace mode writer/coordinator/cycle, HID decoder, command router,
diagnostics and their existing XCTest files; add Home-focused XCTest coverage.

- [ ] RED: startup is Home and foreground changes do not activate or leave it;
  cycle through Home/Codex/SUPER/Hermes/Home, including Hermes pending/error.
- [ ] Add `.home` display mode; selected Mac profile becomes optional for Home.
  Decoder accepts only Home left and strict `show_home`; the latter is control
  resync, not user cooldown input, and clears obsolete active-press state.
- [ ] Fixed writer sends Home and leased Codex; heartbeat covers all work pages.
  Start/attach/detach/stop select Home. ACK Home before a work activation; failed
  output keeps the device guarded, with normal limited retries.
- [ ] Router cancels owned keys on Home resync/cycle, blocks Home app commands;
  foreground callbacks cannot override pinned Home or revive late Hermes launch.
- [ ] Extend real tests for malformed messages, repeat/release gating, heartbeat
  no-launch, permission loss, one-device removal and stale callbacks. Rebuild the
  private harness from current source, run release/smoke; commit independently.

## Task 5: Review, documentation and matched installation

- [ ] Run complete native tests, native previews, USB-mic build and fixed-SDK
  Companion build. Attempt XCTest; run current-source harness separately.
- [ ] Review complete branch against approved design; fix regressions with tests.
  Update bilingual README, Companion README, protocol and layered acceptance.
- [ ] Present actual native Home preview before installing; browser acceptance
  alone is not proof of native fidelity. Update Companion version/build metadata.
- [ ] Private signed-app and firmware backups, hashes and unchanged plist check;
  install matched Companion once, preserving identity and original service.
- [ ] Re-enumerate download device, request exact current port confirmation,
  then USB-mic upload. Retain all recovery artifacts.
- [ ] User-observed Home/offline/reconnect/animation/cycle/navigation/power tests,
  audio recording and deletion, quota and single-instance checks. Record only
  observed results; commit documentation. Do not merge or push.
