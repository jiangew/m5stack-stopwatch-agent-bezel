# Workspace Navigation Isolation Implementation Plan

> Execute serially in this session using executing-plans and TDD. No subagents.

**Goal:** Stop native Codex direction events leaking from dedicated workspaces,
then localize and verify Hermes navigation independently.

**Architecture:** Latch the gesture's source at press time, emit one event family,
preserve origin through Companion decoding, and route only to the matching active
workspace. Add bounded opt-in diagnostics without changing shortcut mappings.

**Tech stack:** C++/ArduinoJson, USB-mic PlatformIO target, Swift/AppKit/IOKit.

## Constraints and baseline

- Continue `feature/hermes-tap-launch` from `34c1049` in the existing worktree.
- Approved specs: `../specs/2026-09-10-workspace-navigation-isolation-design.md`
  and `../specs/2026-09-10-companion-version-metadata-design.md`.
- Preserve current installed app and device until matched builds pass. No merge,
  push, default-wireless behavior change, global keys or application-content reads.
- Do not reset permissions automatically. Source changes and installation can
  change signing requirements; validate actual permissions after installation.
- Each task: failing test first, minimal implementation, fresh verification,
  serial self-review and independent commit. Never call harness results XCTest.

## Task 1 — Firmware gesture origin and exclusive output

Files: new `include/WorkspaceNavigation.h`, new
`simulator/workspace_navigation_test.cpp`, existing `src/main.cpp`,
`src/CodexMicroBle.cpp`, `include/CodexMicroBle.h`.

- [ ] Introduce a pure gesture-origin model with family (`Native`, `Dedicated`),
  workspace (`Super`, `Hermes`), direction, and phase. Its active origin is stored
  on accepted press, consumed once on release/cancellation and cleared on detach.
- [ ] First test that Codex press/release remain native, SUPER/Hermes are dedicated,
  switching modes before release preserves the press family, and second release
  produces no message. Test waiting Hermes and all four directions.
- [ ] Compile the standalone policy test with
  `c++ -std=c++17 -Wall -Wextra -Werror -Iinclude simulator/workspace_navigation_test.cpp -o /private/tmp/workspace-navigation-test`
  and run it. Observe RED before adding production policy, then GREEN.
- [ ] Serialize dedicated events with exactly method/params and the three string
  params workspace/direction/phase, using the existing Report ID 6 framing:

```json
{"method":"host.workspace_navigation","params":{"workspace":"hermes","direction":"up","phase":"press"}}
```

- [ ] Route touch release, power-off and mode-transition cancellation through the
  latched origin rather than unconditionally calling `sendJoystick`. A Codex press
  may still require a native release during transition; never dual-send presses.
- [ ] Restrict new output selection to `CODEX_STOPWATCH_USB_MIC`. Preserve default
  firmware, haptics, palette, wake consumption and central power behavior.
- [ ] Add serialization assertions: dedicated output contains no `v.oai.rad` and
  native output contains no `host.workspace_navigation`. Run existing native
  input/gesture/lease tests, `git diff --check`, and `pio run -d usb-mic`.
- [ ] Commit `feat: isolate dedicated workspace direction reports`.

## Task 2 — Strict decoding and origin-aware routing

Files: `HIDShortcutDecoder.swift`, `SuperEngineeringCommandRouter.swift`,
`WorkspaceCycleController.swift`, listener plumbing and corresponding tests under
`companion/Tests/CodexWatchCompanionTests`.

- [ ] Keep existing direction enum and introduce an event envelope that carries
  `native`, `super`, `hermes`, or center-action origin. Do not discard origin
  before the router. Expose selected workspace read-only through `WorkspaceCycling`
  so real and test implementations use the same guard.
- [ ] Write RED cases for valid press/release fragments, report ID duplication,
  missing/extra/wrong-type/unknown fields, repeated press, wrong-origin release,
  stale source, and center-action/gesture cooldown interaction.
- [ ] Maintain one active origin/direction latch per device decoder. Press during
  cooldown still consumes its release gate; invalid events do not rearm it.
  A matching release rearms even after a legitimate workspace transition. Reset
  removes only that device's decoder state. Keep the 800ms shared action cooldown.
- [ ] Dedicated up/down/right require source=selected=actual foreground profile,
  navigation enabled, Accessibility trusted, and existing emitter PID/bundle
  checks. Dedicated left requires matching selection and retains the cycle logic.
- [ ] Native up/down/right cannot invoke SUPER/Hermes keys. Native left retains
  Codex cycle entry, but is ignored while a dedicated workspace is selected.
  Waiting Hermes directions remain ignored. Do not change key codes or modifiers.
- [ ] Run targeted RED/GREEN harness, then all test bodies using the existing
  `/private/tmp/agentbezel-hermes-tap.cprhZE/make-harness.rb` if still available;
  regenerate temporary harness support if unavailable, never commit it as XCTest.
- [ ] Commit `feat: route navigation by explicit workspace origin`.

