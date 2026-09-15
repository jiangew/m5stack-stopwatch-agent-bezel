# Robot Home verification

Scope: matched C152 USB-mic firmware and Companion 0.1.3 (build 4).
Baseline: `f3be5a4`. Serial execution; no merge or push authorized.

## Source verification, 2026-09-15

- Native suite: 16 test executables passed.
- Current-source Swift harness: 80 test bodies passed with warnings as errors;
  this is not XCTest.
- Full XCTest attempted with the fixed macOS 15.4 SDK: blocked at compilation
  by `no such module 'XCTest'`; not passed.
- USB-mic PlatformIO build: succeeded; no warnings in captured build log.
- Native preview: nine Home scenes generated. Build succeeded with an existing
  third-party M5GFX variable-length-array warning.
- Synthetic `--demo --json-only` smoke: valid quota JSON, exit zero; not a live
  quota, microphone or hardware test.
- User approved the native robot appearance before installation.
- Fixed-SDK release build passed with warnings as errors. Packaging fixture
  verified version 0.1.3/build 4, source/time metadata, signing and overwrite guards.
- Renderer, device integration and Companion integration committed separately.
  No installation or flash has been performed for Home yet.

## Serial review

- Standards: no blocking violation identified against AGENTS.md; runtime
  identities, local-data boundaries, dedicated USB input-only audio and upstream
  notices remain unchanged. Existing compact renderer style is a readability
  limitation, not a hardware-validation claim.
- Spec: inspected Home pinning, left-cycle activation, Home acknowledgment,
  lease ownership, local input isolation, key release and main-loop frame limits.
  Corrected the Home transition log label; extended tests to cover circular
  head geometry across animation phases, charging and Home physical-key policy.
- Mode gating, callbacks and retry paths run in the current-source harness.
  API submission and simulated rendering do not prove device/app behavior.

## Physical acceptance

All Home device behavior is **unverified**: boot/offline Home, gestures, four-page
cycle, previous navigation, no background actions, power/sleep, heartbeat-loss
fallback, reconnect, microphone recording, quota and automatic startup.
Previous-version acceptance does not validate this matched update.

## Installation gates

Preserve signed Companion and firmware backups; verify original service config
unchanged. Fresh download-device enumeration and exact-port consent are required
before flashing. Never use historical port approval. Keep the Hermes auto-launch
task disabled, preserve audio/input identities, and do not reset permissions
unless a newly observed permission problem requires user reauthorization.
