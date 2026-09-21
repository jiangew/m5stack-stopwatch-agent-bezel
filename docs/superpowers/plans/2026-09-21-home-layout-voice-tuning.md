# Home layout and voice tuning implementation plan

> **For agentic workers:** Use executing-plans inline in the current session;
> no subagents. Preview approval is a checkpoint before production edits.

**Goal:** Enlarge and lift the Home portrait and replace only the central voice.

**Architecture:** Preserve the renderer and audio-owner interfaces. Change
Home presentation constants and the ignored local task sample only.

**Tech Stack:** C++17/M5GFX native renderer, macOS local speech, FFmpeg, PlatformIO.

## Global constraints

- Follow the matching design; no BLE, Companion, protocol or navigation changes.
- Do not commit private audio, local paths, device identifiers or captured audio.
- Do not merge, push or upload without the required separate authorization.

## Task 1: Preview checkpoint

- [x] Make a disposable copy of renderer headers, leaving production unchanged.
- [x] Change connection y=44, battery group y=420, portrait center y=225,
  settled scale=1.18 and transition start=1.04 in the copy.
- [x] Render all four portraits plus Talking and transition scenarios.
- [x] Synthesize fixed phrase locally; apply pitch lowering and subtle metallic
  coloration, retaining mono 24kHz PCM16 and a duration under five seconds.
- [x] Present native preview and audition for user acceptance.

## Task 2: Approved production integration

Files: `include/RobotHomeUi.h`, `include/RobotHomeCharacters.h`,
`simulator/robot_home_ui_test.cpp`; ignored `include/RobotSpeechLocal.h`.

- [x] Update renderer test expectations to y=44/420/225 and scale=1.18;
  run `robot_home_ui_test.cpp` first to capture expected RED assertions.
- [x] Add frame boundary checks for all characters, transition endpoints and
  Talking phase peak: bitmap remains inside display; visible rim stays clear
  of status/battery. Account for existing black padding in the JPEGs.
- [x] Apply approved renderer changes; reduce Talking rise to 3px after the
  all-frame clearance test caught the 4px peak violating the safety margin.
- [x] Preserve prior private header and firmware in a private backup directory;
  embed approved audio using `scripts/embed_robot_speech.rb` without changing
  sample ownership or cancellation behavior.
- [x] Run all `simulator/*_test.cpp`, all four Ruby harnesses, asset ring test,
  deterministic art generator check, native preview and `pio run -d usb-mic`.
- [x] Review diff against this scope; record tests and artifact SHA-256.
- [x] Commit only tracked layout/tests/docs; never include private audio or
  pre-existing unrelated BLE changes in the layout commit.

## Task 3: Installation and physical acceptance

- [ ] Obtain fresh unique download-port enumeration and explicit confirmation.
- [ ] Upload verified USB-mic image; require successful written-data hash checks.
- [ ] Verify HID/microphone enumeration and quota sync separately.
- [ ] User checks four complete enlarged rings, status/battery clearance,
  center voice clarity, silent character switching and left workspace cycle.
- [ ] Record only observed checks as passed; no automatic merge or push.

## Verification evidence

- RED: previous renderer failed y=225 assertion. Expanded peak-clearance test
  then caught the Talking rise; reducing it by 1px produced GREEN.
- All 17 C++ executables pass with warnings-as-errors, including 14,080
  character/transition/Talking-frame combinations. All four compiled
  production-code Ruby harnesses pass; all four JPEG ring checks pass.
- Re-embedding art produces an identical header. Native M5GFX preview build
  passes with its existing third-party VLA warning; public four-character
  previews were refreshed from the production renderer.
- USB-mic build passes; 1,706,768-byte application SHA-256:
  `cdd02b7442ceecfe7359caa13cd7248228ebe75b155905defae6f495c50af91e`.
- Approved menacing v3 audition: 3.226375 seconds, mono PCM16 at 24kHz,
  SHA-256 `f775ff01dcfee20767009a292bf9db9c4ae889332ecbd199b50dac23ffb6cc3c`.
  The unused secondary sample was preserved from the old private header.
- Old firmware and private header were backed up before replacement. Installed
  firmware still uses the previous voice; this candidate has not been flashed.
- Existing unrelated BLE working-tree changes remain untouched; Companion,
  permissions and LaunchAgent remain unchanged. No XCTest claimed or required
  for these firmware-only changes. Physical sound/display acceptance pending.