## Task 3 — Bounded in-process diagnostic activation

Files: new `NavigationDiagnostics.swift`, its tests, and watch lifecycle in
`main.swift`; add narrow diagnostic hooks in decoder/router/emitter.

- [ ] Choose SIGUSR1 as the opt-in trigger, installed only in real watch mode via
  a retained DispatchSourceSignal on the main queue. No plist arguments change,
  second watch, global key hooks or new app-launch path.
- [ ] Test an injectable uptime/logger: initially zero records; trigger enables
  at most 120 records over 300 seconds; repeated triggers cannot extend or refill
  the per-process budget. Stop cancels the source and invalidates late callbacks.
- [ ] Log fixed enums only: decoded source/direction, selected-state gate,
  foreground-profile match, Accessibility result, emitter identity guard, and
  submitted/failed outcome. Never log PID, arbitrary bundle name, raw bytes,
  payload, device identity or application content. Submission is not receipt.
- [ ] No diagnostics or signal-handler changes in demo/json/one-shot/bootloader
  modes. Preserve existing shutdown signal behavior and MainActor serialization.
- [ ] Test mode gates, expiry, cap, privacy field allowlist and lifecycle. Run all
  Swift harness bodies and warning-free release build.
- [ ] Commit `feat: add bounded workspace navigation diagnostics`.

## Task 4 — Reproducible versioned packaging

Files: `companion/app/Info.plist`, new `scripts/package_companion.sh`, new
`scripts/package_companion_test.sh`, companion documentation.

- [ ] Set release version `0.1.1` and build `2`. Packaging must require a clean
  source checkout, take the already-built release executable, and produce a new
  private candidate app without overwriting the live installation.
- [ ] Before signing, record full `git rev-parse HEAD` as AgentBezelSourceCommit
  and actual UTC build timestamp as AgentBezelBuildTimestamp. Preserve identifier,
  executable name, background mode and permission descriptions.
- [ ] Add temporary-fixture tests for exact version/build/commit/timestamp fields,
  rejection of dirty inputs, and preservation of unrelated plist keys. Verify
  the complete candidate with `codesign --verify --strict`.
- [ ] Installer must preserve outer app creation time and set its modification
  time to installation completion after signing. Verify signature again afterward.
- [ ] Commit packaging changes before producing the final clean-checkout release;
  metadata records that source commit, not a later acceptance-doc commit.
- [ ] Commit `build: stamp companion version and source metadata`.

## Task 5 — Full pre-install verification and docs

- [ ] Update English/Chinese README, companion README and protocol docs with the
  dedicated event, matched-version requirement, diagnostic trigger and rollback.
- [ ] Run all native tests, unchanged native previews, USB-mic build, full Swift
  harness and synthetic `--demo --json-only` smoke. Verify no native event leakage
  in unit traces for dedicated modes, including cancellation paths.
- [ ] Build Companion with MacOSX15.4.sdk, macOS14 target, warnings-as-errors and
  module/cache/scratch paths under a new private `/private/tmp` directory. Attempt
  `swift test` with the same SDK and writable caches; separately report missing
  XCTest if it persists.
- [ ] Review the complete diff since `34c1049`: lifecycle, mode transitions,
  diagnostics privacy, route guards, microphone boundaries and version provenance.
- [ ] Commit docs separately. Do not treat successful synthetic tests as Hermes
  physical success or as proof that Codex ignores the new method.

## Task 6 — Matched installation and physical gates

- [ ] Save signed Companion and known-good firmware recovery artifacts privately,
  verify their signatures/hashes and state whether firmware is a build or readback.
  Preserve existing backups, plist, device binding and Codex paths.
- [ ] Install the new Companion using the existing signing identifier. Verify
  signature, installed hash, version/build, timestamps and original plist equality;
  restart only the original job. Avoid gestures until the matched firmware is on.
- [ ] Re-enumerate bootloader ports, identify the unique device, ask for current
  exact-port authorization, then upload only the USB-mic image. Never reuse a
  historical port approval.
- [ ] Reauthorize only if needed. If authorization identity mismatch recurs, stop
  installation troubleshooting rather than automatically resetting permissions.
- [ ] Confirm the new watch handler is installed and the original job has one
  live process before sending SIGUSR1 to that exact PID. Test one direction at a
  time with user observation, while collecting only the bounded diagnostic enums.
- [ ] Require independently: SUPER directions succeed, Hermes directions succeed,
  and Codex has no background action. If Hermes submission succeeds but UI does
  not respond, retain evidence and stop for a separately scoped correction; do not
  change mappings or globally inject keys as an incidental workaround.
- [ ] Regress cold/background central launch, three-page cycle, waiting isolation,
  800ms debounce, Codex controls, reconnect, lease expiry, quota and USB microphone.
  Ask the user to confirm Finder version and modification time.
- [ ] Commit sanitized acceptance results, explicitly marking unobserved items.
  On critical regression restore matched components; any firmware rollback requires
  fresh device enumeration and explicit port confirmation. No merge or push.
