# Robot Home Speech Implementation Plan

> Publication follow-up: the user approved a code-only public version. The
> private PCM and its commits are excluded from public ancestry; default builds
> provide silent animation until authorized local audio is supplied. The build
> hashes and physical observations below describe the private installed image.

> **For agentic workers:** Use executing-plans in the current session, serially.

**Goal:** Play two approved local speech clips from Home with one talking animation.

**Architecture:** Reuse the USB microphone capture task's exclusive local-speaker
path. Fixed clip selection and bounded cancellation extend that path without
adding USB output, application commands or a second audio owner.

**Tech Stack:** C++17, M5Unified, ESP32 FreeRTOS, native C++/Ruby harnesses, PlatformIO.

## Global constraints

The approved interaction and safety boundaries are in
`docs/superpowers/specs/2026-09-17-robot-home-voice.md`.
Do not change Companion, default wireless behavior, protocol or LaunchAgent.
Do not install models, merge, push, or flash without fresh exact-port confirmation.

## Task 1: Speech selection, cancellation, and assets

Files: `include/UsbMic.h`, `src/UsbMic.cpp`, new fixed audio assets and native tests.

- [ ] Add failing tests for selecting tap versus directional speech, busy rejection,
  recording priority, cancellation before/during playback and no queued retry.
- [ ] Preserve approved PCM samples in static read-only storage. Derive playback
  timeout from clip sample count plus bounded drain/setup allowance.
- [ ] Extend the existing audio-owner task, keeping all codec switches there.
  UI may only request or cancel. Check cancellation during guard, codec setup,
  playback and drain, and always restore the microphone on early exit.
- [ ] Run native tests and review phase publication and cancellation races.

## Task 2: Unified talking animation and gestures

Files: `include/RobotHomeInteraction.h`, `include/RobotHomeUi.h`, `src/main.cpp`,
`simulator/robot_home_interaction_test.cpp`, `simulator/robot_home_ui_test.cpp`,
`simulator/robot_home_swipe_test.rb`.

- [ ] First add failing cases: all local speech gestures use Talking; a gesture
  triggers once; repeat input does not restart; wake/left/long hold never speak.
- [ ] Add blue-eye pulse and small faceplate movement inside existing circular
  bounds. Preserve battery, status, power overlay and 20 fps limit.
- [ ] Cancel on left exit, actual mode transition, sleep and power overlay.
- [ ] Run native gesture integration and renderer tests across animation frames.

## Task 3: Verification and installation gate

- [ ] Update bilingual Home interaction documentation and audio provenance.
- [ ] Run all native tests, actual gesture harness, `git diff --check`, and USB-mic
  PlatformIO build. Review microphone priority, default-build guards and bounds.
- [ ] Save candidate firmware and SHA-256 separately from baseline backup.
- [ ] Report test/build results without claiming physical acceptance.
- [ ] Enumerate fresh download port, obtain exact-port confirmation, then upload.
- [ ] User verifies both lines, shared animation, repeated input, left cancellation,
  wake-only tap, power behavior, four-page controls and USB microphone recovery.

## Progress

## Resumed verification — 2026-09-20

Implementation tasks 1–2 and task 3's local verification are complete. Physical
installation remains pending; do not interpret the outstanding upload checklist
as authority to reuse a historical port confirmation.

- Baseline: 16 native C++ tests and existing actual Home swipe harness passed.
- RED: new animation API absent; actual audio-owner test failed against the old
  chime-only sample/rate; swipe test failed before cancellation integration;
  renderer geometry test failed before Talking faceplate motion existed.
- GREEN: all 16 native C++ tests plus four Ruby-driven compiled production-code
  harnesses passed after implementation (swipe, request, audio owner, reaction).
- Additional regression checks: cancellation and microphone preemption during
  codec setup, playback and DMA drain; invalid clips, busy rejection and alt1
  pulse; no replay on recording completion. Hardware calls are doubles, not
  assertions about actual audio or USB capture.
- USB-mic PlatformIO build: both preparation and USB-mic environments passed;
  no `warning:` or `error:` lines in the build log. USB image flash use 1639535
  bytes, static RAM use 99980 bytes. Default wireless target not flashed.
- Native preview passed after adding the omitted `home-talking` scenario to its
  allowlist. Checked 466x466 Talking image; existing native M5GFX/archive warnings
  are separate from the warning-free USB-mic build.
- `git diff --check` passed. Serial spec/standards review covered local-only
  ownership, cancellation, microphone restoration, wake/gesture isolation,
  default-build guards, no payload logging and no Companion/protocol changes.
- Audition PCM samples preserved exactly; local synthesized asset provenance
  documented separately from the repository's MIT source license. Do not push
  without resolving distribution rights for the system voice output.
- Candidate firmware SHA-256:
  `f0191b3a41e888e5c293616d4dfd12e0ae024d85effbb78728a3c6a1cf04d6e9`.
- Baseline firmware SHA-256:
  `9e8b1267431a8c9632b3f6e05aae466df165ed809de5b1320b0d8e342894a23d`.
- Companion, signatures, permissions, LaunchAgent, remote and installed firmware
  remain unchanged. No XCTest run or physical speech acceptance is claimed.

## Subsequent upload and user-observed acceptance

- After fresh device enumeration and explicit exact-port authorization, the
  USB-mic upload succeeded and all written-data hashes were verified. Uploaded
  firmware matches the candidate SHA-256 above. Original backup retained.
- User confirmed both spoken lines, unified talking animation, repeat suppression
  and left-swipe cancellation were normal after upload.
- Following the QuickTime procedure, user confirmed microphone recording quality,
  silent Home reactions during recording, and restored speech after quitting
  QuickTime were normal. No recording was collected or analyzed by the assistant.
- Wake-only tap, power-overlay interruption, offline speech and a complete
  four-workspace regression have not been separately confirmed for this image.
- Companion, signature, permissions and LaunchAgent were not changed. No merge
  or push. Audio redistribution clearance remains a separate publication gate.
