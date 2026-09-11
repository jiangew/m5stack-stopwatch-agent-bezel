# Navigation isolation pre-install verification

Date: 2026-09-11. Branch: `feature/hermes-tap-launch`.
Implementation reviewed: `34c1049..e0c36a4`. No merge or push.

## Automated evidence

- All 13 native test executables passed with C++17 and warnings-as-errors.
  Layout tests use a minimal M5GFX enum shim; this is not a hardware test.
- USB-mic PlatformIO build passed, with no warnings in the build output.
  Firmware SHA-256:
  `0805baf173966f18239e1b5d3610d6078e27348e127695ecf646895331a9534c`.
- Native preview built and generated Codex, SUPER and four HERMES states.
  Existing upstream M5GFX VLA and empty-object archive warnings remain in this
  preview build; it is not described as warning-free.
- Companion release build passed with MacOSX15.4.sdk, isolated fresh caches and
  warnings-as-errors. Synthetic `--demo --json-only` passed.
- All 68 temporary Swift harness test bodies passed, including diagnostic timer,
  signal lifecycle and routing checks. These are not a full XCTest execution.
- `swift test` was attempted with the same SDK and fresh scratch storage. It
  failed at test-module compilation: `no such module 'XCTest'`. XCTest remains
  unverified due to this environment limitation.
- Versioned packaging fixture tests and strict signature verification passed.
- USB microphone validator synthetic self-test passed; no recording was made.

## Serial review

Reviewed gesture origin/release ownership, mode transitions, per-device decoding,
MainActor routing guards, diagnostic lifecycle and fixed-enum privacy boundaries,
USB audio isolation, and metadata packaging. No blocking findings identified.
Shortcut mappings are unchanged. Key submission does not prove UI receipt.

## Installation and physical acceptance

Pending. The existing installed Companion and firmware have not been changed by
this verification. Prepare a matched pair and private recovery backups, then
obtain fresh exact-port authorization before flashing. Do not send the new
diagnostic signal to an older Companion process.

Hermes navigation, SUPER navigation, absence of background Codex actions, Finder
metadata, microphone, reconnect, lease expiry and launch regression checks for
this matched version are all **not yet physically verified**.
