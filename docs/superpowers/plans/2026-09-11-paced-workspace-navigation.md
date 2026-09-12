# Paced Workspace Navigation Implementation Plan

> Execute with executing-plans in this session, serially; no subagents.

**Goal:** Reproduce the user-verified paced sequences in Companion with safe Hermes Control ownership.

**Architecture:** Preserve the existing low-level poster, but submit one stroke at a time from a MainActor state machine. Inject uptime, the existing repeating scheduler, trust and identity checks. Separate fixed sequence construction from delivery. Watch-only lifecycle owns cleanup.

**Tech Stack:** Swift, AppKit, CoreGraphics, macOS 14+, fixed MacOSX15.4 SDK.

## Global Constraints

Progress (2026-09-12): Tasks 1 and 2 implemented and committed. Task 3 automated
verification passed except the documented XCTest environment limitation;
installation completed; user-observed acceptance remains pending. Detailed evidence:
`2026-09-12-paced-navigation-verification.md`. The step lists below preserve the
original execution checklist; this progress summary is the current status.

Approved spec: `../specs/2026-09-11-paced-workspace-navigation-design.md`.
Continue existing isolated branch from `a525d1c`; no firmware, protocol, mappings,
LaunchAgent changes, merge, push, global events, content reads or TCC resets.
Ordinary strokes >=30 ms apart; busy input ignored; cleanup only owned keys.

## Task 1: Paced emitter and ownership

Files: `SuperEngineeringKeyEmitter.swift`, new `WorkspaceKeySequence.swift`,
`SuperEngineeringKeyEmitterTests.swift` under the existing companion source/test roots.

- [ ] Add a failing test that right without a Hermes selection posts nothing:
  `XCTAssertTrue(emitter.emit(.confirmHermesSelection, to: hermes)); XCTAssertTrue(poster.deliveries.isEmpty)`.
- [ ] Regenerate the private Swift harness, run that test against current code,
  and record the expected assertion failure (not an import/compiler failure).
- [ ] Introduce `WorkspaceKeySequence.strokes(for:controlHeld:) -> [ProcessKeyStroke]`
  with literal fixed key sequences; no source or target text parameters.
- [ ] Extend emitter init with injectable `WorkspaceModeScheduling`, uptime and
  trust closures. Preserve `emit(_:to:) -> Bool` as acceptance, add `cancel()`
  and `stop()`. Expose no production test-only accessors.
- [ ] Add failing timing/ownership tests using a manual repeating scheduler and
  real emitter: first stroke only at acceptance; 29ms cannot send the second;
  at 30ms it can; delayed ticks send only one stroke. Drain all six SUPER strokes.
- [ ] Implement timer generation invalidation, actual-submitted held-key tracking,
  monotonic minimum gap, no busy queue, complete Hermes repeat/up/right behavior.
- [ ] Add cancellation tests at each partial sequence, wrong foreground/PID,
  trust revoked, failed poster, repeated cancel/stop and stale timer callbacks.
  Routine cleanup drains key-ups with spacing; stop best-effort releases immediately.
- [ ] Run all harness bodies and warnings-as-errors release build, then commit
  `fix: pace targeted navigation and retain Hermes selection`.

## Task 2: Watch lifecycle and routing

Files: new `WorkspaceNavigationLifecycle.swift`, router, `main.swift`, diagnostics,
router tests and new lifecycle tests.

- [ ] Test router cancellation precedes accepted left cycle; denied trust and
  wrong foreground cancel outstanding ownership. Native Codex events never emit.
- [ ] Add `WorkspaceNavigationLifecycle.start/cancel/stop` using a foreground
  observer and emitter; test observer callbacks stop/cancel once and late callbacks
  after stop cannot resume. Start only in existing real-watch gate.
- [ ] Wire HID attach/removal to cancellation, startup failure and defer shutdown
  to stop. Retain lifecycle while listener runs. Reuse original LaunchAgent.
- [ ] Distinguish fixed `sequence_accepted`, `sequence_busy`, `submitted` and
  failure status categories; no per-event arbitrary data logging.
- [ ] Run harness and mode smoke tests, inspect wiring and commit
  `fix: release navigation ownership across watch lifecycle`.

## Task 3: Verification, versioned package and installation

Files: app Info.plist, packaging fixture version expectations, companion README,
English/Chinese README and sanitized acceptance record.

- [ ] Set 0.1.2/build 3, explain pacing and held-selection behavior plus cleanup
  limits. Run packaging fixture tests, all harness bodies, release build with
  `swift build --package-path companion -c release --sdk <15.4-sdk> --scratch-path <private-scratch> --disable-sandbox -Xswiftc -warnings-as-errors`.
- [ ] Run release `--demo --json-only`; attempt `swift test` with isolated caches.
  Missing XCTest remains an environment limitation, not a passing result.
- [ ] Review entire change against approved spec and commit docs/version.
- [ ] Package clean source; privately back up current signed app and verify original
  plist equality. Install only executable/metadata with original signing identifier,
  update outer modification time preserving creation time; restart original label.
- [ ] Ask for permission reauthorization only if needed; perform user-observed SUPER
  directions and Hermes repeated selection/right-open plus lifecycle regression.
  Record untested physical checks explicitly. No firmware flash or automatic cleanup
  of diagnostic apps. Commit sanitized results separately.
