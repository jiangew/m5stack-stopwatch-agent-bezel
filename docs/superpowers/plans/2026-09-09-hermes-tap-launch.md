# Hermes central tap launch

Status: Approved; implementation in progress. Baseline: `f7ea349`.

## Approved behavior

- SUPER → HERMES selects an idle watch page without changing the Mac foreground.
- A short central tap requests Hermes activation once; foreground confirmation
  enables navigation. A three-second timeout or rejection requires a new tap.
- Idle/opening/error pages isolate directions, except left → Codex. External
  foreground activation and device reconnect discard pending selection.
- A dedicated `host.workspace_action` / `open_hermes` event shares the existing
  Report 6 transport and 800ms cooldown. It is not a keyboard/Send event.
- Hermes mode may include fixed `idle`, `opening`, or `error` state. The 5-second
  transport heartbeat and 15-second owner lease never launch an application.
- Center taps require both endpoints inside the square, duration under 500ms,
  no swipe, and an already awake screen. Power holds remain unchanged.

## Work sequence

1. Back up and disable only the approved Desktop auto-launch job; retain its
   plist and leave gateway/dashboard unchanged.
2. Add failing tests, implement the shared interaction state, strict event
   decoder and writer, firmware state parsing and center gesture/renderer.
3. Run native tests/previews, USB-mic build, fixed-SDK Swift build and harness;
   attempt XCTest separately. Review changes and update bilingual documentation.
4. Back up matching installed components, install Companion, freshly identify
   and confirm the download port before flashing. No merge or push.
5. Record user-observed launch/navigation/sleep/reconnect/audio/quota acceptance
   separately from automated results. Unobserved hardware remains unverified.

## Recovery

Retain private backups outside Git. Restore matching firmware/Companion on a
critical regression; restoring the Desktop auto-launch strategy is a separate
explicit rollback choice. Never write local identifiers or launch arguments
into this record.

## Evidence

- Desktop job backup hash matches original; job unloaded and disabled.
- Gateway and dashboard plist hashes unchanged after that operation.
- RED evidence: selecting Hermes caused an unwanted launch; idle-state RPC was
  rejected; the new action produced no decoded event. Each now passes.
- Twelve native test executables pass with `-Wall -Wextra -Werror`.
- Sixty Swift test bodies pass in a temporary harness (not a full XCTest run).
- Fixed macOS 15.4 SDK release build passes with warnings treated as errors.
- Full `swift test` reaches the test target but fails because CLT lacks XCTest.
- USB-mic build passes in a no-space temporary source mirror; final log has no
  compiler warnings/errors. The original whitespace path is unsupported by the
  ESP-IDF preparation step and was not used for the release image.
- Native idle/opening/error previews checked for text overlap; native preview
  dependency build retains upstream M5GFX VLA/empty-archive warnings.
- Synthetic audio-validator self-test, HID RPC self-test and demo JSON smoke
  test pass. These do not prove physical audio or HID operation.
- Serial review checked state ownership, timeout/stale callback guards,
  waiting-page navigation isolation, fixed payloads, lifecycle and privacy.
  Strict center release bounds use the last converted sensor sample rather
  than the touch library's sub-threshold filtered coordinates.
- Installed Companion backup signature and executable hash verified. Old
  temporary firmware backup was missing; the stale main-directory binary was
  rejected as a recovery candidate. Recovery rebuilt successfully from `f7ea349`
  with both USB-mic build stages passing; this is a source-rebuilt recovery
  image, not a byte-for-byte readback of installed flash.
- New firmware SHA-256:
  `5c5c0321e368da08f62c20dc49249cd4d92d9c63c96e3fbd9afcdecef6abeab0`.
- All 31 tracked firmware build inputs match the release mirror exactly.
- Candidate Companion signed and verified; installed Companion and original
  LaunchAgent remain unchanged pending paired installation/flash.
- New installation, flashing and physical acceptance remain pending.
